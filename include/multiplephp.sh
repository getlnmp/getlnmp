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
    read -p "Enter your choice (4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 or 16): " PHPSelect
    case "${PHPSelect}" in
    1)
        echo "You will install ${PHP_Info[0]}"
        MPHP_Path='/usr/local/php5.2'
        Check_DB
        if [ "${DB_Name}" == "None" ];then
            Echo_Red "MySQL or MariaDB not found,can't install PHP 5.2!"
            exit 1
        fi
        ;;
    2)
        echo "You will install ${PHP_Info[1]}"
        MPHP_Path='/usr/local/php5.3'
        ;;
    3)
        echo "You will Install ${PHP_Info[2]}"
        MPHP_Path='/usr/local/php5.4'
        ;;
    4)
        echo "You will install ${PHP_Info[3]}"
        MPHP_Path='/usr/local/php5.5'
        ;;
    5)
        echo "You will install ${PHP_Info[4]}"
        MPHP_Path='/usr/local/php5.6'
        ;;
    6)
        echo "You will install ${PHP_Info[5]}"
        MPHP_Path='/usr/local/php7.0'
        ;;
    7)
        echo "You will install ${PHP_Info[6]}"
        MPHP_Path='/usr/local/php7.1'
        ;;
    8)
        echo "You will install ${PHP_Info[7]}"
        MPHP_Path='/usr/local/php7.2'
        ;;
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
        echo "No enter,You Must enter one option."
        exit 1
        ;;
    esac

    Press_Install
    if [ -d "${MPHP_Path}" ]; then
        echo "${Php_Ver} already exists!"
        exit 1
    fi
    Check_PHP_Option
    cat /etc/issue
    cat /etc/*-release
    Install_PHP_Dependent
    Check_Openssl

    if [ "${PHPSelect}" = "1" ]; then
        Install_MPHP5.2 2>&1 | tee /root/install-mphp5.2.log
    elif [ "${PHPSelect}" = "2" ]; then
        Install_MPHP5.3 2>&1 | tee /root/install-mphp5.3.log
    elif [ "${PHPSelect}" = "3" ]; then
        Install_MPHP5.4 2>&1 | tee /root/install-mphp5.4.log
    elif [ "${PHPSelect}" = "4" ]; then
        Install_MPHP5.5 2>&1 | tee /root/install-mphp5.5.log
    elif [ "${PHPSelect}" = "5" ]; then
        Install_MPHP5.6 2>&1 | tee /root/install-mphp5.6.log
    elif [ "${PHPSelect}" = "6" ]; then
        Install_MPHP7.0 2>&1 | tee /root/install-mphp7.0.log
    elif [ "${PHPSelect}" = "7" ]; then
        Install_MPHP7.1 2>&1 | tee /root/install-mphp7.1.log
    elif [ "${PHPSelect}" = "8" ]; then
        Install_MPHP7.2 2>&1 | tee /root/install-mphp7.2.log
    elif [ "${PHPSelect}" = "9" ]; then
        Install_MPHP7.3 2>&1 | tee /root/install-mphp7.3.log
    elif [ "${PHPSelect}" = "10" ]; then
        Install_MPHP7.4 2>&1 | tee /root/install-mphp7.4.log
    elif [ "${PHPSelect}" = "11" ]; then
        Install_MPHP8.0 2>&1 | tee /root/install-mphp8.0.log
    elif [ "${PHPSelect}" = "12" ]; then
        Install_MPHP8.1 2>&1 | tee /root/install-mphp8.1.log
    elif [ "${PHPSelect}" = "13" ]; then
        Install_MPHP8.2 2>&1 | tee /root/install-mphp8.2.log
    elif [ "${PHPSelect}" = "14" ]; then
        Install_MPHP8.3 2>&1 | tee /root/install-mphp8.3.log
    elif [ "${PHPSelect}" = "15" ]; then
        Install_MPHP8.4 2>&1 | tee /root/install-mphp8.4.log
    elif [ "${PHPSelect}" = "16" ]; then
        Install_MPHP8.5 2>&1 | tee /root/install-mphp8.5.log
    fi
}

Install_MPHP5.6()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://museum.php.net/php5/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${ARCH}" = "aarch64" ]; then
        patch -p1 < ${cur_dir}/src/patch/php-5.5-5.6-asm-aarch64.patch
    fi
#    if command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
#        patch -p1 < ${cur_dir}/src/patch/php-5.6-intl.patch
#    fi
    Install_Libmcrypt
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --enable-intl --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    if [ "${Is_ARM}" != "y" ]; then
        echo "Install ZendGuardLoader for PHP 5.6..."
        Download_Files https://downloads.zend.com/guard/7.0.0/zend-loader-php5.6-linux-${ARCH}.tar.gz zend-loader-php5.6-linux-${ARCH}.tar.gz
        Tar_Cd zend-loader-php5.6-linux-${ARCH}.tar.gz
        mkdir -p /usr/local/zend/
        \cp zend-loader-php5.6-linux-${ARCH}/ZendGuardLoader.so /usr/local/zend/ZendGuardLoader5.6.so

        echo "Write ZendGuardLoader to php.ini..."
        cat >${MPHP_Path}/conf.d/002-zendguardloader.ini<<EOF
[Zend ZendGuard Loader]
zend_extension=/usr/local/zend/ZendGuardLoader5.6.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=
EOF
    fi

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi5.6.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm5.6
    chmod +x /etc/init.d/php-fpm5.6
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm5.6@g' /etc/init.d/php-fpm5.6

    StartUp php-fpm5.6

    \cp ${cur_dir}/conf/enable-php5.6.conf /usr/local/nginx/conf/enable-php5.6.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp5.6.log from your server, and upload install-mphp5.6.log to LNMP Forum."
    fi
}

Install_MPHP7.0()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
#    if command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
#        patch -p1 < ${cur_dir}/src/patch/php-7.0-intl.patch
#    fi
    Install_Libmcrypt
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.0.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.0
    chmod +x /etc/init.d/php-fpm7.0
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.0@g' /etc/init.d/php-fpm7.0

    StartUp php-fpm7.0

    \cp ${cur_dir}/conf/enable-php7.0.conf /usr/local/nginx/conf/enable-php7.0.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.0.log from your server, and upload install-mphp7.0.log to LNMP Forum."
    fi
}

Install_MPHP7.1()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
#    PHP_Openssl3_Patch
#    PHP_ICU70_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.1..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.1.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.1
    chmod +x /etc/init.d/php-fpm7.1
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.1@g' /etc/init.d/php-fpm7.1

    StartUp php-fpm7.1

    \cp ${cur_dir}/conf/enable-php7.1.conf /usr/local/nginx/conf/enable-php7.1.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.1.log from your server, and upload install-mphp7.1.log to LNMP Forum."
    fi
}

Install_MPHP7.2()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
#    PHP_Openssl3_Patch
#    PHP_ICU70_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.2..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.2.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.2
    chmod +x /etc/init.d/php-fpm7.2
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.2@g' /etc/init.d/php-fpm7.2

    StartUp php-fpm7.2

    \cp ${cur_dir}/conf/enable-php7.2.conf /usr/local/nginx/conf/enable-php7.2.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.2.log from your server, and upload install-mphp7.2.log to LNMP Forum."
    fi
}


Install_MPHP7.3()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
#    PHP_Openssl3_Patch
#    PHP_ICU70_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.3..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.3.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.3
    chmod +x /etc/init.d/php-fpm7.3
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.3@g' /etc/init.d/php-fpm7.3

    StartUp php-fpm7.3

    \cp ${cur_dir}/conf/enable-php7.3.conf /usr/local/nginx/conf/enable-php7.3.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.3.log from your server, and upload install-mphp7.3.log to LNMP Forum."
    fi
}

Install_MPHP7.4()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
#    PHP_Openssl3_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.4..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.4.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.4
    chmod +x /etc/init.d/php-fpm7.4
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.4@g' /etc/init.d/php-fpm7.4

    StartUp php-fpm7.4

    \cp ${cur_dir}/conf/enable-php7.4.conf /usr/local/nginx/conf/enable-php7.4.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.4.log from your server, and upload install-mphp7.4.log to LNMP Forum."
    fi
}

Install_MPHP8.0()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
#    PHP_Openssl3_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.0..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.0.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.0
    chmod +x /etc/init.d/php-fpm8.0
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.0@g' /etc/init.d/php-fpm8.0

    StartUp php-fpm8.0

    \cp ${cur_dir}/conf/enable-php8.0.conf /usr/local/nginx/conf/enable-php8.0.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.0.log from your server, and upload install-mphp8.0.log to LNMP Forum."
    fi
}

Install_MPHP8.1()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.1..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.1.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.1
    chmod +x /etc/init.d/php-fpm8.1
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.1@g' /etc/init.d/php-fpm8.1

    StartUp php-fpm8.1

    \cp ${cur_dir}/conf/enable-php8.1.conf /usr/local/nginx/conf/enable-php8.1.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.1.log from your server, and upload install-mphp8.1.log to LNMP Forum."
    fi
}

Install_MPHP8.2()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.2..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.2.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.2
    chmod +x /etc/init.d/php-fpm8.2
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.2@g' /etc/init.d/php-fpm8.2

    StartUp php-fpm8.2

    \cp ${cur_dir}/conf/enable-php8.2.conf /usr/local/nginx/conf/enable-php8.2.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.2.log from your server, and upload install-mphp8.2.log to LNMP Forum."
    fi
}

Install_MPHP8.3()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files https://www.php.net/distributions/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.3..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.3.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
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

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.3
    chmod +x /etc/init.d/php-fpm8.3
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.3@g' /etc/init.d/php-fpm8.3

    StartUp php-fpm8.3

    \cp ${cur_dir}/conf/enable-php8.3.conf /usr/local/nginx/conf/enable-php8.3.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.3.log from your server, and upload install-mphp8.3.log to LNMP Forum."
    fi
}
