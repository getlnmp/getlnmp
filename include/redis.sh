#!/usr/bin/env bash
# https://redis.io/docs/latest/operate/oss_and_stack/install/build-stack/debian-bookworm/
# https://redis.io/docs/latest/operate/oss_and_stack/install/build-stack/ubuntu-noble/
Compile_Redis() {
    Get_OS_Bit
    if [ "${Is_ARM}" = "y" ]; then
            sed -i 's/FINAL_LIBS=-lm/FINAL_LIBS=-lm -latomic/' src/Makefile
    fi
    # cd "${cur_dir}/src/${Redis_Stable_Ver}" || return
    # Export the recommended build environment variables
    export BUILD_TLS=yes BUILD_WITH_MODULES=yes INSTALL_RUST_TOOLCHAIN=yes DISABLE_WERRORS=yes
    
    # Compile Redis using all available CPU cores (-j "$(nproc)")
    make -j"$(nproc)" all
    #make test || echo " Redis Tests failed, continuing..."

    # Unset environment variables to avoid leakage
    unset BUILD_TLS BUILD_WITH_MODULES INSTALL_RUST_TOOLCHAIN DISABLE_WERRORS
}


Install_Redis()
{
    echo "====== Installing Redis ======"
    echo "Install ${Redis_Stable_Ver} Stable Version..."
    Press_Start

    rm -f ${PHP_Path}/conf.d/007-redis.ini
    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}redis.so"
    if [ -s "${zend_ext}" ]; then
        rm -f "${zend_ext}"
    fi

    cd ${cur_dir}/src
    if [ -s /usr/local/redis/bin/redis-server ]; then
        echo "Redis server already exists."
    else
        if gcc -dumpversion|grep -q "^[34]."; then
            Redis_Stable_Ver='redis-5.0.9'
        fi
        Download_Files https://download.redis.io/releases/${Redis_Stable_Ver}.tar.gz ${Redis_Stable_Ver}.tar.gz
        Tar_Cd ${Redis_Stable_Ver}.tar.gz ${Redis_Stable_Ver}

        # compile redis
        Compile_Redis
        # Use the PREFIX variable to specify the custom installation path
        # This tells 'make install' where to place the binaries and script files
        make PREFIX=/usr/local/redis install
        
        #if [[ "${Is_64bit}" = "y" || "${Is_ARM}" = "y" ]]; then
        #    make PREFIX=/usr/local/redis install
        #else
        #    make CFLAGS="-march=i686" PREFIX=/usr/local/redis install
        #fi

        mkdir -p /usr/local/redis/etc/
        \cp redis.conf  /usr/local/redis/etc/
        #sed -i 's/daemonize no/daemonize yes/g' /usr/local/redis/etc/redis.conf
        if ! grep -Eqi '^bind[[:space:]]*127.0.0.1' /usr/local/redis/etc/redis.conf; then
            sed -i 's/^# bind 127.0.0.1/bind 127.0.0.1/g' /usr/local/redis/etc/redis.conf
        fi
        sed -i 's/^# supervised auto/supervised auto/' /usr/local/redis/etc/redis.conf
        sed -i 's#^pidfile /var/run/redis_6379.pid#pidfile /var/run/redis.pid#g' /usr/local/redis/etc/redis.conf
        cd ../
        rm -rf ${cur_dir}/src/${Redis_Stable_Ver}

    fi

    if [ -s ${PHPRedis_Ver} ]; then
        rm -rf ${PHPRedis_Ver}
    fi

    if echo "${Cur_PHP_Version}" | grep -Eqi '^5\.2\.';then
        Download_Files https://pecl.php.net/get/redis-2.2.7.tgz redis-2.2.7.tgz
        Tar_Cd redis-2.2.7.tgz redis-2.2.7
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^5\.[3456].';then
        Download_Files https://pecl.php.net/get/redis-4.3.0.tgz redis-4.3.0.tgz
        Tar_Cd redis-4.3.0.tgz redis-4.3.0
    elif echo "${Cur_PHP_Version}" | grep -Eqi '^7\.[0123].';then
        Download_Files https://pecl.php.net/get/redis-5.3.7.tgz redis-5.3.7.tgz
        Tar_Cd redis-5.3.7.tgz redis-5.3.7
    else
        Download_Files https://pecl.php.net/get/${PHPRedis_Ver}.tgz ${PHPRedis_Ver}.tgz
        Tar_Cd ${PHPRedis_Ver}.tgz ${PHPRedis_Ver}
    fi
    ${PHP_Path}/bin/phpize
    ./configure --with-php-config=${PHP_Path}/bin/php-config
    Make_Install
    cd ../

    cat >${PHP_Path}/conf.d/007-redis.ini<<EOF
extension = "redis.so"
EOF

    #\cp ${cur_dir}/init.d/init.d.redis /etc/init.d/redis
    \cp ${cur_dir}/init.d/redis.service /etc/systemd/system/redis.service
    #chmod +x /etc/init.d/redis
    echo "Add to auto startup..."
    systemctl enable redis
    Restart_PHP
    systemctl start redis

    echo "Copy Redis PHP Test file..."
    \cp ${cur_dir}/conf/redis.php ${Default_Website_Dir}/redis.php

    if [ -s "${zend_ext}" ] && [ -s /usr/local/redis/bin/redis-server ]; then
        Echo_Green "====== Redis install completed ======"
        Echo_Green "Redis installed successfully, enjoy it!"
    else
        rm -f ${PHP_Path}/conf.d/007-redis.ini
        Echo_Red "Redis install failed!"
    fi
}

Uninstall_Redis()
{
    echo "You will uninstall Redis..."
    Press_Start
    systemctl stop redis
    systemctl disable redis
    rm -f ${Default_Website_Dir}/redis.php
    rm -f "${PHP_Path}"/conf.d/007-redis.ini
    Restart_PHP
    echo "Delete Redis files..."
    rm -rf /usr/local/redis
    rm -rf /etc/systemd/system/redis.service
    systemctl daemon-reload
    Echo_Green "Uninstall Redis completed."
}
