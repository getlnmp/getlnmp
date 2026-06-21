#!/usr/bin/env bash

# When MariaDB Server is compiled with TLS and cryptography support, it is usually either statically linked with
# MariaDB's bundled TLS and cryptography library or dynamically linked with the system's OpenSSL library.
# MariaDB's bundled TLS library is either wolfSSL or yaSSL, depending on the server version.

# MariaDB Server on Linux
# Binary Tarballs: statically linked with the bundled wolfSSL library in binary tarballs for Linux, so they do not require a separate OpenSSL library for TLS support.
# DEB Packages: dynamically linked with the system's OpenSSL library in .deb packages.
# RPM Packages: dynamically linked with the system's OpenSSL library in .rpm packages.

# mariadb 5.5 and 10.0, 10.1 can only use openssl 1.0.x for ssl support
# mariadb 10.2 and later versions support openssl 1.1.x
# MariaDB generally comes with a bundled version of either wolfSSL or yaSSL (its predecessor)
# depending on the server version and platform.
# yaSSL for mariadb 5.5 - mariadb 10.4.5
# starting with MariaDB 10.4.6, wolfSSL (formerly yaSSL) has been the chosen bundled library.
# if no suitable version of openssl is found, mariadb will use the bundled yaSSL/wolfSSL library.
# therefore MariaDB_WITHSSL us actually useless.

# starting from mariadb 10.5.17, it can be built with openssl 3.x, and tested on debian 12.
# mariadb 10.6 and later versions support openssl 3.x
# -DWITH_SSL=system(default)
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

# when you compile very old databases(using ld.bfd) on modern linux( GCC 10+ with very new toolchain(ld.lld or gold)), you should always add this option
# Otherwise you will error message in configuration like:
# "our current linker does not support VERSION command in linker scripts like a GNU ld or any compatible linker should.
# Perhaps you're using gold? Either switch to GNU ld compatible linker or
# run cmake with -DDISABLE_LIBMYSQLCLIENT_SYMBOL_VERSIONING=TRUE to be able to complete the build"
# The failure comes from the linker provided by a package called binutils whose version is 2.35 or newer that is shipped from GCC 10+
# so adding this option when compiling MySQL 5.5, 5.6, 5.7, MariaDB 5.5, 10.0, 10.2, 10.3 on Debian 11/12/13, Ubuntu 20+, RHEL9/10.
# Debian 10/RHEL 8 using GCC 8.3+, it's optional and safe to add this option as well
# actually always adding this option when compiling old databases on new linux distrituions and there's no negative consequence to using this flag in modern environments
# conclusion:always add this option for mysql 5.6, 5.6, 5.7 and mariadb 5.5
MariaDB_Symbol_Check() {
    local mariadb_gcc_major_version=$(gcc -dumpversion | cut -f1 -d.)
    if [ "${mariadb_gcc_major_version}" -ge "10" ]; then
        MariaDBSymbolCheck='-DDISABLE_LIBMYSQLCLIENT_SYMBOL_VERSIONING=1'
    else
        MariaDBSymbolCheck=''
    fi
}

MariaDB_Enable_Innodb() {
    # if [ "${Bin}" != "y" ]; then
    #     if [ "${InstallInnodb}" = "y" ]; then
    #         sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    #     else
    #         sed -i '/^default_storage_engine/d' /etc/my.cnf
    #         sed -i 's/^#loose-innodb/loose-innodb/g' /etc/my.cnf
    #         sed -i '/skip-external-locking/i\default_storage_engine = MyISAM\nloose-skip-innodb' /etc/my.cnf
    #     fi
    # fi
    echo "InnoDB is enabled by default"
}

MariaDB_Disable_Explicit_Timestamp() {
    sed -i 's/^explicit_defaults_for_timestamp/#explicit_defaults_for_timestamp/g' /etc/my.cnf
}

MariaDB_Set_UG() {
    sed -i 's/^User=mysql/User=mariadb/g' /etc/systemd/system/mariadb.service
    sed -i 's/^Group=mysql/Group=mariadb/g' /etc/systemd/system/mariadb.service
}

# mariadbd's systemd unit (whether compiled, from the binary tarball, or our
# init.d/mariadb.service fallback) launches mariadbd directly, so [mysqld_safe]
# malloc-lib in my.cnf is inert; apply the selected allocator via a systemd
# drop-in Environment=LD_PRELOAD instead, mirroring MySQL_Set_Malloc_Preload.
MariaDB_Set_Malloc_Preload() {
    case "${SelectMalloc}" in
    2) MallocLib='/usr/local/jemalloc/lib/libjemalloc.so.2' ;;
    3) MallocLib='/usr/local/tcmalloc/lib/libtcmalloc.so.4' ;;
    *) MallocLib='' ;;
    esac
    [ -e "${MallocLib}" ] || MallocLib=''

    if [ -n "${MallocLib}" ]; then
        mkdir -p /etc/systemd/system/mariadb.service.d
        cat >/etc/systemd/system/mariadb.service.d/lnmp-malloc.conf <<EOF
[Service]
Environment=LD_PRELOAD=${MallocLib}
EOF
    else
        rm -f /etc/systemd/system/mariadb.service.d/lnmp-malloc.conf
        rmdir /etc/systemd/system/mariadb.service.d 2>/dev/null
    fi
}

MariaDB_Set_Startup() {
    if [ -s /usr/local/mariadb/support-files/systemd/mariadb.service ]; then
        \cp /usr/local/mariadb/support-files/systemd/mariadb.service /etc/systemd/system/mariadb.service
    elif [ -s /usr/local/mariadb/usr/lib/systemd/system/mariadb.service ]; then
        \cp /usr/local/mariadb/usr/lib/systemd/system/mariadb.service /etc/systemd/system/mariadb.service
    elif [ -s /usr/local/mariadb/lib/systemd/system/mariadb.service ]; then
        \cp /usr/local/mariadb/lib/systemd/system/mariadb.service /etc/systemd/system/mariadb.service
    else
        \cp ${cur_dir}/init.d/mariadb.service /etc/systemd/system/mariadb.service
    fi
    MariaDB_Set_UG
    if [ "${Bin}" = "y" ]; then
        sed -i 's#/usr/local/mysql/data#/usr/local/mariadb/data#g' /etc/systemd/system/mariadb.service
        sed -i 's#/usr/local/mysql/scripts#/usr/local/mariadb/scripts#g' /etc/systemd/system/mariadb.service
        sed -i 's#/usr/local/mysql/bin#/usr/local/mariadb/bin#g' /etc/systemd/system/mariadb.service
        sed -i 's#/usr/local/mysql/bin/my_print_defaults#/usr/local/mariadb/bin/my_print_defaults#' /usr/local/mariadb/bin/galera_recovery
    fi
    if [ ! -z "${MariaDB_Data_Dir}" ] && [ "${MariaDB_Data_Dir}" != "/usr/local/mariadb/data" ]; then
        echo "Set MariaDB data dir in mariadb.service to ${MariaDB_Data_Dir}"
        sed -i "s|/usr/local/mariadb/data|${MariaDB_Data_Dir}|g" /etc/systemd/system/mariadb.service
    fi
    MariaDB_Set_Malloc_Preload
    systemctl daemon-reload
}

# mariadb-install-db is used for mariadb 10.4 and later versions, mysql_install_db is used for mariadb 5.5 - 10.3
# mariadb-install-db initializes the MariaDB data directory and creates the necessary system tables.
# --defaults-file option specifies the path to the my.cnf configuration file, which is used to set various options
# for the initialization process and must be given as the first option
MariaDB_Initialize_DB() {
    local init_status

    if [ -s "/usr/local/mariadb/scripts/mariadb-install-db" ]; then
        echo "Initialize MariaDB database using mariadb-install-db ..."
        /usr/local/mariadb/scripts/mariadb-install-db --defaults-file=/etc/my.cnf --user=mariadb
        init_status=$?
    else
        echo "Initialize MariaDB database using mysql_install_db ..."
        /usr/local/mariadb/scripts/mysql_install_db --defaults-file=/etc/my.cnf --user=mariadb
        init_status=$?
    fi
    #    /usr/local/mariadb/scripts/mariadb-install-db --defaults-file=/etc/my.cnf
    if [ ${init_status} -ne 0 ]; then
        Echo_Red "Error: failed to initialize MariaDB database."
        exit 1
    fi
}

# only for mariadb 10.4 and older
MariaDB_Check_Config() {
    if [ ! -e /usr/local/mariadb/bin/mariadb-config ]; then
        ln -sf /usr/local/mariadb/bin/mariadb_config /usr/local/mariadb/bin/mariadb-config
    fi
}

MariaDB_Add_UG() {
    if ! getent group mariadb >/dev/null 2>&1; then
        groupadd mariadb || {
            Echo_Red "Error: failed to create mariadb group."
            exit 1
        }
    fi
    if ! id mariadb >/dev/null 2>&1; then
        useradd -s /sbin/nologin -M -g mariadb mariadb || {
            Echo_Red "Error: failed to create mariadb user."
            exit 1
        }
    fi
}

MariaDB_SQL_Escape() {
    local value=$1
    local sq="'"

    value=${value//\\/\\\\}
    value=${value//${sq}/${sq}${sq}}
    printf "%s" "${value}"
}

MariaDB_Set_MyCNF_104() {
    #sed -i 's/^#query_cache_type/query_cache_type/g' /etc/my.cnf
    #sed -i 's/^#query_cache_size/query_cache_size/g' /etc/my.cnf
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
local_infile=0

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

log-bin = mariadb-bin
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
EOF

}

MariaDB_Sec_Setting() {

    # 1. system set up
    echo "/usr/local/mariadb/lib" >/etc/ld.so.conf.d/mariadb.conf
    ldconfig
    if [ -d "/proc/vz" ]; then
        ulimit -s unlimited
    fi

    if [ -d "/etc/mysql" ]; then
        mv /etc/mysql /etc/mysql.backup.$(date +%Y%m%d%H%M%S)
    fi

    # 2. service management and symlinks
    systemctl enable mariadb
    systemctl start mariadb

    local bin_dir="/usr/local/mariadb/bin"
    local bins=("mariadb" "mariadb-dump" "mariadbd-safe" "mariadb-check" "mysql" "mysqldump" "mysqld_safe" "mysqlcheck" "myisamchk")

    for bin in "${bins[@]}"; do
        if [ -f "$bin_dir/$bin" ] && { [ ! -e "/usr/bin/$bin" ] || [ -L "/usr/bin/$bin" ]; }; then
            ln -sf "$bin_dir/$bin" "/usr/bin/$bin"
        fi
    done

    echo "Waiting for MariaDB to re-start..."
    systemctl restart mariadb
    sleep 2

    # 3. Securely set the root password using mysqladmin
    echo "Setting MariaDB root password..."
    # /etc/my.cnf configures the global MariaDB server and sets the baseline for the entire system
    # while ~/.my.cnf is a user-specific configuration file that can override or supplement the settings in /etc/my.cnf for that particular user.
    # ~/my.cnf must be set to 600
    # /etc/my.cnf (Global) is loaded first and applies to all users, while ~/.my.cnf (User-Specific) is loaded afterward and can override settings for that user.
    # add default my.cnf file for mysqladmin to prevent high priority of ~/.my.cnf
    if [ -x /usr/local/mariadb/bin/mariadb-admin ]; then
        local Mariadb_admin_BIN="/usr/local/mariadb/bin/mariadb-admin"
    else
        local Mariadb_admin_BIN="/usr/local/mariadb/bin/mysqladmin"
    fi
    if [ -s ~/.my.cnf ]; then
        "${Mariadb_admin_BIN}" --defaults-file=/etc/my.cnf -u root password "${DB_Root_Password}" || {
            Echo_Red "Error: failed to set MariaDB root password using mysqladmin."
            exit 1
        }
    else
        "${Mariadb_admin_BIN}" -u root password "${DB_Root_Password}" || {
            Echo_Red "Error: failed to set MariaDB root password using mysqladmin."
            exit 1
        }
    fi

    systemctl restart mariadb

    Make_TempMycnf "${DB_Root_Password}"
    MariaDB_Do_Query "SELECT 1;" || {
        Echo_Red "Error: MariaDB root password verification failed after initial setup."
        Echo_Red "Try another way to set root password..."
        systemctl restart mariadb
        cat >~/.emptymy.cnf <<EOF
[client]
user=root
password=''
EOF
        escaped_pw=$(MariaDB_SQL_Escape "${DB_Root_Password}")
        /usr/local/mariadb/bin/mariadb --defaults-file="${HOME}/.emptymy.cnf" -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${escaped_pw}');" || {
            Echo_Red "Error: fallback MariaDB root password setup failed."
            exit 1
        }
        echo "Set password Sucessfully."
        /usr/local/mariadb/bin/mariadb --defaults-file="${HOME}/.emptymy.cnf" -e "FLUSH PRIVILEGES;" || {
            Echo_Red "Error: fallback MariaDB privilege reload failed."
            exit 1
        }
        echo "FLUSH PRIVILEGES Sucessfully."
        MariaDB_Do_Query "SELECT 1;" || {
            Echo_Red "Error: Double-check of MariaDB root password verification failed."
            exit 1
        }
        rm -f "${HOME}/.emptymy.cnf"
    }
    echo "OK, Mariadb root password correct."

    # 4. Remove anonymous users, disallow root login remotely, remove test database, and reload privilege tables
    echo "Removing anonymous users..."
    MariaDB_Do_Query "DELETE FROM mysql.user WHERE User='';" || {
        Echo_Red "Error: Failed to remove anonymous MariaDB users."
        exit 1
    }
    echo " ... Success."

    echo "Disallowing root login remotely..."
    MariaDB_Do_Query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || {
        Echo_Red "Error: Failed to remove remote MariaDB root users."
        exit 1
    }
    echo " ... Success."

    echo "Removing test database..."
    MariaDB_Do_Query "DROP DATABASE IF EXISTS test;" || {
        Echo_Red "Error: Failed to remove MariaDB test database."
        exit 1
    }
    echo " ... Success."

    echo "Reloading privilege tables..."
    MariaDB_Do_Query "FLUSH PRIVILEGES;" || {
        Echo_Red "Error: Failed to reload MariaDB privilege tables."
        exit 1
    }
    echo " ... Success."

    echo "MariaDB secure installation completed successfully."
    echo "Stopping MariaDB service..."
    systemctl stop mariadb
}

# backup ${MariaDB_Data_Dir} and continue a fresh installation by default
Check_MariaDB_Data_Dir() {
    if [ -d "${MariaDB_Data_Dir}" ]; then
        datetime=$(date +"%Y%m%d%H%M%S")
        backup_dir="/root/mariadb-data-dir-backup${datetime}"
        echo "Move existing MariaDB data directory to ${backup_dir}..."
        mv "${MariaDB_Data_Dir}" "${backup_dir}" || {
            Echo_Red "Error: failed to backup existing MariaDB data directory."
            exit 1
        }
        mkdir -p "${MariaDB_Data_Dir}" || {
            Echo_Red "Error: failed to create MariaDB data directory."
            exit 1
        }
    else
        mkdir -p "${MariaDB_Data_Dir}" || {
            Echo_Red "Error: failed to create MariaDB data directory."
            exit 1
        }
    fi
    chown -R mariadb:mariadb /usr/local/mariadb || {
        Echo_Red "Error: failed to set MariaDB ownership."
        exit 1
    }
    chown -R mariadb:mariadb "${MariaDB_Data_Dir}" || {
        Echo_Red "Error: failed to set MariaDB data directory ownership."
        exit 1
    }
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

Install_MariaDB_104() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        if [ -x /usr/local/mariadb/bin/mariadbd ] || [ -x /usr/local/mariadb/bin/mysqld ]; then
            Echo_Red "MariaDB is already installed at /usr/local/mariadb. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mariadb
        mv "${MariaDB_FileName}"/* /usr/local/mariadb/
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
            -DWITHOUT_TOKUDB=1 || {
            Echo_Red "Error: failed to configure MariaDB."
            exit 1
        }
        MariaDB_Make_Install || exit 1
    fi
    MariaDB_Check_Config
    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Set_MyCNF_104
    #MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
}

Install_MariaDB_105() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        if [ -x /usr/local/mariadb/bin/mariadbd ] || [ -x /usr/local/mariadb/bin/mysqld ]; then
            Echo_Red "MariaDB is already installed at /usr/local/mariadb. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mariadb
        mv "${MariaDB_FileName}"/* /usr/local/mariadb/
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
            -DWITHOUT_TOKUDB=1 || {
            Echo_Red "Error: failed to configure MariaDB."
            exit 1
        }
        MariaDB_Make_Install || exit 1
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    #MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
}

Install_MariaDB_106() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        if [ -x /usr/local/mariadb/bin/mariadbd ] || [ -x /usr/local/mariadb/bin/mysqld ]; then
            Echo_Red "MariaDB is already installed at /usr/local/mariadb. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mariadb
        mv "${MariaDB_FileName}"/* /usr/local/mariadb/
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
            -DWITHOUT_TOKUDB=1 || {
            Echo_Red "Error: failed to configure MariaDB."
            exit 1
        }
        MariaDB_Make_Install || exit 1
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    #MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
}

Install_MariaDB_1011() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        if [ -x /usr/local/mariadb/bin/mariadbd ] || [ -x /usr/local/mariadb/bin/mysqld ]; then
            Echo_Red "MariaDB is already installed at /usr/local/mariadb. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mariadb
        mv "${MariaDB_FileName}"/* /usr/local/mariadb/
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
            -DWITHOUT_TOKUDB=1 || {
            Echo_Red "Error: failed to configure MariaDB."
            exit 1
        }
        MariaDB_Make_Install || exit 1
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    #MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
}

Install_MariaDB_114() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        if [ -x /usr/local/mariadb/bin/mariadbd ] || [ -x /usr/local/mariadb/bin/mysqld ]; then
            Echo_Red "MariaDB is already installed at /usr/local/mariadb. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mariadb
        mv "${MariaDB_FileName}"/* /usr/local/mariadb/
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
            -DWITHOUT_TOKUDB=1 || {
            Echo_Red "Error: failed to configure MariaDB."
            exit 1
        }
        MariaDB_Make_Install || exit 1
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    #MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
}

Install_MariaDB_118() {
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mariadb_Ver} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        if [ -x /usr/local/mariadb/bin/mariadbd ] || [ -x /usr/local/mariadb/bin/mysqld ]; then
            Echo_Red "MariaDB is already installed at /usr/local/mariadb. Aborting."
            exit 1
        fi
        mkdir -p /usr/local/mariadb
        mv "${MariaDB_FileName}"/* /usr/local/mariadb/
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
            -DWITHOUT_TOKUDB=1 || {
            Echo_Red "Error: failed to configure MariaDB."
            exit 1
        }
        MariaDB_Make_Install || exit 1
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    #MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
}
