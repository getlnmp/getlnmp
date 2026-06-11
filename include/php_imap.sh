#!/usr/bin/env bash

Install_PHP_Imap()
{
    # X4: quote and error-check the cd
    cd "${cur_dir}/src" || { Echo_Red "Cannot enter ${cur_dir}/src"; exit 1; }
    echo "====== Installing PHP Imap ======"
    Press_Start

    # IM4: addons.sh bootstrap does not call Get_OS_Bit; derive ARCH if not set
    [ -z "${ARCH}" ] && ARCH=$(uname -m)

    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}imap.so"

    # X1: already-loaded is a no-op, not an error
    if ${PHP_Path}/bin/php -m | grep -qx imap; then
        Echo_Yellow "PHP Module 'imap' already loaded — nothing to do."
        exit 0
    fi

    if [ "$PM" = "yum" ]; then
        # Gate EPEL per distro — check only the package that applies to this host
        # (rpm -q pkg1 pkg2 exits 0 only if BOTH are installed, so don't combine them)
        if [ "${DISTRO}" = "Oracle" ]; then
            rpm -q oracle-epel-release >/dev/null 2>&1 || yum -y install oracle-epel-release
        else
            rpm -q epel-release >/dev/null 2>&1 || yum -y install epel-release
        fi
        yum -y install libc-client-devel krb5-devel uw-imap-devel

        # EL9/EL10: libc-client dropped from EPEL; fall back to Remi RPMs
        if echo "${RHEL_Version}" | grep -Eqi "^(9|10)" || \
           echo "${Alma_Version}" | grep -Eqi "^(9|10)" || \
           echo "${Rocky_Version}" | grep -Eqi "^(9|10)"; then
            if echo "${RHEL_Version}" | grep -Eqi "^10" || \
               echo "${Alma_Version}" | grep -Eqi "^10" || \
               echo "${Rocky_Version}" | grep -Eqi "^10"; then
                libc_client_rpm="libc-client-2007f-32.el10.remi.${ARCH}.rpm"
                uw_imap_devel_rpm="uw-imap-devel-2007f-32.el10.remi.${ARCH}.rpm"
                libc_client_DL="${libc_client_2007f_el10_DL}"
                uw_imap_devel_DL="${uw_imap_devel_2007f_el10_DL}"
            else
                libc_client_rpm="libc-client-2007f-30.el9.remi.${ARCH}.rpm"
                uw_imap_devel_rpm="uw-imap-devel-2007f-30.el9.remi.${ARCH}.rpm"
                libc_client_DL="${libc_client_2007f_el9_DL}"
                uw_imap_devel_DL="${uw_imap_devel_2007f_el9_DL}"
            fi
            if ! rpm -q libc-client >/dev/null 2>&1 || \
               ! rpm -q uw-imap-devel >/dev/null 2>&1; then
                if [ "${CheckMirror}" = "n" ]; then
                    rpm -Uvh "${cur_dir}/src/${libc_client_rpm}" \
                             "${cur_dir}/src/${uw_imap_devel_rpm}" || {
                        Echo_Red "Failed to install libc-client RPMs from local src/."
                        exit 1
                    }
                else
                    rpm -Uvh "${libc_client_DL}" || {
                        Echo_Red "Failed to download/install libc-client RPM."
                        exit 1
                    }
                    rpm -Uvh "${uw_imap_devel_DL}" || {
                        Echo_Red "Failed to download/install uw-imap-devel RPM."
                        exit 1
                    }
                fi
            fi
        fi

        # Symlink /usr/lib64/libc-client.so → /usr/lib/ for PHP configure
        if [[ -s /usr/lib64/libc-client.so && ! -e /usr/lib/libc-client.so ]]; then
            ln -sf /usr/lib64/libc-client.so /usr/lib/libc-client.so
        fi

    elif [ "$PM" = "apt" ]; then
        # IM5: libssl-dev required for --with-imap-ssl
        DEBIAN_FRONTEND=noninteractive apt-get install -y libc-client-dev libkrb5-dev libssl-dev
    fi

    # Build / install the extension
    # X5: widened to ^8\.[4-9]\. to cover any future 8.6-8.9
    if echo "${Cur_PHP_Version}" | grep -Eqi '^8\.[4-9]\.'; then
        # PHP 8.4+: imap removed from core, install via PECL
        # IM3: use yes '' instead of printf "\n\n" — survives any number of prompts
        yes '' | ${PHP_Path}/bin/pecl install imap || {
            Echo_Red "PHP Imap PECL install failed!"
            exit 1
        }
    else
        Download_PHP_Src
        Tar_Cd php-${Cur_PHP_Version}.tar.bz2 php-${Cur_PHP_Version}/ext/imap
        ${PHP_Path}/bin/phpize || { Echo_Red "phpize failed for PHP Imap."; exit 1; }
        ./configure --with-php-config=${PHP_Path}/bin/php-config \
            --with-imap --with-imap-ssl --with-kerberos || {
            Echo_Red "configure failed for PHP Imap."
            exit 1
        }
        Make_Install_Exit "Imap"
        cd "${cur_dir}/src"
        rm -rf php-"${Cur_PHP_Version}"
    fi

    # X2: write ini and restart only after confirming the .so exists
    if [ -s "${zend_ext}" ]; then
        cat > "${PHP_Path}/conf.d/009-imap.ini" <<EOF
extension = "imap.so"
EOF
        Restart_PHP
        Echo_Green "====== PHP Imap install completed ======"
        Echo_Green "PHP Imap installed successfully, enjoy it!"
        exit 0
    else
        rm -f "${PHP_Path}/conf.d/009-imap.ini"
        Echo_Red "PHP Imap install failed!"
        exit 1
    fi
}

Uninstall_PHP_Imap()
{
    echo "You will uninstall PHP Imap..."
    Press_Start
    rm -f "${PHP_Path}/conf.d/009-imap.ini"
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}imap.so"
    Restart_PHP
    Echo_Green "Uninstall PHP Imap completed."
}
