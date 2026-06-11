#!/usr/bin/env bash

Install_PHP_Swoole()
{
    cd ${cur_dir}/src
    echo "====== Installing PHP Swoole ======"
    Press_Start

    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}swoole.so"

    if ${PHP_Path}/bin/php -m | grep -qx swoole; then
        Echo_Yellow "PHP Module 'swoole' already loaded — nothing to do."
        exit 0
    fi
    
    # openssl-devel/libssl-dev has already been installed when compiling PHP, therefore no need to install again and it's safe to enbale-openssl directly
    if echo "${Cur_PHP_Version}" | grep -Eqi '^8\.[0-9]\.'; then
        Download_Files ${PHPSwoole_DL} ${PHPSwoole_Ver}.tgz
        Tar_Cd ${PHPSwoole_Ver}.tgz ${PHPSwoole_Ver}
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config --enable-openssl --enable-http2
        Make_Install_Exit "Swoole"
        cd "${cur_dir}/src"
        rm -rf ${PHPSwoole_Ver}
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.[2-4]\.'; then
        Download_Files ${PHPSwoole4813_DL} swoole-4.8.13.tgz
        Tar_Cd swoole-4.8.13.tgz swoole-4.8.13
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config --enable-openssl --enable-http2 --enable-swoole-json
        Make_Install_Exit "Swoole"
        cd "${cur_dir}/src"
        rm -rf swoole-4.8.13
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.1\.'; then
        Download_Files ${PHPSwoole4511_DL} swoole-4.5.11.tgz
        Tar_Cd swoole-4.5.11.tgz swoole-4.5.11
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config --enable-openssl --enable-http2 --enable-swoole-json
        Make_Install_Exit "Swoole"
        cd "${cur_dir}/src"
        rm -rf swoole-4.5.11
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.0\.'; then
        Download_Files ${PHPSwoole436_DL} swoole-4.3.6.tgz
        Tar_Cd swoole-4.3.6.tgz swoole-4.3.6
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config --enable-openssl --enable-http2
        Make_Install_Exit "Swoole"
        cd "${cur_dir}/src"
        rm -rf swoole-4.3.6
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^5\.[3-6]\.'; then
        Download_Files ${PHPSwoole1105_DL} swoole-1.10.5.tgz
        Tar_Cd swoole-1.10.5.tgz swoole-1.10.5
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config --enable-openssl
        Make_Install_Exit "Swoole"
        cd "${cur_dir}/src"
        rm -rf swoole-1.10.5
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^5\.2\.'; then
        Download_Files ${PHPSwoole1610_DL} swoole-1.6.10.tgz
        Tar_Cd swoole-1.6.10.tgz swoole-1.6.10
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config --enable-openssl
        Make_Install_Exit "Swoole"
        cd "${cur_dir}/src"
        rm -rf swoole-1.6.10
    else
        Echo_Red "PHP Swoole has no recipe for PHP ${Cur_PHP_Version}"
        exit 1
    fi

    if [ -s "${zend_ext}" ]; then
        cat >${PHP_Path}/conf.d/009-swoole.ini<<EOF
extension = "swoole.so"
EOF
        Restart_PHP
        Echo_Green "====== PHP Swoole install completed ======"
        Echo_Green "PHP Swoole installed successfully, enjoy it!"
        exit 0
    else
        Echo_Red "PHP Swoole install failed!"
        exit 1
    fi
}

Uninstall_PHP_Swoole()
{
    echo "You will uninstall PHP Swoole..."
    Press_Start
    rm -f ${PHP_Path}/conf.d/009-swoole.ini
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}swoole.so"
    Restart_PHP
    Echo_Green "Uninstall PHP Swoole completed."
}
