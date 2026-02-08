#!/usr/bin/env bash

# depcrecated as only for php 5.2 which is dropped support
Export_PHP_Autoconf() {
    if [[ -s /usr/local/autoconf-2.13/bin/autoconf && -s /usr/local/autoconf-2.13/bin/autoheader ]]; then
        Echo_Green "Autconf 2.13...ok"
    else
        Install_Autoconf
    fi
    export PHP_AUTOCONF=/usr/local/autoconf-2.13/bin/autoconf
    export PHP_AUTOHEADER=/usr/local/autoconf-2.13/bin/autoheader
}

Check_Autoconf_Version() {
    Autoconf_Version=$(autoconf --version | head -n1 | awk '{print $NF}')
    Autoconf_Second_Digit=${Autoconf_Version##*.}
}

# only used PHP52 and PHP53, deprecated
Check_Curl() {
    if [ -s /usr/local/curl/bin/curl ]; then
        Echo_Green "Curl ...ok"
    else
        Install_Curl
    fi
}

PHP_with_curl() {
    echo "Checking Curl..."
    if [[ "${DISTRO}" = "CentOS" && "${Is_ARM}" = "y" ]] || [[ "${BuildOpenssl}" = "y" ]]; then
        if [ "${UseOldOpenssl}" = 'y' ]; then
            Install_OldCurl
            with_curl='--with-curl=/usr/local/oldcurl'
            if [ "${PHP_Use_PKG}" = "y" ]; then
                PKG_CONFIG_PATH_TEMP="$PKG_CONFIG_PATH_TEMP:/usr/local/oldcurl/lib/pkgconfig"
                #CPPFLAGS_TEMP="$CPPFLAGS_TEMP -I/usr/local/curl/include"
                #LDFLAGS_TEMP="$LDFLAGS_TEMP -L/usr/local/curl/lib"
            fi
        elif [ "${UseNewOpenssl}" = 'y' ]; then
            Install_Curl
            with_curl='--with-curl=/usr/local/curl'
            if [ "${PHP_Use_PKG}" = "y" ]; then
                PKG_CONFIG_PATH_TEMP="$PKG_CONFIG_PATH_TEMP:/usr/local/curl/lib/pkgconfig"
                #CPPFLAGS_TEMP="$CPPFLAGS_TEMP -I/usr/local/curl/include"
                #LDFLAGS_TEMP="$LDFLAGS_TEMP -L/usr/local/curl/lib"
            fi
        fi
    else
        with_curl='--with-curl'
    fi
}

PHP_with_Libzip() {
    echo "Checking Libzip..."
    if [ "${PHP_Use_PKG}" = 'y' ]; then
        if [ "${BuildOpenssl}" = "y" ]; then
            Custom_Libzip_Path="/usr/local/${Libzip_Ver}"
            Install_Libzip
            PKG_CONFIG_PATH_TEMP="$PKG_CONFIG_PATH_TEMP:${Custom_Libzip_Path}/lib/pkgconfig"
            LDFLAGS_TEMP="-Wl,-rpath=${Custom_Libzip_Path}/lib"
            with_libzip="--with-zip=${Custom_Libzip_Path}"
        else
            with_libzip='--with-zip'
        fi
    else
        if [ "${BuildOpenssl}" = "y" ]; then
            if [ "${UseOldOpenssl}" = 'y' ]; then
                Custom_Libzip_Path="/usr/local/old${Libzip_Ver}"
                Install_Libzip
                with_libzip="--enable-zip --with-libzip=${Custom_Libzip_Path}"
                LDFLAGS_TEMP="-Wl,-rpath=${Custom_Libzip_Path}/lib"
            else 
                Custom_Libzip_Path="/usr/local/${Libzip_Ver}"
                Install_Libzip
                #with_libzip='--enable-zip --with-libzip'
                with_libzip="--enable-zip --with-libzip=${Custom_Libzip_Path}"
                LDFLAGS_TEMP="-Wl,-rpath=${Custom_Libzip_Path}/lib"
            fi
        else
            with_libzip='--enable-zip'
        fi
    fi
}

PHP_with_openssl() {
    echo "Checking OpenSSL..."
    if openssl version | grep -Eqi "OpenSSL 1.1.*|OpenSSL 3.*"; then
        if [[ -n "${PHPSelect}" && "${PHPSelect}" =~ ^[1-6]$ ]] || [[ "${php_version}" =~ ^(5\.|7\.0\.) ]] || [[ "${Php_Ver}" =~ (php-5\.|php-7\.0\.) ]]; then
            UseOldOpenssl='y'
            BuildOpenssl='y'
        fi
    fi
    if openssl version | grep -Eqi "OpenSSL 1.0.*"; then
        if [[ "${PHPSelect}" =~ ^(7|8|9|10|11|12|13|14|15|16)$ ]] || [[ "${php_version}" =~ ^(7\.[1-4]\.|8\.[0-5]\.) ]] || [[ "${Php_Ver}" =~ (php-7\.[1-4]\.|php-8\.[0-5]\.) ]]; then
            UseNewOpenssl='y'
            BuildOpenssl='y'
        fi
    fi
    if openssl version | grep -Eqi "OpenSSL 3.*"; then
        if echo "${PHPSelect}" | grep -Eqi "^(7|8|9|10|11)$" || echo "${php_version}" | grep -Eqi '^7\.[1-4]\.*|^8\.0\.*' || echo "${Php_Ver}" | grep -Eqi "php-7\.[1-4]\.*|php-8\.0\.*"; then
            UseNewOpenssl='y'
            BuildOpenssl='y'
        fi
    fi

    if [ "${UseOldOpenssl}" = "y" ]; then
        Install_Openssl
        with_openssl='--with-openssl=/usr/local/openssl'
        Custom_Openssl_Path="/usr/local/openssl"
        if [ "${PHP_Use_PKG}" = 'y' ]; then
        # export path so that php and curl compiler can find it
            PKG_CONFIG_PATH_TEMP="/usr/local/openssl/lib/pkgconfig"
#            CPPFLAGS_TEMP="-I/usr/local/openssl1.1.1/include"
#            LDFLAGS_TEMP="-L/usr/local/openssl1.1.1/lib"
        fi
    elif [ "${UseNewOpenssl}" = "y" ]; then
        Install_Openssl_New
        with_openssl='--with-openssl=/usr/local/openssl1.1.1'
        Custom_Openssl_Path="/usr/local/openssl1.1.1"
        PHP_Openssl_Export
    #elif [ "${UseOpenssl3}" = "y" ]; then
    #    Install_Openssl3
    #    with_openssl='--with-openssl=/usr/local/openssl3'
    #    Curl_Openssl_Path="/usr/local/openssl3"
    #    PHP_Openssl_Export
    else
        with_openssl='--with-openssl'
        apache_with_ssl='--with-ssl'
    fi
}

PHP_Openssl_Export() {
    if [ "${UseNewOpenssl}" = "y" ]; then
        if [ "${PHP_Use_PKG}" = 'y' ]; then
        # export path so that php and curl compiler can find it
            PKG_CONFIG_PATH_TEMP="/usr/local/openssl1.1.1/lib/pkgconfig"
#            CPPFLAGS_TEMP="-I/usr/local/openssl1.1.1/include"
#            LDFLAGS_TEMP="-L/usr/local/openssl1.1.1/lib"
        fi
    fi
    #if echo "${php_version}" | grep -Eqi '^8\.[1-4]\.*' || echo "${Php_Ver}" | grep -Eqi "php-8\.[1-4]\.*"; then
    # export path so that php and curl compiler can find it
    #    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/usr/local/openssl3/lib/pkgconfig"
    #    export CPPFLAGS="$CPPFLAGS -I/usr/local/openssl3/include"
    #    export LDFLAGS="$LDFLAGS -L/usr/local/openssl3/lib -Wl,-rpath=/usr/local/openssl3/lib"
    #fi
}

PHP_with_fileinfo() {
    echo "Checking fileinfo..."
    if [ "${Enable_PHP_Fileinfo}" = "n" ]; then
        if [[ $(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo) -lt 1024 ]]; then
            with_fileinfo='--disable-fileinfo'
        else
            with_fileinfo=''
        fi
    else
        with_fileinfo=''
    fi
}

PHP_with_Exif() {
    echo "Checking Exif..."
    if [ "${Enable_PHP_Exif}" = "n" ]; then
        with_exif=''
    else
        with_exif='--enable-exif'
    fi
}

PHP_with_iconv() {
    echo "Checking iconv..."
    with_iconv='--with-iconv'
}

PHP_with_Ldap() {
    echo "Checking Ldap..."
    if [ "${Enable_PHP_Ldap}" = "n" ]; then
        with_ldap=''
    else
        if [ "$PM" = "yum" ]; then
            yum -y install openldap-devel cyrus-sasl-devel
            if [ "${Is_64bit}" == "y" ]; then
                ln -sf /usr/lib64/libldap* /usr/lib/
                ln -sf /usr/lib64/liblber* /usr/lib/
            fi
        elif [ "$PM" = "apt" ]; then
            apt-get install -y libldap2-dev libsasl2-dev
            if [ -s /usr/lib/x86_64-linux-gnu/libldap.so ]; then
                ln -sf /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/
                ln -sf /usr/lib/x86_64-linux-gnu/liblber.so /usr/lib/
            fi
        fi
        with_ldap='--with-ldap --with-ldap-sasl'
    fi
}

PHP_with_Bz2() {
    echo "Checking Bz2..."
    if [ "${Enable_PHP_Bz2}" = "n" ]; then
        with_bz2=''
    else
#        Install_Libzip
        with_bz2='--with-bz2'
    fi
}

# As of PHP 7.2.0 this extension is bundled with PHP. For older PHP versions this extension is available via PECL.
PHP_with_Sodium() {
    echo "Checking Sodium..."
    if [ "${Enable_PHP_Sodium}" = "n" ]; then
        with_sodium=''
    else
        if echo "${php_version}" | grep -Eqi '(^7\.[0-1]\.*|^5\.*)' || echo "${Php_Ver}" | grep -Eqi "(php-7\.[0-1]\.*|php-5\.*)"; then
            Echo_Red 'Below PHP 7.2 please use " . /addons.sh install sodium " to install the PHP Sodium module.'
            with_sodium=''
        else   
            if [ "$PM" = "yum" ]; then
                if [ "${DISTRO}" = "Oracle" ]; then
                    yum -y install oracle-epel-release
                else
                    yum -y install epel-release
                fi
                yum -y install libsodium-devel
            elif [ "$PM" = "apt" ]; then
                apt-get install -y libsodium-dev
            fi
            with_sodium='--with-sodium' 
        fi
    fi
}

PHP_with_Imap() {
    echo "Checking Imap..."
    if echo "${php_version}" | grep -Eqi '^8\.(4|5)\.*' || echo "${Php_Ver}" | grep -Eqi "php-8\.(4|5)\.*"; then
        # since php 8.4, IMAP is not bundled with php core and you need to install it via PECL extension.
        with_imap=''
        return 0
    fi

    if [ "${Enable_PHP_Imap}" = "n" ]; then
        with_imap=''
    elif [[ ! "${UseNewOpenssl}" = "y" ]]; then
        if [ "$PM" = "yum" ]; then
            if [ "${DISTRO}" = "Oracle" ]; then
                yum -y install oracle-epel-release
            else
                yum -y install epel-release
            fi
            yum -y install libc-client-devel krb5-devel uw-imap-devel
            if echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
                if ! rpm -qa | grep "libc-client-2007f" || ! rpm -qa | grep "uw-imap-devel"; then
                    if [ "${CheckMirror}" = "n" ]; then
                        rpm -ivh ${cur_dir}/src/libc-client-2007f-30.el9.${ARCH}.rpm ${cur_dir}/src/uw-imap-devel-2007f-30.el9.${ARCH}.rpm
                    else
                        rpm -ivh ${libc_client_2007f_24_el9_DL}
                        rpm -ivh ${uw_imap_devel_2007f_24_el9_DL}
                    fi
                fi
            fi
            [[ -s /usr/lib64/libc-client.so ]] && ln -sf /usr/lib64/libc-client.so /usr/lib/libc-client.so
        elif [ "$PM" = "apt" ]; then
            apt-get install -y libc-client-dev libkrb5-dev
        fi
        with_imap='--with-imap --with-imap-ssl --with-kerberos'
    else
        # build c-library manually
        Echo_Blue "[+] Building UW IMAP"
        cd ${cur_dir}/src
        git clone https://github.com/uw-imap/imap.git
        cd imap
        make slx \
          SSLTYPE=unix.nopwd \
          SSLDIR="${Custom_Openssl_Path}" \
          SSLLIB="${Custom_Openssl_Path}/lib" \
          SSLCERTS="${Custom_Openssl_Path}/certs"\
          EXTRACFLAGS="-fPIC"

        rm -rf /usr/local/imap-ssl
        mkdir -p /usr/local/imap-ssl/include /usr/local/imap-ssl/lib
        cp c-client/*.h /usr/local/imap-ssl/include/
        cp c-client/c-client.a /usr/local/imap-ssl/lib/libc-client.a

        with_imap="--with-imap=/usr/local/imap-ssl --with-imap-ssl=${Custom_Openssl_Path}"

        # cleaning
        rm -rf cd ${cur_dir}/src/imap
    fi
}

PHP_Install_Intl() {
    if echo "${php_version}" | grep -Eqi '^5\.[4-6]\.' || echo "${Php_Ver}" | grep -Eqi "php-5\.[4-6]\."; then
        if [[ "${local_icu_version}" -lt 50 ]]; then
            Install_Icu522
            with_icu_dir='--with-icu-dir=/usr/local/icu522'
            php_with_custom_icu='y'
            php_with_custom_icu_prefix='/usr/local/icu522'
        fi
    fi
    if echo "${php_version}" | grep -Eqi '^7\.[0-1]\.' || echo "${Php_Ver}" | grep -Eqi "php-7\.[0-1]\."; then
        if [[ "${local_icu_version}" -lt 50 || "${local_icu_version}" -gt 60 ]]; then
            Install_Icu582
            with_icu_dir='--with-icu-dir=/usr/local/icu582'
            php_with_custom_icu='y'
            php_with_custom_icu_prefix='/usr/local/icu582'
        fi
    fi
    if echo "${php_version}" | grep -Eqi '^7\.2\.' || echo "${Php_Ver}" | grep -Eqi "php-7\.2\."; then
        if [[ "${local_icu_version}" -lt 50 || "${local_icu_version}" -gt 67 ]]; then
            Install_Icu603
            with_icu_dir='--with-icu-dir=/usr/local/icu603'
            php_with_custom_icu='y'
            php_with_custom_icu_prefix='/usr/local/icu603'
        fi
    fi
    if echo "${php_version}" | grep -Eqi '^7\.3\.' || echo "${Php_Ver}" | grep -Eqi "php-7\.3\."; then
        if [[ "${local_icu_version}" -lt 52 || "${local_icu_version}" -gt 67 ]]; then
            Install_Icu671
            with_icu_dir='--with-icu-dir=/usr/local/icu671'
            php_with_custom_icu='y'
            php_with_custom_icu_prefix='/usr/local/icu671'
        fi
    fi
    if echo "${php_version}" | grep -Eqi '^7\.4\.' || echo "${Php_Ver}" | grep -Eqi "php-7\.4\."; then
    # for best performance
    #   if [[ "${local_icu_version}" -lt 56 || "${local_icu_version}" -gt 69 ]]; then
    # for best compatible
        if [[ "${local_icu_version}" -lt 56 ]]; then
            Install_Icu671
            php_with_custom_icu='y'
            PKG_CONFIG_PATH_TEMP="${PKG_CONFIG_PATH_TEMP:+$PKG_CONFIG_PATH_TEMP:}/usr/local/icu671/lib/pkgconfig"
        fi

    fi
    if echo "${php_version}" | grep -Eqi '^8\.[0-4]\.' || echo "${Php_Ver}" | grep -Eqi "php-8\.[0-4]\."; then
        if [[ "${local_icu_version}" -lt 67 ]]; then
            Install_Icu721
            php_with_custom_icu='y'
            PKG_CONFIG_PATH_TEMP="${PKG_CONFIG_PATH_TEMP:+$PKG_CONFIG_PATH_TEMP:}/usr/local/icu721/lib/pkgconfig"
        fi
    fi
}

PHP_Install_ICU() {
    #if echo "${php_version}" | grep -Eqi '^(5\.6\.|7\.0\.)' || echo "${Php_Ver}" | grep -Eqi "php-(5\.6\.|7\.0\.)"; then
    if echo "${php_version}" | grep -Eqi '^5\.6\.' || echo "${Php_Ver}" | grep -Eqi "^php-5\.6\."; then
        if [[ "${local_icu_version}" -lt 50 || "${local_icu_version}" -gt 67 ]]; then
            Install_Icu603
            with_icu_dir='--with-icu-dir=/usr/local/icu603'
            php_with_custom_icu='y'
            php_with_custom_icu_prefix='/usr/local/icu603'
            local_icu_version=60
        fi
    fi
}

PHP_with_Intl() {
    echo "Checking ICU..."
    Get_ICU_Version
    echo "System ICU version is ${local_icu_version}, detected by ${detected_icu_method}"
    
    php_with_custom_icu='n'
    #PHP_Install_ICU

    if [ "${local_icu_version}" -gt 68 ]; then
        if ! echo "${php_version}" | grep -Eqi '^8\.[2-5]\.' && ! echo "${Php_Ver}" | grep -Eqi '^php-8\.[2-5]\.'; then
            echo "Compiler flags need to be set"
            export CXX="g++ -DTRUE=1 -DFALSE=0"
            export CC="gcc -DTRUE=1 -DFALSE=0"
        else
            echo "Compiler flags does not to be set"
        fi
    fi
}

# Only used for php 5.6, therefore no need pkg_config_path for php environment
PHP_With_Libxml2() {
    echo "Checking Libxml2..."
    if [ "${php_with_custom_icu}" = "y" ]; then
        Libxml2_check=$(find /usr/lib /lib /usr/local/lib -name 'libxml2.so' 2>/dev/null | head -n1)
        echo "Checking ICU linkage in: ${Libxml2_check}"
        if ldd "$Libxml2_check" | grep -qi icu; then
            echo "ICU detected in system libxml2!"
            if [ -d /usr/local/libxml2_icu"${local_icu_version}" ]; then
                echo "Custom libxml2 with ICU ${local_icu_version} already installed, skip."
            else
                Echo_Blue "[+] Installing ${Libxml2_Ver}"
                rm -rf /usr/local/libxml2_icu"${local_icu_version}"
                cd ${cur_dir}/src
                Download_Files ${Libxml2_DL} ${Libxml2_Ver}.tar.xz
                Tar_Cd ${Libxml2_Ver}.tar.xz ${Libxml2_Ver}
                #PKG_CONFIG_PATH=${php_with_custom_icu_prefix}/lib/pkgconfig
                CPPFLAGS="-I${php_with_custom_icu_prefix}/include" \
                LDFLAGS="-L${php_with_custom_icu_prefix}/lib -Wl,-rpath,${php_with_custom_icu_prefix}/lib" \
                ./configure \
                    --prefix=/usr/local/libxml2_icu"${local_icu_version}" \
                    --with-icu \
                    --without-python
                Make_Install
                cd ${cur_dir}/src/
                rm -rf ${cur_dir}/src/${Libxml2_Ver}
            fi
            # export path so that php compiler can find it
            if [ "${PHP_Use_PKG}" = "y" ]; then
                PKG_CONFIG_PATH_TEMP="$PKG_CONFIG_PATH_TEMP:/usr/local/libxml2_icu"${local_icu_version}"/lib/pkgconfig"
                with_libxml_dir=""
            else
                with_libxml_dir="--with-libxml-dir=/usr/local/libxml2_icu"${local_icu_version}""
            fi
        else
            echo "System libxml2 is not linked to ICU. No build needed"
            with_libxml_dir=""
        fi
    else
        with_libxml_dir=""
        echo "PHP is using system ICU. No build needed"
    fi
    
}

PHP_PEAR_Reset() {
    rm -rf ~/.pearrc
}

PHP_Check_PKG() {
    echo "Checking PKG_CONFIG..."
    if echo "${php_version}" | grep -Eqi '^(7\.4\.|8\.[0-5]\.)' || echo "${Php_Ver}" | grep -Eqi "(php-7\.4\.|php-8\.[0-5]\.)"; then
        PHP_Use_PKG="y"
    fi
}

PHP_Post_Set() {
    PHP_ENV_UNSET
}

PHP_ENV_UNSET() {
    if [[ -n "${PKG_CONFIG_PATH_TEMP+x}" ]]; then
        echo "Resetting PKG_CONFIG_PATH (was: ${PKG_CONFIG_PATH_TEMP})"
        unset PKG_CONFIG_PATH
        unset PKG_CONFIG_PATH_TEMP
    fi
    if [[ -n "${LDFLAGS_TEMP+x}" ]]; then
        echo "Resetting LDFLAGS (was: ${LDFLAGS_TEMP})"
        unset LDFLAGS
        unset LDFLAGS_TEMP
    fi
    if [[ -n "${CC+x}" ]]; then
        echo "Resetting CC (was: ${CC}) and CXX (was: ${CXX})"
        unset CC
        unset CXX
    fi
    PHP_GCC14_Unset
}

PHP_ENV_SET() {
    PHP_PEAR_Reset
        if [[ -n "${PKG_CONFIG_PATH_TEMP}" ]]; then
            export PKG_CONFIG_PATH="${PKG_CONFIG_PATH_TEMP}"
            #export CPPFLAGS="${CPPFLAGS_TEMP}"
            echo "PKG_CONFIG_PATH is set to ${PKG_CONFIG_PATH}"
            #echo "CPPFLAGS is set to ${CPPFLAGS}"

        else
            echo "No PKG Environment EXPORT required."
        fi

        if [[ -n "${LDFLAGS_TEMP}" ]]; then
            export LDFLAGS="${LDFLAGS_TEMP}"  
            echo "LDFLAGS is set to ${LDFLAGS}"
        else
            echo "No LDFLAGS Environment EXPORT required."
        fi



#    if echo "${php_version}" | grep -Eqi '^7\.[1-3]\.' && echo "${Php_Ver}" | grep -Eqi '^php-7\.[1-3]\.'; then
#            echo "Compiler flags need to be set"
#            export CXX="g++ -DTRUE=1 -DFALSE=0"
#            export CC="gcc -DTRUE=1 -DFALSE=0"
#    else
#            echo "Compiler flags does not to be set"
#    fi
}

Check_PHP_Option() {
    PHP_Check_PKG
    PHP_ENV_UNSET
    PHP_with_openssl
    PHP_with_curl
    PHP_with_Libzip
    PHP_with_fileinfo
    PHP_with_Exif
    PHP_with_iconv
    PHP_with_Ldap
    PHP_with_Bz2
    PHP_with_Sodium
    PHP_with_Imap
    PHP_with_Intl
    PHP_With_Libxml2
    PHP_Buildin_Option="${with_exif} ${with_ldap} ${with_bz2} ${with_iconv} ${with_sodium} ${with_imap} ${with_icu_dir} ${with_libxml_dir} ${with_libzip}"
    PHP_ENV_SET
}

Ln_PHP_Bin() {
    ln -sf /usr/local/php/bin/php /usr/bin/php
    ln -sf /usr/local/php/bin/phpize /usr/bin/phpize
    if [ -s /usr/local/php/bin/pear ]; then
        ln -sf /usr/local/php/bin/pear /usr/bin/pear
        pear config-set php_ini /usr/local/php/etc/php.ini
    fi
    if [ -s /usr/local/php/bin/pecl ]; then
        ln -sf /usr/local/php/bin/pecl /usr/bin/pecl
        pecl config-set php_ini /usr/local/php/etc/php.ini
    fi
    if [ "${Stack}" = "lnmp" ]; then
        ln -sf /usr/local/php/sbin/php-fpm /usr/bin/php-fpm
    fi
    rm -f /usr/local/php/conf.d/*
}

Pear_Pecl_Set() {
    pear config-set php_ini /usr/local/php/etc/php.ini
    pecl config-set php_ini /usr/local/php/etc/php.ini
}

Install_Composer() {
    if [ "${CheckMirror}" != "n" ]; then
        echo "Downloading Composer..."
        if echo "${PHPSelect}" | grep -Eqi '^[1-14]' || echo "${php_version}" | grep -Eqi '^(5\.[2-6]\.*|7\.[0-4]\.*|8\.[0-5]\.*)' || echo "${Php_Ver}" | grep -Eqi "(php-5\.[2-6]\.*|php-7\.[0-4]\.*|php-8\.[0-5]\.*)"; then
            curl -sS --connect-timeout 30 -m 60 https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
            if [ $? -eq 0 ]; then
                echo "Composer install successfully."
            fi

        else
            wget --progress=dot:giga --prefer-family=IPv4 --no-check-certificate -T 120 -t3 https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer
            if [ $? -eq 0 ]; then
                echo "Composer install successfully."
                chmod +x /usr/local/bin/composer
            else
                echo "Composer install failed, try to from composer official website..."
                curl -sS --connect-timeout 30 -m 60 https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
                if [ $? -eq 0 ]; then
                    echo "Composer install successfully."
                fi
            fi
        fi
        #if [ "${country}" = "CN" ]; then
        #composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
        #fi
    fi
}

PHP_Openssl3_Patch() {
    if [ "${isOpenSSL3}" = "y" ]; then
        if [ "${php_version}" != "" ]; then
            Php_Ver="php-${php_version}"
        fi
        echo "OpenSSL 3.0, apply a patch to ${Php_Ver}..."
        patch -p1 <${cur_dir}/src/patch/${Php_Ver}-openssl3.0.patch
    fi
}

PHP_ICU70_PKGCONFIG_Patch() {
    if [[ "${Php_Ver_Short}" =~ (5.6|7.0) ]]; then
        echo "checking if ICU 7x+ pkgconfig patch is needed..."
        if [ "$local_icu_version" -ge 70 ]; then
            echo "icu 7x+, apply a pkgconfig patch to ${Php_Ver}..."
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-icu-70-pkg-config.patch
            Php_Buildconf='y'
        elif [ "$local_icu_version" -ge 67 ]; then
            ## patch pkg-config lookup issue
            echo "icu 63+, apply a pkg-config patch to ${Php_Ver}..."
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-icu-pkg-config.patch
            ## patch namespace issue
            echo "icu 63+, apply a ICU namespace patch to ${Php_Ver}..."
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-intl-namespace-icu.patch
            Php_Buildconf='y'
        else
            echo "No icu 63+ pkgconfig patch is needed for ${Php_Ver}"
        fi
    fi
}

PHP_ICU70_Patch() {
    if [[ "${Php_Ver_Short}" =~ (7.1|7.2|7.3) ]]; then
        echo "checking if ICU 7x+ patch is needed..."
        if [ "$local_icu_version" -ge 70 ]; then
            echo "icu 7x+, apply a patch to ${Php_Ver}..."
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-icu-70.patch
        else
            echo "No icu 7x+ patch is needed for ${Php_Ver}"
        fi
    fi
}

# ICU version 74 and later require C++17 language standards to build correctly
# while PHP 8.1 and older used an older standard for its internal C++ code.
# PHP 8.1.33 and 8.1.34 fixes this issue, so only need patch for 7.4, 8.0 and 8.1 below 8.1.33
PHP_CPP17_Patch() {
    if [[ "${Php_Ver_Short}" =~ (7.4|8.0) ]]; then
        if [ "$local_icu_version" -ge 75 ]; then
            echo "C++17 patch is required for ICU 75+"
            echo "Apply C++17 patch to ${Php_Ver}..."
            patch -p1 <"${cur_dir}"/src/patch/php-"${Php_Ver_Short}"-icu-74-c++17.patch
            Php_Buildconf='y'
        else
            echo "No C++17 patch is needed for PHP ${Php_Ver}"
        fi
    elif [ "${Php_Ver_Short}" = "8.1" ] && [ "${Php_Third_Ver}" -lt 33 ] && [ "$local_icu_version" -ge 75 ]; then
            echo "C++17 patch is required for ICU 75+"
            echo "Apply C++17 patch to ${Php_Ver}..."
            patch -p1 <"${cur_dir}"/src/patch/php-"${Php_Ver_Short}"-icu-74-c++17.patch
            Php_Buildconf='y'
    else
        echo "No C++17 patch is needed for ${Php_Ver}"
    fi
}

PHP_ICU_Patch() {
    echo "Checking if ICU patch is needed..."
    echo "Local ICU version is ${local_icu_version}"
    PHP_CPP17_Patch
    PHP_ICU70_Patch
    PHP_ICU70_PKGCONFIG_Patch
}

# php 7.3 and earlier using freetype-config which does not exist on modern linux distros
# therefore we need to patch php source to use pkg-config instead
PHP_Freetype_Patch() {
    if [[ "${Php_Ver_Short}" =~ (5.6|7.0|7.1|7.2|7.3) ]]; then
        echo "checking if Freetype patch is needed..."
        if ! command -v freetype-config >/dev/null 2>&1; then
            echo "Freetype patch is required for ${Php_Ver}"
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-freetype2-pkg-config.patch
            Php_Buildconf='y'
        else
            echo "No Freetype patch is needed for ${Php_Ver}"
        fi
    fi
}

PHP_Readdir_r_Patch() {
    if [[ "${Php_Ver_Short}" =~ (7.0|7.1|7.2|7.3) ]]; then
        echo "checking if readdir_r patch is needed..."
        if [ "${Main_Gcc_Ver}" -ge 14 ] && [ "${Glibc_Second_Ver}" -ge 24 ]; then
            echo "readdir_r patch is required for ${Php_Ver} with glibc ${Main_Glibc_Ver}"
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-readdir_r.patch
        else
            echo "No readdir_r patch is needed for ${Php_Ver}"
        fi
    fi
}

PHP_Cast_Patch() {
    if [[ "${Php_Ver_Short}" =~ (7.0|7.1|7.2) ]]; then
        echo "checking if cast patch is needed..."
        if [ "${Main_Gcc_Ver}" -ge 14 ] && [ "${Glibc_Second_Ver}" -ge 24 ]; then
            echo "cast patch is required for ${Php_Ver} with gcc ${Main_Gcc_Ver}"
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-cast.patch
        else
            echo "No cast patch is needed for ${Php_Ver}"
        fi
    fi
}

PHP_Main_Phpconfig_Patch() {
    if [[ "${Php_Ver_Short}" =~ (7.0|7.1) ]]; then
        echo "checking if main php config patch is needed..."
        if [ "${Main_Gcc_Ver}" -ge 14 ]; then
            echo "main php config patch is required for ${Php_Ver} with gcc ${Main_Gcc_Ver}"
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-main-php_config.patch
        else
            echo "No main php config patch is needed for ${Php_Ver}"
        fi
    fi
}   

PHP_Dom_Iterators_Patch() {
    if [[ "${Php_Ver_Short}" =~ 7.0 ]]; then
        echo "checking if DOM Iterators patch is needed..."
        if [ "${Main_Gcc_Ver}" -ge 14 ] && [ "${DISTRO}" = "Debian" ] && [ "${DISTRO_Version}" -ge "13" ]; then
            echo "DOM Iterators patch is required for ${Php_Ver} with gcc ${Main_Gcc_Ver}"
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-dom-iterators.patch
        else
            echo "No DOM Iterators patch is needed for ${Php_Ver}"
        fi
        sleep 5
    fi
}

# only for php 5.6
PHP_Autoconf_Patch() {
    if [[ "${Php_Ver_Short}" =~ 5.6 ]]; then
        echo "checking if autoconf patch is needed..."
        if [ "${Main_Gcc_Ver}" -ge 14 ]; then
            echo "autoconf patch is required for ${Php_Ver} with gcc ${Main_Gcc_Ver}"
            patch -p1 <${cur_dir}/src/patch/php-${Php_Ver_Short}-autoconf.patch
        else
            echo "No autoconf patch is needed for ${Php_Ver}"
        fi
        sleep 5
    fi
}

# -Wno-incompatible-pointer-types solves the following error:
# /src/php-5.6.40/Zend/zend_API.h:122:45: error: initialization of ‘void (*)(void *)’ from 
# incompatible pointer type ‘void (*)(zend_zlib_globals *)’ {aka ‘void (*)(struct _zend_zlib_globals *)’} 
# -Wno-implicit-int -Wno-implicit-function-declaration
# /src/php-5.6.40/ext/fileinfo/libmagic/funcs.c:440:1: error: return type defaults to ‘int’ [-Wimplicit-int]
# 440 | file_replace(struct magic_set *ms, const char *pat, const char *rep)
PHP_GCC14_PATCH() {
    if [[ "${Php_Ver_Short}" = "5.6" ]]; then
        echo "checking if GCC 14 patch is needed..."
        if [ "${Main_Gcc_Ver}" -ge 14 ]; then
            echo "GCC 14 patch is required for ${Php_Ver} with gcc ${Main_Gcc_Ver}"
           # PHP_GCC_OPTIONS='CFLAGS=-Wno-incompatible-pointer-types -Wno-implicit-int -Wno-implicit-function-declaration'
        export CFLAGS="-Wno-incompatible-pointer-types -Wno-implicit-int -Wno-implicit-function-declaration"
        else
            echo "No GCC 14 patch is needed for ${Php_Ver}"
        fi
        sleep 5
    fi
}

PHP_GCC14_Unset() {
    if [ -n "${CFLAGS+x}" ]; then
        echo "Resetting CFLAGS (was: $CFLAGS)"
        unset CFLAGS
    fi
}

PHP_Patch() {
    Php_Buildconf='n'
    if [ "${php_version}" != '' ]; then
        Php_Ver_Short="$(echo ${php_version} | cut -d. -f1-2)"
        Php_Ver="php-${php_version}"
    fi
    Php_Third_Ver=${Php_Ver##*.}
    Main_Gcc_Ver=$(gcc -dumpversion | cut -d. -f1)
    Main_Glibc_Ver=$(ldd --version | head -n1 | awk '{print $NF}')
    Glibc_Second_Ver=${Main_Glibc_Ver##*.}
    ## for debug only
    echo "PHP Version is ${Php_Ver}"
    echo "PHP Version's third number is ${Php_Third_Ver}"
    ## for debug only
    echo "Checking if there's any patch needed for ${Php_Ver}..."
    PHP_ICU_Patch
    PHP_Freetype_Patch
    PHP_Readdir_r_Patch
    PHP_Cast_Patch
    PHP_Main_Phpconfig_Patch
    PHP_Dom_Iterators_Patch
    #PHP_Autoconf_Patch
   if [ "${Php_Buildconf}" = 'y' ]; then
        if [ "${Php_Ver_Short}" = "5.6" ]; then
            Check_Autoconf_Version
            if [ "${Autoconf_Second_Digit}" -gt 69 ]; then
                Install_Autoconf
                echo "Rebuilding the configure script after patching with new autoconf 2.69..."
                cd ${cur_dir}/src/${Php_Ver}
                PHP_AUTOCONF="/usr/local/autoconf-2.69/bin/autoconf" PHP_AUTOHEADER="/usr/local/autoconf-2.69/bin/autoheader" ./buildconf --force
            else
                echo "Rebuilding the configure script after patching with system autoconf..."
                ./buildconf --force
            fi
        else
            echo "Rebuilding the configure script after patching..."
            ./buildconf --force
        fi
    fi
}

PHP_Set_Systemd() {
    if [ "${Stack}" = "lnmp" ]; then
        if [ "${php_version}" != '' ]; then
            Php_Ver="php-${php_version}"
        fi
        #\cp ${cur_dir}/src/php-${php_version}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
        if [ "${Php_Ver_Short}" = "5.6" ]; then
            \cp ${cur_dir}/init.d/php-fpm.service5.6 /etc/systemd/system/php-fpm.service
        else
            \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/php-fpm.service /etc/systemd/system/php-fpm.service        
            sed -i 's/^ProtectSystem=/#ProtectSystem=/g' /etc/systemd/system/php-fpm.service
            sed -i 's/^PrivateTmp=/#PrivateTmp=/g' /etc/systemd/system/php-fpm.service
        fi
        systemctl daemon-reload
        systemctl enable php-fpm
    fi
}

PHP_Create_Conf() {
    if [ "${Stack}" = "lnmp" ]; then
        echo "Creating new php-fpm configure file..."
        cat >/usr/local/php/etc/php-fpm.conf <<EOF
[global]
pid = /usr/local/php/var/run/php-fpm.pid
error_log = /usr/local/php/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi.sock
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
pm.max_requests = 1024
pm.process_idle_timeout = 10s
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF
    fi    
}

PHP_CP_Ini() {
    echo "Copy new php configure file..."
    mkdir -p /usr/local/php/{etc,conf.d}
    \cp php.ini-production /usr/local/php/etc/php.ini
}

PHP_Set_Ini() {
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /usr/local/php/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /usr/local/php/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = America\/New_York/g' /usr/local/php/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /usr/local/php/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /usr/local/php/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /usr/local/php/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /usr/local/php/etc/php.ini
}

Install_PHP_55() {
    Echo_Blue "[+] Installing ${Php_Ver}..."
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${ARCH}" = "aarch64" ]; then
        patch -p1 <${cur_dir}/src/patch/php-5.5-5.6-asm-aarch64.patch
    fi
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
    PHP_Create_Conf
    PHP_Set_Systemd
}

Install_PHP_56() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}

    if [ "${ARCH}" = "aarch64" ]; then
        patch -p1 <${cur_dir}/src/patch/php-5.5-5.6-asm-aarch64.patch
    fi

    #if command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
    #    patch -p1 < ${cur_dir}/src/patch/php-5.6-icu-70-pkg-config.patch
    #fi
    #    if command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
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
    PHP_Create_Conf
    PHP_Set_Systemd
}

Install_PHP_70() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}

    #if command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
    #    patch -p1 < ${cur_dir}/src/patch/php-7.0-icu-70-pkg-config.patch
    #fi
    #    if command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
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
}

Install_PHP_71() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    #    PHP_Openssl3_Patch
    Install_Libmcrypt
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
}

Install_PHP_72() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    #    PHP_Openssl3_Patch
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
}

Install_PHP_73() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    #    PHP_Openssl3_Patch
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Buildin_Option} ${PHP_Modules_Options}
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
}

# starting from php 7.4, --with-png is removed and it will auto-detect by pkg-config
Install_PHP_74() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Patch
    #    PHP_Openssl3_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg--with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
}

Install_PHP_80() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Patch
    #    PHP_Openssl3_Patch
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
}

Install_PHP_81() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd--with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
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
}

Install_PHP_82() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
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
}

Install_PHP_83() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --enable-fpm --with-fpm-systemd --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    else
        ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-config-file-scan-dir=/usr/local/php/conf.d --with-apxs2=/usr/local/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-png --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    Ln_PHP_Bin
    PHP_CP_Ini
    PHP_Set_Ini
    Install_Composer
    PHP_Create_Conf
    PHP_Set_Systemd
}

Install_PHP_84() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
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
}

# starting from php 8.5, --enable-opcache is removed and opcache is always enabled
Install_PHP_85() {
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
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
}

LNMP_PHP_Opt() {
    if [[ ${MemTotal} -gt 1024 && ${MemTotal} -le 2048 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 20#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 10#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 10#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 20#" /usr/local/php/etc/php-fpm.conf
    elif [[ ${MemTotal} -gt 2048 && ${MemTotal} -le 4096 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 40#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 20#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 20#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 40#" /usr/local/php/etc/php-fpm.conf
    elif [[ ${MemTotal} -gt 4096 && ${MemTotal} -le 8192 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 60#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 30#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 30#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 60#" /usr/local/php/etc/php-fpm.conf
    elif [[ ${MemTotal} -gt 8192 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 80#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 40#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 40#" /usr/local/php/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 80#" /usr/local/php/etc/php-fpm.conf
    fi
}

Creat_PHP_Tools() {
    echo "Create PHP Info Tool..."
    cat >${Default_Website_Dir}/phpinfo.php <<eof
<?php
phpinfo();
?>
eof

    echo "Copy PHP Prober..."
    cd ${cur_dir}/src
    #    tar zxf p.tar.gz
    \cp prober.php ${Default_Website_Dir}/prober.php

    \cp ${cur_dir}/conf/index.html ${Default_Website_Dir}/index.html
    \cp ${cur_dir}/conf/lnmp.gif ${Default_Website_Dir}/lnmp.gif

    if [ ${PHPSelect} -ge 4 ]; then
        echo "Copy Opcache Control Panel..."
        \cp ${cur_dir}/conf/ocp.php ${Default_Website_Dir}/ocp.php
    fi
    echo "============================Install PHPMyAdmin================================="
    [[ -d ${Default_Website_Dir}/phpmyadmin ]] && rm -rf ${Default_Website_Dir}/phpmyadmin
    tar Jxf ${PhpMyAdmin_Ver}.tar.xz
    mv ${PhpMyAdmin_Ver} ${Default_Website_Dir}/phpmyadmin
    \cp ${cur_dir}/conf/config.inc.php ${Default_Website_Dir}/phpmyadmin/config.inc.php
    sed -i 's/LNMPORG/GETLNMP_'$(date +%s%N | head -c 13)'_GETLNMP/g' ${Default_Website_Dir}/phpmyadmin/config.inc.php
    mkdir ${Default_Website_Dir}/phpmyadmin/{upload,save}
    chmod 755 -R ${Default_Website_Dir}/phpmyadmin/
    chown www:www -R ${Default_Website_Dir}/phpmyadmin/
    echo "============================phpMyAdmin install completed======================="
}
