#!/usr/bin/env bash

Backup_MariaDB()
{
    echo "Starting backup all databases..."
    echo "If the database is large, the backup time will be longer."
    if [ -s /usr/local/mariadb/bin/mariadb-dump ]; then
        /usr/local/mariadb/bin/mariadb-dump --defaults-file=~/.my.cnf --all-databases > /root/mariadb_all_backup${Upgrade_Date}.sql
    else
        /usr/local/mariadb/bin/mysqldump --defaults-file=~/.my.cnf --all-databases > /root/mariadb_all_backup${Upgrade_Date}.sql
    fi
    if [ $? -eq 0 ]; then
        echo "MariaDB databases backup successfully.";
    else
        echo "MariaDB databases backup failed,Please backup databases manually!"
        exit 1
    fi
    lnmp stop
    
    if [[ ! "${MariaDB_Data_Dir}" =~ ^/usr/local/mariadb/.+ ]]; then
        mv ${MariaDB_Data_Dir} ${MariaDB_Data_Dir}${Upgrade_Date}
    fi
    mv /usr/local/mariadb /usr/local/oldmariadb${Upgrade_Date}
    mv /etc/systemd/system/mariadb.service /usr/local/oldmariadb${Upgrade_Date}/mariadb.service.${Upgrade_Date}
    mv /etc/my.cnf /usr/local/oldmariadb${Upgrade_Date}/my.cnf.mariadb.bak.${Upgrade_Date}
    if echo "${mariadb_version}" | grep -Eqi '^5\.5\.' &&  echo "${cur_mariadb_version}" | grep -Eqi '^10\.';then
        sed -i 's/STATS_PERSISTENT=0//g' /root/mariadb_all_backup${Upgrade_Date}.sql
    fi
}

Upgrade_MariaDB()
{
    Check_DB
    if [ "${Is_MySQL}" = "y" ]; then
        Echo_Red "Current database was MySQL, Can't run MariaDB upgrade script."
        exit 1
    fi

    Verify_DB_Password
    if [ -s /usr/local/mariadb/bin/mariadb-config ]; then
        cur_mariadb_version=$(/usr/local/mariadb/bin/mariadb-config --version)
    else
        cur_mariadb_version=$(/usr/local/mariadb/bin/mysql_config --version)
    fi
    mariadb_version=""
    echo "Current MariaDB Version:${cur_mariadb_version}"
    echo "You can get version number from https://downloads.mariadb.org/"
    echo "We only support upgrading MariaDB to LTS version like 10.6.x, 10.11.x, 11.4.x and 11.8.x"
    Echo_Yellow "Please enter MariaDB Version you want."
    read -p "(example: 11.8.5 ): " mariadb_version

    if echo "${mariadb_version}" | grep -Eqi '^(10\.6\.|10\.11\.|11\.4\.|11\.8\.)';then
        echo "You will upgrade MariaDB to version:${mariadb_version}"
    else
        Echo_Red "Error: You input MariaDB Version was:${mariadb_version}"
        Echo_Red "We only support to upgrade MariaDB to LTS version like 10.6.x, 10.11.x, 11.4.x and 11.8.x"
        exit 1
    fi

    if [ "${mariadb_version}" = "" ]; then
        echo "Error: You must input MariaDB Version!!"
        exit 1
    fi

    if [ "${mariadb_version}" = "${cur_mariadb_version}" ]; then
        echo "Error: Your MariaDB Version is the same as the current version!!"
        exit 1
    fi

    if echo "${mariadb_version}" | grep -Eqi '^10\.6\.';then
        if [[ "${DB_ARCH}" = "x86_64" ]]; then
            read -p "Using Generic Binaries [y/n]: " Bin
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
            read -p "Using Generic Binaries [y/n]: " Bin
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
        read -p "(Default yes, if you want please enter: y , if not please enter: n): " InstallInnodb

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

    if [ -s /usr/local/include/jemalloc/jemalloc.h ] && lsof -n|grep "libjemalloc.so"|grep -q "mysqld"; then
        MariaDBMAOpt=''
    elif [ -s /usr/local/include/gperftools/tcmalloc.h ] && lsof -n|grep "libtcmalloc.so"|grep -q "mysqld"; then
        MariaDBMAOpt="-DCMAKE_EXE_LINKER_FLAGS='-ltcmalloc' -DWITH_SAFEMALLOC=OFF"
    else
        MariaDBMAOpt=''
    fi

    Press_Start

    echo "============================check files=================================="
    cd ${cur_dir}/src
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
			    Download_Files https://archive.mariadb.org/mariadb-${mariadb_version}/bintar-linux-systemd-x86_64/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
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

    Backup_MariaDB
    DB_BIN_Opt
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Starting upgrade mariadb-${mariadb_version} Using Generic Binaries..."
        if [ -d ${MariaDB_FileName} ]; then
            rm -rf ${MariaDB_FileName}
        fi
        Tar_Cd ${MariaDB_FileName}.tar.gz
        mkdir /usr/local/mariadb
        mv ${MariaDB_FileName}/* /usr/local/mariadb/
    else
        Echo_Blue "[+] Starting upgrade mariadb-${mariadb_version} Using Source code..."
        if [ -d mariadb-${mariadb_version} ]; then
            rm -rf mariadb-${mariadb_version}
        fi
        Tar_Cd mariadb-${mariadb_version}.tar.gz mariadb-${mariadb_version}
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

    #MariaDB_Add_UG
    MariaDB_My_Cnf
    MariaDB_Enable_Innodb
    MySQL_Opt
    if [ -d "${MariaDB_Data_Dir}" ]; then
        rm -rf ${MariaDB_Data_Dir}
        mkdir -p ${MariaDB_Data_Dir}
    else
        mkdir -p ${MariaDB_Data_Dir}
    fi
    chown -R mariadb:mariadb /usr/local/mariadb
    chown -R mariadb:mariadb ${MariaDB_Data_Dir}

    MariaDB_Initialize_DB
    MariaDB_Set_Startup
    Mariadb_Sec_Setting
    systemctl start mariadb

    echo "Restore backup databases..."
    /usr/local/mariadb/bin/mariadb --defaults-file=~/.my.cnf < /root/mariadb_all_backup${Upgrade_Date}.sql
    echo "Repair databases..."
    /usr/local/mariadb/bin/mariadb-upgrade -u root -p${DB_Root_Password}

    systemctl stop mariadb
    TempMycnf_Clean
    cd ${cur_dir} && rm -rf ${cur_dir}/src/mariadb-${mariadb_version}

    lnmp start
    if [[ -s /usr/local/mariadb/bin/mariadb && -s /etc/my.cnf ]]; then
        Echo_Green "======== upgrade MariaDB completed ======"
    else
        Echo_Red "======== upgrade MariaDB failed ======"
        Echo_Red "upgrade MariaDB log: /root/upgrade_mariadb${Upgrade_Date}.log"
        echo "You upload upgrade_mariadb${Upgrade_Date}.log to LNMP Forum for help."
    fi
}
