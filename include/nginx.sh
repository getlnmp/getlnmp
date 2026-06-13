#!/usr/bin/env bash
# ngx_http_v3_module require the OpenSSL library version 1.1.1 or higher, and the OpenSSL library version 3.0.0 or higher is recommended for better performance and security. 
# http_v3_module's 0-RTT support requires the OpenSSL library version 3.5.1 or higher
# The OpenSSL library version 3.5.1 or higher is recommended to build nginx with QUIC support
# for best compability, if system openssl version is 1.1.1, compile nginx with openssl 3.5 if nginx version is 1.29 or higher, otherwise compile nginx with openssl 3.0
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
        echo "System uses OpenSSL 1.1.1, compile nginx with custom OpenSSL version: ${Custom_Openssl_Ver}"
        cd ${cur_dir}/src
        Download_Files_Exit ${Custom_Openssl_DL} ${Custom_Openssl_Ver}.tar.gz
        rm -rf ${Custom_Openssl_Ver}
        tar zxf ${Custom_Openssl_Ver}.tar.gz
        Nginx_With_Openssl="--with-openssl=${cur_dir}/src/${Custom_Openssl_Ver}"
    else
        echo "System uses OpenSSL 3.*, compile nginx with system OpenSSL."
        Nginx_With_Openssl=""
    fi
}

#Install_Nginx_Pcre() {
#    if command -v pcre-config >/dev/null 2>&1; then
#        echo "OS is using old PCRE, compile nginx with PCRE2"
#        cd ${cur_dir}/src
#        Download_Files_Exit ${Pcre2_DL} ${Pcre2_Ver}.tar.bz2
#        rm -rf ${Pcre2_Ver}
#        tar jxf ${Pcre2_Ver}.tar.bz2
#        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre2_Ver} --with-pcre-jit"
#    elif command -v pcre2-config >/dev/null 2>&1; then
#        echo "OS is using PCRE2, use system PCRE2"
#        Nginx_With_Pcre="--with-pcre-jit"
#    else
#        echo "OS has no PCRE installed, compile nginx with custom PCRE2"
#        cd ${cur_dir}/src
#        Download_Files_Exit ${Pcre2_DL} ${Pcre2_Ver}.tar.bz2
#        rm -rf ${Pcre2_Ver}
#        tar jxf ${Pcre2_Ver}.tar.bz2
#        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre2_Ver} --with-pcre-jit"
#    fi
#}

# since 1.21.5, nginx support PCRE2 and configure script will look for PCRE2 first. It falls back to PCRE if no PCRE2 finds.
# for 1.21.4 and older: Only support PCRE
Install_Nginx_Pcre2() {
    if command -v pcre2-config >/dev/null 2>&1; then
        echo "OS has PCRE2, use system PCRE2"
        Nginx_With_Pcre="--with-pcre-jit"
    else
        echo "OS has no PCRE2 installed, compile nginx with custom PCRE2"
        cd ${cur_dir}/src
        Download_Files_Exit ${Pcre2_DL} ${Pcre2_Ver}.tar.bz2
        rm -rf ${Pcre2_Ver}
        tar jxf ${Pcre2_Ver}.tar.bz2
        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre2_Ver} --with-pcre-jit"
    fi
}

Install_Nginx_Lua() {
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        echo "Installing Lua for Nginx..."
        cd ${cur_dir}/src
       
        # build and install LuaJIT if not already installed
        if [[ ! -d "/usr/local/luajit/lib/" ]] && [[ ! -f "/etc/ld.so.conf.d/luajit.conf" ]]; then
            Echo_Blue "[+] Installing Luajit... "
            cd ${cur_dir}/src
            rm -rf ${cur_dir}/src/luajit
            git clone --depth 1 --branch v2.1 https://luajit.org/git/luajit.git || {
                Echo_Red "Luajit download failed!"
                exit 1
            }
            cd luajit
            make -j"$(nproc)" || {
                Echo_Red "Luajit build failed!"
                exit 1
            }
            make install PREFIX=/usr/local/luajit || {
                Echo_Red "Luajit install failed!"
                exit 1
             }
            cd ${cur_dir}/src

            # add Luajit library path to ldconfig runtime linker
            cat >/etc/ld.so.conf.d/luajit.conf <<EOF
/usr/local/luajit/lib
EOF
            ldconfig
        else
            echo "LuaJIT is already installed, skipping LuaJIT installation."
        fi
        
        # build time environment variables for LuaJIT
        # LUAJIT_LIB for compile-time headers
        # LUAJIT_INC for compile-time linking
        # tells lua-nginx-mobule where to find LuaJIT's headers and libraries during the nginx build process
        export LUAJIT_LIB=/usr/local/luajit/lib
        export LUAJIT_INC=/usr/local/luajit/include/luajit-2.1
        
        cd ${cur_dir}/src
        # download and prepare lua-nginx-module and ngx_devel_kit
        Download_O_Files_Exit ${LuaNginxModule_DL} ${LuaNginxModule}.tar.gz
        Download_O_Files_Exit ${NgxDevelKit_DL} ${NgxDevelKit}.tar.gz
        Tar_Cd "${LuaNginxModule}.tar.gz" "${LuaNginxModule}" && cd "${cur_dir}/src"
        Tar_Cd "${NgxDevelKit}.tar.gz" "${NgxDevelKit}" && cd "${cur_dir}/src"

        # download Lua resty libraries
        Download_O_Files_Exit ${LuaRestyCore_DL} ${LuaRestyCore}.tar.gz
        Download_O_Files_Exit ${LuaRestyLrucache_DL} ${LuaRestyLrucache}.tar.gz

        Tar_Cd "${LuaRestyCore}.tar.gz" "${LuaRestyCore}"
        make install PREFIX=/usr/local/nginx || {
            Echo_Red "Error: LuaRestyCore build failed."
            exit 1
        }
        cd "${cur_dir}/src"
        Tar_Cd "${LuaRestyLrucache}.tar.gz" "${LuaRestyLrucache}"
        make install PREFIX=/usr/local/nginx || {
            Echo_Red "Error: LuaRestyLrucache build failed."
            exit 1
        }
        cd "${cur_dir}/src"

        Nginx_Module_Lua="--add-module=${cur_dir}/src/${LuaNginxModule} --add-module=${cur_dir}/src/${NgxDevelKit}"
    else
        Nginx_Module_Lua=""
    fi
}

Install_Ngx_FancyIndex() {
    if [ "${Enable_Ngx_FancyIndex}" = 'y' ]; then
        echo "Installing Ngx FancyIndex for Nginx..."
        cd ${cur_dir}/src
        Download_Files_Exit ${NgxFancyIndex_DL} ${NgxFancyIndex_Ver}.tar.xz
        Tar_Cd "${NgxFancyIndex_Ver}.tar.xz" "${NgxFancyIndex_Ver}"
        cd "${cur_dir}/src"
        Ngx_FancyIndex="--add-module=${cur_dir}/src/${NgxFancyIndex_Ver}"
    else
        Ngx_FancyIndex=""
    fi
}

Validate_Nginx_Modules_Options() {
    if [[ "${Nginx_Modules_Options}" =~ [^A-Za-z0-9_=,/.+\-[:space:]] ]]; then
        Echo_Red "Nginx_Modules_Options contains characters not allowed in configure flags. Please check lnmp.conf."
        exit 1
    fi
}

Install_Nginx() {
    Echo_Blue "[+] Installing ${Nginx_Ver}... "
    if ! getent group www >/dev/null 2>&1; then
        groupadd www
    fi
    if ! id www >/dev/null 2>&1; then
        useradd -s /sbin/nologin -g www www
    fi

    Nginx_Version="${Nginx_Ver#nginx-}"

    cd ${cur_dir}/src
    Install_Nginx_Openssl
    Install_Nginx_Pcre2
    Install_Nginx_Lua
    Install_Ngx_FancyIndex
    rm -rf ${Nginx_Ver}
    Tar_Cd ${Nginx_Ver}.tar.gz ${Nginx_Ver}
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.14.2 ${Nginx_Version})
    if gcc -dumpversion | grep -q "^[78\.]" && [ "${Nginx_Ver_Com}" == "1" ]; then
        patch -p1 <${cur_dir}/src/patch/nginx-gcc8.patch
    fi
    Validate_Nginx_Modules_Options
    NGINX_LD_OPT='-Wl,-z,relro -Wl,-z,now -pie'
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        NGINX_LD_OPT="${NGINX_LD_OPT} -Wl,-rpath,/usr/local/luajit/lib"
    fi
    case "${NginxMAOpt}" in
        *ljemalloc*)
            NGINX_LD_OPT="${NGINX_LD_OPT} -L/usr/local/jemalloc/lib -ljemalloc"
            NginxMAOpt=""
            ;;
        *google_perftools*)
            NGINX_LD_OPT="${NGINX_LD_OPT} -L/usr/local/tcmalloc/lib"
            ;;
    esac
    echo "Starting configure nginx..."
    # -fPIC for dynamic modules
    # code compiled with -fPIC is compeletely compatible with the -pie linker flag
    # and the -fPIC flag is required for some modules like ngx_http_v3_module which use OpenSSL APIs that require position-independent code.
    # stick with --with-ld-opt="-pie" and --with-cc-opt="-fPIC"
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
        --with-ld-opt="${NGINX_LD_OPT}" \
        --with-cc-opt="-O2 -g -fstack-protector-strong -Wp,-D_FORTIFY_SOURCE=2 -fPIC"

    Make_Install_Exit "Nginx"
    
    # unset LuaJIT environment variables to avoid potential conflicts with other software
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        unset LUAJIT_LIB
        unset LUAJIT_INC
    fi
    
    cd ${cur_dir}/src

    ln -sf /usr/local/nginx/sbin/nginx /usr/bin/nginx
    
    # fresh install, we don't need to back up any .conf files
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

    if [ ! -d "${Default_Website_Dir}" ]; then
        mkdir -p "${Default_Website_Dir}"
        chown -R www:www "${Default_Website_Dir}"
    fi
    chmod 755 "${Default_Website_Dir}"
    mkdir -p /home/wwwlogs && chmod 755 /home/wwwlogs

    mkdir -p /usr/local/nginx/conf/vhost

    if [ "${Default_Website_Dir}" != "/home/wwwroot/default" ]; then
        sed -i "s#/home/wwwroot/default#${Default_Website_Dir}#g" /usr/local/nginx/conf/nginx.conf
    fi

    if [ "${Stack}" = "lnmp" ]; then
        if [ ! -s /usr/local/nginx/conf/fastcgi.conf ] || ! grep -qF 'fastcgi_param PHP_ADMIN_VALUE "open_basedir=$document_root/:/tmp/";' /usr/local/nginx/conf/fastcgi.conf; then
            cat >>/usr/local/nginx/conf/fastcgi.conf <<EOF
fastcgi_param PHP_ADMIN_VALUE "open_basedir=\$document_root/:/tmp/";
EOF
        fi
    fi

    \cp init.d/nginx.service /etc/systemd/system/nginx.service
    systemctl daemon-reload

    if [ "${SelectMalloc}" = "3" ]; then
        mkdir -p /tmp/tcmalloc
        chown -R www:www /tmp/tcmalloc
        sed -i '/nginx.pid/a\
google_perftools_profiles /tmp/tcmalloc;' /usr/local/nginx/conf/nginx.conf
    fi

    if [ "${Stack}" != "lamp" ]; then
        KMAJ=$(uname -r | cut -d. -f1)
        KMIN=$(uname -r | cut -d. -f2 | cut -d- -f1)
        if [ "${KMAJ}" -gt 3 ] 2>/dev/null || { [ "${KMAJ}" -eq 3 ] && [ "${KMIN}" -ge 9 ] ; }; then
            sed -i 's/listen 80 default_server;/listen 80 default_server reuseport;/g' /usr/local/nginx/conf/nginx.conf
        fi
    fi

    ## cleaning
    cd ${cur_dir}/src && rm -rf ${cur_dir}/src/${Nginx_Ver}
    [[ -d "${Custom_Openssl_Ver}" ]] && rm -rf "${Custom_Openssl_Ver}"
    [[ -d "${Pcre2_Ver}" ]] && rm -rf "${Pcre2_Ver}"
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        rm -rf ${cur_dir}/src/luajit
        rm -rf ${cur_dir}/src/${LuaNginxModule}
        rm -rf ${cur_dir}/src/${NgxDevelKit}
        rm -rf ${cur_dir}/src/${LuaRestyCore}
        rm -rf ${cur_dir}/src/${LuaRestyLrucache}
    fi
    [[ -d "${NgxFancyIndex_Ver}" ]] && rm -rf "${NgxFancyIndex_Ver}"

}
