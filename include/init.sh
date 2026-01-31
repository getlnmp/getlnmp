#!/usr/bin/env bash

Set_Timezone() {
    Echo_Blue "[+] Setting timezone to New York Time..."
    rm -rf /etc/localtime
    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
}

Sync_Time() {
    if ! command -v chronyd >/dev/null 2>&1; then
        Echo_Blue "[+] Installing chrony..."
        if [ "$PM" = "yum" ]; then
            yum install chrony -y
        elif [ "$PM" = "apt" ]; then
            apt-get update --allow-releaseinfo-change -y
            apt-get install -y chrony
        fi
    fi
    Echo_Blue "[+] Syncing system time..."
    # Check if chronyd is already running
    if pidof chronyd >/dev/null 2>&1; then
        # Use chronyc instead of starting another chronyd
        if command -v chronyc >/dev/null 2>&1; then
            echo "Forcing time sync via chronyc"
            chronyc -a makestep
            chronyc tracking
        else
            echo "chronyc not available"
        fi
    else
        echo "chronyd not running, doing one-shot sync"
        chronyd -d -q "server pool.ntp.org iburst"
    fi
    date
    start_time=$(date +%s)
}

RHEL_RemoveAMP() {
    Echo_Blue "[-] Yum remove packages..."
    rpm -qa | grep httpd
    rpm -e httpd httpd-tools --nodeps
    if [[ "${DBSelect}" != "0" ]]; then
        yum -y remove mysql-server mysql mysql-libs mariadb-server mariadb mariadb-libs
        rpm -qa | grep mysql
        if [ $? -ne 0 ]; then
            rpm -e mysql mysql-libs --nodeps
            rpm -e mariadb mariadb-libs --nodeps
        fi
    fi
    rpm -qa | grep php
    rpm -e php-mysql php-cli php-gd php-common php --nodeps

    Remove_Error_Libcurl

    yum -y remove httpd*
    yum -y remove php*
    yum clean all
}

Deb_RemoveAMP() {
    Echo_Blue "[-] apt-get remove packages..."
    apt-get update -y
    [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
    for removepackages in apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd; do apt-get purge -y $removepackages; done
    if [[ "${DBSelect}" != "0" ]]; then
        if echo "${Ubuntu_Version}" | grep -Eqi "^2[0-7]\."; then
            dpkg -l | grep mysql
            dpkg --force-all -P mysql-server
            dpkg --force-all -P mariadb-client mariadb-server mariadb-common libmariadbd-dev
            [[ -d "/etc/mysql" ]] && rm -rf /etc/mysql
            for removepackages in mysql-server mariadb-server; do apt-get purge -y $removepackages; done
        else
            dpkg -l | grep mysql
            dpkg --force-all -P mysql-server mysql-common libmysqlclient15off libmysqlclient15-dev libmysqlclient18 libmysqlclient18-dev libmysqlclient20 libmysqlclient-dev libmysqlclient21
            dpkg --force-all -P mariadb-client mariadb-server mariadb-common libmariadbd-dev
            for removepackages in mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common; do apt-get purge -y $removepackages; done
        fi
    fi
    killall apache2
    dpkg -l | grep apache
    dpkg -P apache2 apache2-doc apache2-mpm-prefork apache2-utils apache2.2-common
    dpkg -l | grep php
    dpkg -P php5 php5-common php5-cli php5-cgi php5-mysql php5-curl php5-gd
    apt-get autoremove -y && apt-get clean
}

Disable_Selinux() {
    if [ -s /etc/selinux/config ]; then
        setenforce 0
        sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
    fi
}

Xen_Hwcap_Setting() {
    if [ -s /etc/ld.so.conf.d/libc6-xen.conf ]; then
        sed -i 's/hwcap 1 nosegneg/hwcap 0 nosegneg/g' /etc/ld.so.conf.d/libc6-xen.conf
    fi
}

Check_Hosts() {
    if grep -Eqi '^127.0.0.1[[:space:]]*localhost' /etc/hosts; then
        echo "Hosts: ok."
    else
        echo "127.0.0.1 localhost.localdomain localhost" >>/etc/hosts
    fi
    if [ "${CheckMirror}" != "n" ]; then
        pingresult=$(ping -c1 www.cloudflare.com 2>&1)
        echo "${pingresult}"
        if echo "${pingresult}" | grep -q "unknown host"; then
            echo "DNS...fail"
            echo "Writing nameserver to /etc/resolv.conf ..."
            echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 8.8.4.4" >/etc/resolv.conf
        else
            echo "DNS...ok"
        fi
    fi
}

# not suggest using centos repository for RHEL
RHEL_Modify_Source() {
    Get_RHEL_Version
    if [ "${RHELRepo}" = "local" ]; then
        echo "DO NOT change RHEL repository, use the repository you set."
    else
        echo "RHEL ${RHEL_Ver} will use aliyun centos repository..."
        if [ ! -s "/etc/yum.repos.d/Centos-${RHEL_Ver}.repo" ]; then
            if command -v curl >/dev/null 2>&1; then
                curl http://mirrors.aliyun.com/repo/Centos-${RHEL_Ver}.repo -o /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
            else
                wget --prefer-family=IPv4 http://mirrors.aliyun.com/repo/Centos-${RHEL_Ver}.repo -O /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
            fi
        fi
        if echo "${RHEL_Version}" | grep -Eqi "^6"; then
            sed -i "s#centos/\$releasever#centos-vault/\$releasever#g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
            sed -i "s/\$releasever/${RHEL_Version}/g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
        elif echo "${RHEL_Version}" | grep -Eqi "^7"; then
            sed -i "s/\$releasever/7/g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
        elif echo "${RHEL_Version}" | grep -Eqi "^8"; then
            sed -i "s#centos/\$releasever#centos-vault/8.5.2111#g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
        elif echo "${RHEL_Version}" | grep -Eqi "^9"; then
            [[ -s /etc/yum.repos.d/Centos-9.repo ]] && rm -f /etc/yum.repos.d/Centos-9.repo
            \cp ${cur_dir}/conf/rhel-9.repo /etc/yum.repos.d/Centos-9.repo
        fi
        yum clean all
        yum makecache
    fi
    sed -i "s/^enabled[ ]*=[ ]*1/enabled=0/" /etc/yum/pluginconf.d/subscription-manager.conf
}

Ubuntu_Modify_Source() {
    if [ "${country}" = "CN" ]; then
        OldReleasesURL='http://mirrors.ustc.edu.cn/ubuntu-old-releases/'
    else
        OldReleasesURL='http://old-releases.ubuntu.com/ubuntu/'
    fi
    CodeName=''
    if grep -Eqi "10.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^10.10'; then
        CodeName='maverick'
    elif grep -Eqi "11.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^11.04'; then
        CodeName='natty'
    elif grep -Eqi "11.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^11.10'; then
        CodeName='oneiric'
    elif grep -Eqi "12.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^12.10'; then
        CodeName='quantal'
    elif grep -Eqi "13.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^13.04'; then
        CodeName='raring'
    elif grep -Eqi "13.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^13.10'; then
        CodeName='saucy'
    elif grep -Eqi "10.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^10.04'; then
        CodeName='lucid'
    elif grep -Eqi "14.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^14.10'; then
        CodeName='utopic'
    elif grep -Eqi "15.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^15.04'; then
        CodeName='vivid'
    elif grep -Eqi "12.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^12.04'; then
        CodeName='precise'
    elif grep -Eqi "15.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^15.10'; then
        CodeName='wily'
    elif grep -Eqi "16.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.10'; then
        CodeName='yakkety'
    elif grep -Eqi "14.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^14.04'; then
        Ubuntu_Deadline trusty
    elif grep -Eqi "17.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^17.04'; then
        CodeName='zesty'
    elif grep -Eqi "17.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^17.10'; then
        CodeName='artful'
    elif grep -Eqi "16.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.04'; then
        Ubuntu_Deadline xenial
    elif grep -Eqi "16.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.10'; then
        CodeName='yakkety'
    elif grep -Eqi "18.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^18.04'; then
        Ubuntu_Deadline bionic
    elif grep -Eqi "18.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^18.10'; then
        CodeName='cosmic'
    elif grep -Eqi "19.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^19.04'; then
        CodeName='disco'
    elif grep -Eqi "19.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^19.10'; then
        CodeName='eoan'
    elif grep -Eqi "20.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^20.10'; then
        CodeName='groovy'
    elif grep -Eqi "21.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^21.04'; then
        CodeName='hirsute'
    elif grep -Eqi "21.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^21.10'; then
        CodeName='impish'
    elif grep -Eqi "22.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^22.10'; then
        CodeName='kinetic'
    elif grep -Eqi "23.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^23.04'; then
        CodeName='lunar'
    elif grep -Eqi "23.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^23.10'; then
        Ubuntu_Deadline mantic
    fi
    if [ "${CodeName}" != "" ]; then
        \cp /etc/apt/sources.list /etc/apt/sources.list.$(date +"%Y%m%d")
        cat >/etc/apt/sources.list <<EOF
deb ${OldReleasesURL} ${CodeName} main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-security main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-updates main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-proposed main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-backports main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName} main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-security main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-updates main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-proposed main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-backports main restricted universe multiverse
EOF
    fi
}

Check_Old_Releases_URL() {
    OR_Status=$(wget --spider --server-response ${OldReleasesURL}/dists/$1/Release 2>&1 | awk '/^  HTTP/{print $2}')
    if [ "${OR_Status}" = "200" ]; then
        echo "Ubuntu old-releases status: ${OR_Status}"
        CodeName="$1"
    fi
}

Ubuntu_Deadline() {
    trusty_deadline=$(date -d "2024-4-30 00:00:00" +%s)
    xenial_deadline=$(date -d "2026-4-30 00:00:00" +%s)
    bionic_deadline=$(date -d "2028-7-30 00:00:00" +%s)
    mantic_deadline=$(date -d "2024-7-30 00:00:00" +%s)
    cur_time=$(date +%s)
    case "$1" in
    trusty)
        if [ ${cur_time} -gt ${trusty_deadline} ]; then
            echo "${cur_time} > ${trusty_deadline}"
            Check_Old_Releases_URL trusty
        fi
        ;;
    xenial)
        if [ ${cur_time} -gt ${xenial_deadline} ]; then
            echo "${cur_time} > ${xenial_deadline}"
            Check_Old_Releases_URL xenial
        fi
        ;;
    bionic)
        if [ ${cur_time} -gt ${bionic_deadline} ]; then
            echo "${cur_time} > ${bionic_deadline}"
            Check_Old_Releases_URL bionic
        fi
        ;;
    mantic)
        if [ ${cur_time} -gt ${mantic_deadline} ]; then
            echo "${cur_time} > ${mantic_deadline}"
            Check_Old_Releases_URL mantic
        fi
        ;;
    esac
}

CentOS6_Modify_Source() {
    if echo "${CentOS_Version}" | grep -Eqi "^6"; then
        Echo_Yellow "CentOS 6 is now end of life, use vault repository."
        mkdir /etc/yum.repos.d/backup
        mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
        \cp ${cur_dir}/conf/CentOS6-Base-Vault.repo /etc/yum.repos.d/CentOS-Base.repo
    fi
}

CentOS8_Modify_Source() {
    if echo "${CentOS_Version}" | grep -Eqi "^8" && [ "${isCentosStream}" != "y" ]; then
        Echo_Yellow "CentOS 8 is now end of life, use vault repository."
        if [ ! -s /etc/yum.repos.d/CentOS8-vault.repo ]; then
            mkdir /etc/yum.repos.d/backup
            mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
            \cp ${cur_dir}/conf/CentOS8-vault.repo /etc/yum.repos.d/CentOS8-vault.repo
        fi
    fi
}

Modify_Source() {
#    if [ "${DISTRO}" = "RHEL" ]; then
#        if subscription-manager status; then
#            Echo_Blue "RHEL subscription exists on the system, skip setting up third-party sources."
#            Get_RHEL_Version
#            if echo "${RHEL_Version}" | grep -Eqi "^[89]"; then
#                subscription-manager repos --enable codeready-builder-for-rhel-${RHEL_Version}-${DB_ARCH}-rpms
#            fi
#        else
#            RHEL_Modify_Source
#        fi
#    elif [ "${DISTRO}" = "Ubuntu" ]; then
#        Ubuntu_Modify_Source
#    elif [ "${DISTRO}" = "CentOS" ]; then
#        CentOS6_Modify_Source
#        CentOS8_Modify_Source
#    fi
    echo ''
    Echo_Red "Please update repository sources manually if needed."
    echo ''
}

Check_PowerTools() {
    if ! yum -v repolist all | grep "PowerTools"; then
        Echo_Red "PowerTools repository not found!"
    fi
    repo_id=$(yum repolist all | grep -Ei "PowerTools" | head -n 1 | awk '{print $1}')
}

Check_Codeready() {
    repo_id=$(yum repolist all | grep -E "CRB" | head -n 1 | awk '{print $1}')
#    [ -z "${repo_id}" ] && repo_id="ol8_codeready_builder"
}

RHEL_Dependent() {
    if [ -s /etc/yum.conf ]; then
        \cp /etc/yum.conf /etc/yum.conf.lnmp
        sed -i 's:exclude=.*:exclude=:g' /etc/yum.conf
    fi

    Echo_Blue "[+] Yum installing dependent packages..."
    for packages in make cmake gcc gcc-c++ gcc-g77 kernel-headers glibc-headers glibc-devel flex bison file libtool libtool-libs autoconf patch wget crontabs libjpeg libjpeg-devel libjpeg-turbo-devel libpng libpng-devel libpng10 libpng10-devel gd gd-devel libxml2 libxml2-devel zlib zlib-devel glib2 glib2-devel unzip tar bzip2 bzip2-devel libzip-devel libevent libevent-devel ncurses ncurses-devel curl curl-devel libcurl libcurl-devel e2fsprogs e2fsprogs-devel krb5 krb5-devel libidn libidn-devel openssl openssl-devel pcre2-devel gettext gettext-devel ncurses-devel gmp-devel pspell-devel unzip libcap diffutils ca-certificates net-tools libc-client-devel psmisc libXpm-devel git-core c-ares-devel libicu-devel libxslt libxslt-devel xz expat-devel libaio-devel rpcgen libtirpc-devel perl cyrus-sasl-devel sqlite-devel oniguruma-devel lsof re2c pkg-config libarchive hostname ncurses-libs numactl-devel libxcrypt libwebp-devel gnutls-devel initscripts iproute libxcrypt-compat git systemd-devel freetype-devel pkgconf libsodium-devel; do yum -y install $packages; done

    yum -y update nss

    if echo "${RHEL_Version}" | grep -Eqi "^8" || echo "${Rocky_Version}" | grep -Eqi "^8" || echo "${Alma_Version}" | grep -Eqi "^8"; then
        Check_PowerTools
        if [ "${repo_id}" != "" ]; then
            echo "Installing packages in PowerTools repository..."
            for c8packages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${c8packages} -y; done
        fi
        dnf install libarchive -y

        dnf install gcc-toolset-10 -y
    fi

    if echo "${RHEL_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
        for cs9packages in oniguruma-devel libzip-devel libtirpc-devel libxcrypt-compat; do dnf --enablerepo=crb install ${cs9packages} -y; done
        if [[ "${Bin}" != "y" && "${DBSelect}" = "[45]" ]]; then
            dnf install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc -y
        fi
    fi

    if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^8"; then
        Check_Codeready
        for o8packages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${o8packages} -y; done
        dnf install libarchive -y
    fi

    if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^9"; then
        Check_Codeready
        dnf --enablerepo=${repo_id} install libtirpc-devel -y
        if [[ "${Bin}" != "y" && "${DBSelect}" =~ "[45]" ]]; then
            dnf install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc -y
        fi
    fi

    if  echo "${RHEL_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9" || echo "${Oracle_Version}" | grep -Eqi "^9"; then
        dnf install chkconfig -y
    fi

    if [ -s /etc/yum.conf.lnmp ]; then
        mv -f /etc/yum.conf.lnmp /etc/yum.conf
    fi
}

# libsystemd-dev for debian 12 and older
# systemd-dev for debian 13
Deb_Dependent() {
    Echo_Blue "[+] Apt-get installing dependent packages..."
    apt-get update -y
    [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
    apt-get autoremove -y
    apt-get -fy install
    export DEBIAN_FRONTEND=noninteractive
    apt-get --no-install-recommends install -y build-essential gcc g++ make
    for packages in debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf automake re2c wget cron bzip2 libzip-dev libc6-dev bison file flex bison m4 gawk less cpp binutils diffutils unzip tar bzip2 libbz2-dev libncurses-dev libtool libevent-dev openssl libssl-dev libsasl2-dev libltdl-dev zlib1g zlib1g-dev libbz2-1.0 libbz2-dev libglib2.0-dev libjpeg62-turbo-dev libpng-dev libkrb5-dev curl libcurl4-openssl-dev libpcre2-dev libpq-dev libpq5 gettext libxml2-dev libcap-dev ca-certificates psmisc patch git libc-ares-dev libicu-dev e2fsprogs libxslt1.1 libxslt1-dev xz-utils libexpat1-dev libaio-dev libtirpc-dev libsqlite3-dev libonig-dev lsof pkg-config libtinfo-dev libnuma-dev libwebp-dev gnutls-dev iproute2 xz-utils gzip libsystemd-dev libgd-dev lsb-release libgnutls28-dev systemd-dev libfreetype6-dev libsodium-dev; do apt-get --no-install-recommends install -y $packages; done
}

Check_Download() {
    Echo_Blue "[+] Downloading files..."
    cd ${cur_dir}/src
    if [ "${SelectMalloc}" = "2" ]; then
        Download_Files ${Jemalloc_DL} ${Jemalloc_Ver}.tar.bz2
    elif [ "${SelectMalloc}" = "3" ]; then
        Download_Files ${TCMalloc_DL} ${TCMalloc_Ver}.tar.gz
        Download_Files ${Libunwind_DL} ${Libunwind_Ver}.tar.gz
    fi
    if [ "${Stack}" != "lamp" ]; then
        Download_Files ${Nginx_DL} ${Nginx_Ver}.tar.gz
    fi
    if [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        if [[ "${Bin}" = "y" && "${DBSelect}" =~ ^[2-3]$ ]]; then
            Download_Files https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz
            if [ $? -ne 0 ]; then
                Download_Files https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz
            fi
        elif [[ "${Bin}" = "y" && "${DBSelect}" = "4" ]]; then
            Download_Files https://cdn.mysql.com/Downloads/MySQL-8.0/${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
            if [ $? -ne 0 ]; then
                Download_Files https://cdn.mysql.com/archives/mysql-8.0/${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
            fi
        elif [[ "${Bin}" = "y" && "${DBSelect}" = "5" ]]; then
            Download_Files https://cdn.mysql.com/Downloads/MySQL-8.4/${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
            if [ $? -ne 0 ]; then
                Download_Files https://cdn.mysql.com/archives/mysql-8.4/${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz ${Mysql_Ver}-linux-glibc2.28-${DB_ARCH}.tar.xz
            fi
        else
            Download_Files https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}.tar.gz ${Mysql_Ver}.tar.gz
            if [ $? -ne 0 ]; then
                Download_Files https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${Mysql_Ver}.tar.gz ${Mysql_Ver}.tar.gz
            fi
        fi
    elif [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        #    Mariadb_Version=$(echo ${Mariadb_Ver} | cut -d- -f2)
        if [ "${Bin}" = "y" ]; then
            MariaDB_FileName="${Mariadb_Ver}-linux-systemd-${DB_ARCH}"
        else
            MariaDB_FileName="${Mariadb_Ver}"
        fi
        Download_Files https://downloads.mariadb.org/rest-api/mariadb/${Mariadb_Version}/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
        if [ $? -ne 0 ]; then
            if [ "${Bin}" = "y" ]; then
                Download_Files https://archive.mariadb.org/mariadb-${Mariadb_Version}/bintar-linux-systemd-x86_64/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
            else
                Download_Files https://archive.mariadb.org/mariadb-${Mariadb_Version}/source/${MariaDB_FileName}.tar.gz ${MariaDB_FileName}.tar.gz
            fi
            if [ -s ${MariaDB_FileName}.tar.gz ]; then
                echo "Download ${MariaDB_FileName}.tar.gz successfully!"
            else
                Echo_Red "Error! Unable to download MariaDB, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        fi
    fi
    Download_Files ${Php_DL} ${Php_Ver}.tar.bz2
    if [ $? -ne 0 ]; then
        Download_Files https://museum.php.net/php${Php_Major_Ver}/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    fi
    Download_Files https://files.phpmyadmin.net/phpMyAdmin/${PhpMyAdmin_Ver_Short}/${PhpMyAdmin_Ver}.tar.xz ${PhpMyAdmin_Ver}.tar.xz
    Download_Files https://github.com/kmvan/x-prober/releases/download/8.20/prober.php prober.php
    if [ "${Stack}" != "lnmp" ]; then
        Download_Files ${Apache_DL} ${Apache_Ver}.tar.bz2
        Download_Files ${APR_DL} ${APR_Ver}.tar.bz2
        Download_Files ${APR_Util_DL} ${APR_Util_Ver}.tar.bz2
    fi
}

Make_Install() {
    make -j"$(nproc)"
    if [ $? -ne 0 ]; then
        make
    fi
    make install
}

PHP_Make_Install() {
#    make ZEND_EXTRA_LIBS='-liconv' -j "$(nproc)"
#    if [ $? -ne 0 ]; then
#        make ZEND_EXTRA_LIBS='-liconv'
#    fi
#    make install
    make -j"$(nproc)"
    if [ $? -ne 0 ]; then
        make
    fi
    make install
    # resetting environment variable to avoid affecting other make processes
    PHP_ENV_UNSET
}

# deprecated as only for php 5.2 which is dropped support
# autoconf 2.69 is required for php 5.6
Install_Autoconf() {
    if [ -s /usr/local/autoconf-2.69/bin/autoconf ] && [ -s /usr/local/autoconf-2.69/bin/autoheader ]; then
        Echo_Yellow "autoconf 2.69 already installed, skip."       
    else
        rm -rf /usr/local/autoconf-2.69
        Echo_Blue "[+] Installing ${Autoconf_Ver}"
        cd ${cur_dir}/src
        Download_Files https://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz autoconf-2.69.tar.gz
        Tar_Cd autoconf-2.69.tar.gz autoconf-2.69
        ./configure --prefix=/usr/local/autoconf-2.69
        Make_Install
        cd ${cur_dir}/src/
        rm -rf ${cur_dir}/src/${Autoconf_Ver}
    fi
}

# iconv can be provided by system glibc or GNU libiconv
# only compile and install libiconv when necessary for php <= 7.1
# use "--with-iconv" flag when using systm glibc iconv for php compile
# php 5.6 and php 7.0, 7.1 may have issue with system glibc iconv, needs test
# use "--with-iconv=/usr/local" flag when using GNU libiconv
# libxml2 needs recompiling if using GNU libiconv
Install_Libiconv() {
    Echo_Blue "[+] Installing ${Libiconv_Ver}"
    cd ${cur_dir}/src
    Download_Files ${Libiconv_DL} ${Libiconv_Ver}.tar.gz
    Tar_Cd ${Libiconv_Ver}.tar.gz ${Libiconv_Ver}
    ./configure --enable-static
    Make_Install
    cd ${cur_dir}/src/
    rm -rf ${cur_dir}/src/${Libiconv_Ver}
}

# install it for php 5.6 - php 7.0, mcrypt extension deprecated from 7.1 and removed since 7.2
# building flag --with-mcrypt for php <= 7.0
# not maintained since 2007, use at your own risk
# for debian, apt-get install libmcrypt-dev
# for RHEL, yum install epel-release yum install libmcrypt-devel
Install_Libmcrypt() {
    if [[ "${php_version}" =~ ^(5\.6\.|7\.[01]\.) ]] || [[ "${Php_Ver}" =~ (php-5\.6\.|php-7\.[01]\.) ]]; then
        if [ -s /usr/lib/x86_64-linux-gnu/libmcrypt.so ] || [ -s /usr/lib64/libmcrypt.so ]; then
            Echo_Yellow "libmcrypt already installed, skip."
        else
            if [ "${PM}" = "yum" ]; then
                Echo_Blue "[+] Installing epel-release for libmcrypt"
                yum -y install epel-release
                yum -y install libmcrypt-devel
            elif [ "${PM}" = "apt" ]; then
                Echo_Blue "[+] Installing libmcrypt-dev from apt repository"
                apt-get -y install libmcrypt-dev
            else
                Compile_Libmcrypt                
            fi
        fi
    else
        Echo_Yellow "PHP ${Php_Ver}${php_version} does not require libmcrypt, skip."
        return
    fi
}
Compile_Libmcrypt() {
    Echo_Blue "[+] Installing ${LibMcrypt_Ver}"
    cd ${cur_dir}/src
    Download_Files ${LibMcrypt_DL} ${LibMcrypt_Ver}.tar.gz
    Tar_Cd ${LibMcrypt_Ver}.tar.gz ${LibMcrypt_Ver}
    ./configure
    Make_Install
    /sbin/ldconfig
    cd libltdl/
    ./configure --enable-ltdl-install
    Make_Install
    ln -sf /usr/local/lib/libmcrypt.la /usr/lib/libmcrypt.la
    ln -sf /usr/local/lib/libmcrypt.so /usr/lib/libmcrypt.so
    ln -sf /usr/local/lib/libmcrypt.so.4 /usr/lib/libmcrypt.so.4
    ln -sf /usr/local/lib/libmcrypt.so.4.4.8 /usr/lib/libmcrypt.so.4.4.8
    ldconfig
    cd ${cur_dir}/src/
    rm -rf ${cur_dir}/src/${LibMcrypt_Ver}
}

# not need to compile if libmcrypt installed from OS repository
Install_Mcrypt() {
    Echo_Blue "[+] Installing ${Mcypt_Ver}"
    cd ${cur_dir}/src
    Download_Files ${Mcypt_DL} ${Mcypt_Ver}.tar.gz
    Tar_Cd ${Mcypt_Ver}.tar.gz ${Mcypt_Ver}
    ./configure
    Make_Install
    cd ${cur_dir}/src/
    rm -rf ${cur_dir}/src/${Mcypt_Ver}
}


# only for php 5.2. As of PHP 5.3.0, the mhash extension is emulated thru the Hash extension
# for php 5.3 - php 7.3, '--with-mhash' flag is required and mhash() enabled via the Hash extension.
# for php 7.4 - php 8.0, '--with-mhash' flag is required and legacy function names is enabled.
# for php 8.1+, '--with-mhash' flag is removed and mhash extension function removed.
Install_Mhash() {
    if [[ "${php_version}" =~ ^(5\.2\.) ]] || [[ "${Php_Ver}" =~ (php-5\.2\.) ]]; then
        if [ -s /usr/lib/libmhash.a ] || [ -s /usr/lib64/libmhash.a ]; then
            Echo_Yellow "libmhash already installed, skip."
        else
            Compile_Mhash
        fi
    else
        Echo_Yellow "PHP ${Php_Ver}${php_version} does not require libmhash, skip."
        return
    fi
}


Compile_Mhash() {
    Echo_Blue "[+] Installing ${Mhash_Ver}"
    cd ${cur_dir}/src
    Download_Files ${Mhash_DL} ${Mhash_Ver}.tar.bz2
    Tar_Cd ${Mhash_Ver}.tar.bz2 ${Mhash_Ver}
    ./configure
    Make_Install
    ln -sf /usr/local/lib/libmhash.a /usr/lib/libmhash.a
    ln -sf /usr/local/lib/libmhash.la /usr/lib/libmhash.la
    ln -sf /usr/local/lib/libmhash.so /usr/lib/libmhash.so
    ln -sf /usr/local/lib/libmhash.so.2 /usr/lib/libmhash.so.2
    ln -sf /usr/local/lib/libmhash.so.2.0.1 /usr/lib/libmhash.so.2.0.1
    ldconfig
    cd ${cur_dir}/src/
    rm -rf ${cur_dir}/src/${Mhash_Ver}
}

# install using system repo
# for debian, apt-get install libfreetype6-dev
# for RHEL, yum install freetype-devel
# for php <=7.3, use flag --with-gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr
# for php >=7.4, use flag --enable-gd --with-freetype --with-jpeg --with-png
Install_Freetype() {
    if [ "${PM}" = "yum" ]; then
        Echo_Blue "[+] Installing freetype-devel from yum repository"
        yum -y install freetype-devel
    elif [ "${PM}" = "apt" ]; then
        Echo_Blue "[+] Installing libfreetype6-dev from apt repository"
        apt-get -y install libfreetype6-dev
    else
        Compile_Freetype
    fi
}
Compile_Freetype() {
    if echo "${Ubuntu_Version}" | grep -Eqi "^(1[89]\.|2[0-9]\.)" || echo "${Mint_Version}" | grep -Eqi "^(19|2[0-9])" || echo "${Deepin_Version}" | grep -Eqi "^(15\.[7-9]|15.1[0-9]|1[6-9]|2[0-9])" || echo "${Debian_Version}" | grep -Eqi "^(9|1[0-9])" || echo "${Raspbian_Version}" | grep -Eqi "^(9|1[0-9])" || echo "${Kali_Version}" | grep -Eqi "^202[0-9]" || echo "${UOS_Version}" | grep -Eqi "^2[0-9]" || echo "${CentOS_Version}" | grep -Eqi "^(8|9)" || echo "${RHEL_Version}" | grep -Eqi "^(8|9)" || echo "${Oracle_Version}" | grep -Eqi "^(8|9)" || echo "${Fedora_Version}" | grep -Eqi "^(3[0-9]|29)" || echo "${Rocky_Version}" | grep -Eqi "^(8|9)" || echo "${Alma_Version}" | grep -Eqi "^(8|9)" || echo "${openEuler_Version}" | grep -Eqi "^2[0-9]" || echo "${Anolis_Version}" | grep -Eqi "^(8|9)" || echo "${Kylin_Version}" | grep -Eqi "^V1[0-9]" || echo "${Amazon_Version}" | grep -Eqi "^202[3-9]" || echo "${OpenCloudOS_Version}" | grep -Eqi "^(8|9|23)" || echo "${HCE_Version}" | grep -Eqi "^2\.[0-9]"; then
        Download_Files ${Freetype_New_DL} ${Freetype_New_Ver}.tar.xz
        Echo_Blue "[+] Installing ${Freetype_New_Ver}"
        Tar_Cd ${Freetype_New_Ver}.tar.xz ${Freetype_New_Ver}
        ./configure --prefix=/usr/local/freetype --enable-freetype-config
    else
        Download_Files ${Freetype_DL} ${Freetype_Ver}.tar.bz2
        Echo_Blue "[+] Installing ${Freetype_Ver}"
        Tar_Cd ${Freetype_Ver}.tar.bz2 ${Freetype_Ver}
        ./configure --prefix=/usr/local/freetype
    fi
    Make_Install

    [[ -d /usr/lib/pkgconfig ]] && \cp /usr/local/freetype/lib/pkgconfig/freetype2.pc /usr/lib/pkgconfig/
    cat >/etc/ld.so.conf.d/freetype.conf <<EOF
/usr/local/freetype/lib
EOF
    ldconfig
    ln -sf /usr/local/freetype/include/freetype2/* /usr/include/
    cd ${cur_dir}/src/
    rm -rf ${cur_dir}/src/${Freetype_Ver}
}

Install_Curl() {
    if [ -s /usr/local/curl/bin/curl ]; then
        echo "Custom curl already compiled with Openssl 1.1.1, skip."
    else
        Echo_Blue "[+] Installing ${Curl_Ver} with Openssl 1.1.1"
        cd ${cur_dir}/src
        Download_Files ${Curl_DL} ${Curl_Ver}.tar.bz2
        Tar_Cd ${Curl_Ver}.tar.bz2 ${Curl_Ver}
        if [ "${BuildOpenssl}" = "y"  ] ; then
             ./configure --prefix=/usr/local/curl --enable-ares --without-nss --with-zlib --disable-ldap --disable-ldaps --with-ssl=${Custom_Openssl_Path}
        else
            ./configure --prefix=/usr/local/curl --enable-ares --without-nss --with-zlib --with-ssl
        fi
        Make_Install
        cd ${cur_dir}/src/
        rm -rf ${cur_dir}/src/${Curl_Ver}
        Remove_Error_Libcurl
    fi

}

Install_OldCurl() {
    if [ -s /usr/local/oldcurl/bin/curl ]; then
        echo "Custom old curl already compiled with Openssl 1.0.2, skip."
    else
        Echo_Blue "[+] Installing ${Curl_Ver} with Openssl 1.0.2"
        cd ${cur_dir}/src
        Download_Files ${Curl_DL} ${Curl_Ver}.tar.bz2
        Tar_Cd ${Curl_Ver}.tar.bz2 ${Curl_Ver}
        if [ "${BuildOpenssl}" = "y"  ] ; then
            ./configure --prefix=/usr/local/oldcurl --enable-ares --without-nss --with-zlib --disable-ldap --disable-ldaps --with-ssl=${Custom_Openssl_Path}
        else
            ./configure --prefix=/usr/local/oldcurl --enable-ares --without-nss --with-zlib --with-ssl
        fi
        Make_Install
        cd ${cur_dir}/src/
        rm -rf ${cur_dir}/src/${Curl_Ver}
    fi

}

Install_Pcre() {
    if ! command -v pcre-config >/dev/null 2>&1 || pcre-config --version | grep -vEqi '^8.'; then
        Echo_Blue "[+] Installing ${Pcre_Ver}"
        cd ${cur_dir}/src
        Download_Files ${Pcre_DL} ${Pcre_Ver}.tar.bz2
        Tar_Cd ${Pcre_Ver}.tar.bz2
        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre_Ver} --with-pcre-jit"
    fi
}

# by default, prefix is /usr/local, jemalloc installs to /usr/local/lib
Install_Jemalloc() {
    Echo_Blue "[+] Installing ${Jemalloc_Ver}"
    cd ${cur_dir}/src
    Tar_Cd ${Jemalloc_Ver}.tar.bz2 ${Jemalloc_Ver}
    ./configure
    Make_Install
    ldconfig
    cd ${cur_dir}/src/
    rm -rf ${cur_dir}/src/${Jemalloc_Ver}
    ln -sf /usr/local/lib/libjemalloc* /usr/lib/
}

Install_TCMalloc() {
    Echo_Blue "[+] Installing ${TCMalloc_Ver}"
    if [ "${Is_64bit}" = "y" ]; then
        Tar_Cd ${Libunwind_Ver}.tar.gz ${Libunwind_Ver}
        CFLAGS=-fPIC ./configure
        make CFLAGS=-fPIC
        make CFLAGS=-fPIC install
        rm -rf ${cur_dir}/src/${Libunwind_Ver}
    fi
    Tar_Cd ${TCMalloc_Ver}.tar.gz ${TCMalloc_Ver}
    if [ "${Is_64bit}" = "y" ]; then
        ./configure
    else
        ./configure --enable-frame-pointers
    fi
    Make_Install
    ldconfig
    cd ${cur_dir}/src/
    rm -rf ${cur_dir}/src/${TCMalloc_Ver}
    ln -sf /usr/local/lib/libtcmalloc* /usr/lib/
}

Install_Icu4c() {
    if command -v icu-config >/dev/null 2>&1 && icu-config --version | grep -Eq "^3."; then
        if [ ! -s /usr/local/icu583/bin/icu-config ]; then
            rm -rf /usr/local/icu583
        fi
        Echo_Blue "[+] Installing icu4c-58_3..."
        cd ${cur_dir}/src
        Download_Files ${Libicu4c_DL} icu4c-58_3-src.tgz
        Tar_Cd icu4c-58_3-src.tgz icu/source
        ./configure --prefix=/usr/local/icu583
        if [ ! -s /usr/include/xlocale.h ]; then
            ln -s /usr/include/locale.h /usr/include/xlocale.h
        fi
        Make_Install

        rm -rf ${cur_dir}/src/icu

        if [ -f /etc/ld.so.conf.d/icu583.conf ]; then
            rm -rf /etc/ld.so.conf.d/icu583.conf
        fi

        echo "/usr/local/icu583/lib" >/etc/ld.so.conf.d/icu583.conf
        ldconfig
    fi
}

Install_Icu522() {
    if [ -s /usr/local/icu522/bin/icu-config ] && [ -s /etc/ld.so.conf.d/icu522.conf ]; then
        echo "ICU 52.2 is already installed."
    else
        rm -rf /usr/local/icu522
        rm -rf /etc/ld.so.conf.d/icu522.conf
        Echo_Blue "[+] Installing icu4c-52_2..."
        cd ${cur_dir}/src
        Download_Files ${Libicu4c_52_2_DL} icu4c-52_2-src.tgz
        Tar_Cd icu4c-52_2-src.tgz icu/source
        ./configure --prefix=/usr/local/icu522
        if [ ! -s /usr/include/xlocale.h ]; then
            ln -s /usr/include/locale.h /usr/include/xlocale.h
        fi
        Make_Install

        rm -rf ${cur_dir}/src/icu

        echo "/usr/local/icu522/lib" >/etc/ld.so.conf.d/icu522.conf
        ldconfig
    fi
}

Install_Icu603() {
    if [ -s /usr/local/icu603/bin/icu-config ] && [ -s /etc/ld.so.conf.d/icu603.conf ]; then
        echo "ICU 60.3 is already installed."
    else
        rm -rf /usr/local/icu603
        rm -rf /etc/ld.so.conf.d/icu603.conf
        Echo_Blue "[+] Installing icu4c-60_3..."
        cd ${cur_dir}/src
        Download_Files ${Libicu4c_60_3_DL} icu4c-60_3-src.tgz
        Tar_Cd icu4c-60_3-src.tgz icu/source
        ./configure --prefix=/usr/local/icu603
        Make_Install

        rm -rf ${cur_dir}/src/icu

        echo "/usr/local/icu603/lib" >/etc/ld.so.conf.d/icu603.conf
        ldconfig
    fi
}

Install_Icu631() {
    if [ -s /usr/local/icu631/bin/icu-config ] && [ -s /etc/ld.so.conf.d/icu631.conf ]; then
        echo "ICU 63.1 is already installed."
    else
        rm -rf /usr/local/icu631
        rm -rf /etc/ld.so.conf.d/icu631.conf
        Echo_Blue "[+] Installing icu4c-63_1..."
        cd ${cur_dir}/src
        Download_Files ${Libicu4c_63_1_DL} icu4c-63_1-src.tgz
        Tar_Cd icu4c-63_1-src.tgz icu/source
        ./configure --prefix=/usr/local/icu631
        Make_Install

        rm -rf ${cur_dir}/src/icu

        echo "/usr/local/icu631/lib" >/etc/ld.so.conf.d/icu631.conf
        ldconfig
    fi
}

Install_Icu671() {
    if [ -s /usr/local/icu671/bin/icu-config ] && [ -s /etc/ld.so.conf.d/icu671.conf ]; then
        echo "ICU 67.1 is already installed."
    else
        rm -rf /usr/local/icu671
        rm -rf /etc/ld.so.conf.d/icu671.conf
        Echo_Blue "[+] Installing icu4c-67_1..."
        cd ${cur_dir}/src
        Download_Files ${Libicu4c_67_1_DL} icu4c-67_1-src.tgz
        Tar_Cd icu4c-67_1-src.tgz icu/source
        ./configure --prefix=/usr/local/icu671
        Make_Install

        rm -rf ${cur_dir}/src/icu

        echo "/usr/local/icu671/lib" >/etc/ld.so.conf.d/icu671.conf
        ldconfig
    fi
}

Install_Icu721() {
    if [ -s /usr/local/icu721/bin/icu-config ] && [ -s /etc/ld.so.conf.d/icu721.conf ]; then
        echo "ICU 72.1 is already installed."
    else
        rm -rf /usr/local/icu721
        rm -rf /etc/ld.so.conf.d/icu721.conf
        Echo_Blue "[+] Installing icu4c-72_1..."
        cd ${cur_dir}/src
        Download_Files ${Libicu4c_72_1_DL} icu4c-72_1-src.tgz
        Tar_Cd icu4c-72_1-src.tgz icu/source
        ./configure --prefix=/usr/local/icu721
        Make_Install

        rm -rf ${cur_dir}/src/icu

        echo "/usr/local/icu721/lib" >/etc/ld.so.conf.d/icu721.conf
        ldconfig
    fi
}

Download_Boost() {
    Echo_Blue "[+] Download or use exist boost..."
    if [ "${DBSelect}" = "3" ] || echo "${mysql_version}" | grep -Eqi '^5\.7\.'; then
        if [ -s "${cur_dir}/src/${Boost_Ver}.tar.bz2" ]; then
            [[ -d "${cur_dir}/src/${Boost_Ver}" ]] && rm -rf "${cur_dir}/src/${Boost_Ver}"
            tar jxf ${cur_dir}/src/${Boost_Ver}.tar.bz2 -C ${cur_dir}/src
            MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/${Boost_Ver}"
        else
            cd ${cur_dir}/src/
            echo "Downloading ${Boost_Ver}.tar.bz2 ..."
            Download_Files ${Boost_DL} ${Boost_Ver}.tar.bz2
            tar jxf ${cur_dir}/src/${Boost_Ver}.tar.bz2
            cd -
            MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/${Boost_Ver}"
        fi
    elif [[ "${DBSelect}" =~ ^(4|5)$ ]] || echo "${mysql_version}" | grep -Eqi '^8\.'; then
       # Get_Boost_Ver=$(grep 'SET(BOOST_PACKAGE_NAME' cmake/boost.cmake | grep -oP '\d+(\_\d+){2}')
       Get_Boost_Ver=$(grep 'SET(BOOST_PACKAGE_NAME' cmake/boost.cmake | cut -d'"' -f2)
       Boost_Ver_Short=$(echo ${Get_Boost_Ver} | sed 's/boost_//' | tr '_' '.')
        if [ -s "${cur_dir}/src/${Get_Boost_Ver}.tar.bz2" ]; then
            [[ -d "${cur_dir}/src/${Get_Boost_Ver}" ]] && rm -rf "${cur_dir}/src/${Get_Boost_Ver}"
            tar jxf ${cur_dir}/src/${Get_Boost_Ver}.tar.bz2 -C ${cur_dir}/src
            MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/${Get_Boost_Ver}"
        else
            cd ${cur_dir}/src/
            echo "Downloading ${Get_Boost_Ver}.tar.bz2 ..."
            Download_Files https://archives.boost.io/release/${Boost_Ver_Short}/source/${Get_Boost_Ver}.tar.bz2 ${Get_Boost_Ver}.tar.bz2
            tar jxf ${Get_Boost_Ver}.tar.bz2
            MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/${Get_Boost_Ver}"
        fi
    fi
}

Install_Boost() {
    Echo_Blue "[+] Download or use exist boost..."
    if [ "${DBSelect}" = "3" ] || [ "${DBSelect}" = "4" ] || [ "${DBSelect}" = "5" ]; then
        if [ -d "${cur_dir}/src/${Mysql_Ver}/boost" ]; then
            MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/${Mysql_Ver}/boost"
        else
            Download_Boost
        fi
    elif echo "${mysql_version}" | grep -Eqi '^5\.7\.' || echo "${mysql_version}" | grep -Eqi '^8\.'; then
        if [ -d "${cur_dir}/src/mysql-${mysql_version}/boost" ]; then
            MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/mysql-${mysql_version}/boost"
        else
            Download_Boost
        fi
    fi
}

Install_Openssl() {
    if [ -s /usr/local/openssl/bin/openssl ] && [ -s /etc/ld.so.conf.d/openssl.conf ]; then
        echo "OpenSSL 1.0.2 is already installed."
    else
        rm -rf /usr/local/openssl
        rm -rf /etc/ld.so.conf.d/openssl.conf
        Echo_Blue "[+] Installing ${Openssl_Ver}"
        cd ${cur_dir}/src
        Download_Files ${Openssl_DL} ${Openssl_Ver}.tar.gz
        [[ -d "${Openssl_Ver}" ]] && rm -rf ${Openssl_Ver}
        Tar_Cd ${Openssl_Ver}.tar.gz ${Openssl_Ver}
        ./config -fPIC --prefix=/usr/local/openssl --openssldir=/usr/local/openssl
        make depend
        Make_Install

        rm -rf ${cur_dir}/src/${Openssl_Ver}

        echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/openssl.conf
        ldconfig
    fi

}

Install_Openssl_New() {

    if [ -s /usr/local/openssl1.1.1/bin/openssl ] && [ -s /etc/ld.so.conf.d/openssl1.1.1.conf ]; then
        echo "OpenSSL 1.1.1 is already installed."
    else
        rm -rf /usr/local/openssl1.1.1
        rm -rf /etc/ld.so.conf.d/openssl1.1.1.conf

        Echo_Blue "[+] Installing ${Openssl_New_Ver}"
        cd ${cur_dir}/src
        Download_Files ${Openssl_New_DL} ${Openssl_New_Ver}.tar.gz
        [[ -d "${Openssl_New_Ver}" ]] && rm -rf ${Openssl_New_Ver}
        Tar_Cd ${Openssl_New_Ver}.tar.gz ${Openssl_New_Ver}
        ./config enable-weak-ssl-ciphers -fPIC --prefix=/usr/local/openssl1.1.1 --openssldir=/usr/local/openssl1.1.1
        make depend
        Make_Install

        rm -rf ${cur_dir}/src/${Openssl_New_Ver}

        echo "/usr/local/openssl1.1.1/lib" > /etc/ld.so.conf.d/openssl1.1.1.conf
        ldconfig

        apache_with_ssl='--with-ssl=/usr/local/openssl1.1.1'
    fi
}

Install_Openssl3() {

    if [ -s /usr/local/openssl3/bin/openssl ] && [ -s /etc/ld.so.conf.d/openssl3.conf ]; then
        echo "OpenSSL 3 is already installed."
    else
        rm -rf /usr/local/openssl3
        rm -rf /etc/ld.so.conf.d/openssl3.conf
        Echo_Blue "[+] Installing ${Openssl_3_Ver}"
        cd ${cur_dir}/src
        Download_Files ${Openssl_3_DL} ${Openssl_3_Ver}.tar.gz
        [[ -d "${Openssl_3_Ver}" ]] && rm -rf ${Openssl_3_Ver}
        Tar_Cd ${Openssl_3_Ver}.tar.gz ${Openssl_3_Ver}
        ./config enable-weak-ssl-ciphers -fPIC --prefix=/usr/local/openssl3 --openssldir=/usr/local/openssl3
        make depend
        Make_Install

        rm -rf ${cur_dir}/src/${Openssl_3_Ver}

        if [ -s /etc/ld.so.conf.d/openssl3.conf ]; then
            rm -rf /etc/ld.so.conf.d/openssl3.conf
        fi

        echo "/usr/local/openssl3/lib" > /etc/ld.so.conf.d/openssl3.conf
        ldconfig
    fi

}

Install_Nghttp2() {
    if [[ ! -s /usr/local/nghttp2/lib/libnghttp2.so || ! -s /usr/local/nghttp2/include/nghttp2/nghttp2.h ]]; then
        Echo_Blue "[+] Installing ${Nghttp2_Ver}"
        cd ${cur_dir}/src
        Download_Files ${Nghttp2_DL} ${Nghttp2_Ver}.tar.xz
        [[ -d "${Nghttp2_Ver}" ]] && rm -rf ${Nghttp2_Ver}
        Tar_Cd ${Nghttp2_Ver}.tar.xz ${Nghttp2_Ver}
        ./configure --prefix=/usr/local/nghttp2
        Make_Install
        cd ${cur_dir}/src/
        rm -rf ${cur_dir}/src/${Nghttp2_Ver}
    fi
}

# Prior to PHP 7.4.0, libzip was bundled with PHP, and to compile the extension one needed to use the --enable-zip configure option.
# Building against the bundled libzip was discouraged as of PHP 7.3.0, but still possible by using the --without-libzip configure option.
# startin php 7.4 , use --with-zip. A --with-libzip=DIR configure option has been added to use a system libzip installation.
Install_Libzip() {
    if [ -d ${Custom_Libzip_Path} ]; then
        if [ "${UseOldOpenssl}" = 'y' ]; then
            echo "Custom Libzip already compiled with Openssl 1.0.2, skip."
        elif [ "${UseNewOpenssl}" = 'y' ]; then
            echo "Custom Libzip already compiled with Openssl 1.1.1, skip."
        fi
    else
        Echo_Blue "[+] Installing ${Libzip_Ver}"
        cd ${cur_dir}/src
        Download_Files ${Libzip_DL} ${Libzip_Ver}.tar.xz
        Tar_Cd ${Libzip_Ver}.tar.xz ${Libzip_Ver}
        mkdir -p build && cd build

        # Configure with CMake
        cmake .. \
            -DCMAKE_INSTALL_PREFIX="${Custom_Libzip_Path}" \
            -DCMAKE_PREFIX_PATH="${Custom_Openssl_Path}" \
            -DOPENSSL_ROOT_DIR="${Custom_Openssl_Path}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_GNUTLS=OFF \
            -DENABLE_OPENSSL=ON
          # -DENABLE_BZIP2=ON 
    
        # Build and install
        make -j"$(nproc)"
        make install
        rm -rf ${cur_dir}/src/${Libzip_Ver}
    fi

}

Distro_Lib_Opt() {
    if [ "${PM}" = "yum" ] || [ "${PM}" = "dnf" ]; then
        RHEL_Lib_Opt
    elif [ "${PM}" = "apt" ]; then
        Deb_Lib_Opt
    fi
}

RHEL_Lib_Opt() {
    ulimit -v unlimited

    if command -v systemd-detect-virt >/dev/null 2>&1 && [[ "$(systemd-detect-virt)" = "lxc" ]]; then
        cat >>/etc/security/limits.conf <<eof
* soft nofile 65535
* hard nofile 65535
eof
    else
        cat >>/etc/security/limits.conf <<eof
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
eof
    fi

    echo "fs.file-max=65535" >>/etc/sysctl.conf
}

Deb_Lib_Opt() {
    ulimit -v unlimited

    cat >>/etc/security/limits.conf <<eof
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
eof

    echo "fs.file-max=65535" >>/etc/sysctl.conf
}

Remove_Error_Libcurl() {
    if [ -s /usr/local/lib/libcurl.so ]; then
        rm -f /usr/local/lib/libcurl*
    fi
}

Add_Swap() {

    Disk_Avail=$(($(df -mP /var | tail -1 | awk '{print $4}' | sed s/[[:space:]]//g) / 1024))

    DD_Count='1024'
    if [[ "${MemTotal}" -lt 1024 ]]; then
        DD_Count='1024'
        if [[ "${Disk_Avail}" -lt 5 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 1024 && "${MemTotal}" -le 2048 ]]; then
        DD_Count='2048'
        if [[ "${Disk_Avail}" -lt 13 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 2048 && "${MemTotal}" -le 4096 ]]; then
        DD_Count='4096'
        if [[ "${Disk_Avail}" -lt 17 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 4096 && "${MemTotal}" -le 16384 ]]; then
        DD_Count='8192'
        if [[ "${Disk_Avail}" -lt 19 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 16384 ]]; then
        DD_Count='8192'
        if [[ "${Disk_Avail}" -lt 27 ]]; then
            Enable_Swap='n'
        fi
    fi
    Swap_Total=$(awk '/SwapTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
    if [[ "${Enable_Swap}" = "y" && "${Swap_Total}" -le 512 && ! -s /var/swapfile ]]; then
        echo "Add Swap file..."
        [ $(cat /proc/sys/vm/swappiness) -eq 0 ] && sysctl vm.swappiness=10
        dd if=/dev/zero of=/var/swapfile bs=1M count=${DD_Count}
        chmod 0600 /var/swapfile
        echo "Enable Swap..."
        /sbin/mkswap /var/swapfile
        /sbin/swapon /var/swapfile
        if [ $? -eq 0 ]; then
            [ $(grep -L '/var/swapfile' '/etc/fstab') ] && echo "/var/swapfile swap swap defaults 0 0" >>/etc/fstab
            /sbin/swapon -s
        else
            rm -f /var/swapfile
            echo "Add Swap Failed!"
        fi
    fi
}
