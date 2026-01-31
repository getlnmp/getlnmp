#!/usr/bin/env bash

Upgrade_Nginx()
{
    Cur_Nginx_Version=$(/usr/local/nginx/sbin/nginx -v 2>&1 | cut -c22-)

    if [ -s /usr/local/include/jemalloc/jemalloc.h ] && /usr/local/nginx/sbin/nginx -V 2>&1|grep -Eqi 'ljemalloc'; then
        NginxMAOpt="--with-ld-opt='-ljemalloc'"
    elif [ -s /usr/local/include/gperftools/tcmalloc.h ] && grep -Eqi "google_perftools_profiles" /usr/local/nginx/conf/nginx.conf; then
        NginxMAOpt='--with-google_perftools_module'
    else
        NginxMAOpt=""
    fi

    Nginx_Version=""
    echo "Current Nginx Version:${Cur_Nginx_Version}"
    echo "You can get version number from https://nginx.org/en/download.html"
    echo "Nginx version format must be like: 1.22.1, 1.23.3, 1.24.0, 1.28.1 etc"
    echo "Minor version (the middle number) must be 22 or higher."
    read -p "Please enter nginx version you want, (example: 1.28.1): " Nginx_Version
    if [ "${Nginx_Version}" = "" ]; then
        echo "Error: You must enter a nginx version!!"
        exit 1
    fi
    Nginx_Second_Digit="${Nginx_Version#*.}"
    Nginx_Second_Digit="${Nginx_Second_Digit%%.*}"
    if [ "${Nginx_Second_Digit}" -lt 22 ]; then
        echo "Error: Nginx version must be 1.22.0 or higher and in correct format!!"
        exit 1
    fi
    echo "+---------------------------------------------------------+"
    echo "|    You will upgrade nginx version to ${Nginx_Version}   |"
    echo "|   YOU MAY NEED TO MODIFY YOUR NGINX.CONF AFTER UPGRADE  |"  
    echo "+---------------------------------------------------------+"

    Press_Start

    echo "============================check files=================================="
    cd ${cur_dir}/src
    if [ -s nginx-${Nginx_Version}.tar.gz ]; then
        echo "nginx-${Nginx_Version}.tar.gz [found]"
    else
        echo "Notice: nginx-${Nginx_Version}.tar.gz not found!!!download now......"
        wget -c --progress=dot:giga https://nginx.org/download/nginx-${Nginx_Version}.tar.gz
        if [ $? -eq 0 ]; then
            echo "Download nginx-${Nginx_Version}.tar.gz successfully!"
        else
            echo "You enter Nginx Version was:"${Nginx_Version}
            Echo_Red "Error! You entered a wrong version number, please check!"
            sleep 5
            exit 1
        fi
    fi
    echo "============================check files=================================="

    Install_Nginx_Openssl
    Install_Nginx_Pcre2
    Install_Nginx_Lua
    Install_Ngx_FancyIndex
    rm -rf nginx-${Nginx_Version}
    Tar_Cd nginx-${Nginx_Version}.tar.gz nginx-${Nginx_Version}
    Get_Dist_Version
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.14.2 ${Nginx_Version})
    if gcc -dumpversion|grep -q "^[8]" && [ "${Nginx_Ver_Com}" == "1" ]; then
        patch -p1 < ${cur_dir}/src/patch/nginx-gcc8.patch
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
        
    make -j"$(nproc)"
    if [ $? -ne 0 ]; then
        make
    fi

    mv /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx.${Upgrade_Date}
    \cp objs/nginx /usr/local/nginx/sbin/nginx
    echo "Test nginx configure file..."
    /usr/local/nginx/sbin/nginx -t
    echo "upgrade..."
    make upgrade

    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        if ! grep -q 'lua_package_path "/usr/local/nginx/lib/lua/?.lua";' /usr/local/nginx/conf/nginx.conf; then
            sed -i "/server_tokens off;/i\        lua_package_path \"/usr/local/nginx/lib/lua/?.lua\";\n" /usr/local/nginx/conf/nginx.conf
        fi
        if ! grep -q "content_by_lua 'ngx.say(\"hello world\")';" /usr/local/nginx/conf/nginx.conf; then
            sed -i "/location \/nginx_status/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
        fi
    fi

    echo "Checking ..."
    if [[ -s /usr/local/nginx/conf/nginx.conf && -s /usr/local/nginx/sbin/nginx ]]; then
        echo "Program will display Nginx Version......"
        /usr/local/nginx/sbin/nginx -v
        Echo_Green "======== upgrade nginx completed ======"
    else
        Echo_Red "Error: Nginx upgrade failed."
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
