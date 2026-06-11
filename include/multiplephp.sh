#!/usr/bin/env bash

Install_Multiplephp()
{
    Get_Dist_Name
    Check_DB
    Check_Stack
    Get_Dist_Version
    . include/upgrade_php.sh

    if [ "${Get_Stack}" != "lnmp" ]; then
        echo "Multiple PHP Versions ONLY for LNMP Stack!"
        exit 1
    fi

    #which PHP Version do you want to install?
    echo "==========================="

    PHPSelect=""
    Echo_Yellow "You have below options for your PHP install."
    #echo "1: Install ${PHP_Info[0]}"
    #echo "2: Install ${PHP_Info[1]}"
    #echo "3: Install ${PHP_Info[2]}"
    #echo "4: Install ${PHP_Info[3]}"
    #echo "5: Install ${PHP_Info[4]}"
    #echo "6: Install ${PHP_Info[5]}"
    #echo "7: Install ${PHP_Info[6]}"
    #echo "8: Install ${PHP_Info[7]}"
    echo "9: Install ${PHP_Info[8]}"
    echo "10: Install ${PHP_Info[9]}"
    echo "11: Install ${PHP_Info[10]}"
    echo "12: Install ${PHP_Info[11]}"
    echo "13: Install ${PHP_Info[12]}"
    echo "14: Install ${PHP_Info[13]}"
    echo "15: Install ${PHP_Info[14]}"
    echo "16: Install ${PHP_Info[15]}"
    read -r -p "Enter your choice (9, 10, 11, 12, 13, 14, 15 or 16): " PHPSelect
    case "${PHPSelect}" in
    9)
        echo "You will install ${PHP_Info[8]}"
        MPHP_Path='/usr/local/php7.3'
        ;;
    10)
        echo "You will install ${PHP_Info[9]}"
        MPHP_Path='/usr/local/php7.4'
        ;;
    11)
        echo "You will install ${PHP_Info[10]}"
        MPHP_Path='/usr/local/php8.0'
        ;;
    12)
        echo "You will install ${PHP_Info[11]}"
        MPHP_Path='/usr/local/php8.1'
        ;;
    13)
        echo "You will install ${PHP_Info[12]}"
        MPHP_Path='/usr/local/php8.2'
        ;;
    14)
        echo "You will install ${PHP_Info[13]}"
        MPHP_Path='/usr/local/php8.3'
        ;;
    15)
        echo "You will install ${PHP_Info[14]}"
        MPHP_Path='/usr/local/php8.4'
        ;;
    16)
        echo "You will install ${PHP_Info[15]}"
        MPHP_Path='/usr/local/php8.5'
        ;;
    *)
        echo "No selection, You MUST choose one option."
        exit 1
        ;;
    esac

    # Press_Install sources include/version.sh, which maps the menu choice
    # ${PHPSelect} to the matching ${Php_Ver} (e.g. 9 -> php-7.3.33); the
    # guard below catches the case where that mapping produced nothing.
    Press_Install
    if [ -d "${MPHP_Path}" ]; then
        echo "${MPHP_Path} already exists!"
        exit 1
    fi
    if [ -z "${Php_Ver}" ]; then
        echo "PHP version is not specified!"
        exit 1
    fi
    Check_PHP_Option
    cat /etc/issue
    cat /etc/*-release
    if pkg-config --exists libxml-2.0 zlib openssl; then
        Echo_Yellow "PHP build deps already present; skipping Install_PHP_Dependent."
    else
        Install_PHP_Dependent
    fi
    Check_Openssl

    if [ "${PHPSelect}" = "9" ]; then
        Install_MPHP7_3 2>&1 | tee /root/install-mphp7.3.log
    elif [ "${PHPSelect}" = "10" ]; then
        Install_MPHP7_4 2>&1 | tee /root/install-mphp7.4.log
    elif [ "${PHPSelect}" = "11" ]; then
        Install_MPHP8_0 2>&1 | tee /root/install-mphp8.0.log
    elif [ "${PHPSelect}" = "12" ]; then
        Install_MPHP8_1 2>&1 | tee /root/install-mphp8.1.log
    elif [ "${PHPSelect}" = "13" ]; then
        Install_MPHP8_2 2>&1 | tee /root/install-mphp8.2.log
    elif [ "${PHPSelect}" = "14" ]; then
        Install_MPHP8_3 2>&1 | tee /root/install-mphp8.3.log
    elif [ "${PHPSelect}" = "15" ]; then
        Install_MPHP8_4 2>&1 | tee /root/install-mphp8.4.log
    elif [ "${PHPSelect}" = "16" ]; then
        Install_MPHP8_5 2>&1 | tee /root/install-mphp8.5.log
    fi
}

MPHP_Get_Files() {
    if [ -n "${php_version}" ] && [ -z "${Php_Ver}" ]; then
        Php_Ver="php-${php_version}"
    fi
    cd ${cur_dir}/src
    if [ ! -s "${Php_Ver}.tar.bz2" ]; then
        Download_Files_Exit https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    fi
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Patch
}

MPHP_Set_Config() {
    if [ -n "${Cur_MPHP_Path}" ] && [ -z "${MPHP_Path}" ]; then
        local M_Path="${Cur_MPHP_Path}"
    elif [ -n "${MPHP_Path}" ] && [ -z "${Cur_MPHP_Path}" ]; then
        local M_Path="${MPHP_Path}"
    else
        Echo_Red "Multiple PHP Paths are not found, please check!"
        exit 1
    fi
    if [[ "${Php_Ver}" =~ ^php-7\.3\. ]] || [[ "${php_version}" =~ ^7\.3\. ]]; then
        ./configure --prefix=${M_Path} --with-config-file-path=${M_Path}/etc --with-config-file-scan-dir=${M_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    elif [[ "${Php_Ver}" =~ ^php-7\.4\. ]] || [[ "${php_version}" =~ ^7\.4\. ]]; then
        ./configure --prefix=${M_Path} --with-config-file-path=${M_Path}/etc --with-config-file-scan-dir=${M_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    elif [[ "${Php_Ver}" =~ ^php-8\.[0-9]\. ]] || [[ "${php_version}" =~ ^8\.[0-9]\. ]]; then
        ./configure --prefix=${M_Path} --with-config-file-path=${M_Path}/etc --with-config-file-scan-dir=${M_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        Echo_Red "Unsupported PHP version: ${Php_Ver}"
        exit 1
    fi
}

MPHP_Cp_Ini() {
    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini
}


MPHP_Set_Ini() {
    if [ -n "${Cur_MPHP_Path}" ] && [ -z "${MPHP_Path}" ]; then
        local M_Path="${Cur_MPHP_Path}"
    elif [ -n "${MPHP_Path}" ] && [ -z "${Cur_MPHP_Path}" ]; then
        local M_Path="${MPHP_Path}"
    else
        Echo_Red "Multiple PHP Paths are not found, please check!"
        exit 1
    fi
    echo "Modify php.ini......"
    sed -i 's|post_max_size =.*|post_max_size = 50M|g' ${M_Path}/etc/php.ini
    sed -i 's|upload_max_filesize =.*|upload_max_filesize = 50M|g' ${M_Path}/etc/php.ini
    sed -i "s|;date.timezone =.*|date.timezone = ${PHP_Timezone}|g" ${M_Path}/etc/php.ini
    sed -i 's|short_open_tag =.*|short_open_tag = On|g' ${M_Path}/etc/php.ini
    sed -i 's|;cgi.fix_pathinfo=.*|cgi.fix_pathinfo=0|g' ${M_Path}/etc/php.ini
    sed -i 's|max_execution_time =.*|max_execution_time = 300|g' ${M_Path}/etc/php.ini
    sed -i 's|disable_functions =.*|disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog|g' ${M_Path}/etc/php.ini
}

MPHP_U_Set_Ini() {
    mkdir -p "${Cur_MPHP_Path}"/{etc,conf.d}
    old_ini="/usr/local/mphp-${Cur_MPHP_Big_Ver}-backup${Upgrade_Date}/etc/php.ini"
    backup_confd="/usr/local/mphp-${Cur_MPHP_Big_Ver}-backup${Upgrade_Date}/conf.d"
    if [ -s "${old_ini}" ]; then
        \cp "${old_ini}" "${Cur_MPHP_Path}/etc/php.ini"
    else
        echo "Copy new php configure file..."        
        \cp php.ini-production ${Cur_MPHP_Path}/etc/php.ini
        MPHP_Set_Ini
    fi
    [ -d "${backup_confd}" ] && cp -a "${backup_confd}/." "${Cur_MPHP_Path}/conf.d/"
}

MPHP_Set_Conf() {
    local M_Version="$1"
    if [ -n "${Cur_MPHP_Path}" ] && [ -z "${MPHP_Path}" ]; then
        local M_Path="${Cur_MPHP_Path}"
    elif [ -n "${MPHP_Path}" ] && [ -z "${Cur_MPHP_Path}" ]; then
        local M_Path="${MPHP_Path}"
    else
        Echo_Red "Multiple PHP Paths are not found, please check!"
        exit 1
    fi
    echo "Creating new php-fpm configure file..."
    cat >${M_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${M_Path}/var/run/php-fpm.pid
error_log = ${M_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi${M_Version}.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0660
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF
}

MPHP_Cp_Startup() {
    local M_Version="$1"
    echo "Copy php-fpm systemctl file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/systemd.php-fpm /etc/systemd/system/php-fpm"${M_Version}".service
    sed -i "s@# Provides:          php-fpm@# Provides:          php-fpm${M_Version}@g" "/etc/systemd/system/php-fpm${M_Version}.service"
    systemctl daemon-reload
    systemctl start php-fpm"${M_Version}"

}

MPHP_U_Startup() {
    local M_Version="$1"
    systemctl daemon-reload
    systemctl start php-fpm"${M_Version}"
}

MPHP_Set_Nginx() {
    local M_Version="$1"
    local dst=/usr/local/nginx/conf/enable-php${M_Version}.conf
    [ -s "${dst}" ] && cp -a "${dst}" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
    \cp "${cur_dir}/conf/enable-php${M_Version}.conf" "${dst}"
    sleep 2
}

Restore_Old_Mphp() {
    Echo_Red "Failed to upgrade php-${php_version}, you can download /root/upgrade_mphp${Upgrade_Date}.log from your server, and upload it to Github GetLNMP issues."
    Echo_Red "Restoring ${Cur_MPHP_Big_Ver} ...."
    rm -rf "${Cur_MPHP_Path}"
    mv "/usr/local/mphp-${Cur_MPHP_Big_Ver}-backup${Upgrade_Date}" "${Cur_MPHP_Path}" 2>/dev/null
    systemctl daemon-reload
    systemctl start "php-fpm${Cur_MPHP_Big_Ver}"
    exit 1
}

MPHP_Final_Check() {
    local M_Version="$1"
    [ -n "${Php_Ver}" ] && rm -rf "${cur_dir}/src/${Php_Ver}"
    local mphp_ver=$("${MPHP_Path}/bin/php-config" --version)
    if [ "php-${mphp_ver}" = "${Php_Ver}" ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        rm -f "/etc/systemd/system/php-fpm${M_Version}.service"
        rm -f "/usr/local/nginx/conf/enable-php${M_Version}.conf"
        systemctl daemon-reload
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp${M_Version}.log from your server, and upload it to Github GetLNMP issues."
        return 1
    fi
}

MPHP_U_Final_Check() {
    local M_Version="$1"
    [ -n "${php_version}" ] && rm -rf "${cur_dir}/src/php-${php_version}"
    local mphp_ver=$("${Cur_MPHP_Path}/bin/php-config" --version)
    if [ "${mphp_ver}" = "${php_version}" ]; then
        echo "==========================================="
        Echo_Green "You have successfully upgraded to php-${php_version} "
        echo "==========================================="
    else
        Restore_Old_Mphp
    fi
}

Install_MPHP7_3()
{
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "7.3"
    # start php-fpm
    MPHP_Cp_Startup "7.3"
    # config nginx php
    MPHP_Set_Nginx "7.3"
    # final check
    MPHP_Final_Check "7.3"
}

Install_MPHP7_4()
{
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "7.4"
    # start php-fpm
    MPHP_Cp_Startup "7.4"
    # config nginx php
    MPHP_Set_Nginx "7.4"
    # final check
    MPHP_Final_Check "7.4"
}

Install_MPHP8_0()
{
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.0"
    # start php-fpm
    MPHP_Cp_Startup "8.0"
    # config nginx php
    MPHP_Set_Nginx "8.0"
    # final check
    MPHP_Final_Check "8.0"
}

Install_MPHP8_1()
{
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.1"
    # start php-fpm
    MPHP_Cp_Startup "8.1"
    # config nginx php
    MPHP_Set_Nginx "8.1"
    # final check
    MPHP_Final_Check "8.1"
}

Install_MPHP8_2()
{
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.2"
    # start php-fpm
    MPHP_Cp_Startup "8.2"
    # config nginx php
    MPHP_Set_Nginx "8.2"
    # final check
    MPHP_Final_Check "8.2"
}

Install_MPHP8_3()
{
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.3"
    # start php-fpm
    MPHP_Cp_Startup "8.3"
    # config nginx php
    MPHP_Set_Nginx "8.3"
    # final check
    MPHP_Final_Check "8.3"
}

Install_MPHP8_4() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.4"
    # start php-fpm
    MPHP_Cp_Startup "8.4"
    # config nginx php
    MPHP_Set_Nginx "8.4"
    # final check
    MPHP_Final_Check "8.4"
}
Install_MPHP8_5() {
    MPHP_Get_Files
    MPHP_Set_Config
    PHP_Make_Install
    # copy new php configure file
    MPHP_Cp_Ini
    # php extensions
    MPHP_Set_Ini
    # php-fpm.conf
    MPHP_Set_Conf "8.5"
    # start php-fpm
    MPHP_Cp_Startup "8.5"
    # config nginx php
    MPHP_Set_Nginx "8.5"
    # final check
    MPHP_Final_Check "8.5"
}