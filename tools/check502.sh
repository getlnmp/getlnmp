#!/usr/bin/env bash
# website: https://getlnmp.com

# ==========================================
# Configuration Variables
# ==========================================
URL="https://yourdomain.com"
# Change this to your specific PHP-FPM version if needed (e.g., php7.4-fpm, php8.1-fpm)
PHP_FPM_SERVICE="php-fpm" 
LOG_FILE="/var/log/502-monitor.log"

# ==========================================
# Execution
# ==========================================

# Get the current timestamp for logging
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_DIR=$(dirname "$LOG_FILE")

if [[ -z "$LOG_FILE" || "$LOG_FILE" == "/" ]]; then
    echo "[$TIMESTAMP] ERROR: LOG_FILE is not configured correctly." >&2
    exit 1
fi

if [[ ! -d "$LOG_DIR" ]]; then
    if ! mkdir -p "$LOG_DIR"; then
        echo "[$TIMESTAMP] ERROR: Failed to create log directory: $LOG_DIR" >&2
        exit 1
    fi
fi

if ! touch "$LOG_FILE" 2>/dev/null || [[ ! -w "$LOG_FILE" ]]; then
    echo "[$TIMESTAMP] ERROR: Log file is not writable: $LOG_FILE" >&2
    exit 1
fi

# Fetch only the HTTP status code using curl
if ! command -v curl >/dev/null 2>&1; then
    echo "[$TIMESTAMP] ERROR: curl command not found." >> "$LOG_FILE"
    exit 1
fi

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL")
if ! [[ "$HTTP_STATUS" =~ ^[0-9]{3}$ ]]; then
    echo "[$TIMESTAMP] ERROR: Invalid HTTP status from $URL: $HTTP_STATUS" >> "$LOG_FILE"
    exit 1
fi

if [ "$HTTP_STATUS" = "000" ]; then
    echo "[$TIMESTAMP] ERROR: Unable to connect to $URL. No action taken." >> "$LOG_FILE"
    exit 1
fi

# Check if the status code is exactly 502
if [ "$HTTP_STATUS" = "502" ]; then
    echo "[$TIMESTAMP] CRITICAL: 502 Bad Gateway detected on $URL. Restarting $PHP_FPM_SERVICE..." >> "$LOG_FILE"
    
    # Restart the PHP-FPM service
    systemctl restart "$PHP_FPM_SERVICE"
    
    # Check if the restart command was successful
    if [ $? -eq 0 ]; then
        echo "[$TIMESTAMP] SUCCESS: $PHP_FPM_SERVICE restarted successfully." >> "$LOG_FILE"
    else
        echo "[$TIMESTAMP] ERROR: Failed to restart $PHP_FPM_SERVICE. Check systemctl status." >> "$LOG_FILE"
    fi
else
    # Uncomment the line below if you want a log entry every time it checks successfully
    # echo "[$TIMESTAMP] OK: Site is returning $HTTP_STATUS. No action taken." >> "$LOG_FILE"
    exit 0
fi
