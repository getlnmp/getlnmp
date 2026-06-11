#!/usr/bin/env bash

Upgrade_phpMyAdmin()
{
    phpMyAdmin_Version=""
    echo "You can get version number from https://www.phpmyadmin.net/downloads/"
    read -r -p "Please enter phpMyAdmin version you want, (example: 5.2.3 ): " phpMyAdmin_Version
    if [ "${phpMyAdmin_Version}" = "" ]; then
        echo "Error: You must enter a phpMyAdmin version!!"
        exit 1
    fi
    echo "+------------------------------------------------------------------+"
    echo "|   You will upgrade phpMyAdmin version to ${phpMyAdmin_Version}"
    echo "+------------------------------------------------------------------+"

    Press_Start

    echo "============================check files=================================="
    cd ${cur_dir}/src || { 
        Echo_Red "Error: ${cur_dir}/src not found"
        exit 1
        }

    Download_Files_Exit https://files.phpmyadmin.net/phpMyAdmin/${phpMyAdmin_Version}/phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz

    echo "Verifying phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz checksum..."
    rm -f "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256"
    wget -q -O "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256" "https://files.phpmyadmin.net/phpMyAdmin/${phpMyAdmin_Version}/phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256"
    if [ $? -ne 0 ] || [ ! -s "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256" ]; then
        Echo_Red "Error! Unable to download sha256 checksum for phpMyAdmin ${phpMyAdmin_Version}, aborting."
        rm -f "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz" "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256"
        exit 1
    fi
    if ! sha256sum -c "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256"; then
        Echo_Red "Error! Checksum mismatch for phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz -- archive is corrupt or tampered with, removing it."
        rm -f "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz" "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256"
        exit 1
    fi
    Echo_Green "Checksum verified OK."
    rm -f "phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz.sha256"

    echo "============================check files=================================="
    echo "Backup old phpMyAdmin..."
    if [ -d "${Default_Website_Dir}/phpmyadmin" ]; then
        mkdir -p /home/wwwroot/backup
        # remove old backups and only keep the newest one
        rm -rf /home/wwwroot/backup/phpmyadmin*
        # backup the newest phpmyadmin version
        mv "${Default_Website_Dir}/phpmyadmin" "/home/wwwroot/backup/phpmyadmin${Upgrade_Date}" \
        || { Echo_Red "Backup of existing phpMyAdmin failed; aborting."; exit 1; }
        have_backup=1
    else
        Echo_Yellow "No existing phpMyAdmin found at ${Default_Website_Dir}/phpmyadmin; doing a fresh install."
        have_backup=0
    fi
    echo "Uncompress phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz ..."
    tar Jxf phpMyAdmin-${phpMyAdmin_Version}-all-languages.tar.xz || { 
        Echo_Red "extract failed"
        if [ "${have_backup}" = "1" ]; then
            mv "/home/wwwroot/backup/phpmyadmin${Upgrade_Date}" "${Default_Website_Dir}/phpmyadmin"
        fi
        exit 1
        }
    mv phpMyAdmin-${phpMyAdmin_Version}-all-languages ${Default_Website_Dir}/phpmyadmin
    old_cfg="/home/wwwroot/backup/phpmyadmin${Upgrade_Date}/config.inc.php"
    if [ -s "${old_cfg}" ]; then
        \cp "${old_cfg}" "${Default_Website_Dir}/phpmyadmin/config.inc.php"
    else
        Echo_Yellow "No previous config.inc.php found; installing default template."
        \cp "${cur_dir}/conf/config.inc.php" "${Default_Website_Dir}/phpmyadmin/config.inc.php"
        phpmyadmin_secret=$(openssl rand -hex 16)
        sed -i "s/GETLNMPCOM/${phpmyadmin_secret}/g" ${Default_Website_Dir}/phpmyadmin/config.inc.php
    fi
    mkdir -p ${Default_Website_Dir}/phpmyadmin/{upload,save}
    chmod 755 -R ${Default_Website_Dir}/phpmyadmin/
    chown www:www -R ${Default_Website_Dir}/phpmyadmin/
    chmod 640 ${Default_Website_Dir}/phpmyadmin/config.inc.php
    Echo_Green "======== upgrade phpMyAdmin completed ======"
}
