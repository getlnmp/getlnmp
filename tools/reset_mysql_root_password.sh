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

DB_SQL_Escape() {
    local value="$1"
    local sq="'"

    value="${value//\\/\\\\}"
    value="${value//${sq}/${sq}${sq}}"
    printf "%s" "${value}"
}

Stop_Safe_Mode_DB() {
    local child_pid
    local pids=()
    local pid

    if [[ -n "${MYSQLD_SAFE_PID:-}" ]] && command -v pgrep >/dev/null 2>&1; then
        while read -r child_pid; do
            [[ -n "${child_pid}" ]] && pids+=("${child_pid}")
        done < <(pgrep -P "${MYSQLD_SAFE_PID}" 2>/dev/null)
    fi

    if [[ -n "${MYSQLD_SAFE_PID:-}" ]] && kill -0 "${MYSQLD_SAFE_PID}" 2>/dev/null; then
        pids+=("${MYSQLD_SAFE_PID}")
    fi

    for pid in "${pids[@]}"; do
        kill -TERM "${pid}" 2>/dev/null
    done

    for pid in "${pids[@]}"; do
        if kill -0 "${pid}" 2>/dev/null; then
            wait "${pid}" 2>/dev/null || true
        fi
    done
}

Cleanup_Reset_On_Exit() {
    local exit_code=$?

    trap - EXIT INT TERM

    if [[ "${RESET_CLEANUP_DONE:-0}" -ne 1 ]]; then
        if [[ "${SAFE_MODE_STARTED:-0}" -eq 1 ]]; then
            Stop_Safe_Mode_DB
        fi

        if [[ "${DB_SERVICE_STOPPED:-0}" -eq 1 ]]; then
            systemctl start "${DB_NAME}" 2>/dev/null
        fi
    fi

    exit "${exit_code}"
}

clear
echo "+-------------------------------------------------------------------+"
echo "|            Reset MySQL/MariaDB root Password for LNMP             |"
echo "+-------------------------------------------------------------------+"
echo "|       A tool to reset MySQL/MariaDB root password for LNMP        |"
echo "+-------------------------------------------------------------------+"
echo "|       For more information please visit https://getlnmp.com       |"
echo "+-------------------------------------------------------------------+"
echo "|           Usage: ./reset_mysql_root_password.sh                   |"
echo "+-------------------------------------------------------------------+"
echo ""

# ==========================================
# Engine Detection
# ==========================================

if [[ -x /usr/local/mariadb/bin/mysql ]]; then
    DB_NAME="mariadb"
    DB_VER=$(/usr/local/mariadb/bin/mysql_config --version)
    DB_BIN_DIR="/usr/local/mariadb/bin"
elif [[ -x /usr/local/mysql/bin/mysql ]]; then
    DB_NAME="mysql"
    DB_VER=$(/usr/local/mysql/bin/mysql_config --version)
    DB_BIN_DIR="/usr/local/mysql/bin"
else
    echo "Error: MySQL/MariaDB binaries not found in standard LNMP paths!"
    exit 1
fi

echo "Detected Engine: $DB_NAME (Version: $DB_VER)"

# ==========================================
# Secure Password Input
# ==========================================

while true; do
    # Use -s to hide the password input from the screen
    read -r -s -p "Enter New ${DB_NAME} root password: " DB_ROOT_PASSWORD
    echo ""
    
    if [[ -z "${DB_ROOT_PASSWORD}" ]]; then
        echo "Error: Password cannot be empty!"
        continue
    fi

    read -r -s -p "Confirm New ${DB_NAME} root password: " DB_ROOT_PASSWORD_CONFIRM
    echo ""

    if [[ "${DB_ROOT_PASSWORD}" != "${DB_ROOT_PASSWORD_CONFIRM}" ]]; then
        echo "Error: Passwords do not match! Please try again."
        echo ""
    else
        break
    fi
done

# ==========================================
# Reset Execution
# ==========================================

echo "-> Stopping ${DB_NAME} service..."
systemctl stop "${DB_NAME}"
DB_SERVICE_STOPPED=1
trap Cleanup_Reset_On_Exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "-> Starting ${DB_NAME} in safe mode (--skip-grant-tables)..."
"${DB_BIN_DIR}/mysqld_safe" --skip-grant-tables --skip-networking >/dev/null 2>&1 &
MYSQLD_SAFE_PID=$!
SAFE_MODE_STARTED=1

# Wait for the safe mode daemon to initialize
sleep 5

echo "-> Updating ${DB_NAME} root password..."
DB_ROOT_PASSWORD_SQL=$(DB_SQL_Escape "${DB_ROOT_PASSWORD}")

# Updated Regex to include MariaDB 11.x and streamline MySQL 8.x matching
if echo "${DB_VER}" | grep -Eqi '^5\.7\.|^8\.[0-9]\.|^10\.([2-9]|1[0-9])\.|^11\.[0-9]\.'; then
    "${DB_BIN_DIR}/mysql" -u root << EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD_SQL}';
EOF
else
    # Legacy fallback for very old versions (MySQL 5.6 / MariaDB 10.1 and older)
    "${DB_BIN_DIR}/mysql" -u root << EOF
UPDATE mysql.user SET password = Password('${DB_ROOT_PASSWORD_SQL}') WHERE User = 'root';
FLUSH PRIVILEGES;
EOF
fi

if [[ $? -eq 0 ]]; then
    echo "-> Password reset successfully in database. Shutting down safe mode..."
    Stop_Safe_Mode_DB
    SAFE_MODE_STARTED=0
    
    # Wait for the process to actually terminate before trying to start systemd service
    sleep 5
    
    echo "-> Restarting the standard ${DB_NAME} service..."
    systemctl start "${DB_NAME}"
    DB_SERVICE_STOPPED=0
    RESET_CLEANUP_DONE=1
    trap - EXIT INT TERM
    echo ""
    echo "+-------------------------------------------------+"
    echo "| Password successfully reset!                    |"
    echo "+-------------------------------------------------+"
else
    echo "Error: Failed to reset ${DB_NAME} root password. Check the database error logs."

    # Attempt cleanup if it fails
    Stop_Safe_Mode_DB
    SAFE_MODE_STARTED=0
    systemctl start "${DB_NAME}" 2>/dev/null
    DB_SERVICE_STOPPED=0
    RESET_CLEANUP_DONE=1
    trap - EXIT INT TERM
    exit 1
fi
