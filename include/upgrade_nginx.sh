#!/usr/bin/env bash

Upgrade_Nginx() {
    Cur_Nginx_Version=$(/usr/local/nginx/sbin/nginx -v 2>&1 | cut -d '/' -f 2)

    if [ -s /usr/local/jemalloc/include/jemalloc/jemalloc.h ] && /usr/local/nginx/sbin/nginx -V 2>&1 | grep -Eqi 'ljemalloc'; then
        NginxMAOpt="--with-ld-opt='-ljemalloc'"
    elif [ -s /usr/local/tcmalloc/include/gperftools/tcmalloc.h ] && grep -Eqi "google_perftools_profiles" /usr/local/nginx/conf/nginx.conf; then
        NginxMAOpt='--with-google_perftools_module'
    else
        NginxMAOpt=""
    fi

    Nginx_Version=""
    echo "Current Nginx Version:${Cur_Nginx_Version}"
    echo "You can get version number from https://nginx.org/en/download.html"
    echo "Nginx version format must be like: 1.22.1, 1.23.3, 1.24.0, 1.28.1 etc"
    echo "Minor version (the middle number) must be 22 or higher."
    read -r -p "Please enter nginx version you want, (example: 1.28.1): " Nginx_Version
    if [ "${Nginx_Version}" = "" ]; then
        Echo_Red "Error: You must enter a nginx version!!"
        exit 1
    fi
    if ! [[ "${Nginx_Version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        Echo_Red "Error: enter a version like 1.28.1"
        exit 1
    fi
    Nginx_First_Digit="${Nginx_Version%%.*}"
    Nginx_Second_Digit="${Nginx_Version#*.}"
    Nginx_Second_Digit="${Nginx_Second_Digit%%.*}"
    if [[ "${Nginx_First_Digit}" -eq 1 ]] && [[ "${Nginx_Second_Digit}" -lt 22 ]]; then
        Echo_Red "Error: Nginx version must be 1.22.0 or higher and in correct format!!"
        exit 1
    fi
    echo "+---------------------------------------------------------+"
    echo "|    You will upgrade nginx version to ${Nginx_Version}   |"
    echo "|   YOU MAY NEED TO MODIFY YOUR NGINX.CONF AFTER UPGRADE  |"
    echo "+---------------------------------------------------------+"

    Press_Start

    echo "============================check files=================================="
    cd "${cur_dir}/src" || {
        Echo_Red "Error: cannot enter ${cur_dir}/src"
        exit 1
    }
    # Reuse the base URL (official site or mirror) that downloadlink.sh resolved for
    # Nginx_DL, but with the user-requested version, so the Use_Official/mirror toggle is honored.
    Download_Files_Exit "${Nginx_DL%/*}/nginx-${Nginx_Version}.tar.gz" "nginx-${Nginx_Version}.tar.gz"
    echo "============================check files=================================="

    Install_Nginx_Openssl
    Install_Nginx_Pcre2
    Install_Nginx_Lua
    Install_Ngx_FancyIndex
    rm -rf "nginx-${Nginx_Version}"
    Tar_Cd "nginx-${Nginx_Version}.tar.gz" "nginx-${Nginx_Version}"
    Get_Dist_Version
    # Nginx Version 1.14.2 is too old, therefore we dropped this patch.
    # Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.14.2 ${Nginx_Version})
    # if gcc -dumpversion | grep -q "^[78\.]" && [ "${Nginx_Ver_Com}" == "1" ]; then
    #     patch -p1 <${cur_dir}/src/patch/nginx-gcc8.patch
    # fi
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
        --with-cc-opt="-O2 -g -fstack-protector-strong -fPIC"
    # remove "-Wp,-D_FORTIFY_SOURCE=2" as modern gcc (like gcc15) will inject _FORTIFY_SOURCE=3 automatically
    #--with-cc-opt="-O2 -g -fstack-protector-strong -Wp,-D_FORTIFY_SOURCE=2 -fPIC"

    make -j"$(nproc)" || make || {
        Echo_Red "Error: Nginx build failed."
        exit 1
    }

    # unset LuaJIT environment variables to avoid potential conflicts with other software
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        unset LUAJIT_LIB
        unset LUAJIT_INC
    fi

    if [ ! -x objs/nginx ]; then
        Echo_Red "Error: new nginx binary was not built."
        exit 1
    fi

    # Move the old binary aside before installing the new one.
    # A running executable cannot be overwritten in place: the kernel returns ETXTBSY
    # ("Text file busy"), so an in-place "cp objs/nginx ..." silently fails and the old
    # binary stays on disk. Renaming it (the inode is kept alive by the running master)
    # frees the path for a fresh inode and doubles as the rollback backup. The later
    # USR2 live upgrade re-execs the new binary from this same path.
    old_nginx="/usr/local/nginx/sbin/nginx"
    backup_nginx="/usr/local/nginx/sbin/nginx.${Upgrade_Date}"
    mv "${old_nginx}" "${backup_nginx}" || {
        Echo_Red "Error: failed to move aside the old nginx binary."
        exit 1
    }

    # install the new binary and test it before upgrading
    \cp objs/nginx "${old_nginx}" || {
        Echo_Red "Error: failed to install new nginx binary, restoring backup."
        \cp "${backup_nginx}" "${old_nginx}"
        exit 1
    }
    echo "Test nginx configure file..."
    /usr/local/nginx/sbin/nginx -t || {
        Echo_Red "Error: New nginx binary failed to start, restoring backup."
        \cp "${backup_nginx}" "${old_nginx}"
        exit 1
    }

    nginx_pid_file="/usr/local/nginx/logs/nginx.pid"
    if [ -s "${nginx_pid_file}" ] && kill -0 "$(cat "${nginx_pid_file}")" 2>/dev/null; then
        # live upgrade nginx without downtime
        # Send USR2 to the running master: it renames its PID file to nginx.pid.oldbin
        # and spawns a new master from the new binary (which writes the new nginx.pid).
        echo "Performing live binary upgrade..."
        kill -USR2 "$(cat "${nginx_pid_file}")"
        # Wait for the new master's PID file to be written
        sleep 1
        if [ -s "${nginx_pid_file}.oldbin" ]; then
            # Gracefully retire the old workers, then the old master.
            kill -WINCH "$(cat "${nginx_pid_file}.oldbin")"
            kill -QUIT "$(cat "${nginx_pid_file}.oldbin")"
            # NOTE: a live USR2 upgrade replaces the master that systemd tracks
            # (Type=forking + PIDFile), so systemd's view can go stale. If you manage
            # nginx via systemctl, run "systemctl restart nginx" later to re-sync tracking.
            Echo_Yellow "Live upgrade done. If nginx is managed by systemd, run 'systemctl restart nginx' later to re-sync tracking."
        else
            Echo_Yellow "New master did not start (no nginx.pid.oldbin); old nginx is still serving on the previous binary. Investigate before retrying."
        fi
    else
        # nginx is not running: there is no master to signal, so start the new binary via systemd.
        echo "nginx is not running; starting the new binary via systemd..."
        systemctl start nginx
    fi

    #    echo "upgrade..."
    #    make upgrade || {
    #        Echo_Red "Error: nginx live upgrade failed, restoring backup."
    #        \cp "${backup_nginx}" "${old_nginx}" 2>/dev/null
    #        exit 1
    #    }

    # reload nginx to apply the new version
    #echo "Reloading nginx to apply the new version..."
    #/usr/local/nginx/sbin/nginx -s reload || {
    #    Echo_Red "Error: Failed to reload nginx, restoring backup."
    #    \cp "${backup_nginx}" "${old_nginx}" 2>/dev/null
    #    systemctl restart nginx
    #    exit 1
    #}

    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        if ! grep -q 'lua_package_path "/usr/local/nginx/lib/lua/?.lua";' /usr/local/nginx/conf/nginx.conf; then
            sed -i "/server_tokens off;/i\        lua_package_path \"/usr/local/nginx/lib/lua/?.lua\";\n" /usr/local/nginx/conf/nginx.conf
        fi
        if ! grep -q "content_by_lua 'ngx.say(\"hello world\")';" /usr/local/nginx/conf/nginx.conf; then
            if grep -q "include enable-php.conf;" /usr/local/nginx/conf/nginx.conf; then
                sed -i "/include enable-php.conf;/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
            elif grep -q "include proxy-pass-php.conf;" /usr/local/nginx/conf/nginx.conf; then
                sed -i "/include proxy-pass-php.conf;/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
            else
                Echo_Yellow "Could not find PHP include anchor for Lua test location. Skip adding /lua example."
            fi
        fi
    fi

    echo "Checking ..."
    # Note: nginx -v reports the on-disk binary version (always the new one after the cp above),
    # so also confirm a master is actually running to distinguish a real reload from a no-op.
    new_ver=$(/usr/local/nginx/sbin/nginx -v 2>&1 | cut -d '/' -f 2)
    if [ "${new_ver}" != "${Nginx_Version}" ]; then
        Echo_Red "Upgrade did not take effect: on-disk binary is ${new_ver}, expected ${Nginx_Version}."
    elif [ -s "${nginx_pid_file}" ] && kill -0 "$(cat "${nginx_pid_file}")" 2>/dev/null; then
        Echo_Green "Upgrade nginx to ${Nginx_Version} completed; nginx is running."
    else
        Echo_Yellow "nginx ${Nginx_Version} binary installed, but nginx does not appear to be running."
        Echo_Yellow "Start it with: systemctl start nginx"
    fi

    ## cleaning
    cd "${cur_dir}/src" && rm -rf "nginx-${Nginx_Version}" && rm -rf "nginx-${Nginx_Version}.tar.gz"
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
