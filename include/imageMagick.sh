#!/usr/bin/env bash

Install_ImageMagick() {
    echo "====== Installing ImageMagick ======"
    Press_Start

    rm -f "${PHP_Path}/conf.d/008-imagick.ini"
    Addons_Get_PHP_Ext_Dir
    zend_ext="${zend_ext_dir}imagick.so"
    if [ -s "${zend_ext}" ]; then
        rm -f "${zend_ext}"
    fi

    Get_Dist_Name
    Get_Dist_Version

    if [ "$PM" = "yum" ]; then
        if ! rpm -q epel-release oracle-epel-release >/dev/null 2>&1; then
            if [ "${DISTRO}" = "Oracle" ]; then
                yum -y install oracle-epel-release
            else
                yum -y install epel-release
            fi
        fi
        #      Get_Country
        #     if [ "${country}" = "CN" ]; then
        #          sed -e 's!^metalink=!#metalink=!g' \
        #              -e 's!^#baseurl=!baseurl=!g' \
        #              -e 's!//download\.fedoraproject\.org/pub!//mirrors.ustc.edu.cn!g' \
        #              -e 's!//download\.example/pub!//mirrors.ustc.edu.cn!g' \
        #              -i /etc/yum.repos.d/epel*.repo
        #      fi
        yum install -y libwebp-devel libjpeg-turbo-devel libpng-devel libtiff-devel freetype-devel lcms2-devel libxml2-devel
    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y libwebp-dev libjpeg-dev libpng-dev libtiff-dev libfreetype6-dev liblcms2-dev libxml2-dev
    fi
    ldconfig

    cd "${cur_dir}/src"
    if [ -x /usr/local/imagemagick/bin/convert ]; then
        echo "ImageMagick already exists."
    else
        #if echo "${Cur_PHP_Version}" | grep -Eqi '^5\.2.';then
        #    Download_Files ${ImageMagickold_DL} ImageMagick-6.9.9-51.tar.gz
        #    Tar_Cd ImageMagick-6.9.9-51.tar.gz ImageMagick-6.9.9-51
        #else
        Download_Files ${ImageMagick_DL} ${ImageMagick_Ver}.tar.xz
        Tar_Cd ${ImageMagick_Ver}.tar.xz ${ImageMagick_Ver}
        #fi

        ./configure --prefix=/usr/local/imagemagick \
            --with-webp=yes --with-png=yes --with-jpeg=yes --with-tiff=yes \
            --with-freetype=yes --with-lcms=yes --with-xml=yes || {
            Echo_Red "ImageMagick configure failed!"
            exit 1
        }
        Make_Install_Exit "ImageMagick"
        cd ../
        rm -rf ${cur_dir}/src/${ImageMagick_Ver}
    fi

    #if echo "${Cur_PHP_Version}" | grep -Eqi '^5\.2.';then
    #    Download_Files ${Imagickold_DL} imagick-3.1.2.tgz
    #    Tar_Cd imagick-3.1.2.tgz imagick-3.1.2
    #else
    Download_Files ${Imagick_DL} ${Imagick_Ver}.tgz
    Tar_Cd ${Imagick_Ver}.tgz ${Imagick_Ver}
    #fi
    ${PHP_Path}/bin/phpize || {
        Echo_Red "imagick phpize failed!"
        exit 1
    }
    ./configure --with-php-config=${PHP_Path}/bin/php-config --with-imagick=/usr/local/imagemagick || {
        Echo_Red "imagick configure failed!"
        exit 1
    }
    Make_Install_Exit "imagick"
    ldconfig
    cd ${cur_dir}/src

    cat >${PHP_Path}/conf.d/008-imagick.ini <<EOF
extension = "imagick.so"
EOF

    if [ -s "${zend_ext}" ] && [ -s /usr/local/imagemagick/bin/convert ]; then
        Echo_Green "====== ImageMagick install completed ======"
        Echo_Green "ImageMagick installed successfully, enjoy it!"
    else
        rm -f ${PHP_Path}/conf.d/008-imagick.ini
        Echo_Red "imagick install failed!"
    fi
    Restart_PHP
}

Uninstall_ImageMagick() {
    echo "You will uninstall ImageMagick..."
    Press_Start
    rm -f ${PHP_Path}/conf.d/008-imagick.ini
    Addons_Get_PHP_Ext_Dir
    rm -f "${zend_ext_dir}imagick.so"
    echo "Delete ImageMagick directory..."
    rm -rf /usr/local/imagemagick
    Restart_PHP
    Echo_Green "Uninstall ImageMagick completed."
}
