#!/usr/bin/env bash
# mariadb 5.5 and 10.0, 10.1 can only use openssl 1.0.x for ssl support
# mariadb 10.2 and later versions support openssl 1.1.x
# MariaDB generally comes with a bundled version of either wolfSSL or yaSSL (its predecessor)
# depending on the server version and platform.
# yaSSL for mariadb 5.5 - mariadb 10.4.5
# starting with MariaDB 10.4.6, wolfSSL has been the chosen bundled library.
# if no suitable version of openssl is found, mariadb will use the bundled yaSSL/wolfSSL library.
# starting from mariadb 10.5.17, it can be built with openssl 3.x, and tested on debian 12.
# mariadb 10.6 and later versions support openssl 3.x
MariaDB_WITHSSL() {
    if openssl version | grep -Eqi "OpenSSL 3\.*"; then
        if [[ "${DBSelect}" =~ ^(7|8)$ ]] || echo "${mariadb_version}" | grep -Eqi '^10.(4|5).'; then
            echo "MariaDB 10.4 and 10.5 do not support OpenSSL 3.x for SSL."
            echo "Installing OpenSSL 1.1.1 ..."
            Install_Openssl_New
            MariaDBWITHSSL='-DWITH_SSL=/usr/local/openssl1.1.1'
        else
            echo "MariaDB 10.6 and later versions support OpenSSL 3.x."
            echo "Using system OpenSSL 3.x ..."
            MariaDBWITHSSL=''
        fi
    else
        echo "Using system OpenSSL 1.1.1..."
        MariaDBWITHSSL=''
    fi
}

MariaDB_Symbol_Check() {
    gcc_major_version=$(gcc -dumpversion | cut -f1 -d.)
    if [ "${gcc_major_version}" -ge "10" ]; then
        MariaDBSymbolCheck='-DDISABLE_LIBMYSQLCLIENT_SYMBOL_VERSIONING=1'
    else
        MariaDBSymbolCheck=''
    fi
}

MariaDB_Enable_Innodb() {
    if [ "${InstallInnodb}" = "y" ]; then
        sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    else
        sed -i '/^default_storage_engine/d' /etc/my.cnf
        sed -i 's/^#loose-innodb/loose-innodb/g' /etc/my.cnf
        sed -i '/skip-external-locking/i\default_storage_engine = MyISAM\nloose-skip-innodb' /etc/my.cnf
    fi
}

MariaDB_Disable_Explicit_Timestamp() {
    sed -i 's/^explicit_defaults_for_timestamp/#explicit_defaults_for_timestamp/g' /etc/my.cnf
}   

MariaDB_Set_UG() {
    sed -i 's/^User=mysql/User=mariadb/g' /etc/systemd/system/mariadb.service
    sed -i 's/^Group=mysql/Group=mariadb/g' /etc/systemd/system/mariadb.service
    if [ ! -z "${MariaDB_Data_Dir}" ] && [ "${MariaDB_Data_Dir}" != "/usr/local/mariadb/data" ]; then
        echo "Set MariaDB data dir in mariadb.service to ${MariaDB_Data_Dir}"
        sed -i "s|/usr/local/mariadb/data|${MariaDB_Data_Dir}|g" /etc/systemd/system/mariadb.service
    fi
}

MariaDB_Set_Startup() {
    \cp /usr/local/mariadb/support-files/systemd/mariadb.service /etc/systemd/system/mariadb.service
    MariaDB_Set_UG
    if [ "${Bin}" = "y" ]; then
        sed -i 's#/usr/local/mysql/data#/usr/local/mariadb/data#g' /etc/systemd/system/mariadb.service
        sed -i 's#/usr/local/mysql/scripts#/usr/local/mariadb/scripts#g' /etc/systemd/system/mariadb.service
        sed -i 's#/usr/local/mysql/bin#/usr/local/mariadb/bin#g' /etc/systemd/system/mariadb.service
        sed -i 's#/usr/local/mysql/bin/my_print_defaults#/usr/local/mariadb/bin/my_print_defaults#' /usr/local/mariadb/bin/galera_recovery
        #if [ -d "/usr/local/mysql" ]; then
        #    sed -i 's#/usr/local/mysql/bin#/usr/local/mariadb/bin#g' /etc/systemd/system/mariadb.service
        #    sed -i 's#/usr/local/mysql/bin/my_print_defaults#/usr/local/mariadb/bin/my_print_defaults#' /usr/local/mariadb/bin/galera_recovery
        #else
        #    mkdir -p /usr/local/mysql
        #    ln -s /usr/local/mariadb/bin /usr/local/mysql/bin
        #fi
    fi
    systemctl daemon-reload
}

MariaDB_Initialize_DB() {
    if [ -s "/usr/local/mariadb/scripts/mariadb-install-db" ]; then
        echo "Initialize MariaDB database using mariadb-install-db ..."
        /usr/local/mariadb/scripts/mariadb-install-db --defaults-file=/etc/my.cnf
    else
        echo "Initialize MariaDB database using mysql_install_db ..."
        /usr/local/mariadb/scripts/mysql_install_db --defaults-file=/etc/my.cnf
    fi
#    /usr/local/mariadb/scripts/mariadb-install-db --defaults-file=/etc/my.cnf
    chown -R mariadb:mariadb ${MariaDB_Data_Dir}
}

MariaDB_Check_Config() {
    if [ ! -e /usr/local/mariadb/bin/mariadb-config ]; then
        ln -sf /usr/local/mariadb/bin/mariadb_config /usr/local/mariadb/bin/mariadb-config
    fi
}

MariaDB_Add_UG() {
    groupadd mariadb
    useradd -s /sbin/nologin -M -g mariadb mariadb
}

MariaDB_Set_MyCNF_104() {
    sed -i 's/^#query_cache_type/query_cache_type/g' /etc/my.cnf
    sed -i 's/^#query_cache_size/query_cache_size/g' /etc/my.cnf
    sed -i 's/^#expire_logs_days/expire_logs_days/g' /etc/my.cnf
    sed -i 's/^binlog_expire_logs_seconds/#binlog_expire_logs_seconds/g' /etc/my.cnf
}

MariaDB_My_Cnf() {
    cat >/etc/my.cnf <<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
port        = 3306
socket      = /tmp/mysql.sock
user    = mariadb

basedir = /usr/local/mariadb
datadir = ${MariaDB_Data_Dir}
log_error = ${MariaDB_Data_Dir}/mariadb.err
pid-file = ${MariaDB_Data_Dir}/mariadb.pid

skip-external-locking
# required for 10.4+ compatibility
explicit_defaults_for_timestamp = true

max_connections = 500
max_connect_errors = 100
open_files_limit = 32768

key_buffer_size = 32M

max_allowed_packet = 64M
table_open_cache = 1024
thread_cache_size = 64
tmp_table_size = 64M

sort_buffer_size = 2M
read_buffer_size = 1M
read_rnd_buffer_size = 1M

# --- Query Cache (10.4 ONLY) ---
#query_cache_type = 0
#query_cache_size = 8M

log-bin = mysql-bin
binlog_format = ROW
server-id   = 1
#expire_logs_days = 10
binlog_expire_logs_seconds = 864000
sync_binlog = 1
binlog_checksum = CRC32

default_storage_engine = InnoDB
#innodb_file_per_table = 1
#innodb_data_home_dir = ${MariaDB_Data_Dir}
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = ${MariaDB_Data_Dir}
#innodb_buffer_pool_size = 1G
#innodb_log_file_size = 256M
#innodb_log_buffer_size = 32M
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

}

Mariadb_Sec_Setting() {
    cat >/etc/ld.so.conf.d/mariadb.conf <<EOF
    /usr/local/mariadb/lib
EOF
    ldconfig

    if [ -d "/proc/vz" ]; then
        ulimit -s unlimited
    fi

    if [ -d "/etc/mysql" ]; then
        mv /etc/mysql /etc/mysql.backup.$(date +%Y%m%d)
    fi

    systemctl enable mariadb
    systemctl start mariadb

    ln -sf /usr/local/mariadb/bin/mariadb /usr/bin/mariadb
    ln -sf /usr/local/mariadb/bin/mariadb-dump /usr/bin/mariadb-dump
    ln -sf /usr/local/mariadb/bin/mariadbd-safe /usr/bin/mariadbd-safe
    ln -sf /usr/local/mariadb/bin/mariadb-check /usr/bin/mariadb-check

    ln -sf /usr/local/mariadb/bin/mysql /usr/bin/mysql
    ln -sf /usr/local/mariadb/bin/mysqldump /usr/bin/mysqldump
    ln -sf /usr/local/mariadb/bin/mysqld_safe /usr/bin/mysqld_safe
    ln -sf /usr/local/mariadb/bin/mysqlcheck /usr/bin/mysqlcheck

    ln -sf /usr/local/mariadb/bin/myisamchk /usr/bin/myisamchk

    systemctl restart mariadb
    sleep 2

    # set root password using mysqladmin
    echo "Setting MySQL root password..."
    # add default my.cnf file for mysqladmin to prevent hight priority ~/.my.cnf
    if [ -s ~/.my.cnf ]; then
        /usr/local/mariadb/bin/mysqladmin --defaults-file=/etc/my.cnf -u root password "${DB_Root_Password}"
    else
        /usr/local/mariadb/bin/mysqladmin -u root password "${DB_Root_Password}"
    fi

    systemctl restart mariadb

    Make_TempMycnf "${DB_Root_Password}"
    Do_Query ""
    if [ $? -ne 0 ]; then
        echo "failed, try other way..."
        systemctl restart myriadb
        cat >~/.emptymy.cnf <<EOF
[client]
user=root
password=''
EOF

        /usr/local/mariadb/bin/mariadb --defaults-file=~/.emptymy.cnf -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_Root_Password}');" 
        [ $? -eq 0 ] && echo "Set password Sucessfully." || echo "Set password failed!"
        /usr/local/mariadb/bin/mariadb --defaults-file=~/.emptymy.cnf -e "FLUSH PRIVILEGES;"
        [ $? -eq 0 ] && echo "FLUSH PRIVILEGES Sucessfully." || echo "FLUSH PRIVILEGES failed!"
        rm -f ~/.emptymy.cnf
    fi

    Do_Query ""
    if [ $? -eq 0 ]; then
        echo "OK, Mariadb root password correct."
    fi
    echo "Remove anonymous users..."
    Do_Query "DELETE FROM mysql.user WHERE User='';"
    Do_Query "DROP USER IF EXISTS''@'%';"
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

    systemctl stop mariadb
}

Check_MariaDB_Data_Dir() {
    if [ -d "${MariaDB_Data_Dir}" ]; then
        datetime=$(date +"%Y%m%d%H%M%S")
        mkdir /root/mariadb-data-dir-backup${datetime}/
        \cp ${MariaDB_Data_Dir}/* /root/mariadb-data-dir-backup${datetime}/
        rm -rf ${MariaDB_Data_Dir}
        mkdir -p ${MariaDB_Data_Dir}
    else
        mkdir -p ${MariaDB_Data_Dir}
    fi
    chown -R mariadb:mariadb /usr/local/mariadb
    chown -R mariadb:mariadb ${MariaDB_Data_Dir}
}

MariaDB_Set_SSL_Cert() {
    # 1. Create directory
    mkdir -p /usr/local/mariadb/ssl
    cd /usr/local/mariadb/ssl

    # 2. Generate CA Key and Certificate (Use -traditional for yaSSL compatibility)
    openssl genrsa -traditional -out ca-key.pem 2048
    openssl req -new -x509 -nodes -days 3650 -key ca-key.pem -out ca-cert.pem -subj "/CN=MariaDB-5.5-CA"

    # 3. Generate Server Key (Use -traditional !!!)
    openssl genrsa -traditional -out server-key.pem 2048

    # 4. Generate Server Certificate Signing Request
    openssl req -new -key server-key.pem -out server-req.pem -subj "/CN=MariaDB-5.5-Server"

    # 5. Sign the Server Certificate
    openssl x509 -req -days 3650 -in server-req.pem -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem

    # 6. Set Permissions (Critical: MariaDB must be able to read these)
    chown -R mariadb:mariadb /usr/local/mariadb/ssl
    chmod 600 /usr/local/mariadb/ssl/*.pem

    # add certs to /etc/my.cnf
    sed -i '/\[mysqld\]/a \
ssl-ca=/usr/local/mariadb/ssl/ca-cert.pem\
ssl-cert=/usr/local/mariadb/ssl/server-cert.pem\
ssl-key=/usr/local/mariadb/ssl/server-key.pem' /etc/my.cnf
        
    }

Install_MariaDB_55() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        MariaDB_Symbol_Check
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DWITH_SSL=bundled \
            -DWITH_ARIA_STORAGE_ENGINE=1 \
            -DWITH_XTRADB_STORAGE_ENGINE=1 \
            -DWITH_INNOBASE_STORAGE_ENGINE=1 \
            -DWITH_PARTITION_STORAGE_ENGINE=1 \
            -DWITH_MYISAM_STORAGE_ENGINE=1 \
            -DWITH_FEDERATED_STORAGE_ENGINE=1 \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DWITHOUT_TOKUDB=1 \
            ${MariaDBSymbolCheck} \
            -DENABLED_LOCAL_INFILE=1
        Make_Install
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MariaDB_Disable_Explicit_Timestamp
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Set_SSL_Cert
    MariaDB_Initialize_DB

    ln -sf /usr/local/mariadb/bin/mysql /usr/bin/mysql
    ln -sf /usr/local/mariadb/bin/mysql /usr/local/mariadb/bin/mariadb
    ln -sf /usr/local/mariadb/bin/mariadb /usr/bin/mariadb
    ln -sf /usr/local/mariadb/bin/mysqld /usr/bin/mysqld
    ln -sf /usr/local/mariadb/bin/mysqld /usr/local/mariadb/bin/mariadbd
    ln -sf /usr/local/mariadb/bin/mariadbd /usr/bin/mariadbd

    ln -sf /usr/local/mariadb/bin/mysqldump /usr/bin/mysqldump
    ln -sf /usr/local/mariadb/bin/mysqld_safe /usr/bin/mysqld_safe
    ln -sf /usr/local/mariadb/bin/mysqlcheck /usr/bin/mysqlcheck

    ln -sf /usr/local/mariadb/bin/myisamchk /usr/bin/myisamchk

    # add startup script
    \cp /usr/local/mariadb/support-files/mysql.server /etc/init.d/mariadb
    chmod 755 /etc/init.d/mariadb
    \cp ${cur_dir}/init.d/mariadb.service /etc/systemd/system/mariadb.service
    sed -i 's/^Type=notify/Type=simple/g' /etc/systemd/system/mariadb.service
    sed -i '/^ExecStart=/ s/$/ --console/' /etc/systemd/system/mariadb.service
    systemctl daemon-reload
    systemctl enable mariadb
    systemctl start mariadb
    
    # optimize mariadb settings
    cat >/etc/ld.so.conf.d/mariadb.conf <<EOF
    /usr/local/mariadb/lib
    /usr/local/lib
EOF
    ldconfig

    if [ -d "/proc/vz" ]; then
        ulimit -s unlimited
    fi

    if [ -d "/etc/mysql" ]; then
        mv /etc/mysql /etc/mysql.backup.$(date +%Y%m%d)
    fi

    # set root password
    /usr/local/mariadb/bin/mysqladmin -u root password "${DB_Root_Password}"
    systemctl restart mariadb

    Make_TempMycnf "${DB_Root_Password}"
    Do_Query ""
    if [ $? -ne 0 ]; then
        echo "failed, try other way..."
        systemctl restart myriadb
        cat >~/.emptymy.cnf <<EOF
[client]
user=root
password=''
EOF
        /usr/local/mariadb/bin/mariadb --defaults-file=~/.emptymy.cnf -e "UPDATE mysql.user SET Password=PASSWORD('${DB_Root_Password}') WHERE User='root';"
        [ $? -eq 0 ] && echo "Set password Sucessfully." || echo "Set password failed!"
        /usr/local/mariadb/bin/mariadb --defaults-file=~/.emptymy.cnf -e "FLUSH PRIVILEGES;"
        [ $? -eq 0 ] && echo "FLUSH PRIVILEGES Sucessfully." || echo "FLUSH PRIVILEGES failed!"
        rm -f ~/.emptymy.cnf
    fi

    echo "Remove anonymous users..."
    Do_Query "DELETE FROM mysql.user WHERE User='';"
    Do_Query "DROP USER ''@'%';"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"
    echo "Disallow root login remotely..."
    Do_Query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"
    echo "Remove test database..."
    Do_Query "DROP DATABASE test;"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"
    echo "Reload privilege tables..."
    Do_Query "FLUSH PRIVILEGES;"
    [ $? -eq 0 ] && echo " ... Success." || echo " ... Failed!"

    systemctl stop mariadb
}

Install_MariaDB_103() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DWITH_ARIA_STORAGE_ENGINE=1 \
            -DWITH_XTRADB_STORAGE_ENGINE=1 \
            -DWITH_INNOBASE_STORAGE_ENGINE=1 \
            -DWITH_PARTITION_STORAGE_ENGINE=1 \
            -DWITH_MYISAM_STORAGE_ENGINE=1 \
            -DWITH_FEDERATED_STORAGE_ENGINE=1 \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITHOUT_TOKUDB=1
        Make_Install
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
}

Install_MariaDB_104() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        #patch -p1 <${cur_dir}/src/patch/mariadb_10.4_install_db.patch
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITHOUT_TOKUDB=1
        Make_Install
    fi
    MariaDB_Check_Config

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Set_MyCNF_104
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
}

Install_MariaDB_105() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        rm -f /etc/my.cnf
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITHOUT_TOKUDB=1
        Make_Install
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
}

Install_MariaDB_106() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        rm -f /etc/my.cnf
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITHOUT_TOKUDB=1
        Make_Install
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
}

Install_MariaDB_1011() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        rm -f /etc/my.cnf
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITHOUT_TOKUDB=1
        Make_Install
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
}

Install_MariaDB_114() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        rm -f /etc/my.cnf
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITHOUT_TOKUDB=1
        Make_Install
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
}

Install_MariaDB_118() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Source code..."
        rm -f /etc/my.cnf
        Tar_Cd ${Mariadb_Ver}.tar.gz ${Mariadb_Ver}
        mkdir -p mariadb-build && cd mariadb-build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
            -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
            -DEXTRA_CHARSETS=all \
            -DDEFAULT_CHARSET=utf8mb4 \
            -DDEFAULT_COLLATION=utf8mb4_general_ci \
            -DWITH_READLINE=1 \
            -DWITH_EMBEDDED_SERVER=1 \
            -DENABLED_LOCAL_INFILE=1 \
            -DWITHOUT_TOKUDB=1
        Make_Install
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
}
