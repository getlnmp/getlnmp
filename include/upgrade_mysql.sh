#!/usr/bin/env bash

Backup_MySQL()
{
    echo "Starting backup all databases..."
    echo "If the database is large, the backup time will be longer."
    if [ -s /usr/local/mysql/bin/mysqldump ]; then
        /usr/local/mysql/bin/mysqldump --defaults-file=~/.my.cnf --all-databases > /root/mysql_all_backup${Upgrade_Date}.sql
    else
        echo "mysqldump not found, please check if MySQL is installed correctly."
    fi
    if [ $? -eq 0 ]; then
        echo "MySQL databases backup successfully.";
    else
        echo "MySQL databases backup failed,Please backup databases manually!"
    fi
    lnmp stop
    if [[ ! "${MySQL_Data_Dir}" =~ ^/usr/local/mysql/ ]]; then
        mv ${MySQL_Data_Dir} ${MySQL_Data_Dir}${Upgrade_Date}
    fi
    mv /usr/local/mysql /usr/local/oldmysql${Upgrade_Date}
    mv /etc/my.cnf /usr/local/oldmysql${Upgrade_Date}/my.cnf.bak.${Upgrade_Date}
    if echo "${mysql_version}" | grep -Eqi '^5\.5\.' &&  echo "${cur_mysql_version}" | grep -Eqi '^5\.6\.';then
        sed -i 's/STATS_PERSISTENT=0//g' /root/mysql_all_backup${Upgrade_Date}.sql
    fi
}

Upgrade_MySQL51()
{
    Tar_Cd mysql-${mysql_version}.tar.gz mysql-${mysql_version}
    MySQL_Gcc7_Patch
    if [ $InstallInnodb = "y" ]; then
        ./configure --prefix=/usr/local/mysql --with-extra-charsets=complex --enable-thread-safe-client --enable-assembler --with-mysqld-ldflags=-all-static --with-charset=utf8 --enable-thread-safe-client --with-big-tables --with-readline --with-ssl --with-embedded-server --enable-local-infile --with-plugins=innobase ${MySQL51MAOpt}
    else
        ./configure --prefix=/usr/local/mysql --with-extra-charsets=complex --enable-thread-safe-client --enable-assembler --with-mysqld-ldflags=-all-static --with-charset=utf8 --enable-thread-safe-client --with-big-tables --with-readline --with-ssl --with-embedded-server --enable-local-infile ${MySQL51MAOpt}
    fi
    sed -i '/set -ex;/,/done/d' Makefile
    Make_Install

    groupadd mysql
    useradd -s /sbin/nologin -M -g mysql mysql

cat > /etc/my.cnf<<EOF
[client]
#password	= your_password
port		= 3306
socket		= /tmp/mysql.sock

[mysqld]
port		= 3306
socket		= /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 8M
tmp_table_size = 16M

#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_format=mixed
server-id	= 1
expire_logs_days = 10

default_storage_engine = InnoDB
#innodb_data_home_dir = ${MySQL_Data_Dir}
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = ${MySQL_Data_Dir}
#innodb_buffer_pool_size = 16M
#innodb_additional_mem_pool_size = 2M
#innodb_log_file_size = 5M
#innodb_log_buffer_size = 8M
#innodb_flush_log_at_trx_commit = 1
#innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout
EOF
    if [ "${InstallInnodb}" = "y" ]; then
        sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    else
        sed -i '/^default_storage_engine/d' /etc/my.cnf
        sed -i '/skip-external-locking/i\default_storage_engine = MyISAM\nloose-skip-innodb' /etc/my.cnf
    fi
    MySQL_Opt
    if [ -d "${MySQL_Data_Dir}" ]; then
        rm -rf ${MySQL_Data_Dir}/*
    else
        mkdir -p ${MySQL_Data_Dir}
    fi
    chown -R mysql:mysql ${MySQL_Data_Dir}
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql
}

Upgrade_MySQL55()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "Starting upgrade MySQL ${mysql_version} Using Generic Binaries..."
        Tar_Cd ${mysql_src}
        mkdir /usr/local/mysql
        mv mysql-${mysql_version}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "Starting upgrade MySQL ${mysql_version} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            MySQL_WITH_SSL='-DWITH_SSL=bundled'
        else
            MySQL_WITH_SSL=''
        fi
        Tar_Cd mysql-${mysql_version}.tar.gz mysql-${mysql_version}
        MySQL_ARM_Patch
        if  g++ -dM -E -x c++ /dev/null | grep -F __cplusplus | cut -d' ' -f3 | grep -Eqi "^2017|202[0-9]"; then
            sed -i '1s/^/set(CMAKE_CXX_STANDARD 11)\n/' CMakeLists.txt
        fi
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_READLINE=1 -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_SSL}
        Make_Install
    fi

    groupadd mysql
    useradd -s /sbin/nologin -M -g mysql mysql

    cat > /etc/my.cnf<<EOF
[client]
#password	= your_password
port		= 3306
socket		= /tmp/mysql.sock

[mysqld]
port		= 3306
socket		= /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 8M
tmp_table_size = 16M

#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_format=mixed
server-id	= 1
expire_logs_days = 10

default_storage_engine = InnoDB
#innodb_data_home_dir = ${MySQL_Data_Dir}
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = ${MySQL_Data_Dir}
#innodb_buffer_pool_size = 16M
#innodb_additional_mem_pool_size = 2M
#innodb_log_file_size = 5M
#innodb_log_buffer_size = 8M
#innodb_flush_log_at_trx_commit = 1
#innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

${MySQLMAOpt}
EOF
    if [ "${InstallInnodb}" = "y" ]; then
        sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    else
        sed -i '/^default_storage_engine/d' /etc/my.cnf
        sed -i '/skip-external-locking/i\default_storage_engine = MyISAM\nloose-skip-innodb' /etc/my.cnf
    fi
    MySQL_Opt
    if [ -d "${MySQL_Data_Dir}" ]; then
        rm -rf ${MySQL_Data_Dir}/*
    else
        mkdir -p ${MySQL_Data_Dir}
    fi
    chown -R mysql:mysql ${MySQL_Data_Dir}
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql
}

Upgrade_MySQL56()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "Starting upgrade MySQL ${mysql_version} Using Generic Binaries..."
        Tar_Cd ${mysql_src}
        mkdir /usr/local/mysql
        mv mysql-${mysql_version}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "Starting upgrade MySQL ${mysql_version} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            Install_Openssl_New
            MySQL_WITH_SSL='-DWITH_SSL=/usr/local/openssl1.1.1'
        else
            MySQL_WITH_SSL=''
        fi
        Tar_Cd mysql-${mysql_version}.tar.gz mysql-${mysql_version}
        if  g++ -dM -E -x c++ /dev/null | grep -F __cplusplus | cut -d' ' -f3 | grep -Eqi "^2017|202[0-9]"; then
            sed -i '1s/^/set(CMAKE_CXX_STANDARD 11)\n/' CMakeLists.txt
        fi
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_SSL}
        Make_Install
    fi

    groupadd mysql
    useradd -s /sbin/nologin -M -g mysql mysql

cat > /etc/my.cnf<<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
port        = 3306
socket      = /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 8M
tmp_table_size = 16M
performance_schema_max_table_instances = 500

explicit_defaults_for_timestamp = true
#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_format=mixed
server-id   = 1
expire_logs_days = 10

#loose-innodb-trx=0
#loose-innodb-locks=0
#loose-innodb-lock-waits=0
#loose-innodb-cmp=0
#loose-innodb-cmp-per-index=0
#loose-innodb-cmp-per-index-reset=0
#loose-innodb-cmp-reset=0
#loose-innodb-cmpmem=0
#loose-innodb-cmpmem-reset=0
#loose-innodb-buffer-page=0
#loose-innodb-buffer-page-lru=0
#loose-innodb-buffer-pool-stats=0
#loose-innodb-metrics=0
#loose-innodb-ft-default-stopword=0
#loose-innodb-ft-inserted=0
#loose-innodb-ft-deleted=0
#loose-innodb-ft-being-deleted=0
#loose-innodb-ft-config=0
#loose-innodb-ft-index-cache=0
#loose-innodb-ft-index-table=0
#loose-innodb-sys-tables=0
#loose-innodb-sys-tablestats=0
#loose-innodb-sys-indexes=0
#loose-innodb-sys-columns=0
#loose-innodb-sys-fields=0
#loose-innodb-sys-foreign=0
#loose-innodb-sys-foreign-cols=0

default_storage_engine = InnoDB
#innodb_data_home_dir = ${MySQL_Data_Dir}
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = ${MySQL_Data_Dir}
#innodb_buffer_pool_size = 16M
#innodb_log_file_size = 5M
#innodb_log_buffer_size = 8M
#innodb_flush_log_at_trx_commit = 1
#innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

${MySQLMAOpt}
EOF

    if [ "${InstallInnodb}" = "y" ]; then
        sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    else
        sed -i '/^default_storage_engine/d' /etc/my.cnf
        sed -i '/skip-external-locking/i\innodb = OFF\nignore-builtin-innodb\nskip-innodb\ndefault_storage_engine = MyISAM\ndefault_tmp_storage_engine = MyISAM' /etc/my.cnf
        sed -i 's/^#loose-innodb/loose-innodb/g' /etc/my.cnf
    fi
    MySQL_Opt
    if [ -d "${MySQL_Data_Dir}" ]; then
        rm -rf ${MySQL_Data_Dir}/*
    else
        mkdir -p ${MySQL_Data_Dir}
    fi
    chown -R mysql:mysql ${MySQL_Data_Dir}
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF

    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql
}

Upgrade_MySQL57()
{   
    Ncurses5_Compat_Check
    rm -rf /etc/my.cnf
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "Starting upgrade MySQL ${mysql_version} Using Generic Binaries..."
        if [ -d mysql-${mysql_version}-linux-glibc2.12-${DB_ARCH} ]; then
            rm -rf mysql-${mysql_version}-linux-glibc2.12-${DB_ARCH}
        fi
        Tar_Cd ${mysql_src}
        mkdir /usr/local/mysql
        mv mysql-${mysql_version}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "Starting upgrade MySQL ${mysql_version} Using Source code..."
        if [ -d ${Mysql_Ver} ]; then
            rm -rf ${Mysql_Ver}
        fi
        if [ "${isOpenSSL3}" = "y" ]; then
            Install_Openssl_New
            MySQL_WITH_SSL='-DWITH_SSL=/usr/local/openssl1.1.1'
        else
            MySQL_WITH_SSL='-DWITH_SSL=system'
        fi
        Tar_Cd ${mysql_src} mysql-${mysql_version}
        #Install_Boost
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        mkdir -p mysql-build && cd mysql-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
            -DSYSCONFDIR=/etc \
            -DWITH_MYISAM_STORAGE_ENGINE=1 \
            -DWITH_INNOBASE_STORAGE_ENGINE=1 \
            -DWITH_PARTITION_STORAGE_ENGINE=1 \
            -DWITH_FEDERATED_STORAGE_ENGINE=1 \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITH_SYSTEMD=1 \
            -DDOWNLOAD_BOOST=ON \
			-DWITH_BOOST=/usr/local/mysql57_boost \
            ${MySQL_WITH_SSL}
        Make_Install
    fi


cat > /etc/my.cnf<<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
# Basic
port        = 3306
socket      = /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
log_error = ${MySQL_Data_Dir}/mysqld.err
pid-file = ${MySQL_Data_Dir}/mysqld.pid

# Network / buffers
max_allowed_packet = 1M
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
tmp_table_size = 16M

# connections
max_connections = 500
max_connect_errors = 100
open_files_limit = 10000
table_open_cache       = 1024
thread_cache_size      = 32

# Binary logging
log_bin            = mysql-bin
server-id          = 1
binlog_format      = ROW
expire_logs_days   = 10

# Performance Schema
performance_schema = ON
performance_schema_max_table_instances = 500

# Default engine
default_storage_engine = InnoDB

innodb_file_per_table = 1
innodb_data_home_dir = ${MySQL_Data_Dir}
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = ${MySQL_Data_Dir}
innodb_buffer_pool_size = 16M
innodb_log_file_size = 5M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

# MyISAM (legacy)
key_buffer_size                = 8M
myisam_sort_buffer_size        = 8M

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer_size = 2M
write_buffer_size = 2M

${MySQLMAOpt}
EOF

    MySQL_Opt
    if [ -d "${MySQL_Data_Dir}" ]; then
        rm -rf ${MySQL_Data_Dir}
        mkdir -p ${MySQL_Data_Dir}
    else
        mkdir -p ${MySQL_Data_Dir}
    fi
    chown -R mysql:mysql /usr/local/mysql/
    /usr/local/mysql/bin/mysqld --initialize-insecure --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}

    rm -rf /etc/systemd/system/mysql.service
    rm -rf /etc/systemd/system/mysqld.service
    \cp ${cur_dir}/init.d/mysql.service5.7 /etc/systemd/system/mysql.service
    ln -sf /etc/systemd/system/mysql.service /etc/systemd/system/mysqld.service
    if [ -s /usr/local/mysql/bin/mysqld_pre_systemd ]; then
        sed -i 's/^#ExecStartPre=/ExecStartPre=/g' /etc/systemd/system/mysql.service
    fi
    systemctl daemon-reload

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF

    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql
}

Upgrade_MySQL80()
{
    rm -f /etc/my.cnf
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        if [ -d ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH} ]; then
            rm -rf ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}
        fi
        Tar_Cd ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ -d ${Mysql_Ver} ]; then
            rm -rf ${Mysql_Ver}
        fi
        Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
        #Install_Boost
        mkdir -p mysql-build && cd mysql-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
            -DSYSCONFDIR=/etc \
            -DWITH_MYISAM_STORAGE_ENGINE=1 \
            -DWITH_INNOBASE_STORAGE_ENGINE=1 \
            -DWITH_FEDERATED_STORAGE_ENGINE=1 \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITH_SYSTEMD=1 \
            -DDOWNLOAD_BOOST=ON \
			-DWITH_BOOST=/usr/local/mysql80_boost
        Make_Install
    fi

cat > /etc/my.cnf<<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
# Basic
port        = 3306
socket      = /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
log_error = ${MySQL_Data_Dir}/mysqld.err
pid-file = ${MySQL_Data_Dir}/mysqld.pid

# Network / buffers
max_allowed_packet = 1M
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
tmp_table_size = 16M

explicit_defaults_for_timestamp = true

# connections
max_connections = 500
max_connect_errors = 100
open_files_limit = 10000
table_open_cache       = 1024
thread_cache_size      = 32


# Authentication (allowed but legacy)
#default_authentication_plugin = mysql_native_password

# Binary logging
log_bin                    = mysql-bin
server-id                  = 1
#binlog_format              = ROW
binlog_expire_logs_seconds = 864000

# Performance Schema
performance_schema = ON
performance_schema_max_table_instances = 500

# Default engine
default_storage_engine = InnoDB

innodb_file_per_table = 1
innodb_data_home_dir = ${MySQL_Data_Dir}
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = ${MySQL_Data_Dir}
innodb_buffer_pool_size = 16M
#innodb_log_file_size = 5M (deprecated since mysql 8.4)
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

# NEW redo log configuration (replaces log_file_size + files_in_group)
innodb_redo_log_capacity       = 128M

# MyISAM (legacy, minimal)
key_buffer_size                = 8M

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer_size = 2M
write_buffer_size = 2M


${MySQLMAOpt}
EOF

    MySQL_Opt
    if [ -d "${MySQL_Data_Dir}" ]; then
        rm -rf ${MySQL_Data_Dir}
        mkdir -p ${MySQL_Data_Dir}
    else
        mkdir -p ${MySQL_Data_Dir}
    fi
    chown -R mysql:mysql /usr/local/mysql/
    /usr/local/mysql/bin/mysqld --initialize-insecure --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
    
    rm -rf /etc/systemd/system/mysql.service
    rm -rf /etc/systemd/system/mysqld.service
    # compiled mysql provides systemd service file
    # binary package only provides mysql.server init script, therefore we copy our own service file
    if [ -s /usr/local/mysql/lib/systemd/system/mysqld.service ]; then
        \cp /usr/local/mysql/lib/systemd/system/mysqld.service /etc/systemd/system/mysql.service
    elif [ -s /usr/local/mysql/usr/lib/systemd/system/mysqld.service ]; then
        \cp /usr/local/mysql/usr/lib/systemd/system/mysqld.service /etc/systemd/system/mysql.service
    else
        \cp ${cur_dir}/init.d/mysql.service8.0 /etc/systemd/system/mysql.service
    fi
    ln -sf /etc/systemd/system/mysql.service /etc/systemd/system/mysqld.service
    systemctl daemon-reload
    
    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF

    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql
}

Upgrade_MySQL84()
{
    rm -f /etc/my.cnf
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        if [ -d ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH} ]; then
            rm -rf ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}
        fi
        Tar_Cd ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ -d ${Mysql_Ver} ]; then
            rm -rf ${Mysql_Ver}
        fi
        Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
        mkdir -p mysql-build && cd mysql-build
        cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
        -DSYSCONFDIR=/etc \
        -DWITH_MYISAM_STORAGE_ENGINE=1 \
        -DWITH_INNOBASE_STORAGE_ENGINE=1 \
        -DWITH_FEDERATED_STORAGE_ENGINE=1 \
        -DDEFAULT_CHARSET=utf8mb4 \
        -DDEFAULT_COLLATION=utf8mb4_general_ci \
        -DENABLED_LOCAL_INFILE=1 \
        -DWITH_SYSTEMD=1 
        
        Make_Install
    fi

cat > /etc/my.cnf<<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
# basic settings
port        = 3306
socket      = /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
log_error = ${MySQL_Data_Dir}/mysqld.err
pid-file = ${MySQL_Data_Dir}/mysqld.pid

# Network / buffers
max_allowed_packet = 1M
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
tmp_table_size = 16M

explicit_defaults_for_timestamp = true

# connections
max_connections = 500
max_connect_errors = 100
open_files_limit = 10000
table_open_cache       = 1024
thread_cache_size      = 32

# MyISAM (legacy, keep minimal)
key_buffer_size                = 8M

# Character set / auth
# mysql_native_password  = ON
# (recommended long term: remove this and migrate users to caching_sha2_password)

# Binary logging
log-bin=mysql-bin
# binlog_format deprecated since mysql 8.4
#binlog_format=mixed
server-id   = 1
binlog_expire_logs_seconds = 864000

# Performance Schema
performance_schema = ON
performance_schema_max_table_instances = 500

# Default engine
default_storage_engine = InnoDB

innodb_file_per_table = 1
innodb_data_home_dir = ${MySQL_Data_Dir}
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = ${MySQL_Data_Dir}
innodb_buffer_pool_size = 16M
#innodb_log_file_size = 5M (deprecated since mysql 8.4)
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

# NEW redo log configuration (replaces log_file_size + files_in_group)
innodb_redo_log_capacity       = 128M

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 8M
sort_buffer_size = 8M
read_buffer_size = 1M
write_buffer_size = 1M


${MySQLMAOpt}
EOF

    MySQL_Opt
    if [ -d "${MySQL_Data_Dir}" ]; then
        rm -rf ${MySQL_Data_Dir}
        mkdir -p ${MySQL_Data_Dir}
    else
        mkdir -p ${MySQL_Data_Dir}
    fi
    chown -R mysql:mysql /usr/local/mysql/
    echo "Initializing MySQL data directory..."
    /usr/local/mysql/bin/mysqld --initialize-insecure --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}

    rm -rf /etc/systemd/system/mysql.service
    rm -rf /etc/systemd/system/mysqld.service
    # compiled mysql provides systemd service file
    # binary package only provides mysql.server init script, therefore we copy our own service file
    echo "Setting up MySQL systemd service..."
    if [ -s /usr/local/mysql/lib/systemd/system/mysqld.service ]; then
        \cp /usr/local/mysql/lib/systemd/system/mysqld.service /etc/systemd/system/mysql.service
    elif [ -s /usr/local/mysql/usr/lib/systemd/system/mysqld.service ]; then
        \cp /usr/local/mysql/usr/lib/systemd/system/mysqld.service /etc/systemd/system/mysql.service
    else
        \cp ${cur_dir}/init.d/mysql.service8.4 /etc/systemd/system/mysql.service
    fi
    ln -sf /etc/systemd/system/mysql.service /etc/systemd/system/mysqld.service
    systemctl daemon-reload

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF

    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql
}

Restore_Start_MySQL()
{
    chgrp -R mysql /usr/local/mysql/.
    ldconfig
    MySQL_Sec_Setting

    echo "Restore backup databases..."
    echo "Starting MySQL..."
    systemctl start mysql
    echo "Starting importing..."
    /usr/local/mysql/bin/mysql --defaults-file=~/.my.cnf < /root/mysql_all_backup${Upgrade_Date}.sql
    echo "Repair databases..."
    MySQL_Ver_Com=$(${cur_dir}/include/version_compare 8.0.16 ${mysql_version})
    if [ "${MySQL_Ver_Com}" != "1" ]; then
        systemctl stop mysql
        echo "Upgrading MySQL..."
        /usr/local/mysql/bin/mysqld --user=mysql --upgrade=FORCE &
        echo "Waiting for upgrade to start..."
        sleep 180
        /usr/local/mysql/bin/mysqladmin --defaults-file=~/.my.cnf shutdown
    else
        /usr/local/mysql/bin/mysql_upgrade -u root -p${DB_Root_Password}
    fi

    systemctl stop mysql
    TempMycnf_Clean
    cd ${cur_dir} && rm -rf ${cur_dir}/src/mysql-${mysql_version}

    lnmp start
    if [[ -s /usr/local/mysql/bin/mysql && -s /etc/my.cnf ]]; then
        Echo_Green "======== upgrade MySQL completed ======"
    else
        Echo_Red "======== upgrade MySQL failed ======"
        Echo_Red "upgrade MySQL log: /root/upgrade_mysq${Upgrade_Date}.log"
        echo "You upload upgrade_mysq${Upgrade_Date}.log to LNMP Forum for help."
    fi
}

Upgrade_MySQL()
{
    Check_DB
    if [ "${Is_MySQL}" = "n" ]; then
        Echo_Red "Current database was MariaDB, Can't run MySQL upgrade script."
        exit 1
    fi

    Verify_DB_Password

    cur_mysql_version=$(/usr/local/mysql/bin/mysql_config --version)
    mysql_version=""
    echo "Current MYSQL Version:${cur_mysql_version}"
    echo "You can get version number from http://dev.mysql.com/downloads/mysql/"
    echo "We only support upgrade MySQL to 8.0.x and 8.4.x"
    Echo_Yellow "Please input MySQL Version you want."
    read -p "(example: 8.4.7 ): " mysql_version
    if [ "${mysql_version}" = "" ]; then
        echo "Error: You must input MySQL Version!!"
        exit 1
    fi

    if [ "${mysql_version}" == "${cur_mysql_version}" ]; then
        echo "Error: The upgrade MYSQL Version is the same as the old Version!!"
        exit 1
    fi

    if echo "${mysql_version}" | grep -Eqi '^(8\.0\.|8\.4\.)';then
        echo "You will upgrade MySQL to version:$mysql_version"
    else
        Echo_Red "Error: You input MySQL Version was:${mysql_version}"
        Echo_Red "We only support to upgrade MySQL to 8.0.x and 8.4.x"
        exit 1
    fi

    if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]] && echo "${mysql_version}" | grep -Eqi '^5\.[5-7].';then
        read -p "Using Generic Binaries [y/n]: " Bin
        case "${Bin}" in
        [yY][eE][sS]|[yY])
            echo "You will install MySQL ${mysql_version} Using Generic Binaries."
            Bin="y"
            ;;
        [nN][oO]|[nN])
            echo "You will install MySQL ${mysql_version} Source code."
            Bin="n"
            ;;
        *)
            echo "Default install MySQL ${mysql_version} Using Generic Binaries."
            Bin="y"
            ;;
        esac
    elif [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" || "${DB_ARCH}" = "aarch64" ]] && echo "${mysql_version}" | grep -Eqi '^8\.';then
        read -p "Using Generic Binaries [y/n]: " Bin
        case "${Bin}" in
        [yY][eE][sS]|[yY])
            echo "You will install MySQL ${mysql_version} Using Generic Binaries."
            Bin="y"
            ;;
        [nN][oO]|[nN])
            echo "You will install MySQL ${mysql_version} Source code."
            Bin="n"
            ;;
        *)
            echo "Default install MySQL ${mysql_version} Using Generic Binaries."
            Bin="y"
            ;;
        esac
    else
        Bin="n"
    fi
    if [ "${Bin}" != "y" ] ; then
        #do you want to install the InnoDB Storage Engine?
        echo "==========================="

        InstallInnodb="y"
        Echo_Yellow "Do you want to install the InnoDB Storage Engine?"
        read -p "(Default yes,if you want please enter: y , if not please enter: n): " InstallInnodb

        case "${InstallInnodb}" in
        [yY][eE][sS]|[yY])
            echo "You will install the InnoDB Storage Engine"
            InstallInnodb="y"
           ;;
        [nN][oO]|[nN])
            echo "You will NOT install the InnoDB Storage Engine!"
           InstallInnodb="n"
           ;;
        *)
            echo "No input, The InnoDB Storage Engine will enable."
           InstallInnodb="y"
           ;;
        esac
    fi

    mysql_short_version=$(echo ${mysql_version} | cut -d. -f1-2)
    if [ ${mysql_version} != '' ]; then
        Mysql_Ver=mysql-${mysql_version}
    fi

    echo "=================================================="
    echo "You will upgrade MySQL Version to ${mysql_version}"
    echo "=================================================="

    if [ -s /usr/local/include/jemalloc/jemalloc.h ] && lsof -n|grep "libjemalloc.so"|grep -q "mysqld"; then
        MySQL51MAOpt='--with-mysqld-ldflags=-ljemalloc'
        MySQL55MAOpt="-DCMAKE_EXE_LINKER_FLAGS='-ljemalloc' -DWITH_SAFEMALLOC=OFF"
    elif [ -s /usr/local/include/gperftools/tcmalloc.h ] && lsof -n|grep "libtcmalloc.so"|grep -q "mysqld"; then
        MySQL51MAOpt='--with-mysqld-ldflags=-ltcmalloc'
        MySQL55MAOpt="-DCMAKE_EXE_LINKER_FLAGS='-ltcmalloc' -DWITH_SAFEMALLOC=OFF"
    else
        MySQL51MAOpt=''
        MySQL55MAOpt=''
    fi

    Press_Start

    echo "============================check files=================================="
    cd ${cur_dir}/src
    if [[ "${Bin}" = "y" && "${mysql_short_version}" = "8.0" ]]; then
        mysql_src="mysql-${mysql_version}-linux-glibc2.28-${DB_ARCH}.tar.xz"
    elif [[ "${Bin}" = "y" && "${mysql_short_version}" = "8.4" ]]; then
        mysql_src="mysql-${mysql_version}-linux-glibc2.28-${DB_ARCH}.tar.xz"
    elif [[ "${Bin}" = "y" && "${mysql_short_version}" =~ ^5\.[5-7]$ ]]; then
        mysql_src="mysql-${mysql_version}-linux-glibc2.12-${DB_ARCH}.tar.gz"
    else
            mysql_src="mysql-${mysql_version}.tar.gz"
    fi
    if [ -s "${mysql_src}" ]; then
        echo "${mysql_src} [found]"
    else
        Download_Files https://cdn.mysql.com/Downloads/MySQL-${mysql_short_version}/${mysql_src} ${mysql_src}
        if [ $? -eq 0 ]; then
            echo "Download ${mysql_src} successfully!"
        else
            Download_Files https://cdn.mysql.com/archives/mysql-${mysql_short_version}/${mysql_src} ${mysql_src}
            if [ $? -ne 0 ]; then
                echo "You enter MySQL Version was: ${mysql_version}"
                Echo_Red "Error! You entered a wrong version number, please check!"
                sleep 5
                exit 1
            fi
        fi
    fi
    Check_Openssl
    DB_BIN_Opt
    if [ "${Bin}" != "y" ]; then
        Echo_Blue "Install dependent packages..."
        . ${cur_dir}/include/only.sh
        DB_Dependent
    fi
    echo "============================check files=================================="

    Backup_MySQL
    if [ "${mysql_short_version}" = "8.0" ]; then
        Upgrade_MySQL80
    elif [ "${mysql_short_version}" = "8.4" ]; then
        Upgrade_MySQL84
    else
        Echo_Red "We only support to upgrade MySQL to 8.0.x and 8.4.x"
        exit 1
    fi
    Restore_Start_MySQL
}
