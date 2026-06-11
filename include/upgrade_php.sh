#!/usr/bin/env bash

Check_Stack_Choose() {
    Check_Stack
    if [[ "${Get_Stack}" = "lnmp" && "${Stack}" = "" ]]; then
        Echo_Red "Current Stack: ${Get_Stack}, please run: ./upgrade.sh php"
        exit 1
    elif [[ "${Get_Stack}" != "lnmp" && "${Stack}" = "lnmp" ]]; then
        Echo_Red "Stack mismatch: detected ${Get_Stack} but ./upgrade.sh php expects lnmp."
        Echo_Red "Use ./upgrade.sh phpa instead."
        exit 1
    fi
}

Restore_old_php() {
    Echo_Red "Upgrade failed; restoring previous PHP installation."
    rm -rf /usr/local/php
    mv "/usr/local/oldphp${Upgrade_Date}" /usr/local/php 2>/dev/null
    if [ "${Stack}" != "lnmp" ]; then
        if echo "${Cur_PHP_Version}" | grep -Eqi '^8\.'; then
            mv "/usr/local/apache/modules/libphp.so.bak.${Upgrade_Date}" /usr/local/apache/modules/libphp.so 2>/dev/null
        elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.'; then
            mv "/usr/local/apache/modules/libphp7.so.bak.${Upgrade_Date}" /usr/local/apache/modules/libphp7.so 2>/dev/null
        else
            mv "/usr/local/apache/modules/libphp5.so.bak.${Upgrade_Date}" /usr/local/apache/modules/libphp5.so 2>/dev/null
        fi
        \cp "/usr/local/apache/conf/httpd.conf.bak.${Upgrade_Date}" /usr/local/apache/conf/httpd.conf 2>/dev/null
    fi
    lnmp start
    exit 1
}

PHP_Make_Install_Or_Restore() {
    make -j"$(nproc)" || make || {
        Echo_Red "Error: failed to build PHP."
        Restore_old_php
    }
    make install || {
        Echo_Red "Error: failed to install PHP."
        Restore_old_php
    }
    PHP_ENV_UNSET
}

Start_Upgrade_PHP() {
    Check_Stack_Choose
    Check_DB
    php_version=""
    Get_PHP_Ext_Dir
    echo "Current PHP Version:${Cur_PHP_Version}"
    echo "You can get version number from http://www.php.net/"
    echo "We only support upgrading PHP to [7.3-7.4].x, [8.0-8.5].x"
    read -r -p "Please enter a PHP Version you want: " php_version
    if [ "${php_version}" = "" ]; then
        Echo_Red "Error: You must enter a corrent php version!!"
        exit 1
    fi
    # allow php downgrades
    if echo "${php_version}" | grep -Eqi '^(7\.[3-4]\.|8\.[0-5]\.)';then
        echo "You will upgrade PHP to version:${php_version}"
    else
        Echo_Red "Error: You input PHP Version was:${php_version}"
        Echo_Red "We only support upgrading PHP to [7.3-7.4].x, [8.0-8.5].x"
        exit 1
    fi
    Press_Start
    cd ${cur_dir}/src
    if [ -s php-${php_version} ]; then
        echo "Remove old php-${php_version} source code..."
        rm -rf php-${php_version}
    fi
    # for php upgrades, we only download php tarball from php official website
    if [ -s php-${php_version}.tar.bz2 ]; then
        echo "php-${php_version}.tar.bz2 [found]"
    else
        echo "Notice: php-$php_version.tar.bz2 not found!!!download now..."
        Download_Files https://www.php.net/distributions/php-${php_version}.tar.bz2 php-${php_version}.tar.bz2
        if [ ! -s php-${php_version}.tar.bz2 ]; then
            echo "Download php-${php_version}.tar.bz2 failed, try another link..."
            Download_Files_Exit https://museum.php.net/php5/php-${php_version}.tar.bz2 php-${php_version}.tar.bz2
        fi
        echo "Download php-${php_version}.tar.bz2 successfully!"
    fi

    lnmp stop

    if [ "${Stack}" = "lnmp" ]; then
        mv /usr/local/php /usr/local/oldphp${Upgrade_Date} || { Echo_Red "Error: failed to move aside /usr/local/php."; lnmp start; exit 1; }
    else
        if echo "${Cur_PHP_Version}" | grep -Eqi '^8\.'; then
            mv /usr/local/apache/modules/libphp.so /usr/local/apache/modules/libphp.so.bak.${Upgrade_Date} || { Echo_Red "Error: failed to back up libphp.so."; lnmp start; exit 1; }
        elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.'; then
            mv /usr/local/apache/modules/libphp7.so /usr/local/apache/modules/libphp7.so.bak.${Upgrade_Date} || { Echo_Red "Error: failed to back up libphp7.so."; lnmp start; exit 1; }
        else
            mv /usr/local/apache/modules/libphp5.so /usr/local/apache/modules/libphp5.so.bak.${Upgrade_Date} || { Echo_Red "Error: failed to back up libphp5.so."; lnmp start; exit 1; }
        fi
        mv /usr/local/php /usr/local/oldphp${Upgrade_Date} || {
            Echo_Red "Error: failed to move aside /usr/local/php."
            if echo "${Cur_PHP_Version}" | grep -Eqi '^8\.'; then
                mv /usr/local/apache/modules/libphp.so.bak.${Upgrade_Date} /usr/local/apache/modules/libphp.so 2>/dev/null
            elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.'; then
                mv /usr/local/apache/modules/libphp7.so.bak.${Upgrade_Date} /usr/local/apache/modules/libphp7.so 2>/dev/null
            else
                mv /usr/local/apache/modules/libphp5.so.bak.${Upgrade_Date} /usr/local/apache/modules/libphp5.so 2>/dev/null
            fi
            lnmp start
            exit 1
        }
        \cp /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak.${Upgrade_Date}
    fi
    Check_PHP_Option
    Install_PHP_Dependent
    Check_Openssl
}

Install_PHP_Dependent() {
    echo "Installing Dependent for PHP..."

    if [ "$PM" = "yum" ]; then

        # 1. EPEL
        if [ "${DISTRO}" = "Oracle" ]; then
            yum -y install oracle-epel-release
        else
            yum -y install epel-release
        fi

        # 2. Base packages (EL7+)
        # libpng10/libpng10-devel removed: EL5-era packages absent from EL7+ repos.
        # gd/gd-devel removed: PHP uses its bundled GD; system gd-devel headers can conflict.
        for packages in make gcc gcc-c++ libjpeg libjpeg-devel libjpeg-turbo-devel \
            libpng libpng-devel libxml2 libxml2-devel zlib zlib-devel \
            glib2-devel bzip2 bzip2-devel libzip-devel \
            libevent libevent-devel ncurses ncurses-devel \
            curl-devel libcurl libcurl-devel e2fsprogs-devel \
            krb5 krb5-devel libidn libidn-devel \
            openssl-devel gettext-devel gmp-devel pspell-devel \
            libc-client-devel libXpm-devel libtirpc-devel \
            cyrus-sasl-devel c-ares-devel libicu-devel \
            libxslt libxslt-devel xz expat-devel \
            sqlite-devel oniguruma-devel libwebp-devel; do
            yum -y install $packages
        done

        # 3. EL9/EL10+: libidn2 is the preferred replacement for the deprecated libidn
        if echo "${RHEL_Version}" | grep -Eqi "^(9|10)" || \
           echo "${Rocky_Version}" | grep -Eqi "^(9|10)" || \
           echo "${Alma_Version}" | grep -Eqi "^(9|10)"; then
            yum -y install libidn2 libidn2-devel
        fi

        # 4. EL8 (RHEL/Rocky/Alma): PowerTools repo for rpcgen, re2c, oniguruma-devel
        if echo "${RHEL_Version}" | grep -Eqi "^8" || \
           echo "${Rocky_Version}" | grep -Eqi "^8" || \
           echo "${Alma_Version}" | grep -Eqi "^8"; then
            Check_PowerTools
            if [ "${repo_id}" != "" ]; then
                echo "Installing packages in PowerTools repository..."
                for c8packages in rpcgen re2c oniguruma-devel; do
                    dnf --enablerepo=${repo_id} install ${c8packages} -y
                done
            fi
            dnf install libarchive -y
        fi

        # 5. EL9/EL10 (Alma/Rocky): CRB repo for oniguruma-devel, libzip-devel, libtirpc-devel
        if echo "${Alma_Version}" | grep -Eqi "^(9|10)" || \
           echo "${Rocky_Version}" | grep -Eqi "^(9|10)"; then
            for cs9packages in oniguruma-devel libzip-devel libtirpc-devel; do
                dnf --enablerepo=crb install ${cs9packages} -y
            done
        fi

        # 6. Oracle 8: CodeReady Linux Builder repo for rpcgen, re2c, oniguruma-devel
        if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^8"; then
            Check_Codeready
            if [ "${repo_id}" != "" ]; then
                for o8packages in rpcgen re2c oniguruma-devel; do
                    dnf --enablerepo=${repo_id} install ${o8packages} -y
                done
            fi
            dnf install libarchive -y
        fi

    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y || apt-get update --allow-releaseinfo-change -y
        keyring_packages=""
        if [ "${DISTRO}" = "Debian" ]; then
            keyring_packages="debian-keyring debian-archive-keyring"
        fi
        for packages in ${keyring_packages} \
            build-essential gcc g++ make \
            libzip-dev libc6-dev libbz2-dev libncurses-dev \
            libevent-dev libssl-dev libsasl2-dev libltdl3-dev libltdl-dev \
            zlib1g zlib1g-dev libbz2-1.0 libbz2-dev \
            libglib2.0-0 libglib2.0-dev libjpeg-dev libpng-dev \
            libkrb5-dev curl libcurl4-openssl-dev libpq-dev libpq5 \
            libxml2-dev libcap-dev libaio-dev libtirpc-dev libc-ares-dev \
            libicu-dev e2fsprogs libxslt1.1 libxslt1-dev xz-utils \
            libexpat1-dev bzip2 libbz2-dev libsqlite3-dev libonig-dev \
            libwebp-dev libsystemd-dev libgd-dev lsb-release \
            libgnutls28-dev systemd-dev libfreetype6-dev libsodium-dev; do
            apt-get --no-install-recommends install -y $packages
        done
    fi

    ldconfig
}

Check_PHP_Upgrade_Files() {
    PHP_ENV_UNSET
    Echo_LNMPA_Upgrade_PHP_Failed() {
        Echo_Red "======== upgrade php failed ======"
        Echo_Red "upgrade php log: /root/upgrade_a_php${Upgrade_Date}.log"
    }
    #rm -rf ${cur_dir}/src/php-${php_version}
    if [ "${Stack}" = "lnmp" ]; then
        new_ver=$(/usr/local/php/bin/php -r 'echo PHP_VERSION;')
        if [ "${new_ver}" = "${php_version}" ]; then
            Echo_Green "Upgrade PHP to ${php_version} completed."
        else
            Echo_Red "======== upgrade php failed ======"
            Echo_Red "upgrade php log: /root/upgrade_lnmp_php${Upgrade_Date}.log"
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

Upgrade_PHP_73() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    #export PKG_CONFIG_PATH="/usr/local/libzip-1.5.2/lib/pkgconfig"
    #export LDFLAGS="-L/usr/local/libzip-1.5.2/lib -Wl,-rpath=/usr/local/libzip-1.5.2/lib"
    #export LDFLAGS="-Wl,-rpath=/usr/local/libzip-1.5.2/lib"
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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

Upgrade_PHP_74() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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

Upgrade_PHP_80() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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
        sed -i '/^LoadModule php_module/d' /usr/local/apache/conf/httpd.conf
        # apxs will then re-add the correct one.
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_81() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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
        sed -i '/^LoadModule php_module/d' /usr/local/apache/conf/httpd.conf
        # apxs will then re-add the correct one.
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_82() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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
        sed -i '/^LoadModule php_module/d' /usr/local/apache/conf/httpd.conf
        # apxs will then re-add the correct one.
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_83() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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
        sed -i '/^LoadModule php_module/d' /usr/local/apache/conf/httpd.conf
        # apxs will then re-add the correct one.
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_84() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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
        sed -i '/^LoadModule php_module/d' /usr/local/apache/conf/httpd.conf
        # apxs will then re-add the correct one.
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP_85() {
    Echo_Blue "[+] Installing ${php_version}"
    Tar_Cd php-${php_version}.tar.bz2 php-${php_version}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options} || Restore_old_php
    fi
    PHP_Make_Install_Or_Restore

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
        sed -i '/^LoadModule php_module/d' /usr/local/apache/conf/httpd.conf
        # apxs will then re-add the correct one.
    fi
    lnmp start
    Check_PHP_Upgrade_Files
}

Upgrade_PHP() {
    Start_Upgrade_PHP
    if echo "${php_version}" | grep -Eqi '^7\.3\.'; then
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
