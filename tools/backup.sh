#!/usr/bin/env bash

#Function: Backup website and mysql database
#Website: https://getlnmp.com

#IMPORTANT!!!Please Setting the following Values!

# ==========================================
# Configuration
# ==========================================
BACKUP_HOME="/home/backup"

# Directories and Databases to Backup
DIRECTORIES_TO_BACKUP=("/home/wwwroot/getlnmp.com" "/home/wwwroot/getlnmp.net")
DATABASES_TO_BACKUP=("getlnmpcom" "getlnmpnet")

# Database Credentials (Works for both MySQL and MariaDB)
DB_USERNAME="root"
DB_PASSWORD="yourrootpassword"

# Retention and FTP Settings
RETENTION_DAYS=3
ENABLE_FTP=0 # 0: enable; 1: disable
FTP_HOST="1.2.3.4"
FTP_USERNAME="getlnmp"
FTP_PASSWORD="yourftppassword"
FTP_DIR="backup"

# ==========================================
# Initialization & Auto-Discovery
# ==========================================
TODAY=$(date +"%Y%m%d")

# 1. Auto-detect the database dump command (MariaDB or MySQL)
if [ -f "/usr/local/mariadb/bin/mysqldump" ]; then
    DB_DUMP_CMD="/usr/local/mariadb/bin/mysqldump"
elif [ -f "/usr/local/mysql/bin/mysqldump" ]; then
    DB_DUMP_CMD="/usr/local/mysql/bin/mysqldump"
elif command -v mysqldump >/dev/null 2>&1; then
    DB_DUMP_CMD=$(command -v mysqldump)
else
    echo "ERROR: mysqldump command not found in /usr/local/mariadb, /usr/local/mysql, or global PATH."
    exit 1
fi

# 2. Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_HOME" ]; then
    mkdir -p "$BACKUP_HOME"
fi

# 3. Check for lftp if FTP is enabled
if [[ "$ENABLE_FTP" -eq 0 ]]; then
    if ! command -v lftp >/dev/null 2>&1; then
        echo "ERROR: lftp command not found. Please install it."
        exit 1
    fi
fi

# ==========================================
# Functions
# ==========================================
backup_directory() {
    local target_path="$1"
    local dir_name=$(basename "$target_path")
    local parent_dir=$(dirname "$target_path")
    local archive_name="${BACKUP_HOME}/www-${dir_name}-${TODAY}.tar.gz"

    echo "Archiving directory: $target_path"
    tar -zcf "$archive_name" -C "$parent_dir" "$dir_name"
}

backup_database() {
    local db_name="$1"
    local sql_file="${BACKUP_HOME}/db-${db_name}-${TODAY}.sql"

    echo "Dumping database: $db_name using $DB_DUMP_CMD"
    # MYSQL_PWD works securely for both MySQL and MariaDB
    MYSQL_PWD="$DB_PASSWORD" "$DB_DUMP_CMD" -u"$DB_USERNAME" "$db_name" > "$sql_file"
}

# ==========================================
# Execution
# ==========================================
echo "--- Starting Backup Process ---"

for dir in "${DIRECTORIES_TO_BACKUP[@]}"; do
    backup_directory "$dir"
done

for db in "${DATABASES_TO_BACKUP[@]}"; do
    backup_database "$db"
done

echo "Cleaning up local backups older than $RETENTION_DAYS days..."
find "$BACKUP_HOME" -type f -name "www-*.tar.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_HOME" -type f -name "db-*.sql" -mtime +$RETENTION_DAYS -delete

if [[ "$ENABLE_FTP" -eq 0 ]]; then
    echo "Uploading backup files to FTP..."
    cd "$BACKUP_HOME" || exit 1
    
    lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "$FTP_HOST" << EOF
cd "$FTP_DIR"
mput *-${TODAY}.tar.gz
mput *-${TODAY}.sql
bye
EOF
    echo "FTP upload complete."
fi

echo "--- Backup Process Completed ---"