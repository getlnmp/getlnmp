#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi

cur_dir=$(pwd)
Stack="$1"

GetLNMP_Ver='1.0'
backup_ts="$(date +%Y%m%d%H%M%S)"

. "${cur_dir}/include/main.sh"
if [ ! -s "${cur_dir}/lnmp.conf" ]; then
    Echo_Red "lnmp.conf missing or empty; cannot determine data dirs."
    exit 1
fi
. "${cur_dir}/lnmp.conf"

#shopt -s extglob

Check_DB
Get_Dist_Name

echo "+------------------------------------------------------------------------+"
echo "|             GetLNMP V${GetLNMP_Ver} for ${DISTRO} Linux Server            |"
echo "+------------------------------------------------------------------------+"
echo "|        A tool to auto-compile & install Nginx+MySQL+PHP on Linux       |"
echo "+------------------------------------------------------------------------+"
echo "|        For more information please visit https://www.getlnmp.com       |"
echo "+------------------------------------------------------------------------+"

# Removes add-on install prefixes that the stack uninstallers above don't
# cover (redis/memcached/imagemagick/luajit/openssl/icu/etc — see RISK_AREAS.md
# §3 and the install paths in redis.sh, memcached.sh, init.sh, nginx.sh,
# mysql.sh, mariadb.sh, pureftpd.sh). Every removal is presence-guarded so
# this is a safe no-op for prefixes that were never installed. Deliberately
# leaves the `www` user/group and any system config files (limits.conf,
# sysctl.conf, selinux/config, localtime, resolv.conf, hosts, fstab) alone --
# restoring those automatically is its own data-loss risk.
Uninstall_Extra_Prefixes()
{
    echo "Removing extra add-on install prefixes..."
    for d in /usr/local/redis /usr/local/memcached /usr/local/libmemcached /usr/local/imagemagick /usr/local/ioncube /usr/local/luajit /usr/local/openssl /usr/local/openssl1.1.1 /usr/local/openssl3 /usr/local/curl /usr/local/oldcurl /usr/local/nghttp2 /usr/local/imap-ssl /usr/local/mysql57_boost /usr/local/mysql80_boost /usr/local/pureftpd; do
        [ -d "${d}" ] && rm -rf "${d}"
    done
    for d in /usr/local/libzip-* /usr/local/icu*; do
        [ -d "${d}" ] && rm -rf "${d}"
    done

    for svc in redis memcached pureftpd; do
        if [ -s "/etc/systemd/system/${svc}.service" ]; then
            systemctl stop "${svc}"
            systemctl disable "${svc}"
            rm -f "/etc/systemd/system/${svc}.service"
        fi
    done

    rm -f /etc/ld.so.conf.d/openssl.conf /etc/ld.so.conf.d/openssl1.1.1.conf /etc/ld.so.conf.d/openssl3.conf /etc/ld.so.conf.d/mysql.conf /etc/ld.so.conf.d/mariadb.conf /etc/ld.so.conf.d/luajit.conf
    rm -f /etc/ld.so.conf.d/icu*.conf
    ldconfig

    for u in mysql mariadb memcached; do
        id -u "${u}" >/dev/null 2>&1 && userdel "${u}" 2>/dev/null
    done
    # www is intentionally left alone: admin webroot content under
    # ${Default_Website_Dir}/wwwroot may still depend on its ownership.

    systemctl daemon-reload
}

# Summarizes what the uninstall intentionally leaves behind, so the user
# doesn't have to guess after seeing "Uninstall completed."
Print_Preserved_Summary()
{
    echo "Preserved (not removed):"
    [ -n "${backup_dir}" ] && echo "  Database backup: ${backup_dir}"
    echo "  'www' user/group and any webroot content under ${Default_Website_Dir}/wwwroot"
    echo "  System config files (limits.conf, sysctl.conf, selinux/config, hosts, fstab, etc.)"
}

Stop_And_Clean_DB() {
    if [ "${DB_Name}" != "None" ]; then
        systemctl stop "${DB_Name}"
        systemctl disable "${DB_Name}"
        backup_dir="/root/databases_backup_${backup_ts}"
        local src
        [ "${DB_Name}" = "mysql" ] && src="${MySQL_Data_Dir}"
        [ "${DB_Name}" = "mariadb" ] && src="${MariaDB_Data_Dir}"
        if [ -d "${src}" ]; then
            mv "${src}" "${backup_dir}" || { Echo_Red "Backup mv failed"; exit 1; }
        fi
        rm -rf "/usr/local/${DB_Name}"
        rm -f /etc/my.cnf
        rm -f "/etc/systemd/system/${DB_Name}.service"
        [ "${DB_Name}" = "mysql" ] && rm -f /etc/systemd/system/mysqld.service
    fi
}

Uninstall_Acme() {
    if [ -s /usr/local/acme.sh/acme.sh ]; then
        /usr/local/acme.sh/acme.sh --uninstall
        rm -rf /usr/local/acme.sh
        # Defensive: drop any residual acme.sh cron entries (--uninstall normally handles this)
        if crontab -l 2>/dev/null | grep -q "/usr/local/acme.sh"; then
            crontab -l 2>/dev/null | grep -v "/usr/local/acme.sh" | crontab -
        fi
    fi
}

Uninstall_LNMP()
{
    echo "Stopping LNMP..."
    if [ -x /bin/lnmp ]; then
        lnmp kill 2>/dev/null
        lnmp stop 2>/dev/null
    fi

    systemctl disable nginx
    systemctl disable php-fpm
    Stop_And_Clean_DB
    echo "Deleting LNMP files..."
    rm -rf /usr/local/nginx
    rm -rf /usr/local/php

    Uninstall_Extra_Prefixes

    for mphp in /usr/local/php{5,7,8}.[0-9]; do
        mphp_ver="${mphp#/usr/local/php}"
        if [ -s /etc/systemd/system/php-fpm${mphp_ver}.service ]; then
            systemctl stop php-fpm${mphp_ver}
            systemctl disable php-fpm${mphp_ver}
            rm -f /etc/systemd/system/php-fpm${mphp_ver}.service
            systemctl daemon-reload
        fi
        if [ -d "${mphp}" ]; then
            rm -rf "${mphp}"
        fi
    done

    Uninstall_Acme

    rm -f /etc/systemd/system/nginx.service
    rm -f /etc/systemd/system/php-fpm.service
    rm -f /bin/lnmp
    rm -f /bin/lnmp-fw
    systemctl daemon-reload
    echo "LNMP Uninstall completed."
    Print_Preserved_Summary
}

Uninstall_LNMPA()
{
    echo "Stopping LNMPA..."
    if [ -x /bin/lnmpa ]; then
        lnmpa kill 2>/dev/null
        lnmpa stop 2>/dev/null
    fi
    
    systemctl disable nginx
    systemctl disable httpd
    Stop_And_Clean_DB
    echo "Deleting LNMPA files..."
    rm -rf /usr/local/nginx
    rm -rf /usr/local/php
    rm -rf /usr/local/apache

    Uninstall_Extra_Prefixes

    Uninstall_Acme

    rm -f /etc/systemd/system/nginx.service
    rm -f /etc/systemd/system/httpd.service
    rm -f /bin/lnmpa
    systemctl daemon-reload
    echo "LNMPA Uninstall completed."
    Print_Preserved_Summary
}

Uninstall_LAMP()
{
    echo "Stopping LAMP..."
    if [ -x /bin/lamp ]; then
        lamp kill 2>/dev/null
        lamp stop 2>/dev/null
    fi

    systemctl disable httpd
    Stop_And_Clean_DB
    echo "Deleting LAMP files..."
    rm -rf /usr/local/apache
    rm -rf /usr/local/php

    Uninstall_Extra_Prefixes

    Uninstall_Acme

    rm -f /etc/systemd/system/httpd.service
    rm -f /bin/lamp
    systemctl daemon-reload
    echo "LAMP Uninstall completed."
    Print_Preserved_Summary
}

main()
{
    Check_Stack
    echo "Current Stack: ${Get_Stack}"

    case "${Get_Stack}" in
        lnmp)  default_action=1 ;;
        lnmpa) default_action=2 ;;
        lamp)  default_action=3 ;;
        *)     default_action="" ;;
    esac

    action=""
    if [ -n "${Stack}" ]; then
        action="${Stack}"
        echo "Uninstalling '${Stack}' as requested on the command line."
    else
        echo "Enter 1 to uninstall LNMP"
        echo "Enter 2 to uninstall LNMPA"
        echo "Enter 3 to uninstall LAMP"
        if [ -n "${default_action}" ]; then
            read -r -p "(Press Enter to uninstall detected ${Get_Stack}, or input 1, 2 or 3): " action
            action="${action:-${default_action}}"
        else
            Echo_Yellow "Could not detect an installed LNMP/LNMPA/LAMP stack."
            read -r -p "(Please input 1, 2 or 3): " action
        fi
    fi

    case "$action" in
        1|[lL][nN][mM][pP])     chosen_stack="lnmp" ;;
        2|[lL][nN][mM][pP][aA]) chosen_stack="lnmpa" ;;
        3|[lL][aA][mM][pP])     chosen_stack="lamp" ;;
        *)                      chosen_stack="" ;;
    esac
    if [ -n "${chosen_stack}" ] && [ -n "${default_action}" ] && [ "${chosen_stack}" != "${Get_Stack}" ]; then
        Echo_Red "Detected stack is ${Get_Stack}, but you chose to uninstall ${chosen_stack}."
        Echo_Yellow "Running the wrong uninstaller can leave the real stack on disk and running."
        read -r -p "Type 'yes' to continue anyway, or anything else to abort: " confirm
        [ "${confirm}" = "yes" ] || { echo "Aborted."; exit 1; }
    fi

    case "${chosen_stack}" in
    lnmp)
        echo "You will uninstall LNMP"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        echo "/usr/local/nginx"
        [ "${DB_Name}" != "None" ] && echo "${MySQL_Dir}"
        echo "/usr/local/php"
        echo "/etc/systemd/system/nginx.service"
        [ "${DB_Name}" != "None" ] && echo "/etc/systemd/system/${DB_Name}.service"
        echo "/etc/systemd/system/php-fpm.service"
        echo "/etc/my.cnf"
        echo "/bin/lnmp"
        read -r -p "Type 'YES' to confirm uninstall (anything else aborts): " confirm
        if [ "${confirm}" != "YES" ]; then
            echo "Aborted."
            exit 0
        fi
        Uninstall_LNMP
    ;;
    lnmpa)
        echo "You will uninstall LNMPA"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        echo "/usr/local/nginx"
        [ "${DB_Name}" != "None" ] && echo "${MySQL_Dir}"
        echo "/usr/local/php"
        echo "/usr/local/apache"
        echo "/etc/systemd/system/nginx.service"
        [ "${DB_Name}" != "None" ] && echo "/etc/systemd/system/${DB_Name}.service"
        echo "/etc/systemd/system/httpd.service"
        echo "/etc/my.cnf"
        echo "/bin/lnmpa"
        read -r -p "Type 'YES' to confirm uninstall (anything else aborts): " confirm
        if [ "${confirm}" != "YES" ]; then
            echo "Aborted."
            exit 0
        fi
        Uninstall_LNMPA
    ;;
    lamp)
        echo "You will uninstall LAMP"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        echo "/usr/local/apache"
        [ "${DB_Name}" != "None" ] && echo "${MySQL_Dir}"
        echo "/etc/systemd/system/httpd.service"
        [ "${DB_Name}" != "None" ] && echo "/etc/systemd/system/${DB_Name}.service"
        echo "/usr/local/php"
        echo "/etc/my.cnf"
        echo "/bin/lamp"
        read -r -p "Type 'YES' to confirm uninstall (anything else aborts): " confirm
        if [ "${confirm}" != "YES" ]; then
            echo "Aborted."
            exit 0
        fi
        Uninstall_LAMP
    ;;
    *)
        Echo_Red "Invalid choice: ${action}"
        exit 1
    ;;
    esac
}
main "$@"
