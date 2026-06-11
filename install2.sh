#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# =============================================================================
# GetLNMP installer
#
# Auto-compiles and installs LNMP / LNMPA / LAMP stacks (or individual nginx,
# database, or multiple-PHP components) on Debian-family and RHEL-family Linux.
#
# Usage: ./install2.sh {lnmp|lnmpa|lamp|nginx|db|mphp}   (default: lnmp)
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Root check
# -----------------------------------------------------------------------------
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. Resolve the script directory and work from there
# -----------------------------------------------------------------------------
cur_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${cur_dir}" || exit 1

# -----------------------------------------------------------------------------
# 3. Parse the requested stack mode (defaults to lnmp)
# -----------------------------------------------------------------------------
case "${1:-lnmp}" in
    lnmp|lnmpa|lamp|nginx|db|mphp)
        Stack="${1:-lnmp}"
        ;;
    *)
        echo "Usage: $0 {lnmp|lnmpa|lamp|nginx|db|mphp}"
        exit 1
        ;;
esac

GetLNMP_Ver='1.0'

# -----------------------------------------------------------------------------
# 4. Load configuration and library functions
# -----------------------------------------------------------------------------
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

# Print a red error message and abort. Used for unsupported version selections.
Exit_Unsupported()
{
    Echo_Red "$1"
    exit 1
}

# -----------------------------------------------------------------------------
# 5. Preflight checks
# -----------------------------------------------------------------------------
Get_Dist_Name

if [ "${DISTRO}" = "unknow" ]; then
    Echo_Red "Unable to get Linux distribution name, or do NOT support the current distribution."
    exit 1
fi

Block_Dist_Name

# Refuse to clobber an existing full-stack install.
if [[ "${Stack}" = "lnmp" || "${Stack}" = "lnmpa" || "${Stack}" = "lamp" ]]; then
    if [ -x /usr/local/php/sbin/php-fpm ] || [ -x /usr/local/php/bin/php ]; then
        Echo_Red "You have installed LNMP/LNMPA/LAMP!"
        echo "If you want to reinstall LNMP/LNMPA/LAMP, please BACKUP your data and run uninstall script: ./uninstall.sh before you install."
        exit 1
    fi
fi

Check_LNMPConf

# -----------------------------------------------------------------------------
# 6. Banner
# -----------------------------------------------------------------------------
clear
echo "+------------------------------------------------------------------------+"
echo "|      GetLNMP V${GetLNMP_Ver} for ${DISTRO} Linux Server By GetLNMP     |"
echo "+------------------------------------------------------------------------+"
echo "|        A tool to auto-compile & install LNMP/LNMPA/LAMP on Linux       |"
echo "+------------------------------------------------------------------------+"
echo "|        For more information please visit https://getlnmp.com       |"
echo "+------------------------------------------------------------------------+"

# -----------------------------------------------------------------------------
# 7. Database installation dispatch (driven by DBSelect)
#    Legacy versions (MySQL 5.5/5.6, MariaDB 5.5) are intentionally rejected.
# -----------------------------------------------------------------------------
Install_Stack_Database()
{
    case "${DBSelect}" in
        1)  Exit_Unsupported "MySQL 5.5 is no longer supported." ;;
        2)  Exit_Unsupported "MySQL 5.6 is no longer supported." ;;
        3)  Install_MySQL_57 ;;
        4)  Install_MySQL_80 ;;
        5)  Install_MySQL_84 ;;
        6)  Exit_Unsupported "MariaDB 5.5 is no longer supported" ;;
        7)  Install_MariaDB_104 ;;
        8)  Install_MariaDB_105 ;;
        9)  Install_MariaDB_106 ;;
        10) Install_MariaDB_1011 ;;
        11) Install_MariaDB_114 ;;
        12) Install_MariaDB_118 ;;
    esac
}

# -----------------------------------------------------------------------------
# 8. Shared initialization run by every full-stack mode
# -----------------------------------------------------------------------------
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

    # Remove distro AMP packages and install build dependencies.
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

    # Optional memory allocator.
    if [ "${SelectMalloc}" = "2" ]; then
        Install_Jemalloc
    elif [ "${SelectMalloc}" = "3" ]; then
        Install_TCMalloc
    fi

    Distro_Lib_Opt
    DB_BIN_Opt
    Install_Stack_Database
    TempMycnf_Clean
    Clean_DB_Src_Dir
    Check_PHP_Option
}

# -----------------------------------------------------------------------------
# 9. PHP installation dispatch (driven by PHPSelect)
#    Legacy versions (PHP 5.2 - 7.2) are intentionally rejected.
# -----------------------------------------------------------------------------
Install_PHP()
{
    case "${PHPSelect}" in
        1)  Exit_Unsupported "PHP 5.2 is no longer supported" ;;
        2)  Exit_Unsupported "PHP 5.3 is no longer supported" ;;
        3)  Exit_Unsupported "PHP 5.4 is no longer supported" ;;
        4)  Exit_Unsupported "PHP 5.5 is no longer supported" ;;
        5)  Exit_Unsupported "PHP 5.6 is no longer supported" ;;
        6)  Exit_Unsupported "PHP 7.0 is no longer supported" ;;
        7)  Exit_Unsupported "PHP 7.1 is no longer supported" ;;
        8)  Exit_Unsupported "PHP 7.2 is no longer supported" ;;
        9)  Install_PHP_73 ;;
        10) Install_PHP_74 ;;
        11) Install_PHP_80 ;;
        12) Install_PHP_81 ;;
        13) Install_PHP_82 ;;
        14) Install_PHP_83 ;;
        15) Install_PHP_84 ;;
        16) Install_PHP_85 ;;
    esac
    Clean_PHP_Src_Dir
}

# -----------------------------------------------------------------------------
# 10. Full-stack flows
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 11. Dispatch the selected stack mode
# -----------------------------------------------------------------------------
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
