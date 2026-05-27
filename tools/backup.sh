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
ENABLE_FTP=0 # 0: disable; 1: enable
FTP_HOST="1.2.3.4"
FTP_USERNAME="getlnmp"
FTP_PASSWORD="yourftppassword"
FTP_DIR="backup"

# ==========================================
# Initialization & Auto-Discovery
# ==========================================
TODAY=$(date +"%Y%m%d")

# 1. Auto-detect the database dump command (MariaDB or MySQL)
if [ -x "/usr/local/mariadb/bin/mariadb-dump" ]; then
    DB_DUMP_CMD="/usr/local/mariadb/bin/mariadb-dump"
elif [ -x "/usr/local/mariadb/bin/mysqldump" ]; then
    DB_DUMP_CMD="/usr/local/mariadb/bin/mysqldump"
elif [ -x "/usr/local/mysql/bin/mysqldump" ]; then
    DB_DUMP_CMD="/usr/local/mysql/bin/mysqldump"
elif command -v mariadb-dump >/dev/null 2>&1; then
    DB_DUMP_CMD=$(command -v mariadb-dump)
elif command -v mysqldump >/dev/null 2>&1; then
    DB_DUMP_CMD=$(command -v mysqldump)
else
    echo "ERROR: mariadb-dump/mysqldump command not found in /usr/local/mariadb, /usr/local/mysql, or global PATH."
    exit 1
fi

# 2. Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_HOME" ]; then
    mkdir -p "$BACKUP_HOME"
fi

# 3. Check for lftp if FTP is enabled
if [[ "$ENABLE_FTP" -eq 1 ]]; then
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
    local dir_name
    local parent_dir
    local archive_name

    dir_name=$(basename "$target_path")
    parent_dir=$(dirname "$target_path")
    archive_name="${BACKUP_HOME}/www-${dir_name}-${TODAY}.tar.gz"

    if [[ ! -d "$target_path" ]]; then
        echo "ERROR: Directory not found: $target_path"
        return 1
    fi

    echo "Archiving directory: $target_path"
    if ! tar -zcf "$archive_name" -C "$parent_dir" "$dir_name"; then
        echo "ERROR: Failed to archive directory: $target_path"
        rm -f "$archive_name"
        return 1
    fi
}

backup_database() {
    local db_name="$1"
    local sql_file="${BACKUP_HOME}/db-${db_name}-${TODAY}.sql"
    ##local tmp_sql_file="${sql_file}.tmp.$$"

    echo "Dumping database: $db_name using $DB_DUMP_CMD"
    # MYSQL_PWD works securely for both MySQL and MariaDB
    if MYSQL_PWD="$DB_PASSWORD" "$DB_DUMP_CMD" -u"$DB_USERNAME" "$db_name" > "$sql_file"; then
        echo "Database $db_name dumped successfully to $sql_file"
    else
        echo "ERROR: Failed to dump database: $db_name"
        rm -f "$sql_file"
        return 1
    fi
}

cleanup_old_backups() {
    echo "Cleaning up local backups older than $RETENTION_DAYS days..."
    find "$BACKUP_HOME" -type f -name "www-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete &&
        find "$BACKUP_HOME" -type f -name "db-*.sql" -mtime +"$RETENTION_DAYS" -delete
}

upload_ftp_backups() {
    echo "Uploading backup files to FTP..."

    lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "$FTP_HOST" << EOF
set cmd:fail-exit yes
lcd "$BACKUP_HOME"
cd "$FTP_DIR"
mput *-${TODAY}.tar.gz
mput *-${TODAY}.sql
bye
EOF
}

# ==========================================
# Execution
# ==========================================
echo "--- Starting Backup Process ---"
BACKUP_FAILED=0

for dir in "${DIRECTORIES_TO_BACKUP[@]}"; do
    backup_directory "$dir" || BACKUP_FAILED=1
done

for db in "${DATABASES_TO_BACKUP[@]}"; do
    backup_database "$db" || BACKUP_FAILED=1
done

if [[ "$BACKUP_FAILED" -ne 0 ]]; then
    echo "ERROR: One or more backup tasks failed. Skipping upload and retention cleanup."
    exit 1
fi

if [[ "$ENABLE_FTP" -eq 1 ]]; then
    if ! upload_ftp_backups; then
        echo "ERROR: FTP upload failed. Skipping retention cleanup."
        exit 1
    fi
    echo "FTP upload complete."
fi

if ! cleanup_old_backups; then
    echo "ERROR: Failed to clean up old local backups."
    exit 1
fi

echo "--- Backup Process Completed ---"
