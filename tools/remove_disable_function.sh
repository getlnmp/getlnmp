#!/usr/bin/env bash

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# ==========================================
# Configuration
# ==========================================

#only for our getlnmp installation, if you use other php version, please change this path accordingly
PHP_INI="/usr/local/php/etc/php.ini" 

# Check if user is root
if [[ $EUID -ne 0 ]]; then
    echo "Error: You must be root to run this script. Please use sudo or root."
    exit 1
fi

clear
echo "+-------------------------------------------------------------------+"
echo "|              Remove PHP disable_functions for LNMP                |"
echo "+-------------------------------------------------------------------+"
echo "|         A tool to remove PHP disable_functions for LNMP           |"
echo "+-------------------------------------------------------------------+"
echo "|        For more information please visit https://getlnmp.com      |"
echo "+-------------------------------------------------------------------+"
echo "|              Usage: ./remove_disable_function.sh                  |"
echo "+-------------------------------------------------------------------+"
echo ""

# Ensure php.ini exists before proceeding
if [[ ! -f "$PHP_INI" ]]; then
    echo "Error: Cannot find $PHP_INI. Please check your PHP installation path."
    exit 1
fi

echo "Options:"
echo "  1: Remove ALL php disable_functions(Default)"
echo "  2: Only remove 'scandir' function"
echo "  3: Only remove 'exec' function"
echo ""
read -p "Please input 1, 2, or 3 [Default: 1]: " choice
choice=${choice:-1} # Defaults to 1 if the user just presses Enter

# Use a case statement for cleaner logic routing
case "$choice" in
    1) echo "Action: You will remove ALL php disable_functions." ;;
    2) echo "Action: You will remove 'scandir' from disable_functions." ;;
    3) echo "Action: You will remove 'exec' from disable_functions." ;;
    *) echo "Error: Invalid option selected. Exiting." && exit 1 ;;
esac

echo ""
# Modern bash native way to wait for a single keystroke
read -n 1 -s -r -p "Press any key to start... or Press Ctrl+C to cancel"
echo -e "\n"

# ==========================================
# Functions
# ==========================================

# Create a backup of php.ini just in case
cp -a "$PHP_INI" "${PHP_INI}.bak_$(date +%s)"

replace_php_ini_from_tmp() {
    local tmp_file="$1"

    if cat "$tmp_file" > "$PHP_INI"; then
        rm -f "$tmp_file"
    else
        rm -f "$tmp_file"
        echo "Error: Failed to update $PHP_INI."
        exit 1
    fi
}

remove_all_disable_functions() {
    local tmp_file

    tmp_file=$(mktemp "${PHP_INI}.tmp.XXXXXX") || exit 1
    awk '
        /^[[:space:]]*disable_functions[[:space:]]*=/ && !/^[[:space:]]*;/ {
            print "disable_functions ="
            next
        }
        { print }
    ' "$PHP_INI" > "$tmp_file" && replace_php_ini_from_tmp "$tmp_file"
}

remove_specific_function() {
    local func_name="$1"
    local tmp_file

    tmp_file=$(mktemp "${PHP_INI}.tmp.XXXXXX") || exit 1
    awk -v func_name="$func_name" '
        /^[[:space:]]*disable_functions[[:space:]]*=/ && !/^[[:space:]]*;/ {
            value = $0
            sub(/^[^=]*=/, "", value)

            output = ""
            count = split(value, functions, ",")
            for (i = 1; i <= count; i++) {
                item = functions[i]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
                if (item == "" || tolower(item) == tolower(func_name)) {
                    continue
                }
                output = output ? output ", " item : item
            }

            print "disable_functions = " output
            next
        }
        { print }
    ' "$PHP_INI" > "$tmp_file" && replace_php_ini_from_tmp "$tmp_file"
}

# Execute based on choice
case "$choice" in
    1) remove_all_disable_functions ;;
    2) remove_specific_function "scandir" ;;
    3) remove_specific_function "exec" ;;
esac

# ==========================================
# Restart Services
# ==========================================

# Intelligently detect which web service or PHP-FPM service is actually running
if systemctl is-active --quiet httpd; then
    echo "Restarting Apache (httpd)..."
    systemctl restart httpd
elif systemctl is-active --quiet apache2; then
    echo "Restarting Apache (apache2)..."
    systemctl restart apache2
elif [[ -x /usr/local/apache/bin/httpd ]] && pgrep httpd >/dev/null; then
    echo "Restarting compiled Apache..."
    systemctl restart httpd
else
    # Find the exact name of the running PHP-FPM service (e.g., php-fpm, php8.2-fpm, etc.)
    FPM_SERVICE=$(systemctl list-units --type=service --state=running | grep -i php | grep fpm | awk '{print $1}' | head -n 1)
    
    if [[ -n "$FPM_SERVICE" ]]; then
        echo "Restarting $FPM_SERVICE..."
        systemctl restart "$FPM_SERVICE"
    else
        echo "Restarting default php-fpm..."
        systemctl restart php-fpm
    fi
fi

echo "+-------------------------------------------------+"
echo "| Remove php disable function completed, enjoy it!|"
echo "+-------------------------------------------------+"
