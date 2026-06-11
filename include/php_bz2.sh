#!/usr/bin/env bash

Install_PHP_Bz2()
{
    cd ${cur_dir}/src
    echo "====== Installing PHP Bz2 ======"
    Press_Start

    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}bz2.so"

    if ${PHP_Path}/bin/php -m | grep -qx bz2; then
        Echo_Yellow "PHP Module 'bz2' already loaded — nothing to do."
        exit 0
    fi

    if [ "$PM" = "yum" ]; then
        yum -y install bzip2-devel
    elif [ "$PM" = "apt" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y libbz2-dev
    fi

    Download_PHP_Src

    Tar_Cd php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}/ext/bz2
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config
    Make_Install_Exit "Bz2"
    cd "${cur_dir}/src"
    rm -rf php-"${Cur_PHP_Version}"

    if [ -s "${zend_ext}" ]; then
        cat >${PHP_Path}/conf.d/009-bz2.ini<<EOF
extension = "bz2.so"
EOF
        Restart_PHP
        Echo_Green "====== PHP Bz2 install completed ======"
        Echo_Green "PHP Bz2 installed successfully, enjoy it!"
        exit 0
    else
        Echo_Red "PHP Bz2 install failed!"
        exit 1
    fi
}

Uninstall_PHP_Bz2()
{
    echo "You will uninstall PHP Bz2..."
    Press_Start
    rm -f ${PHP_Path}/conf.d/009-bz2.ini
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}bz2.so"
    Restart_PHP
    Echo_Green "Uninstall PHP Bz2 completed."
}
