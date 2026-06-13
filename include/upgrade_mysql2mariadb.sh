#!/usr/bin/env bash

Backup_MySQL2() {
    echo "Starting backup all databases..."
    echo "If the database is large, the backup time will be longer."
    # we use --single-transaction option to avoid locking tables during backup, but it only works for InnoDB tables
    # if there are MyISAM tables in your databases, you may want to use --lock-tables option instead, but it will lock tables during backup, so it's not recommended.
    # most of the time --single-transaction option is enough for backup, and it's much faster than --lock-tables option, so we use it by default.
    /usr/local/mysql/bin/mysql --defaults-file="${HOME}/.my.cnf" -N -B -e "
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN (
  'mysql',
  'information_schema',
  'performance_schema',
  'sys'
)
ORDER BY schema_name;
" | xargs -r /usr/local/mysql/bin/mysqldump --defaults-file="${HOME}/.my.cnf" \
        --databases \
        --routines \
        --triggers \
        --events \
        --single-transaction \
        --quick \
        >"/root/mysql_all_backup${Upgrade_Date}.sql"
    if [ -s "/root/mysql_all_backup${Upgrade_Date}.sql" ]; then
        echo "MySQL databases backup successfully."
    else
        echo "MySQL databases backup failed,Please backup databases manually!"
        exit 1
    fi

    # MySQL 8.0 stamps databases/tables with utf8mb4_0900_* collations (default is
    # utf8mb4_0900_ai_ci), which MariaDB does not recognize and rejects on import with
    # "ERROR 1273 (HY000): Unknown collation". Remap them to MariaDB-supported collations
    # so the cross-engine import succeeds. utf8mb4_0900_bin maps to utf8mb4_bin to keep
    # binary semantics; the rest map to utf8mb4_general_ci (the project default).
    backup_sql="/root/mysql_all_backup${Upgrade_Date}.sql"
    if grep -q 'utf8mb4_0900_' "${backup_sql}"; then
        echo "Converting MySQL 8.0 utf8mb4_0900_* collations to MariaDB-compatible collations..."
        sed -i -E 's/utf8mb4_0900_bin/utf8mb4_bin/g; s/utf8mb4_0900_[a-z0-9]+_[a-z0-9]+/utf8mb4_general_ci/g' "${backup_sql}"
    fi

    # MySQL version-gated executable comments like /*!80016 ... */ are evaluated by MariaDB
    # against its own (much higher) version number, so MariaDB executes MySQL-8.x-only
    # syntax instead of skipping it. Neutralize the 8.x gates into plain (inert) comments
    # so MariaDB ignores that MySQL-specific syntax on import. Standard scaffolding gated
    # below 8.0 (e.g. /*!40101 ... */, /*!50503 ... */) is left intact.
    if grep -Eq '/\*!8[0-9]{4} ' "${backup_sql}"; then
        echo "Neutralizing MySQL 8.x version-gated executable comments for MariaDB..."
        sed -i -E 's#/\*!8[0-9]{4} #/* #g' "${backup_sql}"
    fi

    lnmp stop
    echo "Remove autostart..."
    Remove_StartUp mysql
    mv /usr/local/mysql /usr/local/mysql2mariadb${Upgrade_Date}
    mv /etc/systemd/system/mysql.service /usr/local/mysql2mariadb${Upgrade_Date}/mysql2mariadb.service.bak.${Upgrade_Date}
    mv /etc/my.cnf /usr/local/mysql2mariadb${Upgrade_Date}/my.cnf.mysql2mariadbbak.${Upgrade_Date}
    if [[ ! "${MySQL_Data_Dir}" =~ ^/usr/local/mysql/ ]]; then
        mv "${MySQL_Data_Dir}" "${MySQL_Data_Dir}""${Upgrade_Date}"
    fi
    # remove upgrading support from mysql 5.6 to mariadb 5.5 as we've dropped support for mariadb 5.5 and mysql 5.6
    #if echo "${mariadb_version}" | grep -Eqi '^5\.5\.' &&  echo "${cur_mysql_version}" | grep -Eqi '^5\.6\.';then
    #    sed -i 's/STATS_PERSISTENT=0//g' /root/mysql_all_backup${Upgrade_Date}.sql
    #fi
}

Restore_old_mysql2mariadb() {
    Echo_Red "Upgrade failed; restoring previous MySQL installation."
    rm -rf /usr/local/mariadb
    mv "/usr/local/mysql2mariadb${Upgrade_Date}" /usr/local/mysql 2>/dev/null
    if [ -d "${MySQL_Data_Dir}${Upgrade_Date}" ]; then
        rm -rf "${MySQL_Data_Dir}"
        mv "${MySQL_Data_Dir}${Upgrade_Date}" "${MySQL_Data_Dir}"
    fi
    mv "/usr/local/mysql/mysql2mariadb.service.bak.${Upgrade_Date}" /etc/systemd/system/mysql.service 2>/dev/null
    mv "/usr/local/mysql/my.cnf.mysql2mariadbbak.${Upgrade_Date}" /etc/my.cnf 2>/dev/null
    rm -f /etc/systemd/system/mariadb.service.d/lnmp-malloc.conf
    rmdir /etc/systemd/system/mariadb.service.d 2>/dev/null
    systemctl daemon-reload
    systemctl start mysql
    exit 1
}

Upgrade_MySQL2MariaDB() {
    Check_DB
    if [ "${Is_MySQL}" = "n" ]; then
        Echo_Red "Current database was MariaDB, Can't run MySQL2MariaDB upgrade script."
        exit 1
    fi
    Verify_DB_Password

    cur_mysql_version=$(/usr/local/mysql/bin/mysql_config --version)
    mariadb_version=""
    echo "Current MySQL Version:${cur_mysql_version}"
    echo "You can get version number from https://downloads.mariadb.org/"
    echo "We only support upgrading MySQL to LTS version like 10.6.x, 10.11.x, 11.4.x and 11.8.x"
    Echo_Yellow "Please enter MariaDB Version you want."
    read -r -p "(example: 11.8.5 ): " mariadb_version
    if echo "${mariadb_version}" | grep -Eqi '^(10\.6\.|10\.11\.|11\.4\.|11\.8\.)'; then
        echo "You will upgrade MySQL to version:${mariadb_version}"
    else
        Echo_Red "Error: You input MariaDB Version was:${mariadb_version}"
        Echo_Red "We only support to upgrade MySQL to MariaDB LTS version like 10.6.x, 10.11.x, 11.4.x and 11.8.x"
        exit 1
    fi

    if [ "${mariadb_version}" = "" ]; then
        echo "Error: You must input MariaDB Version!!"
        exit 1
    fi

    if echo "${mariadb_version}" | grep -Eqi '^10\.6\.'; then
        if [[ "${DB_ARCH}" = "x86_64" ]]; then
            read -r -p "Using Generic Binaries [y/n]: " Bin
            case "${Bin}" in
            [yY][eE][sS] | [yY])
                echo "You will install mariadb-${mariadb_version} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO] | [nN])
                echo "You will install mariadb-${mariadb_version} from Source."
                Bin="n"
                ;;
            *)
                echo "You will install mariadb-${mariadb_version} Using Generic Binaries."
                Bin="y"
                ;;
            esac
        else
            Bin="n"
        fi
    else
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]]; then
            read -r -p "Using Generic Binaries [y/n]: " Bin
            case "${Bin}" in
            [yY][eE][sS] | [yY])
                echo "You will install mariadb-${mariadb_version} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO] | [nN])
                echo "You will install mariadb-${mariadb_version} from Source."
                Bin="n"
                ;;
            *)
                echo "You will install mariadb-${mariadb_version} Using Generic Binaries."
                Bin="y"
                ;;
            esac
        else
            Bin="n"
        fi
    fi

    #do you want to install the InnoDB Storage Engine?
    echo "==========================="

    InstallInnodb="y"
    Echo_Yellow "Do you want to install the InnoDB Storage Engine?"
    read -r -p "(Default yes, if you want please enter: y , if not please enter: n): " InstallInnodb

    case "${InstallInnodb}" in
    [yY][eE][sS] | [yY])
        echo "You will install the InnoDB Storage Engine"
        InstallInnodb="y"
        ;;
    [nN][oO] | [nN])
        echo "You will NOT install the InnoDB Storage Engine!"
        InstallInnodb="n"
        ;;
    *)
        echo "No input, The InnoDB Storage Engine will enable."
        InstallInnodb="y"
        ;;
    esac

    echo "====================================================================="
    echo "You will upgrade MySQL V${cur_mysql_version} to MariaDB V${mariadb_version}"
    echo "====================================================================="

    Press_Start

    echo "============================check files=================================="
    cd "${cur_dir}/src" || {
        Echo_Red "Error: cannot enter ${cur_dir}/src"
        exit 1
    }
    if [ "${Bin}" = "y" ]; then
        MariaDB_FileName="mariadb-${mariadb_version}-linux-systemd-${DB_ARCH}"
    else
        MariaDB_FileName="mariadb-${mariadb_version}"
    fi
    if [ -s ${MariaDB_FileName}.tar.gz ]; then
        echo "${MariaDB_FileName}.tar.gz [found]"
    else
        echo "Notice: ${MariaDB_FileName}.tar.gz not found!!!download now......"
        Download_Files https://downloads.mariadb.org/rest-api/mariadb/${mariadb_version}/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
        if [ $? -eq 0 ]; then
            echo "Download ${MariaDB_FileName}.tar.gz successfully!"
        else
            if [ "${Bin}" = "y" ]; then
                Download_Files https://archive.mariadb.org/mariadb-${mariadb_version}/bintar-linux-systemd-${DB_ARCH}/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
            else
                Download_Files https://archive.mariadb.org/mariadb-${mariadb_version}/source/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
            fi
            if [ $? -eq 0 ]; then
                echo "Download ${MariaDB_FileName}.tar.gz successfully!"
            else
                echo "You enter MariaDB Version was:"${mariadb_version}
                Echo_Red "Error! You entered a wrong version number or can't download from mariadb mirror, please check!"
                sleep 5
                exit 1
            fi
        fi
    fi
    echo "============================check files=================================="

    Backup_MySQL2

    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Starting upgrade mariadb-${mariadb_version} Using Generic Binaries..."
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb || Restore_old_mysql2mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/ || Restore_old_mysql2mariadb
    else
        Echo_Blue "[+] Starting upgrade mariadb-${mariadb_version} Using Source code..."
        Tar_Cd mariadb-${mariadb_version}.tar.gz mariadb-${mariadb_version}
        # if echo "${mariadb_version}" | grep -Eqi '^10\.4.';then
        #     patch -p1 < ${cur_dir}/src/patch/mariadb_10.4_install_db.patch
        # fi
        mkdir -p mariadb-build && cd mariadb-build
        if echo "${mariadb_version}" | grep -Eqi '^(10\.([5-9]|1[0-9])|1[1-9])\.'; then
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb -DMYSQL_UNIX_ADDR=/tmp/mysql.sock -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_READLINE=1 -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 -DWITHOUT_TOKUDB=1 || {
                Echo_Red "Error: MariaDB cmake configuration failed."
                Restore_old_mysql2mariadb
            }
        elif echo "${mariadb_version}" | grep -Eqi '^10\.4.'; then
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb -DMYSQL_UNIX_ADDR=/tmp/mysql.sock -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_READLINE=1 -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 -DWITHOUT_TOKUDB=1 || {
                Echo_Red "Error: MariaDB cmake configuration failed."
                Restore_old_mysql2mariadb
            }
        elif echo "${mariadb_version}" | grep -Eqi '^10\.[123].'; then
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb -DWITH_ARIA_STORAGE_ENGINE=1 -DWITH_XTRADB_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_READLINE=1 -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 -DWITHOUT_TOKUDB=1 ${MariaDBWITHSSL} || {
                Echo_Red "Error: MariaDB cmake configuration failed."
                Restore_old_mysql2mariadb
            }
        else
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb -DWITH_ARIA_STORAGE_ENGINE=1 -DWITH_XTRADB_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_READLINE=1 -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MariaDBWITHSSL} || {
                Echo_Red "Error: MariaDB cmake configuration failed."
                Restore_old_mysql2mariadb
            }
        fi
        MariaDB_Make_Install || Restore_old_mysql2mariadb
    fi

    MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir
    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
    systemctl start mariadb

    echo "Restore backup databases..."
    import_log="/root/mysql2mariadb_import${Upgrade_Date}.log"
    /usr/local/mariadb/bin/mysql --defaults-file="${HOME}/.my.cnf" </root/mysql_all_backup${Upgrade_Date}.sql 2>"${import_log}"
    if [ $? -ne 0 ] || grep -qi '^ERROR' "${import_log}"; then
        Echo_Red "Error: MariaDB databases import failed, see ${import_log} for details. Old data remains in the backup location."
        cat "${import_log}"
        systemctl stop mariadb
        TempMycnf_Clean
        Restore_old_mysql2mariadb
    fi

    echo "Repair databases..."
    MYSQL_PWD="${DB_Root_Password}" /usr/local/mariadb/bin/mariadb-upgrade -u root || {
        Echo_Red "Error: mariadb-upgrade failed."
        systemctl stop mariadb
        TempMycnf_Clean
        Restore_old_mysql2mariadb
    }

    echo "Add to autostart..."
    systemctl enable mariadb
    echo "Stopping MariaDB..."
    systemctl stop mariadb
    TempMycnf_Clean
    cd "${cur_dir}/src" && rm -rf "${cur_dir}"/src/mariadb-"${mariadb_version}" "${cur_dir}"/src/mariadb-"${mariadb_version}"-linux-*

    lnmp start
    if [ -x /usr/local/mariadb/bin/mariadb-config ]; then
        new_mariadb_version=$(/usr/local/mariadb/bin/mariadb-config --version)
    else
        new_mariadb_version=$(/usr/local/mariadb/bin/mysql_config --version)
    fi
    if [ "${new_mariadb_version}" = "${mariadb_version}" ]; then
        Echo_Green "======== upgrade MySQL to MariaDB completed ======"
        # The mysql system schema is not migrated across engines, so user accounts and
        # their privileges were NOT carried over (and MySQL 8.0 caching_sha2_password
        # users could not be ported to MariaDB anyway). Only the root account exists now.
        Echo_Yellow "=============================== IMPORTANT ==============================="
        Echo_Yellow "Database user accounts and privileges were NOT migrated to MariaDB."
        Echo_Yellow "Only the root account is available. You need to re-create your database"
        Echo_Yellow "users and re-grant their privileges, e.g.:"
        Echo_Yellow "  CREATE USER 'youruser'@'localhost' IDENTIFIED BY 'yourpassword';"
        Echo_Yellow "  GRANT ALL PRIVILEGES ON yourdb.* TO 'youruser'@'localhost';"
        Echo_Yellow "  FLUSH PRIVILEGES;"
        Echo_Yellow "========================================================================"
    else
        Echo_Red "======== upgrade MySQL to MariaDB failed ======"
        Echo_Red "upgrade MariaDB log: /root/upgrade_mysql2mariadb${Upgrade_Date}.log"
        echo "You upload upgrade_mysql2mariadb${Upgrade_Date}.log to LNMP Forum for help."
        lnmp stop 2>/dev/null
        Restore_old_mysql2mariadb
    fi
}
