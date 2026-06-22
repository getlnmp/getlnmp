#!/usr/bin/env bash

# Apache 2.4 can be compiled with  openssl 1.1.1, openssl 3.0.x and openssl 3.5. For best performance, always use latest apache version and openssl 3.* version.
# If built with customized openssl, add "--with-ssl=/usr/local/openssl"
# When php is running as an apache module, apache's openssl version should match php's openssl version
# In this case for example, apache's mod_ssl loads opoenssl 3.5 while mod_php loads openssl 1.1.1 where will cause conflicts.
# when php is running as FastCGI(php-fpm), then apache's openssl version can be different with php's openssl version.
# In this case Apache simply passes the web requests over a network socket to PHP-FPM using mod_proxy_fcgi.
# Because the processes are walled off from each other, there are no library conflicts.

# For this apache installation, php is running as an apache module.
Install_Apache_24() {
    Echo_Blue "[+] Installing ${Apache_Ver}..."
    if [ "${Stack}" = "lamp" ]; then
        getent group www >/dev/null || groupadd www
        id www >/dev/null 2>&1 || useradd -s /sbin/nologin -g www www
        mkdir -p ${Default_Website_Dir}
        chmod 755 ${Default_Website_Dir}
        mkdir -p /home/wwwlogs
        chmod 755 /home/wwwlogs
        chown -R www:www ${Default_Website_Dir}
        Install_Nghttp2
    fi
    # check if customized openssl is required
    # since the minimum openssl version of our support Linux distros is openssl 1.1.1, therefore we don't need to consider the handle of openssl 1.0.*
    if openssl version | grep -Eqi "OpenSSL 3.*"; then
        if echo "${PHPSelect}" | grep -Eqi "^(7|8|9|10|11)$" || echo "${php_version}" | grep -Eqi '^7\.[1-4]\.*|^8\.0\.*' || echo "${Php_Ver}" | grep -Eqi "php-7\.[1-4]\.*|php-8\.0\.*"; then
            Install_Openssl_New
        fi
    fi
    Tar_Cd "${Apache_Ver}".tar.bz2 "${Apache_Ver}"
    cd srclib
    if [ -s "${cur_dir}/src/${APR_Ver}.tar.bz2" ]; then
        echo "${APR_Ver}.tar.bz2 [found]"
        cp ${cur_dir}/src/${APR_Ver}.tar.bz2 .
    else
        Download_Files ${APR_DL} ${APR_Ver}.tar.bz2
    fi
    if [ -s "${cur_dir}/src/${APR_Util_Ver}.tar.bz2" ]; then
        echo "${APR_Util_Ver}.tar.bz2 [found]"
        cp ${cur_dir}/src/${APR_Util_Ver}.tar.bz2 .
    else
        Download_Files ${APR_Util_DL} ${APR_Util_Ver}.tar.bz2
    fi
    tar jxf ${APR_Ver}.tar.bz2
    tar jxf ${APR_Util_Ver}.tar.bz2
    mv ${APR_Ver} apr
    mv ${APR_Util_Ver} apr-util
    cd ..
    if [ "${Stack}" = "lamp" ]; then
        ./configure --prefix=/usr/local/apache --enable-mods-shared=most --enable-headers --enable-mime-magic --enable-proxy --enable-so --enable-rewrite --enable-ssl ${apache_with_ssl} --enable-deflate --with-pcre --with-included-apr --with-apr-util --enable-mpms-shared=all --enable-remoteip --enable-http2 --with-nghttp2=/usr/local/nghttp2
    else
        ./configure --prefix=/usr/local/apache --enable-mods-shared=most --enable-headers --enable-mime-magic --enable-proxy --enable-so --enable-rewrite --enable-ssl ${apache_with_ssl} --enable-deflate --with-pcre --with-included-apr --with-apr-util --enable-mpms-shared=all --enable-remoteip
    fi
    Make_Install_Exit "Apache 2.4"
    cd ${cur_dir}/src
    rm -rf ${cur_dir}/src/${Apache_Ver}

    mv /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak.$(date +%Y%m%d%H%M%S)
    if [ "${Stack}" = "lamp" ]; then
        \cp ${cur_dir}/conf/httpd24-lamp.conf /usr/local/apache/conf/httpd.conf
        \cp ${cur_dir}/conf/httpd-vhosts-lamp.conf /usr/local/apache/conf/extra/httpd-vhosts.conf
        \cp ${cur_dir}/conf/httpd24-ssl.conf /usr/local/apache/conf/extra/httpd-ssl.conf
        \cp ${cur_dir}/conf/example/enable-apache-ssl-vhost-example.conf /usr/local/apache/conf/enable-apache-ssl-vhost-example.conf
    elif [ "${Stack}" = "lnmpa" ]; then
        \cp ${cur_dir}/conf/httpd24-lnmpa.conf /usr/local/apache/conf/httpd.conf
        \cp ${cur_dir}/conf/httpd-vhosts-lnmpa.conf /usr/local/apache/conf/extra/httpd-vhosts.conf
    fi
    \cp ${cur_dir}/conf/httpd-default.conf /usr/local/apache/conf/extra/httpd-default.conf
    \cp ${cur_dir}/conf/mod_remoteip.conf /usr/local/apache/conf/extra/mod_remoteip.conf

    sed -i "s|ServerAdmin you@example.com|ServerAdmin ${ServerAdmin}|g" /usr/local/apache/conf/httpd.conf
    sed -i "s|webmaster@example.com|${ServerAdmin}|g" /usr/local/apache/conf/extra/httpd-vhosts.conf
    mkdir -p /usr/local/apache/conf/vhost

    sed -i 's/NameVirtualHost .*//g' /usr/local/apache/conf/extra/httpd-vhosts.conf
    if [ "${Default_Website_Dir}" != "/home/wwwroot/default" ]; then
        sed -i "s#/home/wwwroot/default#${Default_Website_Dir}#g" /usr/local/apache/conf/httpd.conf
        sed -i "s#/home/wwwroot/default#${Default_Website_Dir}#g" /usr/local/apache/conf/extra/httpd-vhosts.conf
    fi

    # apxs always appends the correct LoadModule line; strip the template's legacy php5_module unconditionally
    sed -i '/^LoadModule php5_module/d' /usr/local/apache/conf/httpd.conf

    \cp ${cur_dir}/init.d/httpd.service /etc/systemd/system/httpd.service
    systemctl daemon-reload
    systemctl enable --now httpd
}
