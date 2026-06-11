#!/usr/bin/env bash

Install_PHP_Exif()
{
    cd ${cur_dir}/src
    echo "====== Installing PHP Exif ======"
    Press_Start

    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}exif.so"

    if ${PHP_Path}/bin/php -m | grep -qx exif; then
        Echo_Yellow "PHP Module 'exif' already loaded — nothing to do."
        exit 0
    fi

    Download_PHP_Src

    Tar_Cd php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}/ext/exif
    # gcc 3 and gcc 4 cannot compile PHP 8.x at all (PHP 8 requires C11 and gcc ≥ 7.4 in practice)
    # if echo "${Cur_PHP_Version}" | grep -Eqi '^8\.' && gcc -dumpversion|grep -Eq "^[3-4]\.";then
    #     export CFLAGS="-std=c99"
    # fi
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config
    Make_Install_Exit "Exif"
    cd "${cur_dir}/src"
    rm -rf php-"${Cur_PHP_Version}"

    if [ -s "${zend_ext}" ]; then
        cat >"${PHP_Path}"/conf.d/009-exif.ini<<EOF
extension = "exif.so"
EOF
        Restart_PHP
        Echo_Green "====== PHP Exif install completed ======"
        Echo_Green "PHP Exif installed successfully, enjoy it!"
        exit 0
    else
        Echo_Red "PHP Exif install failed!"
        exit 1
    fi
}

Uninstall_PHP_Exif()
{
    echo "You will uninstall PHP Exif..."
    Press_Start
    rm -f "${PHP_Path}"/conf.d/009-exif.ini
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}exif.so"
    Restart_PHP
    Echo_Green "Uninstall PHP Exif completed."
}
