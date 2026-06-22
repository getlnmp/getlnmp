#!/usr/bin/env bash

Install_PHP_Fileinfo() {
    cd "${cur_dir}"/src || exit
    echo "====== Installing PHP Fileinfo ======"

    local MemTotal SwapTotal
    MemTotal=$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
    SwapTotal=$(awk '/SwapTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
    if [ $((MemTotal + SwapTotal)) -lt 1024 ]; then
        Echo_Red "Memory + swap is less than 1GB; fileinfo compilation would likely OOM."
        Echo_Red "Add swap space or upgrade memory before retrying."
        exit 1
    elif [ "${MemTotal}" -lt 1024 ]; then
        Echo_Yellow "Memory is less than 1GB; relying on ${SwapTotal}MB swap to compile fileinfo."
    fi
    Press_Start

    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}fileinfo.so"

    if ${PHP_Path}/bin/php -m | grep -qx fileinfo; then
        Echo_Yellow "PHP Module 'fileinfo' already loaded — nothing to do."
        exit 0
    fi

    Download_PHP_Src

    Tar_Cd php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}/ext/fileinfo
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config
    Make_Install_Exit "Fileinfo"
    cd "${cur_dir}/src"
    rm -rf php-"${Cur_PHP_Version}"

    if [ -s "${zend_ext}" ]; then
        cat >${PHP_Path}/conf.d/009-fileinfo.ini <<EOF
extension = "fileinfo.so"
EOF
        Restart_PHP
        Echo_Green "====== PHP Fileinfo install completed ======"
        Echo_Green "PHP Fileinfo installed successfully, enjoy it!"
        exit 0
    else
        Echo_Red "PHP Fileinfo install failed!"
        exit 1
    fi
}

Uninstall_PHP_Fileinfo() {
    echo "You will uninstall PHP Fileinfo..."
    Press_Start
    rm -f "${PHP_Path}"/conf.d/009-fileinfo.ini
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}fileinfo.so"
    Restart_PHP
    Echo_Green "Uninstall PHP Fileinfo completed."
}
