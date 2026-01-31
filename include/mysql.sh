#!/usr/bin/env bash

# mysql ssl requirements:
# mysql 5.1 - 5.5 : openssl 0.9.8 or 1.0.x
# mysql 5.6 - 5.7 : openssl 1.0.x or 1.1.x
# mysql 8.0+      : openssl 1.1.x or 3.x
# mysql 8.4+    : openssl 3.x
# for best performance, mysql 5.7 should be compiled with openssl 1.1.1, mysql 8.0+ should be compiled with openssl 3.x


# deprecated as we dropped support for mysql 5.5
MySQL_ARM_Patch()
{
    if [ "${Is_ARM}" = "y" ]; then
        patch -p1 < ${cur_dir}/src/patch/mysql-5.5-fix-arm-client_plugin.patch
    fi
}

# deprecated as we dropped support for mysql 5.1
MySQL_Gcc7_Patch()
{
    if gcc -dumpversion|grep -Eq "^([7-9]|10)"; then
        echo "gcc version: 7+"
        if [ "${DBSelect}" = "1" ] || echo "${mysql_version}" | grep -Eqi '^5\.1.'; then
            patch -p1 < ${cur_dir}/src/patch/mysql-5.1-mysql-gcc7.patch
        fi
    fi
}

# initialize mysql data directory with no password generated for root user
MySQL_Initialize_DB() {
    /usr/local/mysql/bin/mysqld --initialize-insecure --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
}

MySQL_Add_UG() {
    groupadd mysql
    useradd -s /sbin/nologin -M -g mysql mysql
}



MySQL_Sec_Setting()
{
    if [ -d "/proc/vz" ]; then
        ulimit -s unlimited
    fi

    if [ -d "/etc/mysql" ]; then
        mv /etc/mysql /etc/mysql.backup.$(date +%Y%m%d)
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable mysql.service
    fi
    echo "Starting MySQL..."
    systemctl start mysql

    ln -sf /usr/local/mysql/bin/mysql /usr/bin/mysql
    ln -sf /usr/local/mysql/bin/mysqld /usr/bin/mysqld
    ln -sf /usr/local/mysql/bin/mysqldump /usr/bin/mysqldump
    ln -sf /usr/local/mysql/bin/myisamchk /usr/bin/myisamchk
    ln -sf /usr/local/mysql/bin/mysqld_safe /usr/bin/mysqld_safe
    ln -sf /usr/local/mysql/bin/mysqlcheck /usr/bin/mysqlcheck
    
    echo "Waiting for MySQL to re-start..."
    systemctl restart mysql
    sleep 2
    # set root password using mysqladmin
    echo "Setting MySQL root password..."
    # add default my.cnf file for mysqladmin to prevent hight priority ~/.my.cnf
    if [ -s ~/.my.cnf ]; then
        /usr/local/mysql/bin/mysqladmin --defaults-file=/etc/my.cnf -u root password "${DB_Root_Password}"
    else
        /usr/local/mysql/bin/mysqladmin -u root password "${DB_Root_Password}"
    fi
    if [ $? -ne 0 ]; then
        echo "failed, try other way..."
        systemctl restart mysql
        cat >~/.emptymy.cnf<<EOF
[client]
user=root
password=''
EOF
        /usr/local/mysql/bin/mysql --defaults-file=~/.emptymy.cnf -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_Root_Password}';"
        [ $? -eq 0 ] && echo "Set password Sucessfully." || echo "Set password failed!"
        /usr/local/mysql/bin/mysql --defaults-file=~/.emptymy.cnf -e "FLUSH PRIVILEGES;"
        [ $? -eq 0 ] && echo "FLUSH PRIVILEGES Sucessfully." || echo "FLUSH PRIVILEGES failed!"
        rm -f ~/.emptymy.cnf
    fi
    systemctl restart mysql

    Make_TempMycnf "${DB_Root_Password}"
    Do_Query ""
    if [ $? -eq 0 ]; then
        echo "OK, MySQL root password correct."
    fi

    echo "Remove anonymous users..."
    Do_Query "DELETE FROM mysql.user WHERE User='';"
    Do_Query "DROP USER IF EXISTS ''@'%';"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"
    echo "Disallow root login remotely..."
    Do_Query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"
    echo "Remove test database..."
    Do_Query "DROP DATABASE IF EXISTS test;"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"
    echo "Reload privilege tables..."
    Do_Query "FLUSH PRIVILEGES;"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"

    systemctl restart mysql
    systemctl stop mysql  
}

MySQL_Opt()
{
    if [[ ${MemTotal} -gt 1024 && ${MemTotal} -lt 2048 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 128#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 16#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 16M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 32M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 128M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 32M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 1000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 2048 && ${MemTotal} -lt 4096 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 256#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 32#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 32M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 256M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 64M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 2000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 4096 && ${MemTotal} -lt 8192 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 512#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 64#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 64M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 512M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 128M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 4000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 8192 && ${MemTotal} -lt 16384 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 1024#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 128#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 128M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 128M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 1024M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 256M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 6000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 16384 && ${MemTotal} -lt 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 512M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 2048#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 256#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 256M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 256M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 2048M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 512M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 8000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 1024M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 4096#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 512#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 512M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 512M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 4096M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 1024M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 10000#" /etc/my.cnf
    fi
}

Check_MySQL_Data_Dir()
{
    if [ -d "${MySQL_Data_Dir}" ]; then
        datetime=$(date +"%Y%m%d%H%M%S")
        mkdir -p /root/mysql-data-dir-backup${datetime}/
        \cp ${MySQL_Data_Dir}/* /root/mysql-data-dir-backup${datetime}/
        rm -rf ${MySQL_Data_Dir}
        mkdir -p ${MySQL_Data_Dir}
    else
        mkdir -p ${MySQL_Data_Dir}
    fi
    chown -R mysql:mysql /usr/local/mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
}

Install_MySQL_51()
{
    Echo_Blue "[+] Installing ${Mysql_Ver}..."
    rm -f /etc/my.cnf
    Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
    MySQL_Gcc7_Patch
    if [ "${InstallInnodb}" = "y" ]; then
        ./configure --prefix=/usr/local/mysql --with-extra-charsets=complex --enable-thread-safe-client --enable-assembler --with-mysqld-ldflags=-all-static --with-charset=utf8 --enable-thread-safe-client --with-big-tables --with-readline --with-ssl --with-embedded-server --enable-local-infile --with-plugins=innobase ${MySQL51MAOpt}
    else
        ./configure --prefix=/usr/local/mysql --with-extra-charsets=complex --enable-thread-safe-client --enable-assembler --with-mysqld-ldflags=-all-static --with-charset=utf8 --enable-thread-safe-client --with-big-tables --with-readline --with-ssl --with-embedded-server --enable-local-infile ${MySQL51MAOpt}
    fi
    sed -i '/set -ex;/,/done/d' Makefile
    Make_Install

    MySQL_Add_UG

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
#innodb_file_per_table = 1
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
        sed -i 's#default_storage_engine.*#default_storage_engine = MyISAM#' /etc/my.cnf
    fi
    MySQL_Opt
    Check_MySQL_Data_Dir
    chown -R mysql:mysql /usr/local/mysql
    /usr/local/mysql/bin/mysql_install_db --user=mysql --datadir=${MySQL_Data_Dir}
    chown -R mysql:mysql ${MySQL_Data_Dir}
    \cp /usr/local/mysql/share/mysql/mysql.server /etc/init.d/mysql
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
    /usr/local/mysql/lib/mysql
    /usr/local/lib
EOF
    ldconfig

    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

Install_MySQL_55()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            MySQL_WITH_SSL='-DWITH_SSL=bundled'
        else
            MySQL_WITH_SSL=''
        fi
        Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
        MySQL_ARM_Patch
        if  g++ -dM -E -x c++ /dev/null | grep -F __cplusplus | cut -d' ' -f3 | grep -Eqi "^(2017|202[0-9])"; then
            sed -i '1s/^/set(CMAKE_CXX_STANDARD 11)\n/' CMakeLists.txt
        fi
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        mkdir -p mysql-build && cd mysql-build
        cmake ..\
            -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
            -DSYSCONFDIR=/etc \
            -DWITH_MYISAM_STORAGE_ENGINE=1 \
            -DWITH_INNOBASE_STORAGE_ENGINE=1 \
            -DWITH_PARTITION_STORAGE_ENGINE=1 \
            -DWITH_FEDERATED_STORAGE_ENGINE=1 \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            ${MySQL_WITH_SSL}
        Make_Install
    fi

    MySQL_Add_UG

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
#innodb_file_per_table = 1
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
    Check_MySQL_Data_Dir
    chown -R mysql:mysql /usr/local/mysql
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
    \cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
    \cp ${cur_dir}/init.d/mysql.service /etc/systemd/system/mysql.service
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
/usr/local/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

Install_MySQL_56()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            Install_Openssl_New
            MySQL_WITH_SSL='-DWITH_SSL=/usr/local/openssl1.1.1'
        else
            MySQL_WITH_SSL='yes'
        fi
        Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
        if  g++ -dM -E -x c++ /dev/null | grep -F __cplusplus | cut -d' ' -f3 | grep -Eqi "^(2017|202[0-9])"; then
            sed -i '1s/^/set(CMAKE_CXX_STANDARD 11)\n/' CMakeLists.txt
        fi
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_SSL}
        Make_Install
    fi

    MySQL_Add_UG

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
#innodb_file_per_table = 1
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
        sed -i '/skip-external-locking/i\innodb=OFF\nignore-builtin-innodb\nskip-innodb\ndefault_storage_engine = MyISAM\ndefault_tmp_storage_engine = MyISAM' /etc/my.cnf
        sed -i 's/^#loose-innodb/loose-innodb/g' /etc/my.cnf
    fi
    MySQL_Opt
    Check_MySQL_Data_Dir
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
    \cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
    \cp ${cur_dir}/init.d/mysql.service /etc/systemd/system/mysql.service
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
    /usr/local/mysql/lib
    /usr/local/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

# mysql 5.7.44 still only support openssl 1.1.1. But binary package uses openssl 3.
# mysql 5.7 BIN is built with libncurses.so.5, but most OS use libncurses.so.6 now.
# So we need to install ncurses5 compatibility library for mysql 5.7 BIN package

Install_MySQL_57()
{
    rm -rf /etc/my.cnf
    Ncurses5_Compat_Check
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            echo "MySQL 5.7.x not support OpenSSL 3, so we will install OpenSSL 1.1.1."
            Install_Openssl_New
            MySQL_WITH_SSL='-DWITH_SSL=/usr/local/openssl1.1.1'
        else
            MySQL_WITH_SSL='-DWITH_SSL=system'
        fi
        Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
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
    
    MySQL_Add_UG

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
    Check_MySQL_Data_Dir
    MySQL_Initialize_DB
 
    \cp ${cur_dir}/init.d/mysql.service5.7 /etc/systemd/system/mysql.service
    ln -sf /etc/systemd/system/mysql.service /etc/systemd/system/mysqld.service
    if [ -s /usr/local/mysql/bin/mysqld_pre_systemd ]; then
        sed -i 's/^#ExecStartPre=/ExecStartPre=/g' /etc/systemd/system/mysql.service
    fi
    systemctl daemon-reload
 
    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
    /usr/local/mysql/lib
    /usr/local/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

# support both openssl 1.1.1 and openssl 3
Install_MySQL_80()
{
    rm -f /etc/my.cnf
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
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

    MySQL_Add_UG

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
    Check_MySQL_Data_Dir
    MySQL_Initialize_DB
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
    /usr/local/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

# mysql 8.4 has boost bundled in source package
# support openssl 1.1.1 and openssl 3
# for best performance, please use openssl 3
Install_MySQL_84()
{
    rm -f /etc/my.cnf
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
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

    MySQL_Add_UG

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
    Check_MySQL_Data_Dir
    MySQL_Initialize_DB
    # compiled mysql provides systemd service file
    # binary package only provides mysql.server init script, therefore we copy our own service file
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

    MySQL_Sec_Setting
}