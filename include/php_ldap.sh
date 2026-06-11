#!/usr/bin/env bash

Install_PHP_Ldap()
{
    cd ${cur_dir}/src
    echo "====== Installing PHP Ldap ======"
    Press_Start

    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}ldap.so"

    if ${PHP_Path}/bin/php -m | grep -qx ldap; then
        Echo_Yellow "PHP Module 'ldap' already loaded — nothing to do."
        exit 0
    fi

    if [ "$PM" = "yum" ]; then
        yum -y install openldap-devel cyrus-sasl-devel
    elif [ "$PM" = "apt" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y libldap2-dev libsasl2-dev
    fi

    Download_PHP_Src

    Tar_Cd php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}/ext/ldap
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config --with-ldap=/usr --with-ldap-sasl
    Make_Install_Exit "Ldap"
    cd "${cur_dir}/src"
    rm -rf php-"${Cur_PHP_Version}"

    if [ -s "${zend_ext}" ]; then
        cat >${PHP_Path}/conf.d/009-ldap.ini<<EOF
extension = "ldap.so"
EOF
        Restart_PHP
        Echo_Green "====== PHP Ldap install completed ======"
        Echo_Green "PHP Ldap installed successfully, enjoy it!"
        exit 0
    else
        Echo_Red "PHP Ldap install failed!"
        exit 1
    fi
}

Uninstall_PHP_Ldap()
{
    echo "You will uninstall PHP Ldap..."
    Press_Start
    rm -f ${PHP_Path}/conf.d/009-ldap.ini
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}ldap.so"
    Restart_PHP
    Echo_Green "Uninstall PHP Ldap completed."
}
