#!/usr/bin/env bash
# website: https://getlnmp.com

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# ==========================================
# Initialization
# ==========================================

# Modern check if user is root
if [[ $EUID -ne 0 ]]; then
    echo "Error: You must be root to run this script!"
    exit 1
fi

clear
echo "+-------------------------------------------------------------------+"
echo "|             Remove open_basedir restriction for LNMP              |"
echo "+-------------------------------------------------------------------+"
echo "|        A tool to remove open_basedir restriction for LNMP         |"
echo "+-------------------------------------------------------------------+"
echo "|        For more information please visit https://getlnmp.com      |"
echo "+-------------------------------------------------------------------+"
echo "|          Usage: ./remove_open_basedir_restriction.sh              |"
echo "+-------------------------------------------------------------------+"
echo ""

# ==========================================
# Main Logic
# ==========================================

while true; do
    read -r -p "Enter website root directory (or type 'q' to quit): " website_root
    
    if [[ "$website_root" == "q" || "$website_root" == "quit" ]]; then
        echo "Exiting without making changes."
        exit 0
    fi

    # Strip any accidental trailing slashes
    website_root="${website_root%/}"

    if [[ -d "$website_root" ]]; then
        ini_file="${website_root}/.user.ini"
        
        # Step 1: Remove local .user.ini restriction (if it exists)
        if [[ -f "$ini_file" ]]; then
            echo "-> Removing immutable flag from $ini_file..."
            chattr -i "$ini_file"
            
            echo "-> Deleting $ini_file..."
            rm -f "$ini_file"
        else
            echo "-> Notice: $ini_file does not exist locally. Proceeding to global config."
        fi
        
        # Step 2: Remove global fastcgi parameter restriction
        nginx_conf="/usr/local/nginx/conf/fastcgi.conf"
        if [[ -f "$nginx_conf" ]]; then
            echo "-> Updating Nginx configuration ($nginx_conf)..."
            sed -i -E 's/^[[:space:]]*fastcgi_param[[:space:]]+PHP_ADMIN_VALUE/#fastcgi_param PHP_ADMIN_VALUE/g' "$nginx_conf"
        else
            echo "-> Warning: Could not find $nginx_conf."
        fi
        
        # Step 3: Restart Services
        echo "-> Restarting services to apply changes..."
        
        FPM_SERVICE=$(systemctl list-units --type=service --state=running | grep -i php | grep fpm | awk '{print $1}' | head -n 1)
        if [[ -n "$FPM_SERVICE" ]]; then
            systemctl restart "$FPM_SERVICE"
        else
            systemctl restart php-fpm 2>/dev/null
        fi
        
        if systemctl is-active --quiet nginx; then
            systemctl reload nginx
        elif [[ -x /usr/local/nginx/sbin/nginx ]]; then
            /usr/local/nginx/sbin/nginx -s reload
        fi
        
        echo "Done. open_basedir restrictions have been completely removed."
        break
    else
        echo "Error: '$website_root' is not a directory or does not exist. Please try again."
        echo ""
    fi
done