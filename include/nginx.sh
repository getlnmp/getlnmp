#!/usr/bin/env bash
Install_Nginx_Openssl() {
    Check_Openssl
    if [ "${isOpenSSL111}" = 'y' ]; then
        if [[ "${Nginx_Version}" =~ ^1\.(29|[3-5][0-9])\. ]]; then
            Custom_Openssl_Ver=${Openssl_35_Ver}
            Custom_Openssl_DL=${Openssl_35_DL}
        else
            Custom_Openssl_Ver=${Openssl_3_Ver}
            Custom_Openssl_DL=${Openssl_3_DL}
        fi  
        echo "System OpenSSL version is 1.1.1, compile nginx with custom OpenSSL version: ${Custom_Openssl_Ver}"
        cd ${cur_dir}/src
        Download_Files ${Custom_Openssl_DL} ${Custom_Openssl_Ver}.tar.gz
        rm -rf ${Custom_Openssl_Ver}
        tar zxf ${Custom_Openssl_Ver}.tar.gz
        Nginx_With_Openssl="--with-openssl=${cur_dir}/src/${Custom_Openssl_Ver}"
    else
        echo "Current system OpenSSL version is not 1.1.1, using system OpenSSL."
        Nginx_With_Openssl=""
    fi
}

Install_Nginx_Pcre() {
    if command -v pcre-config >/dev/null 2>&1; then
        echo "OS is using old PCRE, compile nginx with PCRE2"
        cd ${cur_dir}/src
        Download_Files ${Pcre2_DL} ${Pcre2_Ver}.tar.bz2
        rm -rf ${Pcre2_Ver}
        tar jxf ${Pcre2_Ver}.tar.bz2
        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre2_Ver} --with-pcre-jit"
    elif command -v pcre2-config >/dev/null 2>&1; then
        echo "OS is using PCRE2, use system PCRE2"
        Nginx_With_Pcre="--with-pcre-jit"
    else
        echo "OS has no PCRE installed, compile nginx with custom PCRE2"
        cd ${cur_dir}/src
        Download_Files ${Pcre2_DL} ${Pcre2_Ver}.tar.bz2
        rm -rf ${Pcre2_Ver}
        tar jxf ${Pcre2_Ver}.tar.bz2
        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre2_Ver} --with-pcre-jit"
    fi
}

# since 1.21.5, nginx support PCRE2 and configure script will look for PCRE2 first. It falls back to PCRE if no PCRE2 finds.
# for 1.21.4 and older: Only support PCRE
Install_Nginx_Pcre2() {
    if command -v pcre2-config >/dev/null 2>&1; then
        echo "OS is using PCRE2, use system PCRE2"
        Nginx_With_Pcre="--with-pcre-jit"
    else
        echo "OS has no PCRE2 installed, compile nginx with custom PCRE2"
        cd ${cur_dir}/src
        Download_Files ${Pcre2_DL} ${Pcre2_Ver}.tar.bz2
        rm -rf ${Pcre2_Ver}
        tar jxf ${Pcre2_Ver}.tar.bz2
        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre2_Ver} --with-pcre-jit"
    fi
}

Install_Nginx_Lua() {
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        echo "Installing Lua for Nginx..."
        cd ${cur_dir}/src
        #      Download_Files ${Luajit_DL} ${Luajit_Ver}.tar.gz
        git clone https://luajit.org/git/luajit.git
        Download_O_Files ${LuaNginxModule_DL} ${LuaNginxModule}.tar.gz
        Download_O_Files ${NgxDevelKit_DL} ${NgxDevelKit}.tar.gz
        Download_O_Files ${LuaRestyCore_DL} ${LuaRestyCore}.tar.gz
        Download_O_Files ${LuaRestyLrucache_DL} ${LuaRestyLrucache}.tar.gz

        Echo_Blue "[+] Installing Luajit... "
        tar zxf ${LuaNginxModule}.tar.gz
        tar zxf ${NgxDevelKit}.tar.gz
        cd luajit
        make
        make install PREFIX=/usr/local/luajit
        cd ${cur_dir}/src

        cat >/etc/ld.so.conf.d/luajit.conf <<EOF
/usr/local/luajit/lib
EOF
        if [ "${Is_64bit}" = "y" ]; then
            ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2 /lib64/libluajit-5.1.so.2
        else
            ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2 /usr/lib/libluajit-5.1.so.2
        fi
        ldconfig

        cat >/etc/profile.d/luajit.sh <<EOF
export LUAJIT_LIB=/usr/local/luajit/lib
export LUAJIT_INC=/usr/local/luajit/include/luajit-2.1
EOF

        source /etc/profile.d/luajit.sh

        Tar_Cd ${LuaRestyCore}.tar.gz ${LuaRestyCore}
        make install PREFIX=/usr/local/nginx
        cd -
        Tar_Cd ${LuaRestyLrucache}.tar.gz ${LuaRestyLrucache}
        make install PREFIX=/usr/local/nginx
        cd -

        Nginx_Module_Lua="--with-ld-opt='-Wl,-rpath,/usr/local/luajit/lib' --add-module=${cur_dir}/src/${LuaNginxModule} --add-module=${cur_dir}/src/${NgxDevelKit}"
    else
        Nginx_Module_Lua=""
    fi
}

Install_Ngx_FancyIndex() {
    if [ "${Enable_Ngx_FancyIndex}" = 'y' ]; then
        echo "Installing Ngx FancyIndex for Nginx..."
        cd ${cur_dir}/src
        Download_Files ${NgxFancyIndex_DL} ${NgxFancyIndex_Ver}.tar.xz
        Tar_Cd ${NgxFancyIndex_Ver}.tar.xz
        Ngx_FancyIndex="--add-module=${cur_dir}/src/${NgxFancyIndex_Ver}"
    else
        Ngx_FancyIndex=""
    fi
}

Install_Nginx() {
    Echo_Blue "[+] Installing ${Nginx_Ver}... "
    groupadd www
    useradd -s /sbin/nologin -g www www

    Nginx_Version="${Nginx_Ver#nginx-}"

    cd ${cur_dir}/src
    Install_Nginx_Openssl
    Install_Nginx_Pcre2
    Install_Nginx_Lua
    Install_Ngx_FancyIndex
    rm -rf ${Nginx_Ver}
    Tar_Cd ${Nginx_Ver}.tar.gz ${Nginx_Ver}
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.14.2 ${Nginx_Version})
    if gcc -dumpversion | grep -q "^[8]" && [ "${Nginx_Ver_Com}" == "1" ]; then
        patch -p1 <${cur_dir}/src/patch/nginx-gcc8.patch
    fi
    echo "Starting configure nginx..."
    ./configure \
        --user=www \
        --group=www \
        --prefix=/usr/local/nginx \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_sub_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        ${Nginx_With_Openssl} \
        ${Nginx_With_Pcre} \
        ${Nginx_Module_Lua} \
        ${NginxMAOpt} \
        ${Ngx_FancyIndex} \
        ${Nginx_Modules_Options} \
        --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie' \
        --with-cc-opt="-O2 -g -fstack-protector-strong -Wp,-D_FORTIFY_SOURCE=2 -fPIC"

    Make_Install
    cd ../

    ln -sf /usr/local/nginx/sbin/nginx /usr/bin/nginx

    rm -f /usr/local/nginx/conf/nginx.conf
    cd ${cur_dir}
    if [ "${Stack}" = "lnmpa" ]; then
        \cp conf/nginx_a.conf /usr/local/nginx/conf/nginx.conf
        \cp conf/proxy.conf /usr/local/nginx/conf/proxy.conf
        \cp conf/proxy-pass-php.conf /usr/local/nginx/conf/proxy-pass-php.conf
    else
        \cp conf/nginx.conf /usr/local/nginx/conf/nginx.conf
    fi
    \cp -ra conf/rewrite /usr/local/nginx/conf/
    \cp conf/pathinfo.conf /usr/local/nginx/conf/pathinfo.conf
    \cp conf/enable-php.conf /usr/local/nginx/conf/enable-php.conf
    \cp conf/enable-php-pathinfo.conf /usr/local/nginx/conf/enable-php-pathinfo.conf
    \cp -ra conf/example /usr/local/nginx/conf/example
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        if ! grep -q 'lua_package_path "/usr/local/nginx/lib/lua/?.lua";' /usr/local/nginx/conf/nginx.conf; then
            sed -i "/server_tokens off;/i\        lua_package_path \"/usr/local/nginx/lib/lua/?.lua\";\n" /usr/local/nginx/conf/nginx.conf
        fi
        if [ "${Stack}" = "lnmp" ]; then
            sed -i "/include enable-php.conf;/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
        else
            sed -i "/include proxy-pass-php.conf;/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
        fi
    fi
    if [ "${isWSL}" = "y" ]; then
        sed -i "/gzip on;/i\        fastcgi_buffering off;\n" /usr/local/nginx/conf/nginx.conf
    fi

    mkdir -p ${Default_Website_Dir}
    chmod +w ${Default_Website_Dir}
    mkdir -p /home/wwwlogs
    chmod 777 /home/wwwlogs

    chown -R www:www ${Default_Website_Dir}

    mkdir /usr/local/nginx/conf/vhost

    if [ "${Default_Website_Dir}" != "/home/wwwroot/default" ]; then
        sed -i "s#/home/wwwroot/default#${Default_Website_Dir}#g" /usr/local/nginx/conf/nginx.conf
    fi

    if [ "${Stack}" = "lnmp" ]; then
        cat >${Default_Website_Dir}/.user.ini <<EOF
open_basedir=${Default_Website_Dir}:/tmp/:/proc/
EOF
        chmod 644 ${Default_Website_Dir}/.user.ini
        chattr +i ${Default_Website_Dir}/.user.ini
        cat >>/usr/local/nginx/conf/fastcgi.conf <<EOF
fastcgi_param PHP_ADMIN_VALUE "open_basedir=\$document_root/:/tmp/:/proc/";
EOF
    fi

    \cp init.d/nginx.service /etc/systemd/system/nginx.service
    systemctl daemon-reload

    if [ "${SelectMalloc}" = "3" ]; then
        mkdir /tmp/tcmalloc
        chown -R www:www /tmp/tcmalloc
        sed -i '/nginx.pid/a\
google_perftools_profiles /tmp/tcmalloc;' /usr/local/nginx/conf/nginx.conf
    fi

    if [ "${Stack}" != "lamp" ]; then
        uname_r=$(uname -r)
        if echo $uname_r | grep -Eq "^3\.(9|1[0-9])*|^[4-9]\.*"; then
            echo "3.9+"
            sed -i 's/listen 80 default_server;/listen 80 default_server reuseport;/g' /usr/local/nginx/conf/nginx.conf
        fi
    fi

    ## cleaning
    cd ${cur_dir}/src && rm -rf ${cur_dir}/src/${Nginx_Ver}
    [[ -d "${Custom_Openssl_Ver}" ]] && rm -rf ${Custom_Openssl_Ver}
    [[ -d "${Pcre2_Ver}" ]] &&rm -rf ${Pcre2_Ver}
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        rm -rf ${cur_dir}/src/luajit
        rm -rf ${LuaNginxModule}
        rm -rf ${NgxDevelKit}
        rm -rf ${LuaRestyCore}
        rm -rf ${LuaRestyLrucache}
    fi
    [[ -d "${NgxFancyIndex_Ver}" ]] && rm -rf ${NgxFancyIndex_Ver}

}
