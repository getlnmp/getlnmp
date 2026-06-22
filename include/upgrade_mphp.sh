#!/usr/bin/env bash

Upgrade_Multiplephp() {
    Get_Dist_Name
    Check_DB
    Check_Stack
    . include/upgrade_php.sh

    if [ "${Get_Stack}" != "lnmp" ]; then
        echo "Multiple PHP Versions ONLY for LNMP Stack!"
        exit 1
    fi

    if [[ ! -s /usr/local/php7.3/sbin/php-fpm ]] && [[ ! -s /usr/local/php7.4/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.0/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.1/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.2/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.3/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.4/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.5/sbin/php-fpm ]] && [[ ! -s /usr/local/php8.6/sbin/php-fpm ]]; then
        echo "Multiple php version not found!"
        exit 1
    else
        echo "List all mutiple php, Please select the PHP version."
        if [[ -s /usr/local/php7.3/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php7.3.conf ]]; then
            Echo_Green "5: PHP 7.3 [found]"
        fi
        if [[ -s /usr/local/php7.4/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php7.4.conf ]]; then
            Echo_Green "6: PHP 7.4 [found]"
        fi
        if [[ -s /usr/local/php8.0/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.0.conf ]]; then
            Echo_Green "7: PHP 8.0 [found]"
        fi
        if [[ -s /usr/local/php8.1/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.1.conf ]]; then
            Echo_Green "8: PHP 8.1 [found]"
        fi
        if [[ -s /usr/local/php8.2/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.2.conf ]]; then
            Echo_Green "9: PHP 8.2 [found]"
        fi
        if [[ -s /usr/local/php8.3/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.3.conf ]]; then
            Echo_Green "10: PHP 8.3 [found]"
        fi
        if [[ -s /usr/local/php8.4/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.4.conf ]]; then
            Echo_Green "11: PHP 8.4 [found]"
        fi
        if [[ -s /usr/local/php8.5/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.5.conf ]]; then
            Echo_Green "12: PHP 8.5 [found]"
        fi
        if [[ -s /usr/local/php8.6/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.6.conf ]]; then
            Echo_Green "13: PHP 8.6 [found]"
        fi
    fi

    while :; do
        MPHP_Select=""
        read -r -p "Please select which multiple php version to upgrade: " MPHP_Select
        if [ "${MPHP_Select}" = "" ]; then
            Echo_Red "Error: Please input number!"
        else
            break
        fi
    done

    if [ "${MPHP_Select}" = "5" ]; then
        Cur_MPHP_Big_Ver="7.3"
        Cur_MPHP_Path='/usr/local/php7.3'
    elif [ "${MPHP_Select}" = "6" ]; then
        Cur_MPHP_Big_Ver="7.4"
        Cur_MPHP_Path='/usr/local/php7.4'
    elif [ "${MPHP_Select}" = "7" ]; then
        Cur_MPHP_Big_Ver="8.0"
        Cur_MPHP_Path='/usr/local/php8.0'
    elif [ "${MPHP_Select}" = "8" ]; then
        Cur_MPHP_Big_Ver="8.1"
        Cur_MPHP_Path='/usr/local/php8.1'
    elif [ "${MPHP_Select}" = "9" ]; then
        Cur_MPHP_Big_Ver="8.2"
        Cur_MPHP_Path='/usr/local/php8.2'
    elif [ "${MPHP_Select}" = "10" ]; then
        Cur_MPHP_Big_Ver="8.3"
        Cur_MPHP_Path='/usr/local/php8.3'
    elif [ "${MPHP_Select}" = "11" ]; then
        Cur_MPHP_Big_Ver="8.4"
        Cur_MPHP_Path='/usr/local/php8.4'
    elif [ "${MPHP_Select}" = "12" ]; then
        Cur_MPHP_Big_Ver="8.5"
        Cur_MPHP_Path='/usr/local/php8.5'
    else
        Echo_Red "Invalid selection: ${MPHP_Select}."
        exit 1
    fi

    Echo_Yellow "Please choose which multiple php version to upgrade."
    Echo_Yellow "Note: you can't upgrade php cross-version!"

    php_version=""
    Cur_MPHP_Version=$("${Cur_MPHP_Path}/bin/php-config" --version)
    echo "Current PHP Version: ${Cur_MPHP_Version}"
    echo "You can get version number from http://www.php.net"
    read -r -p "Please enter a PHP Version you want: " php_version
    if [ "${php_version}" = "" ]; then
        Echo_Red "Error: You must enter a corrent php version!!"
        exit 1
    fi
    if [ "${php_version}" = "${Cur_MPHP_Version}" ]; then
        Echo_Red "Refusing to re-install the same version (${Cur_MPHP_Version})."
        exit 1
    fi
    if [[ "${php_version}" == "${Cur_MPHP_Big_Ver}".* ]]; then
        Echo_Blue "You will upgrade php from ${Cur_MPHP_Version} to ${php_version}."
    else
        Echo_Red "Error: You can't upgrade php cross-version!"
        exit 1
    fi
    Press_Start
    cd "${cur_dir}/src"
    if [ -s "php-${php_version}.tar.bz2" ]; then
        echo "php-${php_version}.tar.bz2 [found]"
    else
        echo "Notice: php-${php_version}.tar.bz2 not found!!!download now..."
        Download_Files https://www.php.net/distributions/php-${php_version}.tar.bz2 php-${php_version}.tar.bz2
        if [ $? -eq 0 ]; then
            echo "Download php-${php_version}.tar.bz2 successfully!"
        else
            Download_Files https://museum.php.net/php5/php-${php_version}.tar.bz2 php-${php_version}.tar.bz2
            if [ $? -eq 0 ]; then
                echo "Download php-${php_version}.tar.bz2 successfully!"
            else
                echo "You enter PHP Version was:"${php_version}
                Echo_Red "Error! You entered a wrong version number, please check!"
                exit 1
            fi
        fi
    fi

    systemctl stop php-fpm${Cur_MPHP_Big_Ver}

    Echo_Blue "Backup old multiple php version..."
    mv ${Cur_MPHP_Path} /usr/local/mphp-${Cur_MPHP_Big_Ver}-backup${Upgrade_Date}
    #mv /etc/systemd/system/php-fpm${Cur_MPHP_Big_Ver}.service /etc/systemd/system/php-fpm${Cur_MPHP_Big_Ver}.service.bak.${Upgrade_Date}

    Check_PHP_Option
    cat /etc/issue
    cat /etc/*-release
    #for upgrade, usually it does not need to install any new dependents
    #Install_PHP_Dependent
    Check_Openssl

    if [ "${MPHP_Select}" = "5" ]; then
        Upgrade_MPHP7_3
    elif [ "${MPHP_Select}" = "6" ]; then
        Upgrade_MPHP7_4
    elif [ "${MPHP_Select}" = "7" ]; then
        Upgrade_MPHP8_0
    elif [ "${MPHP_Select}" = "8" ]; then
        Upgrade_MPHP8_1
    elif [ "${MPHP_Select}" = "9" ]; then
        Upgrade_MPHP8_2
    elif [ "${MPHP_Select}" = "10" ]; then
        Upgrade_MPHP8_3
    elif [ "${MPHP_Select}" = "11" ]; then
        Upgrade_MPHP8_4
    elif [ "${MPHP_Select}" = "12" ]; then
        Upgrade_MPHP8_5
    else
        Echo_Red "PHP version: ${php_version} is not supported."
        exit 1
    fi
}

Upgrade_MPHP7_3() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "7.3"
    # start php-fpm
    MPHP_U_Startup "7.3"
    # config nginx php
    MPHP_Set_Nginx "7.3"
    # final check
    MPHP_U_Final_Check "7.3"
}

Upgrade_MPHP7_4() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "7.4"
    # start php-fpm
    MPHP_U_Startup "7.4"
    # config nginx php
    MPHP_Set_Nginx "7.4"
    # final check
    MPHP_U_Final_Check "7.4"
}

Upgrade_MPHP8_0() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.0"
    # start php-fpm
    MPHP_U_Startup "8.0"
    # config nginx php
    MPHP_Set_Nginx "8.0"
    # final check
    MPHP_U_Final_Check "8.0"
}

Upgrade_MPHP8_1() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.1"
    # start php-fpm
    MPHP_U_Startup "8.1"
    # config nginx php
    MPHP_Set_Nginx "8.1"
    # final check
    MPHP_U_Final_Check "8.1"
}

Upgrade_MPHP8_2() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.2"
    # start php-fpm
    MPHP_U_Startup "8.2"
    # config nginx php
    MPHP_Set_Nginx "8.2"
    # final check
    MPHP_U_Final_Check "8.2"
}

Upgrade_MPHP8_3() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.3"
    # start php-fpm
    MPHP_U_Startup "8.3"
    # config nginx php
    MPHP_Set_Nginx "8.3"
    # final check
    MPHP_U_Final_Check "8.3"
}

Upgrade_MPHP8_4() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.4"
    # start php-fpm
    MPHP_U_Startup "8.4"
    # config nginx php
    MPHP_Set_Nginx "8.4"
    # final check
    MPHP_U_Final_Check "8.4"
}

Upgrade_MPHP8_5() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # sert php ini
    MPHP_U_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.5"
    # start php-fpm
    MPHP_U_Startup "8.5"
    # config nginx php
    MPHP_Set_Nginx "8.5"
    # final check
    MPHP_U_Final_Check "8.5"
}
