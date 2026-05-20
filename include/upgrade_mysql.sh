#!/usr/bin/env bash

Backup_MySQL()
{
    dump_file="/root/mysql_all_backup${Upgrade_Date}.sql"

    echo "Starting backup all databases..."
    echo "If the database is large, the backup time will be longer."
    if [ ! -x /usr/local/mysql/bin/mysqldump ]; then
        Echo_Red "mysqldump not found, please check if MySQL is installed correctly."
        exit 1
    fi
    if /usr/local/mysql/bin/mysqldump --defaults-file=~/.my.cnf --all-databases --routines --triggers --events --single-transaction > "${dump_file}"; then
        if [ -s "${dump_file}" ]; then
            echo "MySQL databases backup successfully."
        else
            Echo_Red "MySQL databases backup failed, dump file is empty."
            exit 1
        fi
    else
        Echo_Red "MySQL databases backup failed, please backup databases manually!"
        exit 1
    fi
    lnmp stop
    if [[ ! "${MySQL_Data_Dir}" =~ ^/usr/local/mysql/ ]]; then
        mv ${MySQL_Data_Dir} ${MySQL_Data_Dir}${Upgrade_Date}
    fi
    mv /usr/local/mysql /usr/local/oldmysql${Upgrade_Date}
    mv /etc/my.cnf /usr/local/oldmysql${Upgrade_Date}/my.cnf.bak.${Upgrade_Date}
    if echo "${mysql_version}" | grep -Eqi '^5\.5\.' &&  echo "${cur_mysql_version}" | grep -Eqi '^5\.6\.';then
        sed -i 's/STATS_PERSISTENT=0//g' "${dump_file}"
    fi
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
    backup_sql="/root/mysql_all_backup${Upgrade_Date}.sql"

    chgrp -R mysql /usr/local/mysql/. || {
        Echo_Red "Error: failed to set MySQL group ownership."
        exit 1
    }
    ldconfig
    MySQL_Sec_Setting

    echo "Restore backup databases..."
    if [ ! -s "${backup_sql}" ]; then
        Echo_Red "Error: MySQL backup file ${backup_sql} was not found or is empty."
        exit 1
    fi
    echo "Starting MySQL..."
    systemctl start mysql
    echo "Starting importing..."
    /usr/local/mysql/bin/mysql --defaults-file=~/.my.cnf < "${backup_sql}" || {
        Echo_Red "Error: failed to import MySQL backup."
        systemctl stop mysql
        exit 1
    }
    echo "Repair databases..."
    MySQL_Ver_Com=$(${cur_dir}/include/version_compare 8.0.16 ${mysql_version})
    if [ "${MySQL_Ver_Com}" != "1" ]; then
        systemctl stop mysql
        echo "Upgrading MySQL..."
        /usr/local/mysql/bin/mysqld --user=mysql --upgrade=FORCE &
        mysql_upgrade_pid=$!
        echo "Waiting for upgrade to start..."
        sleep 180
        if ! kill -0 "${mysql_upgrade_pid}" >/dev/null 2>&1; then
            Echo_Red "Error: MySQL upgrade process exited unexpectedly."
            wait "${mysql_upgrade_pid}"
            exit 1
        fi
        /usr/local/mysql/bin/mysqladmin --defaults-file=~/.my.cnf shutdown || {
            Echo_Red "Error: failed to shut down MySQL after upgrade repair."
            exit 1
        }
        wait "${mysql_upgrade_pid}" || {
            Echo_Red "Error: MySQL upgrade repair failed."
            exit 1
        }
    else
        /usr/local/mysql/bin/mysql_upgrade --defaults-file=~/.my.cnf || {
            Echo_Red "Error: mysql_upgrade failed."
            systemctl stop mysql
            exit 1
        }
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
        exit 1
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
    read -r -p "(example: 8.4.7 ): " mysql_version
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
        read -r -p "Using Generic Binaries [y/n]: " Bin
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
        read -r -p "Using Generic Binaries [y/n]: " Bin
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
        read -r -p "(Default yes,if you want please enter: y , if not please enter: n): " InstallInnodb

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
