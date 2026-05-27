#!/usr/bin/env bash
#function:cut nginx log files
#author: https://getlnmp.com

# ==========================================
# Configuration
# ==========================================
LOG_FILES_PATH="/home/wwwlogs"
LOG_FILES_NAME=("access" "getlnmpcom" "getlnmpnet")
NGINX_SBIN="/usr/local/nginx/sbin/nginx"
SAVE_DAYS=30

# ==========================================
# Initialization
# ==========================================
# Calculate dates once to improve efficiency and prevent edge-case bugs around midnight
YESTERDAY_YEAR=$(date -d "yesterday" +"%Y")
YESTERDAY_MONTH=$(date -d "yesterday" +"%m")
YESTERDAY_DATE=$(date -d "yesterday" +"%Y%m%d")

LOG_DEST_DIR="${LOG_FILES_PATH}/${YESTERDAY_YEAR}/${YESTERDAY_MONTH}"

# ==========================================
# Execution
# ==========================================

# 1. Create destination directory
mkdir -p "$LOG_DEST_DIR"

# 2. Rotate log files safely
ROTATE_FAILED=0
for log_name in "${LOG_FILES_NAME[@]}"; do
    src_log="${LOG_FILES_PATH}/${log_name}.log"
    dest_log="${LOG_DEST_DIR}/${log_name}_${YESTERDAY_DATE}.log"

    # Only attempt to move if the source file actually exists
    if [ -f "$src_log" ]; then
        if ! mv "$src_log" "$dest_log"; then
            echo "Error: Failed to move $src_log to $dest_log."
            ROTATE_FAILED=1
        fi
    else
        echo "Warning: Log file $src_log not found, skipping."
    fi
done

if [ "$ROTATE_FAILED" -ne 0 ]; then
    echo "Error: Log rotation failed. Skipping nginx reload and retention cleanup."
    exit 1
fi

# 3. Reload Nginx to release file descriptors and generate new log files
if [ -x "$NGINX_SBIN" ]; then
    "$NGINX_SBIN" -s reload
    if [ $? -ne 0 ]; then
        echo "Error: Failed to reload Nginx."
        exit 1
    fi
else
    echo "Error: Nginx binary not found or not executable at $NGINX_SBIN"
    exit 1
fi

# 4. Safely delete logs older than the retention period
find "$LOG_FILES_PATH" -type f -name "*.log" -mtime "+$SAVE_DAYS" -delete

# 5. Clean up any empty month/year directories left behind
find "$LOG_FILES_PATH" -mindepth 1 -type d -empty -delete 2>/dev/null

echo "Log rotation completed successfully."
