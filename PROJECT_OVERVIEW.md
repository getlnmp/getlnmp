# PROJECT_OVERVIEW

## 1. Project Purpose

This project is a Bash-based installer and manager for production LNMP, LNMPA, and LAMP stacks on Debian-family and RHEL-family Linux servers. It installs, configures, starts, upgrades, uninstalls, and manages web stack components including nginx, Apache httpd, PHP, MySQL, MariaDB, Redis, Memcached, phpMyAdmin, PHP extensions, firewall rules, and systemd services.

The primary installer is `install.sh`. Supporting scripts provide add-on installation, upgrades, uninstallation, PureFTPd installation, backup, log rotation, and small repair utilities.

## 2. Supported Stack Modes

- `lnmp`: Linux + nginx + MySQL/MariaDB + PHP-FPM.
- `lnmpa`: Linux + nginx front end + Apache back end + MySQL/MariaDB + PHP.
- `lamp`: Linux + Apache + MySQL/MariaDB + PHP.
- `nginx`: nginx-only installation path.
- `db`: database-only installation path.
- `mphp`: multiple-PHP installation path for LNMP mode.

OpenResty support is unclear. The inspected source supports nginx with optional lua-nginx modules, but no OpenResty-specific installer function was found.

## 3. Supported Operating Systems

The code detects more distributions than it currently allows to continue. `Block_Dist_Name` permits only Debian/Ubuntu for apt-based systems and RHEL/Rocky/Alma/Oracle for yum-family systems. Other detected distributions are rejected by the current main installer flow.

### Debian Family

- Debian 11, 12, 13 are listed in `readme.md`.
- Debian is detected generically in `include/main.sh`.
- Raspbian, Deepin, Mint, Kali, UOS, and Kylin Desktop are detected, but `Block_Dist_Name` rejects apt-based distributions other than Debian and Ubuntu.

### Ubuntu Family

- Ubuntu 22 LTS and 24 LTS are listed in `readme.md`.
- Older Ubuntu releases from 10.04 through 23.10 are handled by `Ubuntu_Modify_Source` for old-releases mirror behavior.
- Ubuntu is detected generically in `include/main.sh`.

### RHEL Family

- RHEL 8, 9, and 10 are listed in `readme.md`.
- RHEL 5, 6, 7, 8, 9, and 10 are detected by `Get_RHEL_Version`, but current support for 5-7 is unclear because the README focuses on 8-10.
- Oracle Linux is allowed by `Block_Dist_Name`.
- CentOS, CentOS Stream, Fedora, Amazon Linux, Alibaba/Alibaba Cloud Linux, Aliyun Linux, openEuler, Anolis OS, Kylin Advanced Server, OpenCloudOS, and Huawei Cloud EulerOS are detected, but `Block_Dist_Name` rejects yum-family distributions other than RHEL, Rocky, Alma, and Oracle.

### Rocky Linux

- Rocky Linux 8, 9, and 10 are implied by the README's RHEL-family PHP guidance.
- Rocky Linux is detected generically in `include/main.sh`.

### AlmaLinux

- AlmaLinux 8, 9, and 10 are implied by the README's RHEL-family PHP guidance.
- AlmaLinux is detected generically in `include/main.sh`.

### Oracle Linux

- Oracle Linux is detected and allowed by `Block_Dist_Name`.
- Oracle Linux 8 and 9 have dependency branches in `RHEL_Dependent`; other versions are unclear.

### Other

- Other apt/yum-family distributions are detected in `Get_Dist_Name`, but current main installer support is unclear or rejected by `Block_Dist_Name`.

## 4. Main Components

- nginx: compiled from source into `/usr/local/nginx`, configured from `conf/nginx.conf` or `conf/nginx_a.conf`, and managed by `nginx.service`.
- Apache httpd: compiled from source into `/usr/local/apache`, configured from `conf/httpd24-*.conf`, and managed by `httpd.service`.
- PHP: compiled from source into `/usr/local/php`, configured with php.ini and PHP-FPM settings, and optionally built with many compatibility patches and extensions.
- MySQL: installed from source or generic binaries depending on version, architecture, and `Bin`; data path defaults to `/usr/local/mysql/data`.
- MariaDB: installed from source or binaries depending on selection; data path defaults to `/usr/local/mariadb/data`.
- Redis: installs Redis server under `/usr/local/redis`, PHP Redis extension, `redis.service`, and a test file.
- Memcached: installs memcached server under `/usr/local/memcached`, optional php-memcache/php-memcached extension, `memcached.service`, and a test file.
- phpMyAdmin: referenced by README and upgrade scripts; installation path is under `${Default_Website_Dir}/phpmyadmin`.
- acme.sh / SSL: `Acmesh_Ver` and download URLs exist; certificate request flow is not clear from the inspected install path.
- Firewall: applies firewalld on yum-family systems and UFW on apt-family systems, opens SSH/HTTP/HTTPS, rejects TCP 3306, and optionally whitelists a detected management IP.
- systemd services: copies unit files from `init.d/` into `/etc/systemd/system`, reloads systemd, enables, and starts services.
- PureFTPd: separate `pureftpd.sh` installer and uninstaller.
- PHP add-ons: opcache, APCu, ionCube, ImageMagick/imagick, exif, fileinfo, LDAP, bz2, sodium, imap, swoole, and older eAccelerator/XCache scripts.

Current version variables in `include/version.sh` map DB selections to MySQL 5.5.62, 5.6.51, 5.7.44, 8.0.37, 8.4.7 and MariaDB 5.5.68, 10.4.34, 10.5.29, 10.6.24, 10.11.15, 11.4.9, 11.8.5. `DB_Info` still labels MariaDB 10.4 as 10.4.33, so that menu/version mismatch should be treated carefully.

PHP version variables map selections to PHP 5.2.17 through PHP 8.5.5, but only `Install_PHP_55` through `Install_PHP_85` were found in `include/php.sh`. `install.sh` still dispatches `Install_PHP_52`, `Install_PHP_53`, and `Install_PHP_54`, but those function definitions were not found in the inspected source; PHP selections 1-3 are therefore unclear/broken in the current tree.

## 5. Main Entry Points

| File | Purpose | Type |
|---|---|---|
| `install.sh` | Main LNMP/LNMPA/LAMP/nginx/db/mphp installer. | Installer |
| `addons.sh` | Installs or uninstalls cache, optimizer, image, loader, and PHP extension add-ons. | Add-on manager |
| `upgrade.sh` | Dispatches nginx, MySQL, MariaDB, PHP, phpMyAdmin, and multiple-PHP upgrades. | Upgrade manager |
| `uninstall.sh` | Removes LNMP, LNMPA, or LAMP installations after confirmation. | Uninstaller |
| `pureftpd.sh` | Installs or uninstalls PureFTPd and opens FTP ports. | Optional component installer |
| `tools/backup.sh` | Backs up configured website directories and databases. | Helper script |
| `tools/check502.sh` | Checks a URL and restarts PHP-FPM on HTTP 502. | Helper script |
| `tools/cut_nginx_logs.sh` | Rotates nginx logs. | Helper script |
| `tools/reset_mysql_root_password.sh` | Resets MySQL/MariaDB root password. | Helper script |
| `tools/remove_disable_function.sh` | Removes selected PHP disabled functions. | Helper script |
| `tools/remove_open_basedir_restriction.sh` | Removes PHP open_basedir restrictions. | Helper script |
| `tools/denyhosts.sh`, `tools/fail2ban.sh` | Install SSH protection tools. | Helper installers |

## 6. Main Runtime Paths

| Path | Purpose | Controlled By |
|---|---|---|
| `/usr/local/nginx` | nginx install prefix. | Fixed in `Install_Nginx` |
| `/usr/local/apache` | Apache install prefix. | Fixed in `Install_Apache_24` |
| `/usr/local/php` | Main PHP install prefix. | Fixed in PHP install functions |
| `/usr/local/php7.3` through `/usr/local/php8.5` | Multiple-PHP prefixes. | `include/multiplephp.sh` |
| `/usr/local/mysql` | MySQL install prefix. | MySQL install functions |
| `/usr/local/mysql/data` | MySQL data directory. | `MySQL_Data_Dir` |
| `/usr/local/mariadb` | MariaDB install prefix. | MariaDB install functions |
| `/usr/local/mariadb/data` | MariaDB data directory. | `MariaDB_Data_Dir` |
| `/usr/local/redis` | Redis install prefix. | `Install_Redis` |
| `/usr/local/memcached` | Memcached install prefix. | `Install_Memcached` |
| `/usr/local/libmemcached` | libmemcached install prefix. | `Install_PHPMemcached` |
| `/usr/local/imagemagick` | ImageMagick install prefix. | `include/imageMagick.sh` |
| `/usr/local/ioncube` | ionCube loader path. | `include/ionCube.sh` |
| `/home/wwwroot/default` | Default website root. | `Default_Website_Dir` |
| `/home/wwwlogs` | Website/nginx logs. | Fixed in web installers and tools |
| `/home/backup` | Backup destination. | `Backup_Home` in `tools/backup.sh` |
| `${cur_dir}/src` | Source tarballs and extracted source trees. | `cur_dir` |
| `/root/getlnmp-install.log` | Main install log. | `install.sh` |
| `/root/upgrade_*${Upgrade_Date}.log` | Upgrade logs. | `upgrade.sh` |
| `/etc/systemd/system/*.service` | Installed systemd unit files. | Component installers |
| `/etc/my.cnf` | MySQL/MariaDB configuration. | DB config functions |
| `${PHP_Path}/conf.d/*.ini` | PHP extension ini files. | Add-on functions |

## 7. Generated Files

- `/bin/lnmp`: copied from `conf/lnmp`, `conf/lnmpa`, or `conf/lamp`.
- `/etc/systemd/system/nginx.service`, `httpd.service`, `php-fpm.service`, `mysql.service`, `mariadb.service`, `redis.service`, `memcached.service`, `pureftpd.service`.
- `/usr/local/nginx/conf/nginx.conf`, `proxy.conf`, `proxy-pass-php.conf`, `pathinfo.conf`, `enable-php*.conf`, rewrite rules, examples, and vhost directory.
- `/usr/local/apache/conf/httpd.conf`, `extra/httpd-vhosts.conf`, `extra/httpd-ssl.conf`, `extra/httpd-default.conf`, `extra/mod_remoteip.conf`, and vhost directory.
- `/usr/local/php/etc/php.ini`, PHP-FPM config, and `${PHP_Path}/conf.d/*.ini` extension loaders.
- `/etc/my.cnf`, `~/.my.cnf`, database initialization files, and database data directories.
- Firewall rules through UFW or firewalld.
- Test files under `${Default_Website_Dir}` such as `phpinfo.php`, Redis and Memcached test pages, phpMyAdmin, and default index/prober files.
- Backup files for upgraded components under `/usr/local/old*${Upgrade_Date}` and database dumps under `/root/*_all_backup${Upgrade_Date}.sql`.
