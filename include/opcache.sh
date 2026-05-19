#!/usr/bin/env bash

# bundled with PHP 5.5.0 and later, and is » available in PECL for PHP versions 5.2, 5.3 and 5.4
Install_Opcache()
{

    Echo_Red "Install Opcache will auto uninstall eAccelerator if exists..."
    echo "====== Installing zend opcache ======"
    Press_Start

    echo "Uninstall eAccelerator..."
    rm -f ${PHP_Path}/conf.d/004-opcache.ini

    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}opcache.so"
    if echo "${Cur_PHP_Version}" | grep -Eqi '^5\.[234].'; then
        if [ -s "${zend_ext}" ]; then
            rm -f "${zend_ext}"
        fi
    fi

    if echo "${Cur_PHP_Version}" | grep -Eqi '^5\.[56]\.' || echo "${Cur_PHP_Version}" | grep -Eqi '^7\.'; then
        cat >${PHP_Path}/conf.d/004-opcache.ini<<EOF
[Zend Opcache]
zend_extension="opcache.so"
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
opcache.enable_cli=1
EOF
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^8\.'; then
        cat >${PHP_Path}/conf.d/004-opcache.ini<<EOF
[Zend Opcache]
zend_extension="opcache.so"
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
opcache.enable_cli=1

opcache.jit = 1255
opcache.jit_buffer_size = 64M
EOF

    else
        echo "Error: can't get php version!"
        echo "Maybe php was didn't install or php configuration file has errors.Please check."
        sleep 3
        exit 1
    fi

    echo "Copy Opcache Control Panel..."
    \cp "${cur_dir}"/conf/ocp.php "${Default_Website_Dir}"/ocp.php
    Restart_PHP
    if [ -s "${zend_ext}" ]; then
        Echo_Green "====== Opcache install completed ======"
        Echo_Green "Opcache installed successfully, enjoy it!"
        exit 0
    else
        rm -f "${PHP_Path}"/conf.d/004-opcache.ini
        Echo_Red "OPcache install failed!"
        exit 1
    fi
}

Uninstall_Opcache()
{
    echo "You will uninstall opcache..."
    Press_Start
    rm -f ${Default_Website_Dir}/ocp.php
    rm -f "${PHP_Path}"/conf.d/004-opcache.ini
    Restart_PHP
    Echo_Green "Uninstall Opcache completed."
}
