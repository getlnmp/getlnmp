#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi

# get current dir
cur_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${cur_dir}" || exit 1

# dispatch stack
case "${1:-lnmp}" in
    lnmp|lnmpa|lamp|nginx|db|mphp) 
        Stack="${1:-lnmp}"
        ;;
    *) 
        Echo_Red "Usage: $0 {lnmp|lnmpa|lamp|nginx|db|mphp}"
        exit 1
        ;;
esac

GetLNMP_Ver='1.0'
. lnmp.conf
. include/version.sh
. include/downloadlink.sh
. include/main.sh
. include/init.sh
. include/mysql.sh
. include/mariadb.sh
. include/php.sh
. include/nginx.sh
. include/apache.sh
. include/end.sh
. include/only.sh
. include/multiplephp.sh

Get_Dist_Name

if [ "${DISTRO}" = "unknow" ]; then
    Echo_Red "Unable to get Linux distribution name, or do NOT support the current distribution."
    exit 1
fi

Block_Dist_Name

if [[ "${Stack}" = "lnmp" || "${Stack}" = "lnmpa" || "${Stack}" = "lamp" ]]; then
    if [ -x /usr/local/php/sbin/php-fpm ] || [ -x /usr/local/php/bin/php ]; then
        Echo_Red "You have installed LNMP/LNMPA/LAMP!"
        echo "If you want to reinstall LNMP/LNMPA/LAMP, please BACKUP your data and run uninstall script: ./uninstall.sh before you install."
        exit 1
    fi
fi

Check_LNMPConf

clear
echo "+------------------------------------------------------------------------+"
echo "|      GetLNMP V${GetLNMP_Ver} for ${DISTRO} Linux Server By GetLNMP     |"
echo "+------------------------------------------------------------------------+"
echo "|        A tool to auto-compile & install LNMP/LNMPA/LAMP on Linux       |"
echo "+------------------------------------------------------------------------+"
echo "|        For more information please visit https://www.getlnmp.com       |"
echo "+------------------------------------------------------------------------+"

Init_Install()
{
    Print_APP_Ver
    Press_Install
    Stop_Package_Manager
    Get_Dist_Version
    Print_Sys_Info
    Check_Hosts
    Check_CMPT
    if [ "${CheckMirror}" != "n" ]; then
        Modify_Source
#       Check_Mirror
    fi
    Add_Swap
    Set_Timezone
    Sync_Time
    if [ "$PM" = "yum" ]; then
        RHEL_RemoveAMP
        RHEL_Dependent
    elif [ "$PM" = "apt" ]; then
        Deb_RemoveAMP
        Deb_Dependent
    fi
    Disable_Selinux
    Check_Openssl
    Check_Download
    Install_Freetype
    if [ "${SelectMalloc}" = "2" ]; then
        Install_Jemalloc
    elif [ "${SelectMalloc}" = "3" ]; then
        Install_TCMalloc
    fi
    Distro_Lib_Opt
    DB_BIN_Opt
    if [ "${DBSelect}" = "1" ]; then
        Echo_Red "MySQL 5.5 is no longer supported."
        exit 1
    elif [ "${DBSelect}" = "2" ]; then
        Echo_Red "MySQL 5.6 is no longer supported."
        exit 1
    elif [ "${DBSelect}" = "3" ]; then
        Install_MySQL_57
    elif [ "${DBSelect}" = "4" ]; then
        Install_MySQL_80
    elif [ "${DBSelect}" = "5" ]; then
        Install_MySQL_84
    elif [ "${DBSelect}" = "6" ]; then
        Echo_Red "MariaDB 5.5 is no longer supported"
        exit 1
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
    Clean_DB_Src_Dir
    Check_PHP_Option
}

Install_PHP()
{
    if [ "${PHPSelect}" = "1" ]; then
        Echo_Red "PHP 5.2 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "2" ]; then
        Echo_Red "PHP 5.3 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "3" ]; then
        Echo_Red "PHP 5.4 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "4" ]; then
        Echo_Red "PHP 5.5 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "5" ]; then
        Echo_Red "PHP 5.6 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "6" ]; then
        Echo_Red "PHP 7.0 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "7" ]; then
        Echo_Red "PHP 7.1 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "8" ]; then
        Echo_Red "PHP 7.2 is no longer supported"
        exit 1
    elif [ "${PHPSelect}" = "9" ]; then
        Install_PHP_73
    elif [ "${PHPSelect}" = "10" ]; then
        Install_PHP_74
    elif [ "${PHPSelect}" = "11" ]; then
        Install_PHP_80
    elif [ "${PHPSelect}" = "12" ]; then
        Install_PHP_81
    elif [ "${PHPSelect}" = "13" ]; then
        Install_PHP_82
    elif [ "${PHPSelect}" = "14" ]; then
        Install_PHP_83
    elif [ "${PHPSelect}" = "15" ]; then
        Install_PHP_84
    elif [ "${PHPSelect}" = "16" ]; then
        Install_PHP_85
    fi
    Clean_PHP_Src_Dir
}

LNMP_Stack()
{
    Init_Install
    Install_PHP
    LNMP_PHP_Opt
    Install_Nginx
    Creat_PHP_Tools
    Add_Firewall_Rules
    Add_LNMP_Startup
    Check_LNMP_Install
}

LNMPA_Stack()
{
    Apache_Selection
    Init_Install
    Install_Apache_24
    Install_PHP
    Install_Nginx
    Creat_PHP_Tools
    Add_Firewall_Rules
    Add_LNMPA_Startup
    Check_LNMPA_Install
}

LAMP_Stack()
{
    Apache_Selection
    Init_Install
    Install_Apache_24
    Install_PHP
    Creat_PHP_Tools
    Add_Firewall_Rules
    Add_LAMP_Startup
    Check_LAMP_Install
}

case "${Stack}" in
    lnmp)
        Display_Selection
        LNMP_Stack 2>&1 | tee /root/getlnmp-install.log
        ;;
    lnmpa)
        Display_Selection
        LNMPA_Stack 2>&1 | tee /root/getlnmp-install.log
        ;;
    lamp)
        Display_Selection
        LAMP_Stack 2>&1 | tee /root/getlnmp-install.log
        ;;
    nginx)
        Install_Only_Nginx 2>&1 | tee /root/nginx-install.log
        ;;
    db)
        Install_Only_Database
        ;;
    mphp)
        Install_Multiplephp
        ;;
    *)
        Echo_Red "Usage: $0 {lnmp|lnmpa|lamp|nginx|db|mphp}"
        exit 1
        ;;
esac
