#!/usr/bin/env bash

# As of PHP 7.2.0 this extension is bundled with PHP. For older PHP versions this extension is available via PECL.
# branch on PHP 5.2-7.1 (libsodium PECL) vs PHP 7.2+ (bundled ext/sodium)
Install_PHP_Sodium() {
    cd "${cur_dir}/src"
    echo "====== Installing PHP Sodium ======"
    Press_Start

    Addons_Get_PHP_Ext_Dir

    if echo "${Cur_PHP_Version}" | grep -Eqi '^5\.2\.'; then
        Echo_Red "PHP Sodium does not support PHP 5.2!"
        exit 1
    fi
    if echo "${Cur_PHP_Version}" | grep -Eqi '^(5\.[3-6]|7\.[01])\.'; then
        zend_ext="${zend_ext_dir}libsodium.so"
    else
        zend_ext="${zend_ext_dir}sodium.so"
    fi

    if ${PHP_Path}/bin/php -m | grep -qx sodium; then
        Echo_Yellow "PHP Module 'sodium' already loaded — nothing to do."
        exit 0
    fi

    if [ "$PM" = "yum" ]; then
        if ! rpm -q epel-release oracle-epel-release >/dev/null 2>&1; then
            if [ "${DISTRO}" = "Oracle" ]; then
                yum -y install oracle-epel-release
            else
                yum -y install epel-release
            fi
        fi
        yum -y install libsodium-devel
    elif [ "$PM" = "apt" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y libsodium-dev
    fi

    if echo "${Cur_PHP_Version}" | grep -Eqi '^(7\.[234]|8\.[0-5])\.'; then
        Download_PHP_Src
        Tar_Cd php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}/ext/sodium
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config
        Make_Install_Exit "Sodium"
        cd "${cur_dir}/src"
        # we need to delete the whole php tarball for cleaning
        rm -rf php-"${Cur_PHP_Version}"
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.[01]\.'; then
        Download_Files ${PHPSodium_DL} ${PHPSodium_Ver}.tgz
        Tar_Cd ${PHPSodium_Ver}.tgz ${PHPSodium_Ver}
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config
        Make_Install_Exit "Libsodium"
        cd "${cur_dir}/src"
        rm -rf "${PHPSodium_Ver}"
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^5\.[3-6]\.'; then
        Download_Files ${PHPSodiumOld_DL} libsodium-1.0.7.tgz
        Tar_Cd libsodium-1.0.7.tgz libsodium-1.0.7
        ${PHP_Path}/bin/phpize
        ./configure --with-php-config=${PHP_Path}/bin/php-config
        Make_Install_Exit "Libsodium"
        cd "${cur_dir}/src"
        rm -rf libsodium-1.0.7
    fi

    if [ -s "${zend_ext}" ]; then
        if echo "${Cur_PHP_Version}" | grep -Eqi '^(5\.[3-6]\.|7\.[01]\.)'; then
            echo 'extension = "libsodium.so"' >${PHP_Path}/conf.d/009-sodium.ini
        else
            echo 'extension = "sodium.so"' >${PHP_Path}/conf.d/009-sodium.ini
        fi
        Restart_PHP
        Echo_Green "====== PHP Sodium install completed ======"
        Echo_Green "PHP Sodium installed successfully, enjoy it!"
        exit 0
    else
        Echo_Red "PHP Sodium install failed!"
        exit 1
    fi
}

Uninstall_PHP_Sodium() {
    echo "You will uninstall PHP Sodium..."
    Press_Start
    rm -f ${PHP_Path}/conf.d/009-sodium.ini
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}sodium.so" "${zend_ext_dir}libsodium.so"
    Restart_PHP
    Echo_Green "Uninstall PHP Sodium completed."
}
