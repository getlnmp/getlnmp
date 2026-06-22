#!/usr/bin/env bash

Install_EL9_Chkconfig() {
    [ "${EL_Ver}" = "9" ] && dnf install chkconfig -y
}

Nginx_Dependent() {
    if [ "$PM" = "yum" ]; then
        if rpm -q httpd >/dev/null 2>&1; then
            Echo_Red "Detected Apache (httpd) installed via distro packages."
            Echo_Yellow "Nginx-only install will remove it. Back up /etc/httpd now if you need its config."
            Press_Install
            rpm -e httpd httpd-tools
        fi
        for packages in make gcc gcc-c++ wget crontabs zlib zlib-devel openssl openssl-devel perl patch bzip2 bzip2-devel initscripts xz gzip; do yum -y install $packages; done
        Get_RHEL_Family_Major
        Install_EL9_Chkconfig
    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y || apt-get update --allow-releaseinfo-change -y || {
            Echo_Red "apt-get update failed."
            exit 1
        }
        if dpkg -l apache2 2>/dev/null | grep -q '^ii'; then
            Echo_Red "Detected Apache (apache2) installed via distro packages."
            Echo_Yellow "Nginx-only install will remove it. Back up /etc/apache2 now if you need its config."
            Press_Install
            for removepackages in apache2 apache2-bin apache2-data apache2-utils apache2-doc; do
                dpkg -l "$removepackages" 2>/dev/null | grep -q '^ii' && apt-get remove -y $removepackages
            done
        fi
        for packages in debian-keyring debian-archive-keyring build-essential gcc g++ make autoconf automake wget cron openssl libssl-dev zlib1g zlib1g-dev bzip2 bzip2-doc xz-utils gzip; do apt-get --no-install-recommends install -y $packages; done
    fi
}

Install_Only_Nginx() {
    clear
    echo "+-----------------------------------------------------------------------+"
    echo "|                        Install Nginx for LNMP                         |"
    echo "+-----------------------------------------------------------------------+"
    echo "|                     A tool to only install Nginx.                     |"
    echo "+-----------------------------------------------------------------------+"
    echo "|           For more information please visit https://getlnmp.com       |"
    echo "+-----------------------------------------------------------------------+"
    Press_Install
    Echo_Blue "Install dependent packages..."
    Get_Dist_Version
    Modify_Source
    Nginx_Dependent
    cd "${cur_dir}"/src || exit
    Download_Files ${Nginx_DL} ${Nginx_Ver}.tar.gz
    Install_Nginx
    StartUp nginx
    StartOrStop start nginx
    Add_Firewall_Rules
    \cp ${cur_dir}/conf/index.html ${Default_Website_Dir}/index.html
    \cp ${cur_dir}/conf/lnmp /bin/lnmp
    Check_Nginx_Files
}

DB_Dependent() {
    if [ "$PM" = "yum" ]; then
        # yum resolves reverse-deps; avoid `rpm -e --nodeps` (silently breaks dependents).
        yum -y remove mysql-server mysql mysql-libs mariadb-server mariadb mariadb-libs
        # If distro mysql/mariadb packages still remain (e.g. differently-named ones such as
        # mysql-community-server / mariadb-connector-c), remove them by their actual names too.
        remaining_db_pkgs=$(rpm -qa --qf '%{NAME}\n' | grep -Ei '^(mysql|mariadb)')
        if [ -n "${remaining_db_pkgs}" ]; then
            echo "Removing remaining DB packages: ${remaining_db_pkgs}"
            yum -y remove ${remaining_db_pkgs}
        fi
        for packages in make cmake gcc gcc-c++ flex bison wget zlib zlib-devel openssl openssl-devel ncurses ncurses-devel libaio-devel rpcgen libtirpc-devel patch cyrus-sasl-devel pkg-config pcre-devel libxml2-devel hostname ncurses-libs numactl-devel libxcrypt gnutls-devel initscripts libxcrypt-compat perl xz gzip systemd-devel; do yum -y install $packages; done
        Get_RHEL_Family_Major

        if [ "${EL_Ver}" = "8" ]; then
            Set_RHEL_Family_CRB_Repo
            if [ "${repo_id}" != "" ]; then
                dnf --enablerepo=${repo_id} install rpcgen re2c -y
            fi
            dnf install libarchive -y

            dnf install gcc-toolset-10 -y
        fi

        if [[ "${EL_Ver}" =~ ^(9|10)$ ]]; then
            Set_RHEL_Family_CRB_Repo
            if [ "${repo_id}" != "" ]; then
                dnf --enablerepo=${repo_id} install libtirpc-devel libxcrypt-compat -y
            fi
            if [[ "${EL_Ver}" = "9" && "${Bin}" != "y" && "${DBSelect}" =~ ^[45]$ ]]; then
                dnf install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc -y
            fi
        fi

        Install_EL9_Chkconfig
    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y || apt-get update --allow-releaseinfo-change -y || {
            Echo_Red "apt-get update failed."
            exit 1
        }
        # Back up the distro DB config tree, then remove (not purge) installed packages so
        # user my.cnf / TLS material is preserved and reverse-deps are respected.
        [ -d /etc/mysql ] && mv /etc/mysql "/etc/mysql.lnmp_backup.$(date +%Y%m%d%H%M%S)"
        for removepackages in mysql-client mysql-server mysql-common mariadb-client mariadb-server mariadb-common; do
            dpkg -l "$removepackages" 2>/dev/null | grep -q '^ii' && apt-get remove -y $removepackages
        done
        for packages in debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf automake wget openssl libssl-dev zlib1g zlib1g-dev libncurses-dev bison libaio-dev libtirpc-dev libsasl2-dev pkg-config libpcre2-dev libxml2-dev libtinfo-dev libnuma-dev libgnutls28-dev gnutls-dev xz-utils gzip libsystemd-dev; do apt-get --no-install-recommends install -y $packages; done
        if echo "${Debian_Version}" | grep -Eqi "^1[3-9]" || echo "${Ubuntu_Version}" | grep -Eqi "^2[4-9]\."; then
            apt-get --no-install-recommends install -y systemd-dev
        fi
    fi
    Ncurses5_Compat_Check
}

Install_Database() {
    [ -z "${DBSelect}" ] && {
        Echo_Red "DBSelect is not set."
        exit 1
    }
    case "${DBSelect}" in
    [1-5])
        { [ -z "${Mysql_Ver}" ] || [ -z "${Mysql_Ver_Short}" ]; } && {
            Echo_Red "MySQL version not resolved."
            exit 1
        }
        ;;
    [6-9] | 1[0-2])
        { [ -z "${Mariadb_Ver}" ] || [ -z "${Mariadb_Version}" ]; } && {
            Echo_Red "MariaDB version not resolved."
            exit 1
        }
        ;;
    esac
    echo "============================check files=================================="
    cd ${cur_dir}/src
    #    Mysql_Ver_Short=$(echo ${Mysql_Ver} | sed 's/mysql-//' | cut -d. -f1-2)
    if [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        case "${Mysql_Ver_Short}" in
        5.6 | 5.7) MySQL_BIN_Glibc_Tag="glibc2.12" ;;
        *) MySQL_BIN_Glibc_Tag="glibc2.28" ;;
        esac
        if [[ "${Bin}" = "y" && "${DBSelect}" =~ ^[2-3]$ ]]; then
            Download_Files https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.gz ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.gz
            #            [[ $? -ne 0 ]] && Download_Files https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.gz ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.gz
            if [[ $? -ne 0 ]]; then
                Download_Files https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.gz ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.gz
            fi
            if [ ! -s ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.gz ]; then
                Echo_Red "Error! Unable to download MySQL ${Mysql_Ver_Short} Generic Binaries, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        elif [[ "${Bin}" = "y" && "${DBSelect}" = "4" ]]; then
            Download_Files https://cdn.mysql.com/Downloads/MySQL-8.0/${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz
            if [[ $? -ne 0 ]]; then
                Download_Files https://cdn.mysql.com/archives/mysql-8.0/${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz
            fi
            if [ ! -s ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz ]; then
                Echo_Red "Error! Unable to download MySQL 8.0 Generic Binaries, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        elif [[ "${Bin}" = "y" && "${DBSelect}" = "5" ]]; then
            Download_Files https://cdn.mysql.com/Downloads/MySQL-8.4/${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz
            if [[ $? -ne 0 ]]; then
                Download_Files https://cdn.mysql.com/archives/mysql-8.4/${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz
            fi
            if [ ! -s ${Mysql_Ver}-linux-${MySQL_BIN_Glibc_Tag}-${DB_ARCH}.tar.xz ]; then
                Echo_Red "Error! Unable to download MySQL 8.4 Generic Binaries, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        else
            Download_Files https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}.tar.gz ${Mysql_Ver}.tar.gz
            if [[ $? -ne 0 ]]; then
                Download_Files https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${Mysql_Ver}.tar.gz ${Mysql_Ver}.tar.gz
            fi
            if [ ! -s ${Mysql_Ver}.tar.gz ]; then
                Echo_Red "Error! Unable to download MySQL source code, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        fi
    elif [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        if [ "${Bin}" = "y" ]; then
            MariaDB_FileName="${Mariadb_Ver}-linux-systemd-${DB_ARCH}"
        else
            MariaDB_FileName="${Mariadb_Ver}"
        fi
        Download_Files https://downloads.mariadb.org/rest-api/mariadb/${Mariadb_Version}/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
        if [ $? -ne 0 ]; then
            if [ "${Bin}" = "y" ]; then
                Download_Files https://archive.mariadb.org/mariadb-${Mariadb_Version}/bintar-linux-systemd-${DB_ARCH}/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
            else
                Download_Files https://archive.mariadb.org/mariadb-${Mariadb_Version}/source/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
            fi
            if [ -s ${MariaDB_FileName}.tar.gz ]; then
                echo "Download ${MariaDB_FileName}.tar.gz successfully!"
            else
                Echo_Red "Error! Unable to download MariaDB, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        fi
    fi
    echo "============================check files=================================="

    Echo_Blue "Install dependent packages..."
    Get_Dist_Version
    Modify_Source
    DB_Dependent
    Check_Openssl
    DB_BIN_Opt
    if [ "${DBSelect}" = "3" ]; then
        Install_MySQL_57
    elif [ "${DBSelect}" = "4" ]; then
        Install_MySQL_80
    elif [ "${DBSelect}" = "5" ]; then
        Install_MySQL_84
    elif [ "${DBSelect}" = "7" ]; then
        Install_MariaDB_104
    elif [ "${DBSelect}" = "8" ]; then
        Install_MariaDB_105
    elif [ "${DBSelect}" = "9" ]; then
        Install_MariaDB_106
    elif [ "${DBSelect}" = "10" ]; then
        Install_MariaDB_1011
    elif [ "${DBSelect}" = "11" ]; then
        Install_MariaDB_114
    elif [ "${DBSelect}" = "12" ]; then
        Install_MariaDB_118
    fi
    TempMycnf_Clean

    if [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        StartUp mariadb
        StartOrStop start mariadb
    elif [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        StartUp mysql
        StartOrStop start mysql
    fi

    Check_DB_Files
    if [[ "${isDB}" = "ok" ]]; then
        Clean_DB_Src_Dir
        if [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
            Echo_Green "MySQL/MariaDB root password is stored in /root/.my.cnf (sudo cat /root/.my.cnf)."
            Echo_Green "Install ${Mysql_Ver} completed! enjoy it."
        elif [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
            Echo_Green "MySQL/MariaDB root password is stored in /root/.my.cnf (sudo cat /root/.my.cnf)."
            Echo_Green "Install ${Mariadb_Ver} completed! enjoy it."
        fi
    else
        Echo_Yellow "Source tree preserved at ${cur_dir}/src for debugging."
    fi
}

Install_Only_Database() {
    clear
    echo "+-----------------------------------------------------------------------+"
    echo "|             Install MySQL/MariaDB database for LNMP                   |"
    echo "+-----------------------------------------------------------------------+"
    echo "|            A tool to install MySQL/MariaDB for LNMP                   |"
    echo "+-----------------------------------------------------------------------+"
    echo "|        For more information please visit https://www.getlnmp.com      |"
    echo "+-----------------------------------------------------------------------+"

    Get_Dist_Name
    Check_DB
    if [ "${DB_Name}" != "None" ]; then
        echo "You have install ${DB_Name}!"
        exit 1
    fi

    Echo_Red "The script will REMOVE MySQL/MariaDB installed via yum or apt-get and their databases!!!"
    Database_Selection
    if [ "${DBSelect}" = "0" ]; then
        echo "DO NOT Install MySQL or MariaDB."
        exit 1
    fi
    if [ "${DBSelect}" = "1" ]; then
        Echo_Red "MySQL 5.5 is no longer supported."
        exit 1
    elif [ "${DBSelect}" = "2" ]; then
        Echo_Red "MySQL 5.6 is no longer supported."
        exit 1
    elif [ "${DBSelect}" = "6" ]; then
        Echo_Red "MariaDB 5.5 is no longer supported"
        exit 1
    fi
    Press_Install
    Install_Database 2>&1 | tee "/root/install_only_database$(date +%Y%m%d%H%M%S).log"
}
