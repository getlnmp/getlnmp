#!/usr/bin/env bash

# Since Mariadb 10.4+, it supports hybrid authentication, which means you can use unix socket authentication(default mode) to login as root user without password or use password to login at the same time
# and we can backup databases with root user without password. This is more secure and more convenient.
Backup_MariaDB()
{
    dump_file="/root/mariadb_all_backup${Upgrade_Date}.sql"
    echo "Starting backup all databases..."
    echo "If the database is large, the backup time will be longer."
    # we use --single-transaction option to avoid locking tables during backup, but it only works for InnoDB tables
    # if there are MyISAM tables in your databases, you may want to use --lock-tables option instead, but it will lock tables during backup, so it's not recommended.
    # most of the time --single-transaction option is enough for backup, and it's much faster than --lock-tables option, so we use it by default.
    if [ -x /usr/local/mariadb/bin/mariadb-dump ]; then
        /usr/local/mariadb/bin/mariadb-dump --defaults-file="${HOME}/.my.cnf" --all-databases --routines --triggers --events --single-transaction > "${dump_file}"
    else
        /usr/local/mariadb/bin/mysqldump --defaults-file="${HOME}/.my.cnf" --all-databases --routines --triggers --events --single-transaction > "${dump_file}"
    fi
    if [ -s "${dump_file}" ]; then
        echo "MariaDB databases backup successfully.";
    else
        echo "MariaDB databases backup failed,Please backup databases manually!"
        exit 1
    fi
    lnmp stop
    
    if [[ ! "${MariaDB_Data_Dir}" =~ ^/usr/local/mariadb/.+ ]]; then
        mv "${MariaDB_Data_Dir}" "${MariaDB_Data_Dir}""${Upgrade_Date}"
    fi
    mv /usr/local/mariadb /usr/local/oldmariadb"${Upgrade_Date}"
    mv /etc/systemd/system/mariadb.service /usr/local/oldmariadb"${Upgrade_Date}"/mariadb.service."${Upgrade_Date}"
    mv /etc/my.cnf /usr/local/oldmariadb"${Upgrade_Date}"/my.cnf.mariadb.bak."${Upgrade_Date}"

    #remove support for downgrading from MariaDB 10.0+ to 5.5 as we've dropped support for MariaDB 5.5.
    #if echo "${mariadb_version}" | grep -Eqi '^5\.5\.' &&  echo "${cur_mariadb_version}" | grep -Eqi '^10\.';then
    #    sed -i 's/STATS_PERSISTENT=0//g' /root/mariadb_all_backup"${Upgrade_Date}".sql
    #fi
}

Restore_old_mariadb() {
    Echo_Red "Upgrade failed; restoring previous MariaDB installation."
    rm -rf /usr/local/mariadb
    mv "/usr/local/oldmariadb${Upgrade_Date}" /usr/local/mariadb 2>/dev/null
    if [ -d "${MariaDB_Data_Dir}${Upgrade_Date}" ]; then
        rm -rf "${MariaDB_Data_Dir}"
        mv "${MariaDB_Data_Dir}${Upgrade_Date}" "${MariaDB_Data_Dir}"
    fi
    mv "/usr/local/mariadb/my.cnf.mariadb.bak.${Upgrade_Date}" /etc/my.cnf 2>/dev/null
    mv "/usr/local/mariadb/mariadb.service.${Upgrade_Date}" /etc/systemd/system/mariadb.service 2>/dev/null
    rm -f /etc/systemd/system/mariadb.service.d/lnmp-malloc.conf
    rmdir /etc/systemd/system/mariadb.service.d 2>/dev/null
    systemctl daemon-reload
    systemctl start mariadb
    exit 1
}

Upgrade_MariaDB()
{
    Check_DB
    if [ "${Is_MySQL}" = "y" ]; then
        Echo_Red "Current database was MySQL, Can't run MariaDB upgrade script."
        exit 1
    fi

    Verify_DB_Password
    if [ -x /usr/local/mariadb/bin/mariadb-config ]; then
        cur_mariadb_version=$(/usr/local/mariadb/bin/mariadb-config --version)
    else
        cur_mariadb_version=$(/usr/local/mariadb/bin/mysql_config --version)
    fi
    mariadb_version=""
    echo "Current MariaDB Version:${cur_mariadb_version}"
    echo "You can get version number from https://downloads.mariadb.org/"
    echo "We only support upgrading MariaDB to LTS version like 10.6.x, 10.11.x, 11.4.x and 11.8.x"
    Echo_Yellow "Please enter MariaDB Version you want."
    read -r -p "(example: 11.8.5 ): " mariadb_version

    if echo "${mariadb_version}" | grep -Eqi '^(10\.6\.|10\.11\.|11\.4\.|11\.8\.)';then
        echo "You will upgrade MariaDB to version:${mariadb_version}"
    else
        Echo_Red "Error: You input MariaDB Version was:${mariadb_version}"
        Echo_Red "We only support to upgrade MariaDB to LTS version like 10.6.x, 10.11.x, 11.4.x and 11.8.x"
        exit 1
    fi

    if [ "${mariadb_version}" = "" ]; then
        Echo_Red "Error: You must input MariaDB Version!!"
        exit 1
    fi

    if [ "${mariadb_version}" = "${cur_mariadb_version}" ]; then
        Echo_Red "Error: Your MariaDB Version is the same as the current version!!"
        exit 1
    fi

    if [ "$(${cur_dir}/include/version_compare ${cur_mariadb_version} ${mariadb_version})" = "1" ]; then
        Echo_Red "Refusing downgrade from ${cur_mariadb_version} to ${mariadb_version}."
        exit 1
    fi

    if echo "${mariadb_version}" | grep -Eqi '^10\.6\.';then
        if [[ "${DB_ARCH}" = "x86_64" ]]; then
            read -r -p "Using Generic Binaries [y/n]: " Bin
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install mariadb-${mariadb_version} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
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
            [yY][eE][sS]|[yY])
                echo "You will install mariadb-${mariadb_version} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
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
    if [ "${Bin}" != "y" ] ; then
        #do you want to install the InnoDB Storage Engine?
        echo "==========================="

        InstallInnodb="y"
        Echo_Yellow "Do you want to install the InnoDB Storage Engine?"
        read -r -p "(Default yes, if you want please enter: y , if not please enter: n): " InstallInnodb

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
        esac
    fi
    echo "====================================================================="
    echo "You will upgrade MariaDB V${cur_mariadb_version} to V${mariadb_version}"
    echo "====================================================================="

    Press_Start

    echo "============================check files=================================="
    cd "${cur_dir}/src" || { Echo_Red "Error: cannot enter ${cur_dir}/src"; exit 1; }
    if [ "${Bin}" = "y" ]; then
        MariaDB_FileName="mariadb-${mariadb_version}-linux-systemd-${DB_ARCH}"
    else
        MariaDB_FileName="mariadb-${mariadb_version}"
    fi
    if [ -s "${MariaDB_FileName}.tar.gz" ]; then
        echo "${MariaDB_FileName}.tar.gz [found]"
    else
        echo "Notice: ${MariaDB_FileName}.tar.gz not found!!!download now......"
        Download_Files https://downloads.mariadb.org/rest-api/mariadb/${mariadb_version}/${MariaDB_FileName}.tar.gz "${MariaDB_FileName}.tar.gz"
        if [ $? -eq 0 ]; then
            echo "Download ${MariaDB_FileName}.tar.gz successfully!"
        else
			if [ "${Bin}" = "y" ]; then
		        Download_Files https://archive.mariadb.org/mariadb-${mariadb_version}/bintar-linux-systemd-${DB_ARCH}/${MariaDB_FileName}.tar.gz "${MariaDB_FileName}.tar.gz"
			else
		        Download_Files https://archive.mariadb.org/mariadb-${mariadb_version}/source/${MariaDB_FileName}.tar.gz "${MariaDB_FileName}.tar.gz"
			fi
			if [ $? -eq 0 ]; then
			    echo "Download ${MariaDB_FileName}.tar.gz successfully!"
			else
                echo "You enter MariaDB Version was: ${mariadb_version}"
                Echo_Red "Error! You entered a wrong version number or can't download from mariadb mirror, please check!"
                sleep 5
                exit 1
			fi
        fi
    fi
    echo "============================check files=================================="

    Backup_MariaDB
    DB_BIN_Opt
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Starting upgrade mariadb-${mariadb_version} Using Generic Binaries..."
        if [ -d "${MariaDB_FileName}" ]; then
            rm -rf "${MariaDB_FileName}"
        fi
        Tar_Cd "${MariaDB_FileName}.tar.gz"
        mkdir /usr/local/mariadb || Restore_old_mariadb
        mv "${MariaDB_FileName}"/* /usr/local/mariadb/ || Restore_old_mariadb
    else
        Echo_Blue "[+] Starting upgrade mariadb-${mariadb_version} Using Source code..."
        if [ -d "mariadb-${mariadb_version}" ]; then
            rm -rf "mariadb-${mariadb_version}"
        fi
        Tar_Cd "mariadb-${mariadb_version}.tar.gz" "mariadb-${mariadb_version}"
        mkdir -p mariadb-build && cd mariadb-build
        # drop MariaDB_Symbol_Check as it's only needed for mariadb 5.5 -10.3 which is not included in mariadb upgrade.
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
                Echo_Red "Error: MariaDB cmake configuration failed."
                Restore_old_mariadb
            }
        MariaDB_Make_Install || Restore_old_mariadb
    fi
    MariaDB_Check_Config

    #MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    Check_MariaDB_Data_Dir

    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    MariaDB_Sec_Setting
    systemctl start mariadb

    echo "Restore backup databases..."
    import_log="/root/mariadb_import${Upgrade_Date}.log"
    /usr/local/mariadb/bin/mariadb --defaults-file="${HOME}/.my.cnf" < /root/mariadb_all_backup${Upgrade_Date}.sql 2>"${import_log}"
    if [ $? -ne 0 ] || grep -qi '^ERROR' "${import_log}"; then
        Echo_Red "Error: MariaDB databases import failed, see ${import_log} for details. Old data remains in the backup location."
        cat "${import_log}"
        systemctl stop mariadb
        TempMycnf_Clean
        Restore_old_mariadb
    fi
    echo "Repair databases..."
    # mariadb-upgrade will check and repair tables if necessary, and also upgrade the system tables in the mysql database to be compatible with the new version.
    # it's required for major version upgrade, and also recommended for minor version upgrade.
    MYSQL_PWD="${DB_Root_Password}" /usr/local/mariadb/bin/mariadb-upgrade -u root || {
        Echo_Red "Error: mariadb-upgrade failed."
        systemctl stop mariadb
        TempMycnf_Clean
        Restore_old_mariadb
    }

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
        Echo_Green "======== upgrade MariaDB completed ======"
    else
        Echo_Red "======== upgrade MariaDB failed ======"
        Echo_Red "upgrade MariaDB log: /root/upgrade_mariadb${Upgrade_Date}.log"
        echo "Upload upgrade_mariadb${Upgrade_Date}.log to LNMP Forum for help."
        lnmp stop 2>/dev/null
        Restore_old_mariadb
    fi
}
