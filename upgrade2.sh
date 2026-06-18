#!/usr/bin/env bash
#
# Upgrade script for LNMP V2.1
# A tool to upgrade Nginx, MySQL/MariaDB, PHP for LNMP/LNMPA/LAMP
# For more information please visit https://getlnmp.com
#
# Structure:
#   1. Environment setup        (PATH, root check, globals)
#   2. Source dependencies      (include/*.sh)
#   3. Detect system            (dist name/version, memory)
#   4. UI helpers               (banner, menu)
#   5. Dispatcher               (map action -> upgrade function)
#   6. main                     (entrypoint)

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# ----------------------------------------------------------------------------
# 1. Environment setup
# ----------------------------------------------------------------------------
Setup_Environment() {
    # Check if user is root
    if [ "$(id -u)" != "0" ]; then
        echo "Error: You must be root to run this script"
        exit 1
    fi

    cur_dir=$(pwd)
    shopt -s extglob
    Upgrade_Date=$(date +"%Y%m%d%H%M%S")
}

# ----------------------------------------------------------------------------
# 2. Source dependencies
# ----------------------------------------------------------------------------
Load_Includes() {
    . lnmp.conf
    . include/version.sh
    . include/downloadlink.sh
    . include/main.sh
    . include/init.sh
    . include/php.sh
    . include/multiplephp.sh
    . include/nginx.sh
    . include/mysql.sh
    . include/mariadb.sh
    . include/upgrade_nginx.sh
    . include/upgrade_php.sh
    . include/upgrade_mysql.sh
    . include/upgrade_mariadb.sh
    . include/upgrade_mysql2mariadb.sh
    . include/upgrade_phpmyadmin.sh
    . include/upgrade_mphp.sh
}

# ----------------------------------------------------------------------------
# 3. Detect system
# ----------------------------------------------------------------------------
Detect_System() {
    Get_Dist_Name
    Get_Dist_Version
    MemTotal=$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
}

# ----------------------------------------------------------------------------
# 4. UI helpers
# ----------------------------------------------------------------------------
Display_Banner() {
    clear
    echo "+-----------------------------------------------------------------------+"
    echo "|            Upgrade script for LNMP V2.1, Written by Licess            |"
    echo "+-----------------------------------------------------------------------+"
    echo "|     A tool to upgrade Nginx,MySQL/Mariadb,PHP for LNMP/LNMPA/LAMP     |"
    echo "+-----------------------------------------------------------------------+"
    echo "|           For more information please visit https://lnmp.org          |"
    echo "+-----------------------------------------------------------------------+"
}

Display_Upgrade_Menu() {
    echo "1: Upgrade Nginx"
    echo "2: Upgrade MySQL"
    echo "3: Upgrade MariaDB"
    echo "4: Upgrade PHP for LNMP"
    echo "5: Upgrade PHP for LNMPA or LAMP"
    echo "6: Upgrade MySQL to MariaDB"
    echo "7: Upgrade phpMyAdmin"
    echo "8: Upgrade Multiple PHP"
    echo "exit: Exit current script"
    echo "###################################################"
    read -r -p "Enter your choice (1, 2, 3, 4, 5, 6, 7 or exit): " action
}

# ----------------------------------------------------------------------------
# 5. Dispatcher
# ----------------------------------------------------------------------------
Run_Upgrade() {
    case "${action}" in
    1 | [nN][gG][iI][nN][xX])
        Upgrade_Nginx 2>&1 | tee /root/upgrade_nginx"${Upgrade_Date}".log
        ;;
    2 | [mM][yY][sS][qQ][lL])
        Upgrade_MySQL 2>&1 | tee /root/upgrade_mysql"${Upgrade_Date}".log
        ;;
    3 | [mM][aA][rR][iI][aA][dD][bB])
        Upgrade_MariaDB 2>&1 | tee /root/upgrade_mariadb"${Upgrade_Date}".log
        ;;
    4 | [pP][hP][pP])
        Stack="lnmp"
        Upgrade_PHP 2>&1 | tee /root/upgrade_lnmp_php"${Upgrade_Date}".log
        ;;
    5 | [pP][hP][pP][aA])
        Upgrade_PHP 2>&1 | tee /root/upgrade_a_php"${Upgrade_Date}".log
        ;;
    6 | [mM]2[mY])
        Upgrade_MySQL2MariaDB 2>&1 | tee /root/upgrade_mysql2mariadb"${Upgrade_Date}".log
        ;;
    7 | [pP][hH][pP][mM][yY][aA][dD][mM][iI][nN])
        Upgrade_phpMyAdmin 2>&1 | tee /root/upgrade_phpmyadmin"${Upgrade_Date}".log
        ;;
    8 | [mM][pP][hH][pP])
        Upgrade_Multiplephp 2>&1 | tee /root/upgrade_mphp"${Upgrade_Date}".log
        ;;
    [eE][xX][iI][tT])
        exit 1
        ;;
    *)
        echo "Usage: ./upgrade2.sh {nginx|mysql|mariadb|m2m|php|phpa|phpmyadmin}"
        exit 1
        ;;
    esac
}

# ----------------------------------------------------------------------------
# 6. main
# ----------------------------------------------------------------------------
main() {
    action=$1

    Setup_Environment
    Load_Includes
    Detect_System
    Display_Banner

    if [ "${action}" == "" ]; then
        Display_Upgrade_Menu
    fi

    Run_Upgrade
}

main "$@"
