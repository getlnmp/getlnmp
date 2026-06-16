#!/usr/bin/env bash

Add_Firewall_Rules() {
    Get_Management_IP
    if [ "${PM}" = "apt" ]; then
        Apply_UFW
    elif [ "${PM}" = "yum" ]; then
        Apply_Firewalld
    else
        echo "Error: Unsupported OS. Script supports RHEL-family or Debian-family only."
        exit 1
    fi
}

Get_Management_IP() {
    # --- CONFIGURATION: AUTO-DETECT IP ---
    # This block attempts to find the IP you are SSHing from.
    # It tries SSH_CLIENT first, then falls back to 'who am i'.

    # 1. Try environment variable (works if sudo -E is used)
    DETECTED_IP=$(echo $SSH_CLIENT | awk '{print $1}')

    # 2. If empty, try 'who am i' (works in standard sudo)
    if [[ -z "$DETECTED_IP" ]]; then
        DETECTED_IP=$(who am i | awk '{print $NF}' | tr -d '()')
    fi

    # 3. Validation: Ensure it looks like an IP (simple check)
    if [[ "$DETECTED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        MANAGEMENT_IPS="$DETECTED_IP"
        echo "-> Auto-detected Management IP: $MANAGEMENT_IPS"
    else
        MANAGEMENT_IPS=""
        echo "-> Warning: Could not detect SSH IP. Management whitelist will be disabled."
        echo "   (This is normal if you are on the console/KVM, not SSH)"
    fi
}

Apply_Firewalld() {
    echo "--- Configuring Firewalld (RHEL/Rocky/Alma) ---"

    # Ensure firewalld is installed (just in case it's a minimal cloud image)
    if ! command -v firewall-cmd &>/dev/null; then
        echo "Firewalld not found. Installing..."
        dnf install -y firewalld
    fi

    # Enable and Start
    systemctl enable --now firewalld

    # Default zone: only force 'public' if the operator hasn't already picked a zone
    # (e.g. 'trusted' for a private VPC, 'internal' for a multi-zone setup).
    current_zone=$(firewall-cmd --get-default-zone 2>/dev/null)
    if [ -n "${current_zone}" ] && [ "${current_zone}" != "public" ]; then
        echo "Default firewalld zone is already '${current_zone}', leaving it unchanged."
    else
        firewall-cmd --set-default-zone=public
    fi

    # --- Management IPs (Trusted Zone) ---
    if [[ -n "$MANAGEMENT_IPS" ]]; then
        for ip in $MANAGEMENT_IPS; do
            echo "Whitelisting Management IP: $ip"
            firewall-cmd --permanent --zone=trusted --add-source="$ip"
        done
    fi

    # --- Standard Rules ---
    # Note: Loopback & Established connections are handled automatically by firewalld core.

    # Rules 3, 4, 5: Allow SSH, HTTP, HTTPS
    echo "Opening SSH, HTTP, HTTPS..."
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https

    # Rule 6: Drop MySQL (3306) unless the operator opted in to remote DB access via lnmp.conf
    if [ "${Open_DB_Port:-n}" != "y" ]; then
        # We remove the port first (in case it was added previously) then add a rich rule to reject it.
        firewall-cmd --permanent --remove-port=3306/tcp &>/dev/null
        firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="3306" protocol="tcp" reject'
        firewall-cmd --permanent --add-rich-rule='rule family="ipv6" port port="3306" protocol="tcp" reject'
    else
        echo "Open_DB_Port=y, leaving port 3306 reachable per lnmp.conf."
    fi

    # Rule 7: Ensure ICMP (Ping) is allowed
    firewall-cmd --permanent --remove-icmp-block=echo-request &>/dev/null

    # Reload to apply changes
    echo "Reloading Firewall..."
    firewall-cmd --reload
    echo "[SUCCESS] Firewalld configured."
}

Apply_UFW() {
    echo "--- Configuring UFW (Debian/Ubuntu) ---"

    # Check if UFW is installed
    if ! command -v ufw &>/dev/null; then
        echo "UFW not found. Installing..."
        apt-get update
        apt-get install -y ufw
    fi

    # Reset UFW to ensure a clean slate (User iptables rules implied a specific state)
    echo "Resetting UFW rules..."
    ufw --force reset

    # --- Management IPs ---
    if [[ -n "$MANAGEMENT_IPS" ]]; then
        for ip in $MANAGEMENT_IPS; do
            echo "Whitelisting Management IP: $ip"
            ufw allow from "$ip"
        done
    fi

    # --- Standard Rules ---
    # Default Policies (Drop Incoming, Allow Outgoing)
    # This covers your IPTables Rule 2 (Established) automatically.
    ufw default deny incoming
    ufw default allow outgoing

    # Rule 3, 4, 5: Allow SSH, HTTP, HTTPS
    # Detect a non-default sshd port so hardened hosts (sshd on e.g. 2222) don't get locked out.
    ssh_port=$(awk '/^[[:space:]]*Port[[:space:]]+[0-9]+/ {print $2; exit}' /etc/ssh/sshd_config 2>/dev/null)
    ssh_port="${ssh_port:-22}"
    echo "Opening SSH (port ${ssh_port}), HTTP, HTTPS..."
    ufw allow "${ssh_port}/tcp"
    ufw allow 80/tcp
    ufw allow 443/tcp

    # Rule 6: Drop MySQL (3306)
    # Explicitly deny 3306.
    ufw deny 3306/tcp

    # Rule 7: ICMP
    # UFW allows ping by default via /etc/ufw/before.rules configuration.
    # Allow ping
    sed -i 's/^-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/' \
        /etc/ufw/before.rules || true

    # Enable Firewall (force 'yes' to confirmation prompts)
    Echo_Yellow "About to enable UFW with default-deny incoming."
    Echo_Yellow "Detected SSH port: ${ssh_port}. Management whitelist: ${MANAGEMENT_IPS:-NONE}."
    Echo_Yellow "Make sure you can reach this host on the SSH port above before continuing."
    echo "Enabling UFW..."
    ufw --force enable
    echo "[SUCCESS] UFW configured."
}

Add_LNMP_Startup() {
    echo "Add Startup and Starting LNMP..."
    [ -s /bin/lnmp ] && cp -a /bin/lnmp "/bin/lnmp.bak.$(date +%Y%m%d%H%M%S)"
    \cp ${cur_dir}/conf/lnmp /bin/lnmp
    \cp ${cur_dir}/conf/lnmp-fw /bin/lnmp-fw
    chmod +x /bin/lnmp
    chmod +x /bin/lnmp-fw
    LNMP_Created_Bin_Lnmp="y"
    systemctl enable nginx
    systemctl start nginx
    if [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        systemctl enable mariadb
        systemctl start mariadb
        # sed -i 's#/etc/init.d/mysql#/etc/init.d/mariadb#' /bin/lnmp
    elif [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        systemctl enable mysql
        systemctl start mysql
    fi
    systemctl enable php-fpm
    systemctl start php-fpm
}

Add_LNMPA_Startup() {
    echo "Add Startup and Starting LNMPA..."
    [ -s /bin/lnmpa ] && cp -a /bin/lnmpa "/bin/lnmpa.bak.$(date +%Y%m%d%H%M%S)"
    \cp ${cur_dir}/conf/lnmpa /bin/lnmpa
    chmod +x /bin/lnmpa
    systemctl enable nginx
    systemctl start nginx
    if [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        systemctl enable mariadb
        systemctl start mariadb
    elif [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        systemctl enable mysql
        systemctl start mysql
    fi
    systemctl enable httpd
    systemctl start httpd
}

Add_LAMP_Startup() {
    echo "Add Startup and Starting LAMP..."
    [ -s /bin/lamp ] && cp -a /bin/lamp "/bin/lamp.bak.$(date +%Y%m%d%H%M%S)"
    \cp ${cur_dir}/conf/lamp /bin/lamp
    chmod +x /bin/lamp
    systemctl enable httpd
    systemctl start httpd
    if [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        systemctl enable mariadb
        systemctl start mariadb
    elif [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        systemctl enable mysql
        systemctl start mysql
    fi
}

Check_Nginx_Files() {
    isNginx=""
    echo "============================== Check install =============================="
    echo "Checking ..."
    if [[ -s /usr/local/nginx/conf/nginx.conf && -s /usr/local/nginx/sbin/nginx ]]; then
        Echo_Green "Nginx: OK"
        isNginx="ok"
    else
        Echo_Red "Error: Nginx install failed."
    fi
}

Check_DB_Files() {
    isDB=""
    if [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        if [[ -s /usr/local/mariadb/bin/mariadb && -s /etc/my.cnf ]]; then
            Echo_Green "MariaDB: OK"
            isDB="ok"
        else
            Echo_Red "Error: MariaDB install failed."
        fi
    elif [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        if [[ -s /usr/local/mysql/bin/mysql && -s /etc/my.cnf ]]; then
            Echo_Green "MySQL: OK"
            isDB="ok"
        else
            Echo_Red "Error: MySQL install failed."
        fi
    elif [ "${DBSelect}" = "0" ]; then
        Echo_Green "Do not install MySQL/MariaDB."
        isDB="ok"
    fi
}

Check_PHP_Files() {
    isPHP=""
    if [ "${Stack}" = "lnmp" ]; then
        if [[ -s /usr/local/php/sbin/php-fpm && -s /usr/local/php/etc/php.ini && -s /usr/local/php/bin/php ]]; then
            Echo_Green "PHP: OK"
            Echo_Green "PHP-FPM: OK"
            isPHP="ok"
        else
            Echo_Red "Error: PHP install failed."
        fi
    else
        if [[ -s /usr/local/php/bin/php && -s /usr/local/php/etc/php.ini ]]; then
            Echo_Green "PHP: OK"
            isPHP="ok"
        else
            Echo_Red "Error: PHP install failed."
        fi
    fi
}

Check_Apache_Files() {
    isApache=""
    if [[ "${PHPSelect}" =~ ^([6789]|10)$ ]]; then
        if [[ -s /usr/local/apache/bin/httpd && -s /usr/local/apache/modules/libphp7.so && -s /usr/local/apache/conf/httpd.conf ]]; then
            Echo_Green "Apache: OK"
            isApache="ok"
        else
            Echo_Red "Error: Apache install failed."
        fi
    elif [[ "${PHPSelect}" =~ ^1[1-6]$ ]]; then
        if [[ -s /usr/local/apache/bin/httpd && -s /usr/local/apache/modules/libphp.so && -s /usr/local/apache/conf/httpd.conf ]]; then
            Echo_Green "Apache: OK"
            isApache="ok"
        else
            Echo_Red "Error: Apache install failed."
        fi
    else
        if [[ -s /usr/local/apache/bin/httpd && -s /usr/local/apache/modules/libphp5.so && -s /usr/local/apache/conf/httpd.conf ]]; then
            Echo_Green "Apache: OK"
            isApache="ok"
        else
            Echo_Red "Error: Apache install failed."
        fi
    fi
}

Clean_DB_Src_Dir() {
    echo "Clean database src directory..."
    if [[ "${DBSelect}" =~ ^[1-5]$ ]]; then
        [ -d "${cur_dir}/src/${Mysql_Ver}" ] && rm -rf "${cur_dir}/src/${Mysql_Ver}"
    elif [[ "${DBSelect}" =~ ^([6789]|1[0-2])$ ]]; then
        [ -d "${cur_dir}/src/${Mariadb_Ver}" ] && rm -rf "${cur_dir}/src/${Mariadb_Ver}"
    fi
    if [[ "${DBSelect}" = "3" ]]; then
        [ -d "${cur_dir}/src/${Boost_Ver}" ] && rm -rf "${cur_dir}/src/${Boost_Ver}"
    elif [[ "${DBSelect}" = "4" ]] || [[ "${DBSelect}" = "5" ]]; then
        [ -d "${cur_dir}/src/${Get_Boost_Ver}" ] && rm -rf "${cur_dir}/src/${Get_Boost_Ver}"
    fi
}

Clean_PHP_Src_Dir() {
    echo "Clean PHP src directory..."
    [ -d "${cur_dir}/src/${Php_Ver}" ] && rm -rf "${cur_dir}/src/${Php_Ver}"
}

Clean_Web_Src_Dir() {
    echo "Clean Web Server src directory..."
    if [ "${Stack}" = "lnmp" ]; then
        [ -d "${cur_dir}/src/${Nginx_Ver}" ] && rm -rf "${cur_dir}/src/${Nginx_Ver}"
    elif [ "${Stack}" = "lnmpa" ]; then
        [ -d "${cur_dir}/src/${Nginx_Ver}" ] && rm -rf "${cur_dir}/src/${Nginx_Ver}"
        [ -d "${cur_dir}/src/${Apache_Ver}" ] && rm -rf "${cur_dir}/src/${Apache_Ver}"
    elif [ "${Stack}" = "lamp" ]; then
        [ -d "${cur_dir}/src/${Apache_Ver}" ] && rm -rf "${cur_dir}/src/${Apache_Ver}"
    fi
    [ -d "${cur_dir}/src/${Openssl_Ver}" ] && rm -rf "${cur_dir}/src/${Openssl_Ver}"
    [ -d "${cur_dir}/src/${Openssl_New_Ver}" ] && rm -rf "${cur_dir}/src/${Openssl_New_Ver}"
    [ -d "${cur_dir}/src/${Pcre_Ver}" ] && rm -rf "${cur_dir}/src/${Pcre_Ver}"
    [ -d "${cur_dir}/src/${LuaNginxModule}" ] && rm -rf "${cur_dir}/src/${LuaNginxModule}"
    [ -d "${cur_dir}/src/${NgxDevelKit}" ] && rm -rf "${cur_dir}/src/${NgxDevelKit}"
    [ -d "${cur_dir}/src/${NgxFancyIndex_Ver}" ] && rm -rf "${cur_dir}/src/${NgxFancyIndex_Ver}"
}

Print_Sucess_Info() {
    Clean_Web_Src_Dir
    echo "+------------------------------------------------------------------------+"
    echo "|           GetLNMP V${GetLNMP_Ver} for ${DISTRO} Linux Server           |"
    echo "+------------------------------------------------------------------------+"
    echo "|         For more information please visit https://www.getlnmp.com      |"
    echo "+------------------------------------------------------------------------+"
    echo "|    lnmp status manage: lnmp {start|stop|reload|restart|kill|status}    |"
    echo "+------------------------------------------------------------------------+"
    echo "|  phpMyAdmin: http://IP/phpmyadmin/                                     |"
    echo "|  phpinfo: http://IP/phpinfo.php                                        |"
    echo "+------------------------------------------------------------------------+"
    echo "|  Add VirtualHost: lnmp vhost add                                       |"
    echo "+------------------------------------------------------------------------+"
    echo "|  Default directory: ${Default_Website_Dir}                              |"
    if [ "${DBSelect}" != "0" ]; then
        echo "+------------------------------------------------------------------------+"
        echo "|  MySQL/MariaDB root password: ${DB_Root_Password}                          |"
    fi
    echo "+------------------------------------------------------------------------+"
    lnmp status
    if command -v ss >/dev/null 2>&1; then
        ss -ntl
    else
        netstat -ntl
    fi
    stop_time=$(date +%s)
    echo "Installation takes $(((stop_time - start_time) / 60)) minutes."
    Echo_Green "GetLNMP V${GetLNMP_Ver} installation completed!"
    LNMP_Installation_Status="y"
}

Print_Failed_Info() {
    if [ -s /bin/lnmp ] && [ -n "${LNMP_Created_Bin_Lnmp}" ]; then
        rm -f /bin/lnmp
    fi
    Echo_Red "Sorry, Failed to install LNMP!"
    Echo_Red "Please visit https://github.com/getlnmp/getlnmp feedback errors and logs."
    Echo_Red "You can download /root/getlnmp-install.log from your server,and upload getlnmp-install.log to GetLNMP github."
}

Check_LNMP_Install() {
    Check_Nginx_Files
    Check_DB_Files
    Check_PHP_Files
    if [[ "${isNginx}" = "ok" && "${isDB}" = "ok" && "${isPHP}" = "ok" ]]; then
        Print_Sucess_Info
    else
        Print_Failed_Info
    fi
}

Check_LNMPA_Install() {
    Check_Nginx_Files
    Check_DB_Files
    Check_PHP_Files
    Check_Apache_Files
    if [[ "${isNginx}" = "ok" && "${isDB}" = "ok" && "${isPHP}" = "ok" && "${isApache}" = "ok" ]]; then
        Print_Sucess_Info
    else
        Print_Failed_Info
    fi
}

Check_LAMP_Install() {
    Check_Apache_Files
    Check_DB_Files
    Check_PHP_Files
    if [[ "${isApache}" = "ok" && "${isDB}" = "ok" && "${isPHP}" = "ok" ]]; then
        Print_Sucess_Info
    else
        Print_Failed_Info
    fi
}
