#!/usr/bin/env bash

Install_ionCube() {
    echo "====== Installing ionCube ======"
    Press_Start

    rm -f "${PHP_Path}/conf.d/001-ioncube.ini"
    Addons_Get_PHP_Ext_Dir
    PHP_Short_Ver="$(echo ${Cur_PHP_Version} | cut -d. -f1-2)"
    if "${PHP_Path}/bin/php" -i 2>/dev/null | grep -i 'Thread Safety' | grep -qi 'enabled'; then
        zend_ext="ioncube_loader_lin_${PHP_Short_Ver}_ts.so"
    else
        zend_ext="ioncube_loader_lin_${PHP_Short_Ver}.so"
    fi

    cd "${cur_dir}/src" || {
        Echo_Red "Error: ${cur_dir}/src not found"
        exit 1
    }
    rm -rf ioncube
    rm -rf ioncube_loaders_lin_*.tar.gz

    local ic_arch
    case "${ARCH}" in
    i386) ic_arch='x86' ;;
    x86_64) ic_arch='x86-64' ;;
    armhf) ic_arch='armv7l' ;;
    aarch64) ic_arch='aarch64' ;;
    *)
        Echo_Red "Unsupported architecture: ${ARCH}"
        exit 1
        ;;
    esac

    Download_Files https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${ic_arch}.tar.gz ioncube_loaders_lin_${ic_arch}.tar.gz || {
        Echo_Red "Download failed"
        exit 1
    }

    tar zxf ioncube_loaders_lin_${ic_arch}.tar.gz || {
        Echo_Red "Extract failed"
        exit 1
    }
    if [ ! -d "/usr/local/ioncube" ]; then
        mkdir -p /usr/local/ioncube
    fi
    if [ -s "ioncube/${zend_ext}" ]; then
        \cp "ioncube/${zend_ext}" /usr/local/ioncube/
    else
        Echo_Red "ioncube does not support the current PHP version!"
        exit 1
    fi

    echo "Writing ionCube Loader to configure files..."
    cat >${PHP_Path}/conf.d/001-ioncube.ini <<EOF
[ionCube Loader]
zend_extension="/usr/local/ioncube/${zend_ext}"
;ioncubeend
EOF

    if "${PHP_Path}/bin/php" -v 2>/dev/null | grep -qi 'ionCube'; then
        Restart_PHP
        Echo_Green "ionCube installed successfully, enjoy it!"
    else
        rm -f "${PHP_Path}/conf.d/001-ioncube.ini"
        Echo_Red "ionCube failed to load (incompatible loader for this PHP build?)."
        exit 1
    fi
}

Uninstall_ionCube() {
    echo "You will uninstall ionCube..."
    Press_Start
    rm -f "${PHP_Path}/conf.d/001-ioncube.ini"
    Restart_PHP
    Echo_Green "Uninstall ionCube completed."
}
