#!/usr/bin/env bash

# mysql ssl requirements:
# mysql 5.1 - 5.5 : openssl 0.9.8 or 1.0.x
# mysql 5.6 - 5.7 : openssl 1.0.x or 1.1.x
# mysql 8.0+      : openssl 1.1.x or 3.x
# mysql 8.4+    : openssl 3.x
# for best performance, mysql 5.7 should be compiled with openssl 1.1.1, mysql 8.0+ should be compiled with openssl 3.x


# deprecated as we dropped support for mysql 5.5
#MySQL_ARM_Patch()
#{
#    if [ "${Is_ARM}" = "y" ]; then
#        patch -p1 < ${cur_dir}/src/patch/mysql-5.5-fix-arm-client_plugin.patch
#    fi
#}

# deprecated as we dropped support for mysql 5.1
#MySQL_Gcc7_Patch()
#{
#    if gcc -dumpversion|grep -Eq "^([7-9]|10)"; then
#        echo "gcc version: 7+"
#        if [ "${DBSelect}" = "1" ] || echo "${mysql_version}" | grep -Eqi '^5\.1.'; then
#            patch -p1 < ${cur_dir}/src/patch/mysql-5.1-mysql-gcc7.patch
#        fi
#    fi
#}

# initialize mysql data directory with no password generated for root user
MySQL_Initialize_DB() {
    /usr/local/mysql/bin/mysqld --initialize-insecure --basedir=/usr/local/mysql --datadir="${MySQL_Data_Dir}" --user=mysql || {
        Echo_Red "Error: failed to initialize MySQL data directory."
        exit 1
    }
    chown -R mysql:mysql "${MySQL_Data_Dir}" || {
        Echo_Red "Error: failed to set MySQL data directory ownership."
        exit 1
    }
}

MySQL_Add_UG() {
    if ! getent group mysql >/dev/null 2>&1; then
        groupadd mysql || {
            Echo_Red "Error: failed to create mysql group."
            exit 1
        }
    fi
    if ! id mysql >/dev/null 2>&1; then
        useradd -s /sbin/nologin -M -g mysql mysql || {
            Echo_Red "Error: failed to create mysql user."
            exit 1
        }
    fi
}

MySQL_SQL_Escape()
{
    local value=$1
    local sq="'"

    value=${value//\\/\\\\}
    value=${value//${sq}/${sq}${sq}}
    printf "%s" "${value}"
}



MySQL_Sec_Setting()
{   
    # 1. system set up
    if [ -d "/proc/vz" ]; then
        ulimit -s unlimited
    fi

    if [ -d "/etc/mysql" ]; then
        mv /etc/mysql "/etc/mysql.backup.$(date +%Y%m%d%H%M%S)"
    fi
    
    # 2. service management and symlinks
    systemctl enable mysql
    systemctl start mysql

    local bin_dir="/usr/local/mysql/bin"
    local bins=("mysql" "mysqld" "mysqldump" "mysqld_safe" "mysqlcheck" "myisamchk")
    
    for bin in "${bins[@]}"; do
        if [ -f "$bin_dir/$bin" ] && { [ ! -e "/usr/bin/$bin" ] || [ -L "/usr/bin/$bin" ]; }; then
            ln -sf "$bin_dir/$bin" "/usr/bin/$bin"
        fi
    done
    
    echo "Waiting for MySQL to re-start..."
    systemctl restart mysql
    sleep 2

    # 3. Securely set the root password using mysqladmin
    echo "Setting MySQL root password..."
    # /etc/my.cnf configures the global MySQL server and sets the baseline for the entire system
    # while ~/.my.cnf is a user-specific configuration file that can override or supplement the settings in /etc/my.cnf for that particular user.
    # ~/my.cnf must be set to 600
    # /etc/my.cnf (Global) is loaded first and applies to all users, while ~/.my.cnf (User-Specific) is loaded afterward and can override settings for that user.
    mysqladmin_ok=0
    if [ -s ~/.my.cnf ]; then
        /usr/local/mysql/bin/mysqladmin --defaults-file=/etc/my.cnf -u root password "${DB_Root_Password}" && mysqladmin_ok=1
    else
        /usr/local/mysql/bin/mysqladmin -u root password "${DB_Root_Password}" && mysqladmin_ok=1
    fi

    if [ "${mysqladmin_ok}" -eq 0 ]; then
        echo "mysqladmin failed; trying ALTER USER fallback..."
        systemctl restart mysql
        cat >~/.emptymy.cnf<<EOF
[client]
user=root
password=''
EOF
        escaped_password=$(MySQL_SQL_Escape "${DB_Root_Password}")
        /usr/local/mysql/bin/mysql --defaults-file="${HOME}/.emptymy.cnf" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${escaped_password}';" || {
            Echo_Red "Error: fallback MySQL root password setup failed."
            exit 1
        }
        echo "Set MySQL root password successfully using fallback method."
        /usr/local/mysql/bin/mysql --defaults-file="${HOME}/.emptymy.cnf" -e "FLUSH PRIVILEGES;" || {
            Echo_Red "Error: failed to reload MySQL privilege tables."
            exit 1
        }
        echo "FlUSH PRIVILEGES successfully."
        rm -f "${HOME}/.emptymy.cnf"
    fi
    systemctl restart mysql || {
        Echo_Red "Error: failed to restart MySQL service after password setup."
        exit 1
    }

    Make_TempMycnf "${DB_Root_Password}"
    Mysql_Do_Query "SELECT 1;" || {
         Echo_Red "Error: MySQL root password verification failed after setup."
         exit 1
    }
    echo "OK, MySQL root password correct."

    # 4. Remove anonymous users, disallow root login remotely, remove test database, and reload privilege tables
    echo "Removing anonymous users..."
    Mysql_Do_Query "DELETE FROM mysql.user WHERE User='';" || {
        Echo_Red "Error: failed to remove anonymous MySQL users."
        exit 1
    }
    Mysql_Do_Query "DROP USER IF EXISTS ''@'%';" || {
        Echo_Red "Error: failed to drop anonymous MySQL users."
        exit 1
    }
    echo " ... Success."

    echo "Disallowing root login remotely..."
    Mysql_Do_Query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || {
        Echo_Red "Error: failed to disallow remote MySQL root login."
        exit 1
    }
    echo " ... Success."

    echo "Removing test database..."
    Mysql_Do_Query "DROP DATABASE IF EXISTS test;" || {
        Echo_Red "Error: failed to remove MySQL test database."
        exit 1
    }
    echo " ... Success."

    echo "Reloading privilege tables..."
    Mysql_Do_Query "FLUSH PRIVILEGES;" || {
        Echo_Red "Error: failed to reload MySQL privilege tables."
        exit 1
    }
    echo " ... Success."

    echo "MySQL secure installation completed successfully."
    echo "Stopping MySQL service..."
    systemctl stop mysql
}

MySQL_Set_Opt()
{
    local name=$1
    local value=$2

    if grep -q "^${name}[[:space:]=]" /etc/my.cnf; then
        sed -i "s#^${name}.*#${name} = ${value}#" /etc/my.cnf
    fi
}

MySQL_Opt()
{
    local key_buffer table_open sort_buffer read_buffer myisam_sort thread_cache query_cache tmp_table
    local innodb_buffer innodb_log innodb_redo performance_tables

    if [[ ${MemTotal} -gt 1024 && ${MemTotal} -lt 2048 ]]; then
        key_buffer="32M"; table_open="128"; sort_buffer="768K"; read_buffer="768K"; myisam_sort="8M"
        thread_cache="16"; query_cache="16M"; tmp_table="32M"; innodb_buffer="128M"; innodb_log="32M"; innodb_redo="128M"; performance_tables="1000"
    elif [[ ${MemTotal} -ge 2048 && ${MemTotal} -lt 4096 ]]; then
        key_buffer="64M"; table_open="256"; sort_buffer="1M"; read_buffer="1M"; myisam_sort="16M"
        thread_cache="32"; query_cache="32M"; tmp_table="64M"; innodb_buffer="256M"; innodb_log="64M"; innodb_redo="256M"; performance_tables="2000"
    elif [[ ${MemTotal} -ge 4096 && ${MemTotal} -lt 8192 ]]; then
        key_buffer="128M"; table_open="512"; sort_buffer="2M"; read_buffer="2M"; myisam_sort="32M"
        thread_cache="64"; query_cache="64M"; tmp_table="64M"; innodb_buffer="512M"; innodb_log="128M"; innodb_redo="512M"; performance_tables="4000"
    elif [[ ${MemTotal} -ge 8192 && ${MemTotal} -lt 16384 ]]; then
        key_buffer="256M"; table_open="1024"; sort_buffer="4M"; read_buffer="4M"; myisam_sort="64M"
        thread_cache="128"; query_cache="128M"; tmp_table="128M"; innodb_buffer="1024M"; innodb_log="256M"; innodb_redo="1024M"; performance_tables="6000"
    elif [[ ${MemTotal} -ge 16384 && ${MemTotal} -lt 32768 ]]; then
        key_buffer="512M"; table_open="2048"; sort_buffer="8M"; read_buffer="8M"; myisam_sort="128M"
        thread_cache="256"; query_cache="256M"; tmp_table="256M"; innodb_buffer="2048M"; innodb_log="512M"; innodb_redo="2048M"; performance_tables="8000"
    elif [[ ${MemTotal} -ge 32768 ]]; then
        key_buffer="1024M"; table_open="4096"; sort_buffer="16M"; read_buffer="16M"; myisam_sort="256M"
        thread_cache="512"; query_cache="512M"; tmp_table="512M"; innodb_buffer="4096M"; innodb_log="1024M"; innodb_redo="4096M"; performance_tables="10000"
    elif [ "${MemTotal}" -le 1024 ]; then
        Echo_Yellow "Detected <1GB RAM; using minimal MySQL optimization."
        return 0
    else
        return 0
    fi

    MySQL_Set_Opt "key_buffer_size" "${key_buffer}"
    MySQL_Set_Opt "table_open_cache" "${table_open}"
    MySQL_Set_Opt "sort_buffer_size" "${sort_buffer}"
    MySQL_Set_Opt "read_buffer_size" "${read_buffer}"
    MySQL_Set_Opt "myisam_sort_buffer_size" "${myisam_sort}"
    MySQL_Set_Opt "thread_cache_size" "${thread_cache}"
    MySQL_Set_Opt "tmp_table_size" "${tmp_table}"
    MySQL_Set_Opt "innodb_buffer_pool_size" "${innodb_buffer}"
    MySQL_Set_Opt "performance_schema_max_table_instances" "${performance_tables}"

    if grep -q "^query_cache_size[[:space:]=]" /etc/my.cnf; then
        MySQL_Set_Opt "query_cache_size" "${query_cache}"
    fi
    if grep -q "^innodb_redo_log_capacity[[:space:]=]" /etc/my.cnf; then
        MySQL_Set_Opt "innodb_redo_log_capacity" "${innodb_redo}"
    elif grep -q "^innodb_log_file_size[[:space:]=]" /etc/my.cnf; then
        MySQL_Set_Opt "innodb_log_file_size" "${innodb_log}"
    fi
}

# if "${MySQL_Data_Dir} exists, backup it and continue as a fresh installation by default
Check_MySQL_Data_Dir()
{
    if [ -d "${MySQL_Data_Dir}" ]; then
            datetime=$(date +"%Y%m%d%H%M%S")
            backup_dir="/root/mysql-data-dir-backup${datetime}"
            echo "Move existing MySQL data directory to ${backup_dir}..."
            mv "${MySQL_Data_Dir}" "${backup_dir}" || {
                Echo_Red "Error: failed to backup existing MySQL data directory."
                exit 1
            }
        mkdir -p "${MySQL_Data_Dir}" || {
            Echo_Red "Error: failed to create MySQL data directory."
            exit 1
        }
    else
    mkdir -p "${MySQL_Data_Dir}" || {
        Echo_Red "Error: failed to create MySQL data directory."
        exit 1
    }
    fi
    chown -R mysql:mysql /usr/local/mysql || {
        Echo_Red "Error: failed to set MySQL ownership."
        exit 1
    }
    chown -R mysql:mysql "${MySQL_Data_Dir}" || {
        Echo_Red "Error: failed to set MySQL data directory ownership."
        exit 1
    }
}

# [mysqld_safe] malloc-lib in my.cnf is inert on 5.7/8.0/8.4 (systemd launches mysqld
# directly); apply the selected allocator via LD_PRELOAD instead.
MySQL_Set_Malloc_Preload()
{
    case "${SelectMalloc}" in
    2) MallocLib='/usr/lib/libjemalloc.so' ;;
    3) MallocLib='/usr/lib/libtcmalloc.so' ;;
    *) MallocLib='' ;;
    esac
    [ -e "${MallocLib}" ] || MallocLib=''

    if [ -n "${MallocLib}" ]; then
        mkdir -p /etc/sysconfig
        echo "LD_PRELOAD=${MallocLib}" > /etc/sysconfig/mysql
    else
        rm -f /etc/sysconfig/mysql
    fi
}

# Allocator is unsupported for mysql 5.6
Install_MySQL_56()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz
        if [ -x /usr/local/mysql/bin/mysqld ]; then
            Echo_Red "MySQL is already installed at /usr/local/mysql. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mysql
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
        sed -i '1s/^/set(CMAKE_CXX_STANDARD 11)\n/' CMakeLists.txt
        if echo "${Rocky_Version}${Alma_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_SSL} || {
            Echo_Red "Error: failed to configure MySQL."
            exit 1
        }
        MySQL_Make_Install || exit 1
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
local_infile=0
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
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir="${MySQL_Data_Dir}" --user=mysql || {
        Echo_Red "Error: failed to initialize MySQL data directory."
        exit 1
    }
    chown -R mysql:mysql "${MySQL_Data_Dir}" || {
        Echo_Red "Error: failed to set MySQL data directory ownership."
        exit 1
    }
    \cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
    \cp ${cur_dir}/init.d/mysql.service /etc/systemd/system/mysql.service
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF
    ldconfig

    MySQL_Sec_Setting
}

# mysql 5.7.44 still only support openssl 1.1.1. But binary package uses openssl 3.
# mysql 5.7 and before BIN is built with libncurses.so.5, but most OS use libncurses.so.6 now.
# So we need to install ncurses5 compatibility library for mysql 5.7 BIN package

Install_MySQL_57()
{
    Ncurses5_Compat_Check
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz
        if [ -x /usr/local/mysql/bin/mysqld ]; then
            Echo_Red "MySQL is already installed at /usr/local/mysql. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mysql
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
        if echo "${Rocky_Version}${Alma_Version}" | grep -Eqi "^9"; then
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
            ${MySQL_WITH_SSL} || {
            Echo_Red "Error: failed to configure MySQL."
            exit 1
        }
        MySQL_Make_Install || exit 1
    fi
    
    MySQL_Add_UG

    rm -f /etc/my.cnf
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
local_infile=0

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
    MySQL_Set_Malloc_Preload
    systemctl daemon-reload
 
    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF
    ldconfig

    MySQL_Sec_Setting
}

# support both openssl 1.1.1 and openssl 3
Install_MySQL_80()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
        if [ -x /usr/local/mysql/bin/mysqld ]; then
            Echo_Red "MySQL is already installed at /usr/local/mysql. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
        if [ "${isOpenSSL10}" = "y" ]; then
            Echo_Red "MySQL 8.0 requires OpenSSL 1.1.1 or 3.x; system OpenSSL is older. Aborting."
            exit 1
        fi
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
            -DWITH_BOOST=/usr/local/mysql80_boost || {
            Echo_Red "Error: failed to configure MySQL."
            exit 1
        }
        MySQL_Make_Install || exit 1
    fi

    MySQL_Add_UG

    rm -f /etc/my.cnf
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
local_infile=0

# Network / buffers
max_allowed_packet = 16M
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
    MySQL_Set_Malloc_Preload
    systemctl daemon-reload

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF
    ldconfig

    MySQL_Sec_Setting
}

# mysql 8.4 has boost bundled in source package
# support openssl 1.1.1 and openssl 3
# for best performance, please use openssl 3
Install_MySQL_84()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
        if [ -x /usr/local/mysql/bin/mysqld ]; then
            Echo_Red "MySQL is already installed at /usr/local/mysql. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        Tar_Cd ${Mysql_Ver}.tar.gz ${Mysql_Ver}
        if [ "${isOpenSSL10}" = "y" ]; then
            Echo_Red "MySQL 8.4 requires OpenSSL 1.1.1 or 3.x; system OpenSSL is older. Aborting."
            exit 1
        fi
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
        -DWITH_SYSTEMD=1 || {
            Echo_Red "Error: failed to configure MySQL."
            exit 1
        }
        
        MySQL_Make_Install || exit 1
    fi

    MySQL_Add_UG

    rm -f /etc/my.cnf
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
local_infile=0

# Network / buffers
max_allowed_packet = 16M
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
    MySQL_Set_Malloc_Preload
    systemctl daemon-reload

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
EOF
    ldconfig

    MySQL_Sec_Setting
}
