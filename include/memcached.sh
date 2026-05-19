#!/usr/bin/env bash

# there are three memcache concepts: memcached, php-memcache and php-memcached
# memcached is a high-performance, distributed memory object caching system, which is used to speed up dynamic web applications by alleviating database load. It is a server-side application that runs in the background and listens for requests from clients to store and retrieve data in memory.
# php-memcache(old) is a PHP extension that provides an interface to interact with the memcached server. It allows PHP applications to connect to the memcached server, store and retrieve data from it. It is a simple and efficient way to use memcached in PHP applications.
# php-memcached(new) is another PHP extension that provides an interface to interact with the memcached server. It is a more feature-rich extension compared to php-memcache, offering additional functionalities such as support for binary protocol, consistent hashing, and more
# for php 5.6, 7.0, 7.1, we prefer memcache
# for php 7.2 and above, we prefer memcached
# both php memcache extension and php memcached extension rely on memcached server.
Install_PHPMemcache()
{
    echo "Install memcache php extension..."
    cd ${cur_dir}/src
    if echo "${Cur_PHP_Version}" | grep -Eqi '^8.';then
        Download_Files ${PHP8Memcache_DL} ${PHP8Memcache_Ver}.tgz
        Tar_Cd ${PHP8Memcache_Ver}.tgz ${PHP8Memcache_Ver}
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^7.';then
        Download_Files ${PHP7Memcache_DL} ${PHP7Memcache_Ver}.tgz
        Tar_Cd ${PHP7Memcache_Ver}.tgz ${PHP7Memcache_Ver}
    else
        if ! gcc -dumpversion|grep -q "^[34]."; then
            export CFLAGS=" -fgnu89-inline"
        fi
        Download_Files ${PHPMemcache_DL} ${PHPMemcache_Ver}.tgz
        Tar_Cd ${PHPMemcache_Ver}.tgz ${PHPMemcache_Ver}
    fi
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config
    Make_Install
    cd ../
}

Install_PHPMemcached()
{
    echo "Install memcached php extension..."
    cd ${cur_dir}/src
    Get_Dist_Name
    if [ "$PM" = "yum" ]; then
        yum install cyrus-sasl-devel -y
        Get_Dist_Version
    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get install libsasl2-2 sasl2-bin libsasl2-2 libsasl2-dev libsasl2-modules -y
    fi
    Download_Files ${Libmemcached_DL}
    Tar_Cd ${Libmemcached_Ver}.tar.gz ${Libmemcached_Ver}
    if gcc -dumpversion|grep -Eq "^([7-9]|1[0-5])"; then
        patch -p1 < ${cur_dir}/src/patch/libmemcached-1.0.18-gcc7.patch
    fi
    ./configure --prefix=/usr/local/libmemcached --with-memcached
    Make_Install
    cd ../

    cd ${cur_dir}/src
    if echo "${Cur_PHP_Version}" | grep -Eqi '^8.';then
        [[ -d "${PHP8Memcached_Ver}" ]] && rm -rf "${PHP8Memcached_Ver}"
        Download_Files ${PHP8Memcached_DL} ${PHP8Memcached_Ver}.tgz
        Tar_Cd ${PHP8Memcached_Ver}.tgz ${PHP8Memcached_Ver}
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^7.';then
        [[ -d "${PHP7Memcached_Ver}" ]] && rm -rf "${PHP7Memcached_Ver}"
        Download_Files ${PHP7Memcached_DL} ${PHP7Memcached_Ver}.tgz
        Tar_Cd ${PHP7Memcached_Ver}.tgz ${PHP7Memcached_Ver}
    else
        [[ -d "${PHPMemcached_Ver}" ]] && rm -rf "${PHPMemcached_Ver}"
        Download_Files ${PHPMemcached_DL} ${PHPMemcached_Ver}.tgz
        Tar_Cd ${PHPMemcached_Ver}.tgz ${PHPMemcached_Ver}
    fi
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config --enable-memcached --with-libmemcached-dir=/usr/local/libmemcached
    Make_Install
    cd ../
}

Install_Memcached()
{
    ver="1"
    echo "Which memcached php extension do you choose:"
    echo "Install php-memcache, please enter: 1"
    echo "Install php-memcached, please enter: 2"
    read -r -p "Enter 1 or 2 (Default 1): " ver

    if [ "${ver}" = "1" ]; then
        echo "You choose php-memcache"
        PHP_ZTS="memcache.so"
    elif [ "${ver}" = "2" ]; then
        echo "You choose php-memcached"
        PHP_ZTS="memcached.so"
    else
        ver="1"
        echo "You choose php-memcache"
        PHP_ZTS="memcache.so"
    fi

    echo "====== Installing memcached ======"
    Press_Start

    rm -f ${PHP_Path}/conf.d/005-memcached.ini
    Addons_Get_PHP_Ext_Dir
    zend_ext=${zend_ext_dir}${PHP_ZTS}
    if [ -s "${zend_ext}" ]; then
        rm -f "${zend_ext}"
    fi

    cat >${PHP_Path}/conf.d/005-memcached.ini<<EOF
extension = ${PHP_ZTS}
EOF

    echo "Install memcached..."
    cd ${cur_dir}/src
    if [ -s /usr/local/memcached/bin/memcached ]; then
        echo "Memcached already exists."
    else
        # memcached should not run as root user, so we create a memcached user to run memcached
        useradd -r -s /usr/sbin/nologin -M memcached

        Download_Files ${Memcached_DL} ${Memcached_Ver}.tar.gz
        Tar_Cd ${Memcached_Ver}.tar.gz ${Memcached_Ver}
        ./configure --prefix=/usr/local/memcached
        make -j"$(nproc)"
        make install
        cd ../
        rm -rf ${cur_dir}/src/${Memcached_Ver}

        ln -sf /usr/local/memcached/bin/memcached /usr/bin/memcached

        \cp ${cur_dir}/init.d/memcached.service /etc/systemd/system/memcached.service
        systemctl daemon-reload
        systemctl enable --now memcached
        
    fi

    if [ "${ver}" = "1" ]; then
        Install_PHPMemcache
    elif [ "${ver}" = "2" ]; then
        Install_PHPMemcached
    fi

    echo "Copy Memcached PHP Test file..."
    \cp ${cur_dir}/conf/memcached${ver}.php ${Default_Website_Dir}/memcached.php

    Restart_PHP

    echo "Re-Starting Memcached..."
    systemctl restart memcached

    if [ -s "${zend_ext}" ] && [ -s /usr/local/memcached/bin/memcached ]; then
        Echo_Green "====== Memcached install completed ======"
        Echo_Green "Memcached installed successfully, enjoy it!"
    else
        rm -f ${PHP_Path}/conf.d/005-memcached.ini
        Echo_Red "Memcached install failed!"
    fi
}

Uninstall_Memcached()
{
    echo "You will uninstall Memcached..."
    Press_Start
    rm -f ${PHP_Path}/conf.d/005-memcached.ini
    Restart_PHP
    systemctl disable memcached
    echo "Delete Memcached files..."
    rm -rf /usr/local/libmemcached
    rm -rf /usr/local/memcached
    rm -rf /etc/systemd/system/memcached.service
    rm -rf /usr/bin/memcached
    systemctl daemon-reload
    Echo_Green "Uninstall Memcached completed."
}
