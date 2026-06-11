#!/usr/bin/env bash

Install_Apcu()
{
    echo "You will install apcu..."
    apcu_pass=""
    for _ in 1 2 3; do
        read -r -p "Please enter admin password of apcu: " apcu_pass
        if [ "${apcu_pass}" != "" ]; then
            echo "================================================="
            echo "Your admin password of apcu was: ${apcu_pass}"
            echo "================================================="
            break
        else
            Echo_Red "Password cannot be empty!"
        fi
    done
    if [ "${apcu_pass}" = "" ]; then
        Echo_Red "No password provided after 3 attempts, aborting apcu installation."
        exit 1
    fi
    echo "====== Installing apcu ======"
    Press_Start

    rm -f ${PHP_Path}/conf.d/009-apcu.ini
    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}apcu.so"
    if [ -s "${zend_ext}" ]; then
        rm -f "${zend_ext}"
    fi

    cd ${cur_dir}/src

    if echo "${Cur_PHP_Version}" | grep -Eqi '^(7\.|8\.|9\.)'; then
        Download_Files ${PHPNewApcu_DL} ${PHPNewApcu_Ver}.tgz
        Tar_Cd ${PHPNewApcu_Ver}.tgz ${PHPNewApcu_Ver}
    else
        Echo_Red "We've dropped support for APCU on PHP 5.6 and earlier versions due to security vulnerabilities and compatibility issues. Please consider upgrading to a newer PHP version to use APCU."
        exit 1
    fi
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config
    Make_Install_Exit "apcu"
    \cp -a "${cur_dir}/src/${PHPNewApcu_Ver}/apc.php" "${Default_Website_Dir}/apc.php"
    escaped_pass=$(printf '%s' "$apcu_pass" | sed -e 's/[&|]/\\&/g')
    sed -i "s|^defaults('ADMIN_PASSWORD','.*|defaults('ADMIN_PASSWORD','${escaped_pass}');|" "${Default_Website_Dir}/apc.php"
    cd ${cur_dir}/src

    # PHP 7 requires apcu_bc for backward compatibility with APC, while PHP 8 does not need it
    if echo "${Cur_PHP_Version}" | grep -Eqi '^7\.'; then
        Download_Files ${PHPApcu_Bc_DL} ${PHPApcu_Bc_Ver}.tgz
        Tar_Cd ${PHPApcu_Bc_Ver}.tgz ${PHPApcu_Bc_Ver}
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config
        Make_Install_Exit "apcu bc"
        cd ${cur_dir}/src
        rm -rf ${cur_dir}/src/${PHPApcu_Bc_Ver}
        rm -rf ${cur_dir}/src/${PHPNewApcu_Ver}
    else
        rm -rf ${cur_dir}/src/${PHPOldApcu_Ver} ${cur_dir}/src/${PHPNewApcu_Ver}
    fi

    cat >${PHP_Path}/conf.d/009-apcu.ini<<EOF
[APCu]
extension=apcu.so
apc.enabled=1
apc.shm_size=32M
apc.enable_cli=1

EOF

    if echo "${Cur_PHP_Version}" | grep -Eqi '^7\.'; then
        sed -i '/apcu.so/a\extension=apc.so' ${PHP_Path}/conf.d/009-apcu.ini
    fi

    if [ -s "${zend_ext}" ]; then
        Restart_PHP
        Echo_Green "APCu Dashboard: http://yourIP/apc.php "
        Echo_Green "Admin Username: apc"
        Echo_Green "Admin Password: ${apcu_pass}"
        Echo_Green "======== apcu install completed ======"
        Echo_Green "apcu installed successfully, enjoy it!"
    else
        rm -f ${PHP_Path}/conf.d/009-apcu.ini
        Echo_Red "apcu install failed!"
    fi
}

Uninstall_Apcu()
{
    echo "You will uninstall apcu..."
    Press_Start
    rm -f ${Default_Website_Dir}/apc.php
    rm -f ${PHP_Path}/conf.d/009-apcu.ini
    Addons_Get_PHP_Ext_Dir
    echo "Delete apcu files..."
    rm -f "${zend_ext_dir}apcu.so" "${zend_ext_dir}apc.so"
    Restart_PHP
    Echo_Green "Uninstall apcu completed."
}
