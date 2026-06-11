#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script"
    exit 1
fi

cur_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${cur_dir}" || exit 1
action="${1,,}"
action2="${2,,}"

. lnmp.conf
. include/main.sh
. include/init.sh
. include/version.sh
. include/memcached.sh
. include/opcache.sh
. include/redis.sh
. include/imageMagick.sh
. include/ionCube.sh
. include/apcu.sh
. include/php_exif.sh
. include/php_fileinfo.sh
. include/php_ldap.sh
. include/php_bz2.sh
. include/php_sodium.sh
. include/php_imap.sh
. include/php_swoole.sh
. include/downloadlink.sh

Display_Addons_Menu()
{
    local menu_action="${1:-install}"
    echo "##### cache / optimizer / accelerator #####"
    echo "  3: Memcached"
    echo "  4: opcache"
    echo "  5: Redis"
    echo "  6: apcu"
    echo "##### Image Processing #####"
    echo "  7: imageMagick"
    echo "##### encryption/decryption utility for PHP #####"
    echo "  8: ionCube Loader"
    echo "##### PHP Modules/Extensions #####"
    echo " 10: Exif"
    echo " 11: Fileinfo"
    echo " 12: Ldap"
    echo " 13: Bz2"
    echo " 14: Sodium"
    echo " 15: Imap"
    echo " 16: Swoole"
    echo "#################################################"
    echo " exit: Exit current script"
    echo "#################################################"
    read -r -p "Enter the addon to ${menu_action} (3-8, 10-16 or exit): " action2
}

# In LAMP/LNMPA mode PHP runs as an Apache module, so restart httpd to reload the extension.
# In LNMP mode (no Apache) restart the selected php-fpm instance (main or an alternative version).
Restart_PHP()
{
    if [ -s /usr/local/apache/bin/httpd ] && [ -s /usr/local/apache/conf/httpd.conf ] && [ -s /etc/systemd/system/httpd.service ]; then
        echo "Restarting Apache......"
        systemctl restart httpd
    else
        echo "Restarting php-fpm......"
        systemctl restart ${PHPFPM_Initd}
    fi
}

clear
echo "+-----------------------------------------------------------------------+"
echo "|                    Addons script for GetLNMP                          |"
echo "+-----------------------------------------------------------------------+"
echo "|    A tool to Install cache,optimizer,accelerator...addons for LNMP    |"
echo "+-----------------------------------------------------------------------+"
echo "|         For more information please visit https://getlnmp.com         |"
echo "+-----------------------------------------------------------------------+"

Select_PHP()
{
    if [ "${action2}" == "exit" ]; then
        exit 0
    fi
    # Multiple PHP versions only run in LNMP mode (nginx + php-fpm). In LAMP and LNMPA
    # mode PHP runs as an Apache module, so always operate on the main PHP under Apache.
    if [ -s /usr/local/apache/bin/httpd ] && [ -s /usr/local/apache/conf/httpd.conf ] && [ -s /etc/systemd/system/httpd.service ]; then
        PHP_Path='/usr/local/php'
        PHPFPM_Initd='php-fpm'
    elif [[ ! -s /usr/local/php7.3/sbin/php-fpm ]] && [[ ! -s /usr/local/php7.4/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.0/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.1/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.2/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.3/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.4/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.5/sbin/php-fpm ]]; then
        PHP_Path='/usr/local/php'
        PHPFPM_Initd='php-fpm'
    else
        echo "Multiple PHP version found, Please select the PHP version."
        if [[ -x /usr/local/php/bin/php-config ]]; then
            Cur_PHP_Version="$(/usr/local/php/bin/php-config --version)"
            Echo_Green "1: Default Main PHP ${Cur_PHP_Version}"
        fi
        if [[ -s /usr/local/php7.3/sbin/php-fpm && -s /etc/systemd/system/php-fpm7.3.service ]]; then
            Echo_Green "10: PHP 7.3 [found]"
        fi
        if [[ -s /usr/local/php7.4/sbin/php-fpm && -s /etc/systemd/system/php-fpm7.4.service ]]; then
            Echo_Green "11: PHP 7.4 [found]"
        fi
        if [[ -s /usr/local/php8.0/sbin/php-fpm && -s /etc/systemd/system/php-fpm8.0.service ]]; then
            Echo_Green "12: PHP 8.0 [found]"
        fi
        if [[ -s /usr/local/php8.1/sbin/php-fpm && -s /etc/systemd/system/php-fpm8.1.service ]]; then
            Echo_Green "13: PHP 8.1 [found]"
        fi
        if [[ -s /usr/local/php8.2/sbin/php-fpm && -s /etc/systemd/system/php-fpm8.2.service ]]; then
            Echo_Green "14: PHP 8.2 [found]"
        fi
        if [[ -s /usr/local/php8.3/sbin/php-fpm && -s /etc/systemd/system/php-fpm8.3.service ]]; then
            Echo_Green "15: PHP 8.3 [found]"
        fi
        if [[ -s /usr/local/php8.4/sbin/php-fpm && -s /etc/systemd/system/php-fpm8.4.service ]]; then
            Echo_Green "16: PHP 8.4 [found]"
        fi
        if [[ -s /usr/local/php8.5/sbin/php-fpm && -s /etc/systemd/system/php-fpm8.5.service ]]; then
            Echo_Green "17: PHP 8.5 [found]"
        fi
        Echo_Yellow "Enter your choice (1, 10, 11, 12, 13, 14, 15, 16 or 17): "
        read -r php_select
        case "${php_select}" in
            1)
                if [[ -x /usr/local/php/bin/php-config ]]; then                   
                    echo "Current selection: PHP ${Cur_PHP_Version}"
                    PHP_Path='/usr/local/php'
                    PHPFPM_Initd='php-fpm'
                else
                    Echo_Red "Error: Default Main PHP not found under /usr/local/php."
                    exit 1
                fi
                ;;
            10)
                if [[ -x /usr/local/php7.3/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php7.3/bin/php-config --version)"
                    PHP_Path='/usr/local/php7.3'
                    PHPFPM_Initd='php-fpm7.3'
                else
                    Echo_Red "Error: PHP 7.3 not found under /usr/local/php7.3."
                    exit 1
                fi
                ;;
            11)
                if [[ -x /usr/local/php7.4/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php7.4/bin/php-config --version)"
                    PHP_Path='/usr/local/php7.4'
                    PHPFPM_Initd='php-fpm7.4'
                else
                    Echo_Red "Error: PHP 7.4 not found under /usr/local/php7.4."
                    exit 1
                fi
                ;;
            12)
                if [[ -x /usr/local/php8.0/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php8.0/bin/php-config --version)"
                    PHP_Path='/usr/local/php8.0'
                    PHPFPM_Initd='php-fpm8.0'
                else
                    Echo_Red "Error: PHP 8.0 not found under /usr/local/php8.0."
                    exit 1
                fi
                ;;
            13)
                if [[ -x /usr/local/php8.1/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php8.1/bin/php-config --version)"
                    PHP_Path='/usr/local/php8.1'
                    PHPFPM_Initd='php-fpm8.1'
                else
                    Echo_Red "Error: PHP 8.1 not found under /usr/local/php8.1."
                    exit 1
                fi
                ;;
            14)
                if [[ -x /usr/local/php8.2/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php8.2/bin/php-config --version)"
                    PHP_Path='/usr/local/php8.2'
                    PHPFPM_Initd='php-fpm8.2'
                else
                    Echo_Red "Error: PHP 8.2 not found under /usr/local/php8.2."
                    exit 1
                fi
                ;;
            15)
                if [[ -x /usr/local/php8.3/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php8.3/bin/php-config --version)"
                    PHP_Path='/usr/local/php8.3'
                    PHPFPM_Initd='php-fpm8.3'
                else
                    Echo_Red "Error: PHP 8.3 not found under /usr/local/php8.3."
                    exit 1
                fi
                ;;
            16)
                if [[ -x /usr/local/php8.4/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php8.4/bin/php-config --version)"
                    PHP_Path='/usr/local/php8.4'
                    PHPFPM_Initd='php-fpm8.4'
                else
                    Echo_Red "Error: PHP 8.4 not found under /usr/local/php8.4."
                    exit 1
                fi
                ;;
            17)
                if [[ -x /usr/local/php8.5/bin/php-config ]]; then
                    echo "Current selection: PHP $(/usr/local/php8.5/bin/php-config --version)"
                    PHP_Path='/usr/local/php8.5'
                    PHPFPM_Initd='php-fpm8.5'
                else
                    Echo_Red "Error: PHP 8.5 not found under /usr/local/php8.5."
                    exit 1
                fi
                ;;
            [eE][xX][iI][tT])
                exit 0
                ;;
            *)
                Echo_Red "Invalid choice: '${php_select}'. Please select one of the listed PHP versions."
                exit 1
                ;;
        esac
    fi
}

Check_Addons_PHP()
{
    if [[ -z "${PHP_Path}" || ! -x "${PHP_Path}/bin/php" || ! -x "${PHP_Path}/bin/php-config" ]]; then
        Echo_Red "Error: PHP executable or php-config not found under ${PHP_Path:-unknown}."
        Echo_Red "Please install PHP or select a valid PHP version before installing addons."
        exit 1
    fi
}

Addons_Get_PHP_Ext_Dir()
{
    Check_Addons_PHP
    Cur_PHP_Version="$(${PHP_Path}/bin/php-config --version)"
    zend_ext_dir="$(${PHP_Path}/bin/php-config --extension-dir)/"
}

Download_PHP_Src()
{
    cd "${cur_dir}/src" || exit 1
    if [ -s php-${Cur_PHP_Version}.tar.bz2 ]; then
        echo "php-${Cur_PHP_Version}.tar.bz2 [found]"
    else
        echo "Notice: php-${Cur_PHP_Version}.tar.bz2 not found!!!download now..."
        Download_Files https://www.php.net/distributions/php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}.tar.bz2
        if [ $? -eq 0 ]; then
            echo "Download php-${Cur_PHP_Version}.tar.bz2 successfully!"
        else
            Download_Files https://museum.php.net/php5/php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}.tar.bz2
            if [ $? -eq 0 ]; then
                echo "Download php-${Cur_PHP_Version}.tar.bz2 successfully!"
            else
                Echo_Red "Error! Can't download PHP ${Cur_PHP_Version}, please check!"
                exit 1
            fi
        fi
    fi
}

if [[ -z "${action}" ]]; then
    action='install'
fi
if [[ -z "${action2}" ]] && [[ "${action}" == "install" || "${action}" == "uninstall" ]]; then
    Display_Addons_Menu "${action}"
fi
# normalize menu/CLI input so addon and exit matching is case-insensitive
action2="${action2,,}"
Get_Dist_Name
Select_PHP
Check_Addons_PHP

case "${action}" in
install)
    case "${action2}" in
        3|[mM]emcached)
            Install_Memcached
            ;;
        4|opcache)
            Install_Opcache
            ;;
        5|[rR]edis)
            Install_Redis
            ;;
        6|apcu)
            Install_Apcu
            ;;
        7|image[mM]agick)
            Install_ImageMagick
            ;;
        8|ion[cC]ube)
            Install_ionCube
            ;;
        10|[eE]xif)
            Install_PHP_Exif
            ;;
        11|[fF]ileinfo)
            Install_PHP_Fileinfo
            ;;
        12|[lL]dap)
            Install_PHP_Ldap
            ;;
        13|[bB]z2)
            Install_PHP_Bz2
            ;;
        14|[sS]odium)
            Install_PHP_Sodium
            ;;
        15|[iI]map)
            Install_PHP_Imap
            ;;
        16|[sS]woole)
            Install_PHP_Swoole
            ;;
        [eE][xX][iI][tT])
            exit 0
            ;;
        *)
            echo "Usage: ./addons.sh install {memcached|opcache|redis|imagemagick|ioncube|exif|fileinfo|ldap|bz2|sodium|imap|swoole}"
            ;;
    esac
    ;;
uninstall)
    case "${action2}" in
        3|[mM]emcached)
            Uninstall_Memcached
            ;;
        4|opcache)
            Uninstall_Opcache
            ;;
        5|[rR]edis)
            Uninstall_Redis
            ;;
        6|apcu)
            Uninstall_Apcu
            ;;
        7|image[mM]agick)
            Uninstall_ImageMagick
            ;;
        8|ion[cC]ube)
            Uninstall_ionCube
            ;;
        10|[eE]xif)
            Uninstall_PHP_Exif
            ;;
        11|[fF]ileinfo)
            Uninstall_PHP_Fileinfo
            ;;
        12|[lL]dap)
            Uninstall_PHP_Ldap
            ;;
        13|[bB]z2)
            Uninstall_PHP_Bz2
            ;;
        14|[sS]odium)
            Uninstall_PHP_Sodium
            ;;
        15|[iI]map)
            Uninstall_PHP_Imap
            ;;
        16|[sS]woole)
            Uninstall_PHP_Swoole
            ;;
        *)
            echo "Usage: ./addons.sh uninstall {memcached|opcache|redis|apcu|imagemagick|ioncube|exif|fileinfo|ldap|bz2|sodium|imap|swoole}"
            ;;
    esac
    ;;
[eE][xX][iI][tT])
    exit 0
    ;;
*)
    echo "Usage: ./addons.sh {install|uninstall} {memcached|opcache|redis|apcu|imagemagick|ioncube|exif|fileinfo|ldap|bz2|sodium|imap|swoole}"
    exit 1
    ;;
esac
