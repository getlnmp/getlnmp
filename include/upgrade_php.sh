#!/usr/bin/env bash

Check_Stack_Choose() {
    Check_Stack
    if [[ "${Get_Stack}" = "lnmp" && "${Stack}" = "" ]]; then
        echo "Current Stack: ${Get_Stack}, please run: ./upgrade.sh php"
        exit 1
    elif [[ "${Get_Stack}" = "lnmpa" || "${Get_Stack}" = "lamp" ]] && [[ "${Stack}" = "lnmp" ]]; then
        echo "Current Stack: ${Get_Stack}, please run: ./upgrade.sh phpa"
        exit 1
    fi
}

Start_Upgrade_PHP() {
    Check_Stack_Choose
    Check_DB
    php_version=""
    Get_PHP_Ext_Dir
    echo "Current PHP Version:${Cur_PHP_Version}"
    echo "You can get version number from http://www.php.net/"
    echo "We only support upgrading PHP to 5.6.x, [7.0-7.4].x, [8.0-8.5].x"
    read -p "Please enter a PHP Version you want: " php_version
    if [ "${php_version}" = "" ]; then
        echo "Error: You must enter a corrent php version!!"
        exit 1
    fi
    if echo "${php_version}" | grep -Eqi '^(5\.6\.|7\.[0-4]\.|8\.[0-5]\.)';then
        echo "You will upgrade PHP to version:${php_version}"
    else
        Echo_Red "Error: You input PHP Version was:${php_version}"
        Echo_Red "We only support upgrading PHP to 5.6.x, [7.0-7.4].x, [8.0-8.5].x"
        exit 1
    fi
    Press_Start
    cd ${cur_dir}/src
    if [ -s php-${php_version} ]; then
        echo "Remove old php-${php_version} source code..."
        rm -rf php-${php_version}
    fi
    if [ -s php-${php_version}.tar.bz2 ]; then
        echo "php-${php_version}.tar.bz2 [found]"
    else
        echo "Notice: php-$php_version.tar.bz2 not found!!!download now..."
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

    if echo "${php_version}" | grep -Eqi '^5\.2\.'; then
        #       Download_Files ${Download_Mirror}/web/phpfpm/php-${php_version}-fpm-0.5.14.diff.gz php-${php_version}-fpm-0.5.14.diff.gz
        Download_Files https://php-fpm.org/downloads/php-${php_version}-fpm-0.5.14.diff.gz php-${php_version}-fpm-0.5.14.diff.gz
    fi
    lnmp stop

    if [ "${Stack}" = "lnmp" ]; then
        mv /usr/local/php /usr/local/oldphp${Upgrade_Date}
    else
        if echo "${Cur_PHP_Version}" | grep -Eqi '^7\.'; then
            mv /usr/local/apache/modules/libphp7.so /usr/local/apache/modules/libphp7.so.bak.${Upgrade_Date}
        else
            mv /usr/local/apache/modules/libphp5.so /usr/local/apache/modules/libphp5.so.bak.${Upgrade_Date}
        fi
        mv /usr/local/php /usr/local/oldphp${Upgrade_Date}
        \cp /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak.${Upgrade_Date}
        if echo "${Cur_PHP_Version}" | grep -Eqi '^7\.' && echo "${php_version}" | grep -Eqi '^5\.'; then
            sed -i '/libphp7.so/d' /usr/local/apache/conf/httpd.conf
        fi
    fi
    Check_PHP_Option
    Install_PHP_Dependent
    Check_Openssl
}

Install_PHP_Dependent() {
    echo "Installing Dependent for PHP..."
    if [ "$PM" = "yum" ]; then
        if [ "${DISTRO}" = "Oracle" ]; then
            yum -y install oracle-epel-release
        else
            yum -y install epel-release
        fi
        for packages in make gcc gcc-c++ gcc-g77 libjpeg libjpeg-devel libjpeg-turbo-devel libpng libpng-devel libpng10 libpng10-devel gd gd-devel libxml2 libxml2-devel zlib zlib-devel glib2-devel bzip2-devel libzip-devel libevent libevent-devel ncurses ncurses-devel curl-devel libcurl libcurl-devel e2fsprogs-devel krb5 krb5-devel libidn libidn-devel openssl-devel gettext-devel ncurses-devel gmp-devel pspell-devel libc-client-devel libXpm-devel libtirpc-devel cyrus-sasl-devel c-ares-devel libicu-devel libxslt libxslt-devel xz expat-devel libzip-devel bzip2 bzip2-devel sqlite-devel oniguruma-devel libwebp-devel; do yum -y install $packages; done
    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        for packages in debian-keyring debian-archive-keyring build-essential gcc g++ make libzip-dev libc6-dev libbz2-dev libncurses-dev libevent-dev libssl-dev libsasl2-dev libltdl3-dev libltdl-dev zlib1g zlib1g-dev libbz2-1.0 libbz2-dev libglib2.0-0 libglib2.0-dev libjpeg-dev libpng-dev libkrb5-dev curl libcurl4-openssl-dev libpq-dev libpq5 libxml2-dev libcap-dev libaio-dev libtirpc-dev libc-ares-dev libicu-dev e2fsprogs libxslt1.1 libxslt1-dev xz-utils libexpat1-dev bzip2 libbz2-dev libsqlite3-dev libonig-dev libwebp-dev libsystemd-dev libgd-dev lsb-release libgnutls28-dev systemd-dev libfreetype6-dev libsodium-dev; do apt-get --no-install-recommends install -y $packages; done
    fi

    if echo "${CentOS_Version}" | grep -Eqi "^8" || echo "${RHEL_Version}" | grep -Eqi "^8" || echo "${Rocky_Version}" | grep -Eqi "^8" || echo "${Alma_Version}" | grep -Eqi "^8" || echo "${Anolis_Version}" | grep -Eqi "^8" || echo "${OpenCloudOS_Version}" | grep -Eqi "^8"; then
        Check_PowerTools
        if [ "${repo_id}" != "" ]; then
            echo "Installing packages in PowerTools repository..."
            for c8packages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${c8packages} -y; done
        fi
        dnf install libarchive -y
    fi

    if echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
        for cs9packages in oniguruma-devel libzip-devel libtirpc-devel; do dnf --enablerepo=crb install ${cs9packages} -y; done
    fi

    if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^8"; then
        Check_Codeready
        for o8packages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${o8packages} -y; done
        dnf install libarchive -y
    fi

    if echo "${CentOS_Version}" | grep -Eqi "^7" || echo "${RHEL_Version}" | grep -Eqi "^7" || echo "${Aliyun_Version}" | grep -Eqi "^2" || echo "${Alibaba_Version}" | grep -Eqi "^2" || echo "${Oracle_Version}" | grep -Eqi "^7" || echo "${Anolis_Version}" | grep -Eqi "^7"; then
        if [ "${DISTRO}" = "Oracle" ]; then
            yum -y install oracle-epel-release
        else
            yum -y install epel-release
            if [ "${country}" = "CN" ]; then
                sed -e 's!^metalink=!#metalink=!g' \
                    -e 's!^#baseurl=!baseurl=!g' \
                    -e 's!//download\.fedoraproject\.org/pub!//mirrors.ustc.edu.cn!g' \
                    -e 's!//download\.example/pub!//mirrors.ustc.edu.cn!g' \
                    -i /etc/yum.repos.d/epel*.repo
            fi
        fi
        yum -y install oniguruma oniguruma-devel
        if [ "${CheckMirror}" = "n" ]; then
            rpm -ivh ${cur_dir}/src/oniguruma-6.8.2-1.el7.x86_64.rpm ${cur_dir}/src/oniguruma-devel-6.8.2-1.el7.x86_64.rpm
        fi
        yum -y install libsodium-devel
        yum -y install libc-client-devel uw-imap-devel
    fi

    if [ "${DISTRO}" = "UOS" ]; then
        Check_PowerTools
        if [ "${repo_id}" != "" ]; then
            echo "Installing packages in PowerTools repository..."
            for uospackages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${uospackages} -y; done
        fi
    fi

    ldconfig
}

Check_PHP_Upgrade_Files() {
    PHP_ENV_UNSET
    Echo_LNMPA_Upgrade_PHP_Failed() {
        Echo_Red "======== upgrade php failed ======"
        Echo_Red "upgrade php log: /root/upgrade_a_php${Upgrade_Date}.log"
        echo "You upload upgrade_a_php.log to LNMP Forum for help."
    }
    #rm -rf ${cur_dir}/src/php-${php_version}
    if [ "${Stack}" = "lnmp" ]; then
        if [[ -s /usr/local/php/sbin/php-fpm && -s /usr/local/php/bin/php ]]; then
            Echo_Green "======== upgrade php completed ======"
        else
            Echo_Red "======== upgrade php failed ======"
            Echo_Red "upgrade php log: /root/upgrade_lnmp_php${Upgrade_Date}.log"
            echo "You upload upgrade_lnmp_php.log to LNMP Forum for help."
        fi
    else
        if echo "${php_version}" | grep -Eqi '^7\.'; then
            if [[ -s /usr/local/apache/bin/httpd && -s /usr/local/apache/modules/libphp7.so && -s /usr/local/apache/conf/httpd.conf ]]; then
                Echo_Green "======== upgrade php completed ======"
            else
                Echo_LNMPA_Upgrade_PHP_Failed
            fi
        elif echo "${php_version}" | grep -Eqi '^8\.'; then
            if [[ -s /usr/local/apache/bin/httpd && -s /usr/local/apache/modules/libphp.so && -s /usr/local/apache/conf/httpd.conf ]]; then
                Echo_Green "======== upgrade php completed ======"
            else
                Echo_LNMPA_Upgrade_PHP_Failed
            fi
        else
            if [[ -s /usr/local/apache/modules/libphp5.so && -s /usr/local/php/etc/php.ini && -s /usr/local/php/bin/php ]]; then
                Echo_Green "======== upgrade php completed ======"
            else
                Echo_LNMPA_Upgrade_PHP_Failed
            fi
        fi
    fi
}


Upgrade_PHP_556() {
    Echo_Blue "Start install php-${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    if [ "${ARCH}" = "aarch64" ]; then
        patch -p1 <${cur_dir}/src/patch/php-5.5-5.6-asm-aarch64.patch
    fi
    #    if echo "${php_version}" | grep -Eqi '^5.6.' && command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
    #        patch -p1 < ${cur_dir}/src/patch/php-5.6-intl.patch
    #    fi
    Install_Libmcrypt
    PHP_Patch
    PHP_GCC14_PATCH
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --enable-intl --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --enable-intl --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer

    cd ${cur_dir}/src
    echo "Download Opcache Control Panel..."
    \cp ${cur_dir}/conf/ocp.php /home/wwwroot/default/ocp.php

    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt

    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_7() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
#    if echo "${php_version}" | grep -Eqi '^7\.1\.'; then
        #    PHP_Openssl3_Patch
        #    PHP_ICU70_Patch
#    fi
    #    if echo "${php_version}" | grep -Eqi '^7.0.' && command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
    #        patch -p1 < ${cur_dir}/src/patch/php-7.0-intl.patch
    #    fi 
    Install_Libmcrypt       
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_72() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_73() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    #export PKG_CONFIG_PATH="/usr/local/libzip-1.5.2/lib/pkgconfig"
    #export LDFLAGS="-L/usr/local/libzip-1.5.2/lib -Wl,-rpath=/usr/local/libzip-1.5.2/lib"
    #export LDFLAGS="-Wl,-rpath=/usr/local/libzip-1.5.2/lib"
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_74() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_80() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
        sed -i '/^LoadModule php7_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_81() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
        sed -i '/^LoadModule php7_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_82() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
        sed -i '/^LoadModule php7_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_83() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
        sed -i '/^LoadModule php7_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_84() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
        sed -i '/^LoadModule php7_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_85() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
	LNMP_PHP_Opt
    if [ "${Stack}" != "lnmp" ]; then
        sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf
        sed -i '/^LoadModule php7_module/d' /usr/local/apache/conf/httpd.conf
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP() {
    Start_Upgrade_PHP
    if echo "${php_version}" | grep -Eqi '^5\.2\.'; then
        Upgrade_PHP_52
    elif echo "${php_version}" | grep -Eqi '^5\.3\.'; then
        Upgrade_PHP_53
    elif echo "${php_version}" | grep -Eqi '^5\.4\.'; then
        Upgrade_PHP_54
    elif echo "${php_version}" | grep -Eqi '^5\.[56]\.'; then
        Upgrade_PHP_556
    elif echo "${php_version}" | grep -Eqi '^7\.[01]\.'; then
        Upgrade_PHP_7
    elif echo "${php_version}" | grep -Eqi '^7\.2\.'; then
        Upgrade_PHP_72
    elif echo "${php_version}" | grep -Eqi '^7\.3\.'; then
        Upgrade_PHP_73
    elif echo "${php_version}" | grep -Eqi '^7\.4\.'; then
        Upgrade_PHP_74
    elif echo "${php_version}" | grep -Eqi '^8\.0\.'; then
        Upgrade_PHP_80
    elif echo "${php_version}" | grep -Eqi '^8\.1\.'; then
        Upgrade_PHP_81
    elif echo "${php_version}" | grep -Eqi '^8\.2\.'; then
        Upgrade_PHP_82
    elif echo "${php_version}" | grep -Eqi '^8\.3\.'; then
        Upgrade_PHP_83
    elif echo "${php_version}" | grep -Eqi '^8\.4\.'; then
        Upgrade_PHP_84
    elif echo "${php_version}" | grep -Eqi '^8\.5\.'; then
        Upgrade_PHP_85
    else
        Echo_Red "PHP version: ${php_version} is not supported."
        exit 1
    fi
}
