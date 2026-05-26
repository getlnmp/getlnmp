#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi

cur_dir=$(pwd)
Stack=$1

GetLNMP_Ver='1.0'

. lnmp.conf
. include/main.sh

shopt -s extglob

Check_DB
Get_Dist_Name

clear
echo "+------------------------------------------------------------------------+"
echo "|             GetLNMP V${GetLNMP_Ver} for ${DISTRO} Linux Server            |"
echo "+------------------------------------------------------------------------+"
echo "|        A tool to auto-compile & install Nginx+MySQL+PHP on Linux       |"
echo "+------------------------------------------------------------------------+"
echo "|        For more information please visit https://www.getlnmp.com       |"
echo "+------------------------------------------------------------------------+"

Sleep_Sec()
{
    seconds=$1
    while [ "${seconds}" -ge "0" ];do
      echo -ne "\r     \r"
      echo -n ${seconds}
      seconds=$(($seconds - 1))
      sleep 1
    done
    echo -ne "\r"
}

Uninstall_LNMP()
{
    echo "Stopping LNMP..."
    lnmp kill
    lnmp stop

    systemctl disable nginx
    systemctl disable php-fpm
    if [ ${DB_Name} != "None" ]; then
        systemctl disable ${DB_Name}
        echo "Backup ${DB_Name} databases directory to /root/databases_backup_$(date +"%Y%m%d%H%M%S")"
        if [ ${DB_Name} == "mysql" ]; then
            mv ${MySQL_Data_Dir} /root/databases_backup_$(date +"%Y%m%d%H%M%S")
        elif [ ${DB_Name} == "mariadb" ]; then
            mv ${MariaDB_Data_Dir} /root/databases_backup_$(date +"%Y%m%d%H%M%S")
        fi
    fi
    echo "Deleting LNMP files..."
    rm -rf /usr/local/nginx
    rm -rf /usr/local/php
    rm -rf /usr/local/zend

    if [ ${DB_Name} != "None" ]; then
        rm -rf /usr/local/${DB_Name}
        rm -f /etc/my.cnf
        rm -f /etc/systemd/system/${DB_Name}.service
    fi

    for mphp in /usr/local/php[5,7].[0-9]; do
        mphp_ver=$(echo $mphp|sed 's#/usr/local/php##')
        if [ -s /etc/systemd/system/php-fpm${mphp_ver}.service ]; then
            systemctl stop php-fpm${mphp_ver}
            systemctl disable php-fpm${mphp_ver}
            rm -f /etc/systemd/system/php-fpm${mphp_ver}.service
            systemctl daemon-reload
        fi
        if [ -d ${mphp} ]; then
            rm -rf ${mphp}
        fi
    done

    if [ -s /usr/local/acme.sh/acme.sh ]; then
        /usr/local/acme.sh/acme.sh --uninstall
        rm -rf /usr/local/acme.sh
        if crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh"; then
            crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh" | crontab -
        fi
    fi

    rm -f /etc/systemd/system/nginx.service
    rm -f /etc/systemd/system/php-fpm.service
    rm -f /bin/lnmp
    echo "LNMP Uninstall completed."
}

Uninstall_LNMPA()
{
    echo "Stopping LNMPA..."
    lnmp kill
    lnmp stop
    
    Remove_StartUp nginx
    Remove_StartUp httpd
    if [ ${DB_Name} != "None" ]; then
        Remove_StartUp ${DB_Name}
        echo "Backup ${DB_Name} databases directory to /root/databases_backup_$(date +"%Y%m%d%H%M%S")"
        if [ ${DB_Name} == "mysql" ]; then
            mv ${MySQL_Data_Dir} /root/databases_backup_$(date +"%Y%m%d%H%M%S")
        elif [ ${DB_Name} == "mariadb" ]; then
            mv ${MariaDB_Data_Dir} /root/databases_backup_$(date +"%Y%m%d%H%M%S")
        fi
    fi
    echo "Deleting LNMPA files..."
    rm -rf /usr/local/nginx
    rm -rf /usr/local/php
    rm -rf /usr/local/apache
    rm -rf /usr/local/zend

    if [ ${DB_Name} != "None" ]; then
        rm -rf /usr/local/${DB_Name}
        rm -f /etc/my.cnf
        rm -f /etc/systemd/system/${DB_Name}.service
    fi

    if [ -s /usr/local/acme.sh/acme.sh ]; then
        /usr/local/acme.sh/acme.sh --uninstall
        rm -rf /usr/local/acme.sh
        if crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh"; then
            crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh" | crontab -
        fi
    fi

    rm -f /etc/systemd/system/nginx.service
    rm -f /etc/systemd/system/httpd.service
    rm -f /bin/lnmp
    echo "LNMPA Uninstall completed."
}

Uninstall_LAMP()
{
    echo "Stopping LAMP..."
    lnmp kill
    lnmp stop

    Remove_StartUp httpd
    if [ ${DB_Name} != "None" ]; then
        Remove_StartUp ${DB_Name}
        echo "Backup ${DB_Name} databases directory to /root/databases_backup_$(date +"%Y%m%d%H%M%S")"
        if [ ${DB_Name} == "mysql" ]; then
            mv ${MySQL_Data_Dir} /root/databases_backup_$(date +"%Y%m%d%H%M%S")
        elif [ ${DB_Name} == "mariadb" ]; then
            mv ${MariaDB_Data_Dir} /root/databases_backup_$(date +"%Y%m%d%H%M%S")
        fi
    fi
    echo "Deleting LAMP files..."
    rm -rf /usr/local/apache
    rm -rf /usr/local/php
    rm -rf /usr/local/zend

    if [ ${DB_Name} != "None" ]; then
        rm -rf /usr/local/${DB_Name}
        rm -f /etc/my.cnf
        rm -f /etc/systemd/system/${DB_Name}.service
    fi

    if [ -s /usr/local/acme.sh/acme.sh ]; then
        /usr/local/acme.sh/acme.sh --uninstall
        rm -rf /usr/local/acme.sh
        if crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh"; then
            crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh" | crontab -
        fi
    fi

    rm -f /etc/my.cnf
    rm -f /etc/systemd/system/httpd.service
    rm -f /bin/lnmp
    echo "LAMP Uninstall completed."
}

    Check_Stack
    echo "Current Stack: ${Get_Stack}"

    action=""
    echo "Enter 1 to uninstall LNMP"
    echo "Enter 2 to uninstall LNMPA"
    echo "Enter 3 to uninstall LAMP"
    read -p "(Please input 1, 2 or 3): " action

    case "$action" in
    1|[lL][nN][nM][pP])
        echo "You will uninstall LNMP"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        cat << EOF
/usr/local/nginx
${MySQL_Dir}
/usr/local/php
/etc/systemd/system/nginx.service
/etc/systemd/system/${DB_Name}.service
/etc/systemd/system/php-fpm.service
/usr/local/zend
/etc/my.cnf
/bin/lnmp
EOF
        Sleep_Sec 3
        Press_Start
        Uninstall_LNMP
    ;;
    2|[lL][nN][nM][pP][aA])
        echo "You will uninstall LNMPA"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        cat << EOF
/usr/local/nginx
${MySQL_Dir}
/usr/local/php
/usr/local/apache
/etc/systemd/system/nginx.service
/etc/systemd/system/${DB_Name}.service
/etc/systemd/system/httpd.service
/usr/local/zend
/etc/my.cnf
/bin/lnmp
EOF
        Sleep_Sec 3
        Press_Start
        Uninstall_LNMPA
    ;;
    3|[lL][aA][nM][pP])
        echo "You will uninstall LAMP"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        cat << EOF
/usr/local/apache
${MySQL_Dir}
/etc/systemd/system/httpd.service
/etc/systemd/system/${DB_Name}.service
/usr/local/php
/usr/local/zend
/etc/my.cnf
/bin/lnmp
EOF
        Sleep_Sec 3
        Press_Start
        Uninstall_LAMP
    ;;
    esac
