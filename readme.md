# GetLNMP One-Click Installer - Readme

## What is GetLNMP?

GetLNMP is a Linux Shell-based installer for deploying production LNMP (Nginx/MySQL/PHP), LNMPA (Nginx/MySQL/PHP/Apache), and LAMP (Apache/MySQL/PHP) environments on Debian, Ubuntu, RHEL, Rocky Linux, AlmaLinux VPSes, or dedicated servers.

## Supported Versions

| Distribution  |  EOL   | kernel | glibc | OpenSSL |  GCC  | ICU  |
| :-----------: | :----: | :----: | :---: | :-----: | :---: | :--: |
|   Debian 11   | 2026.8 |  5.1   | 2.31  |  1.1.1  | 10.2  | 67.1 |
|   Debian 12   | 2028.6 |  6.1   | 2.36  | 3.0.\*  | 12.2  | 72.1 |
|   Debian 13   | 2030.6 |  6.8   | 2.41  | 3.5.\*  |  14   | 74.1 |
| Ubuntu 22 LTS | 2027.4 |  5.15  | 2.35  | 3.0.\*  | 11.2  | 70.1 |
| Ubuntu 24 LTS | 2029.5 |  6.8   | 2.39  | 3.0.\*  | 13.2  | 74.2 |
| Ubuntu 26 LTS | 2031.4 |  7.0   | 2.43  | 3.5.\*  | 15.2  | 78.2 |
|    RHEL 8     | 2029.5 |  4.1   | 2.28  |  1.1.1  | 8.\*  | 60.3 |
|    RHEL 9     | 2032.5 |  5.1   | 2.34  | 3.5.\*  | 11.\* | 67.1 |
|    RHEL 10    | 2035.5 |  6.1   | 2.39  | 3.5.\*  |  14   | 74.2 |

## Installation Recommendations

The system OpenSSL version has a large impact on which PHP versions can be used. For best stability, we recommend:

Systems with OpenSSL 1.1.1: install PHP 7.3-8.\*  
Systems with OpenSSL 3.\*: install PHP 8.1+

- **Ubuntu 26 LTS uses GCC 15 and CMake 4, only supports PHP 8.1+**

In other words:

- Debian 11: PHP 7.3+
- Debian 12: PHP 8.1+
- Debian 13: PHP 8.1+
- Ubuntu 22 LTS: PHP 8.1+
- Ubuntu 24 LTS: PHP 8.1+
- **Ubuntu 26 LTS: ONLY support PHP 8.1+**
- RHEL 8/Rocky 8/AlmaLinux 8: PHP 7.3+
- RHEL 9/Rocky 9/AlmaLinux 9: PHP 8.1+
- RHEL 10/Rocky 10/AlmaLinux 10: PHP 8.1+

## Software Versions

- PHP currently supports PHP 7.3-7.4 and PHP 8.0-8.5.
- MySQL supports 5.7, 8.0, and 8.4.
- MariaDB supports 10.6, 10.11, 11.4, and 11.8.
- Nginx installs the latest stable version by default.
- Apache currently supports only 2.4.

## What Features Does GetLNMP Provide?

GetLNMP supports custom Nginx and PHP compile options, custom website and database directories, Let's Encrypt/ZeroSSL free SSL certificate generation, unattended installation, multiple PHP versions in LNMP mode, standalone Nginx/MySQL/MariaDB/PureFTPd installation, and many utility scripts. These include virtual host management, firewall management, FTP user management, Nginx/MySQL/MariaDB/PHP upgrades, one-click installation of common PHP modules such as exif, fileinfo, ldap, bz2, sodium, imap, and swoole, cache components such as Redis, Memcached, OPcache, and APCu, MySQL root password reset, automatic restart on 502 errors, log rotation, SSH protection with Fail2Ban, backups, and more.

- GetLNMP official site: <https://getlnmp.com>
- Author: getlnmp <admin@getlnmp.com>

## Installing GetLNMP

Before installation, update system first (`apt update && apt upgrade` or `dnf clean all && dnf update`) and make sure `wget` and `git` are installed.

If you see `wget: command not found`, install it with `yum install wget` or `apt-get install wget`.
If you see `git: command not found`, install it with `yum install git` or `apt-get install git`.

To avoid interruption from disconnected SSH sessions, `screen` is recommended. You can run `screen -S getlnmp` first, then run the GetLNMP installation command:

`git clone https://github.com/getlnmp/getlnmp.git && cd getlnmp && ./install.sh {lnmp|lnmpa|lamp}`

If the connection drops, use `screen -r getlnmp` to reconnect.

## Common Usage

**Run the following commands from the GetLNMP package directory.**

### Custom Parameters

The `lnmp.conf` file can be used to customize the download server, website/database directories, Nginx modules, and PHP compile parameters. It is used during both installation and upgrade. If you change default parameters, back up this file.

### FTP Server

Run `./pureftpd.sh` to install PureFTPd. You can manage it with `lnmp ftp {add|list|del}`.

### Firewall Management

`conf/lnmp-fw` is a universal firewall port management script. It uses `firewall-cmd` on RHEL/Rocky/Alma/CentOS/Fedora systems and `ufw` on Debian/Ubuntu systems. Firewall backend support in this helper is independent from the main GetLNMP installer OS support scope.

Before use, copy it to a system command path, for example: `cp conf/lnmp-fw /usr/local/bin/lnmp-fw`.

Common commands:

- Allow a port: `lnmp-fw allow <port> [tcp|udp|all]`
- Deny a port: `lnmp-fw deny <port> [tcp|udp|all]`
- Delete an allow rule: `lnmp-fw delete-allow <port> [tcp|udp|all]`
- Delete a deny rule: `lnmp-fw delete-deny <port> [tcp|udp|all]`
- Show firewall status: `lnmp-fw status`
- Reload firewall: `lnmp-fw reload`

Examples:

- Allow HTTP: `lnmp-fw allow 80 tcp`
- Allow HTTPS: `lnmp-fw allow 443 tcp`
- Allow DNS over UDP: `lnmp-fw allow 53 udp`
- Allow both TCP and UDP: `lnmp-fw allow 53 all`
- Deny the MySQL port: `lnmp-fw deny 3306 tcp`
- Delete the allow rule for port 8080: `lnmp-fw delete-allow 8080 tcp`

Note: when running `deny` or `delete-allow` against an SSH port, interactive confirmation is required. For unattended scripts, add `--force`, for example `lnmp-fw deny 22 tcp --force`, or set `LNMP_FW_FORCE=1`.

### Upgrade Script

Run `./upgrade.sh` and follow the prompts, or pass an argument directly:

`./upgrade.sh {nginx|mysql|mariadb|php|phpa|mphp|m2m|phpmyadmin}`

- `nginx`: upgrade to any Nginx version.
- `mysql`: upgrade MySQL to any version. MySQL upgrades are risky; although data is backed up automatically, you should still make your own backup.
- `mariadb`: upgrade the installed MariaDB. Although data is backed up automatically, you should still make your own backup.
- `m2m`: upgrade from MySQL to MariaDB. Although data is backed up automatically, you should still make your own backup.
- `php`: upgrade PHP for LNMP only. Most PHP versions are supported.
- `phpa`: upgrade PHP for LNMPA/LAMP. Most PHP versions are supported.
- `mphp`: upgrade tool for multiple PHP versions. It only supports minor-version upgrades such as 7.2.x to 7.2.x. Install a new major version directly.
- `phpmyadmin`: upgrade phpMyAdmin.

### Add-ons

Run:

`./addons.sh {install|uninstall} {memcached|opcache|redis|apcu|imagemagick|ioncube|exif|fileinfo|ldap|bz2|sodium|imap|swoole}`

Add-on installation notes:

#### Cache Acceleration

- `redis`: install Redis.
- `memcached`: choose either the php-memcache or php-memcached extension. php-memcached is recommended.
- `opcache`: can be managed at `http://yourIP/ocp.php`.
- `apcu`: installs the APCu PHP extension and supports PHP 7. It can be managed at `http://yourIP/apc.php`.

**Do not install multiple cache acceleration extensions. Installing several may cause website issues.**

#### PHP Components/Modules

- `exif`: image EXIF metadata reading module.
- `fileinfo`: file MIME type detection module. At least 1 GB RAM is required, otherwise installation may fail.
- `ldap`: LDAP extension.
- `bz2`: bzip2 compression extension.
- `imap`: IMAP module.
- `swoole`: PHP coroutine framework module. Third-party modules cannot be enabled for installation through `lnmp.conf`.

#### Image Processing

- Install/uninstall ImageMagick with `./addons.sh {install|uninstall} imageMagick`. ImageMagick path: `/usr/local/imagemagick/bin/`.

#### Loaders and Encryption

- Install IonCube with `./addons.sh {install|uninstall} ionCube`.
- Install/uninstall the Sodium encryption library extension with `./addons.sh {install|uninstall} sodium`. It is commonly required for services such as WeChat Pay. PHP versions below 7.2 do not support enabling it through `lnmp.conf`.

#### Other Common Scripts

- Option 1: run `./install.sh mphp` to install multiple PHP versions. This only supports LNMP mode. When running `lnmp vhost add`, select the desired PHP version. Alternatively, update the nginx virtual host config by replacing `include enable-php.conf` with `include enable-php5.6.conf`, changing `5.6` to the major PHP version you installed, such as `5.*` or `7.0`.
- Option 2: run `./install.sh db` to install only MySQL or MariaDB.
- Option 3: run `./install.sh nginx` to install only Nginx.

**The following tools are in the `tools` directory of the LNMP package** and can be copied elsewhere to run:

- Option 4: run `./reset_mysql_root_password.sh` to reset the MySQL/MariaDB root password.
- Option 5: run `./check502.sh` to check whether php-fpm is down and restart it on 502 errors. Use it with crontab.
- Option 6: run `./cut_nginx_logs.sh` for log rotation.
- Option 7: run `./remove_disable_function.sh` to remove disabled PHP functions.

### Unattended Installation

**Unattended command generator: <https://getlnmp.com/auto.html>**

Set the following environment variables to run a fully unattended installation:

| Variable         | Meaning                                                                                                                                                      |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| LNMP_Auto        | Enable unattended automatic installation                                                                                                                     |
| DBSelect         | Database version number                                                                                                                                      |
| DB_Root_Password | Database root password. It cannot be empty. Not required if no database is installed                                                                         |
| PHPSelect        | PHP version number                                                                                                                                           |
| SelectMalloc     | Memory allocator version number                                                                                                                              |
| ServerAdmin      | Administrator email. Required only for LNMPA and LAMP modes                                                                                                  |
| RHELRepo         | Optional. Set to `local` to use local repositories on RHEL. If unset, the 163 CentOS mirror is used                                                          |
| CheckMirror      | Optional. Skip download mirror checks during installation, useful for offline installation                                                                   |
| Bin              | Optional. Use binary installation for MySQL 5.7/8.0/8.4 and MariaDB, `y` or `n`. Binary mode is used by default; offline mode defaults to source compilation |

Apache is always installed as version 2.4 from source, so no Apache version variable is required.

Program version numbers:

| Database (`DBSelect`)  | Number | PHP (`PHPSelect`) | Number | Memory Allocator (`SelectMalloc`) | Number |
| :--------------------: | :----: | :---------------: | :----: | :-------------------------------: | :----: |
|       MySQL 5.7        |   3    |      PHP 7.2      |   8    |          None (default)           |   1    |
|       MySQL 8.0        |   4    |      PHP 7.3      |   9    |             Jemalloc              |   2    |
|       MySQL 8.4        |   5    |      PHP 7.4      |   10   |             TCMalloc              |   3    |
|      MariaDB 10.4      |   7    |      PHP 8.0      |   11   |                                   |
|      MariaDB 10.5      |   8    |      PHP 8.1      |   12   |                                   |
|      MariaDB 10.6      |   9    |      PHP 8.2      |   13   |                                   |
|     MariaDB 10.11      |   10   |      PHP 8.3      |   14   |                                   |
| MariaDB 11.4 (default) |   11   |      PHP 8.4      |   15   |                                   |
|      MariaDB 11.8      |   12   |      PHP 8.5      |   16   |                                   |
|      No database       |   0    |                   |        |                                   |

The interactive installer defaults to MariaDB 11.4 (`DBSelect=11`) and PHP 8.3 (`PHPSelect=14`).

Example: in LNMP mode, install MariaDB 11.4, set the database root password to `getlnmp.com`, enable InnoDB, install PHP 8.3, and use no memory allocator. First run screen if needed, then download and extract the LNMP package:

`git clone https://github.com/getlnmp/getlnmp.git && cd getlnmp && ./install.sh {lnmp|lnmpa|lamp}`

Then set unattended parameters and install:

`LNMP_Auto="y" DBSelect="11" DB_Root_Password="getlnmp.com" PHPSelect="14" SelectMalloc="1" ./install.sh lnmp`

If required parameters are missing, prompts will still appear for the missing options.

### Uninstall

- To uninstall LNMP, LNMPA, or LAMP, run `./uninstall.sh` and follow the prompts.

## Status Management

- LNMP/LNMPA/LAMP status management: `lnmp {start|stop|reload|restart|kill|status}`
- Nginx status management: `lnmp nginx` or `systemctl {start|stop|reload|restart} nginx`
- MySQL status management: `lnmp mysql` or `systemctl {start|stop|restart|reload|force-reload|status} mysql`
- MariaDB status management: `lnmp mariadb` or `systemctl {start|stop|restart|reload|force-reload|status} mariadb`
- PHP-FPM status management: `lnmp php-fpm` or `systemctl {start|stop|quit|restart|reload|logrotate} php-fpm`
- PureFTPd status management: `lnmp pureftpd` or `systemctl {start|stop|restart|kill|status} pureftp`
- Apache status management: `lnmp httpd` or `systemctl {start|stop|restart|graceful|graceful-stop|configtest|status} httpd`

## Virtual Host Management

- Add: `lnmp vhost add`
- Delete: `lnmp vhost del`
- List: `lnmp vhost list`
- Database management: `lnmp database {add|list|edit|del}`
- FTP user management: `lnmp ftp {add|list|edit|del|show}`
- Add SSL: `lnmp ssl add`
- Add wildcard/multi-domain SSL: `lnmp dnsssl {ali|cf|dp|he|gd|aws|namecheap|namesilo}`. This requires a domain DNS API.

## Related Web Interfaces

- phpMyAdmin: `http://yourIP/phpmyadmin/`
- phpinfo: `http://yourIP/phpinfo.php`
- Zend Opcache management: `http://yourIP/ocp.php`
- APCu management: `http://yourIP/apc.php`

## LNMP Directories and Files

### Directory Locations

- Nginx: `/usr/local/nginx/`
- MySQL: `/usr/local/mysql/`
- MariaDB: `/usr/local/mariadb/`
- PHP: `/usr/local/php/`
- Multiple PHP directory: `/usr/local/php5.6/`. The version number changes depending on the installed version.
- PHP extension plugin configuration directory: `/usr/local/php/conf.d/`
- Jemalloc (only when the Jemalloc allocator is selected): `/usr/local/jemalloc/`
- TCMalloc (only when the TCMalloc allocator is selected): `/usr/local/tcmalloc/`
- phpMyAdmin: `/home/wwwroot/default/phpmyadmin/`
- Default virtual host website directory: `/home/wwwroot/default/`
- Nginx log directory: `/home/wwwlogs/`

### Configuration Files

- Nginx main configuration file: `/usr/local/nginx/conf/nginx.conf`
- MySQL/MariaDB configuration file: `/etc/my.cnf`
- PHP configuration file: `/usr/local/php/etc/php.ini`
- PHP-FPM configuration file: `/usr/local/php/etc/php-fpm.conf`
- PureFTPd configuration file: `/usr/local/pureftpd/etc/pure-ftpd.conf`
- Apache configuration file: `/usr/local/apache/conf/httpd.conf`

### `lnmp.conf` Configuration Parameters

|       Parameter       |                                                 Description                                                 |                               Example / Default                               |
| :-------------------: | :---------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------: |
|    Download_Mirror    |                                 Download mirror, used when `Use_Official=n`                                 |    Default: `https://lax.getlnmp.com`. Change it if downloads are abnormal    |
|     Use_Official      |                              Download files from their official upstream sites                              |           Default: `y`; set to `n` to use `Download_Mirror` instead           |
|        country        |                         Server country code, used to pick a closer download mirror                          |                                   e.g. `US`                                   |
| Nginx_Modules_Options |                                Add Nginx modules or other compile parameters                                |               `--add-module=/path/to/third-party-module-source`               |
|  PHP_Modules_Options  |                                    Add PHP modules or compile parameters                                    |   `--enable-exif`; some modules require dependencies to be installed first    |
|      OS_Timezone      |                                               System timezone                                               |                              Default: `Etc/UTC`                               |
|     PHP_Timezone      |                                                PHP timezone                                                 |                                Default: `UTC`                                 |
|     Open_DB_Port      |                    Whether to open port 3306 in the firewall for remote database access                     |                                 Default: `n`                                  |
|    MySQL_Data_Dir     |                                          MySQL database directory                                           |                       Default: `/usr/local/mysql/data`                        |
|   MariaDB_Data_Dir    |                                         MariaDB database directory                                          |                      Default: `/usr/local/mariadb/data`                       |
|  Default_Website_Dir  |                                   Default virtual host website directory                                    |                       Default: `/home/wwwroot/default`                        |
|   Enable_Nginx_Lua    |                                  Whether to install Lua support for Nginx                                   | Default: `n`; Lua support can be used by some Lua-based WAF website firewalls |
| Enable_Ngx_FancyIndex |                                  Whether to install the fancyIndex module                                   |       Default: `n`; fancyIndex is a third-party directory index module        |
|      Enable_Swap      |                                             Whether to add swap                                             |    Default: `y`; improves compile/install success rate when memory is low     |
|    Enable_PHP_Exif    |                                     Whether to add the PHP exif module                                      |                      Default: `n`; set to `y` to install                      |
|  Enable_PHP_Fileinfo  |                                   Whether to add the PHP fileinfo module                                    |                   Default: `y`; requires more than 1 GB RAM                   |
|    Enable_PHP_Ldap    |                                     Whether to add the PHP ldap module                                      |                      Default: `n`; set to `y` to install                      |
|    Enable_PHP_Bz2     |                                      Whether to add the PHP bz2 module                                      |                      Default: `n`; set to `y` to install                      |
|   Enable_PHP_Sodium   | Whether to add the PHP sodium module. PHP versions below 7.2 do not support enabling it through `lnmp.conf` |                                 Default: `y`                                  |
|    Enable_PHP_Imap    |                                     Whether to add the PHP imap module                                      |                      Default: `n`; set to `y` to install                      |
|     SelectMalloc      |       Memory allocator to keep using on MySQL/MariaDB upgrades (`1` none, `2` Jemalloc, `3` TCMalloc)       |                 Set to match the value chosen at install time                 |

## Technical Support
