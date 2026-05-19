# GLOBAL_VARIABLES

This file documents important globals found in `install.sh`, `lnmp.conf`, `include/main.sh`, `include/version.sh`, and the component scripts. Many variables are populated dynamically after user selection or when version files are sourced.

## 1. OS/Platform Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `DISTRO` | `include/main.sh` | Detected values include `Debian`, `Ubuntu`, `RHEL`, `Rocky`, `Alma`, `Oracle`, `CentOS`, and others. Main installer allowlist is narrower. | Distribution identity. | OS, dependency, repo, compatibility functions | `Get_Dist_Name` | High: gates package manager and compatibility behavior. |
| `PM` | `include/main.sh` | `apt`, `yum` | Package manager family. | dependency, firewall, repo functions | `Get_Dist_Name` | High: wrong value runs wrong package/firewall logic. |
| `DISTRO_Version` | `include/main.sh` | Version string | Generic distro version. | compatibility functions | `Get_Dist_Version` | Medium. |
| `${DISTRO}_Version` | `include/main.sh` | e.g. `Debian_Version`, `Ubuntu_Version`, `RHEL_Version` | Dynamic distro-specific version var. | repo/dependency/compatibility functions | `Get_Dist_Version` | High. |
| `RHEL_Ver` | `include/main.sh` | `5`-`10` when RHEL | RHEL major version. | RHEL repo/dependency helpers | `Get_RHEL_Version` | Medium. |
| `RHEL_Version` | `include/main.sh` | Full RHEL release | RHEL full version. | RHEL helpers | `Get_RHEL_Version`, `Get_Dist_Version` | Medium. |
| `ARCH` | `include/main.sh` | `x86_64`, `i386`, `armhf`, `aarch64`, `arm` | CPU architecture for downloads/packages. | download links, package helpers | `Get_OS_Bit` | High. |
| `DB_ARCH` | `include/main.sh` | `x86_64`, `i686`, `aarch64` | Database binary architecture. | DB selection/install | `Get_OS_Bit` | High. |
| `Is_64bit` | `include/main.sh` | `y`, `n` | 64-bit detection. | builds and add-ons | `Get_OS_Bit` | Medium. |
| `Is_ARM` | `include/main.sh` | `y` or empty | ARM detection. | Redis and compatibility builds | `Get_OS_Bit` | Medium. |
| `isCentosStream` | `include/main.sh` | `y` or empty | CentOS Stream detection. | RHEL-family logic | `Get_Dist_Name` | Medium. |
| `isWSL` | `include/main.sh` | `y` or empty | WSL detection. | nginx config | `Check_WSL` | Low/Medium. |
| `isDocker` | `include/main.sh` | `y` or empty | Docker/container detection. | compatibility/startup logic | `Check_Docker` | Low/Medium. |

## 2. Install Mode Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `Stack` | `install.sh`, `uninstall.sh` | `lnmp` default; `lnmp`, `lnmpa`, `lamp`, `nginx`, `db`, `mphp` | Top-level mode. | installer/uninstaller/component config | Script arg handling | High: controls installed stack and config templates. |
| `LNMP_Auto` | environment/readme | `y` or unset | Enables unattended install. | selection functions | User environment | Medium: missing vars fall back to prompts. |
| `DBSelect` | env/menu | `0`, `1`-`12`; current default in code is `11`; interactive menu displays 3,4,5,7,8,9,10,11,12,0 | Database version/type choice. | installer, startup, checks | `Database_Selection` | High: controls MySQL/MariaDB version and service. |
| `PHPSelect` | env/menu | `1`-`16`; default is `14`; displayed interactive options are 9-16, while cases 1-16 exist | PHP version choice. | PHP installer, Apache checks | `PHP_Selection` | High: affects compatibility and build patches; selections 1-3 reference missing installer functions in current source. |
| `SelectMalloc` | env/menu | `1` none, `2` jemalloc, `3` tcmalloc | Memory allocator choice. | install flow, nginx config | `MemoryAllocator_Selection` | Medium. |
| `ApacheSelect` | readme/env mention | Unclear; `readme.md` mentions it, but current `Apache_Selection` does not read it and always states Apache 2.4 from source. | Historical or intended Apache choice. | No current reader found in inspected source | Unclear | Low/Medium: do not rely on it without changing source. |
| `ServerAdmin` | env/menu | Email address | Apache ServerAdmin/vhost email. | `Install_Apache_24` | `Apache_Selection` | Low. |
| `Bin` | env/menu | `y`, `n` | Database binary vs source install. | DB installers | `Database_Selection`, `DB_BIN_Opt` | High. |
| `InstallInnodb` | env/menu | `y`, `n` | InnoDB enable/disable for DB config. | DB config helpers | DB selection helpers | High for DB behavior. |

## 3. Version Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `DB_Info` | `include/main.sh` | MySQL 5.5/5.6/5.7/8.0/8.4; MariaDB 5.5/10.4/10.5/10.6/10.11/11.4/11.8. The MariaDB 10.4 label is `10.4.33`, while `Mariadb_Ver` is `10.4.34`. | DB menu labels. | `Database_Selection` | Static array | Low for labels, but mismatch can confuse reviews. |
| `PHP_Info` | `include/main.sh` | PHP 5.2 through 8.5 labels | PHP menu labels. | `PHP_Selection` | Static array | Low for labels; selections 1-3 are unclear because installer functions were not found. |
| `Apache_Info` | `include/main.sh` | Apache 2.2.34, 2.4.66 labels | Apache menu labels. | `Apache_Selection` | Static array | Low; actual `Apache_Ver` differs in `include/version.sh`. |
| `Acmesh_Ver` | `include/version.sh` | `3.1.0` | acme.sh version. | download links/SSL flow | Static | Medium; SSL flow unclear. |
| `Nginx_Ver` | `include/version.sh` | `nginx-1.30.1` | nginx source version. | nginx install/download | Static or edited | High. |
| `Apache_Ver` | `include/version.sh` | `httpd-2.4.67` | Apache source version. | Apache install/download | Static or edited | High. |
| `Php_Ver` | `include/version.sh` | `php-5.2.17`, `php-5.3.29`, `php-5.4.45`, `php-5.5.38`, `php-5.6.40`, `php-7.0.33`, `php-7.1.33`, `php-7.2.34`, `php-7.3.33`, `php-7.4.33`, `php-8.0.30`, `php-8.1.34`, `php-8.2.30`, `php-8.3.30`, `php-8.4.20`, `php-8.5.5` | Selected PHP source version. | PHP installers | `include/version.sh` when sourced by `Press_Install`; some upgrade paths may set it from `php_version` | High. |
| `Mysql_Ver` | `include/version.sh` | `mysql-5.5.62`, `mysql-5.6.51`, `mysql-5.7.44`, `mysql-8.0.37`, `mysql-8.4.7` | Selected MySQL version. | MySQL installers | `include/version.sh`; upgrade paths may set it from `mysql_version` | High. |
| `Mariadb_Ver` | `include/version.sh` | `mariadb-5.5.68`, `mariadb-10.4.34`, `mariadb-10.5.29`, `mariadb-10.6.24`, `mariadb-10.11.15`, `mariadb-11.4.9`, `mariadb-11.8.5` | Selected MariaDB version. | MariaDB installers | `include/version.sh` | High. |
| `Redis_Stable_Ver` | `include/version.sh` | `redis-7.4.9` | Redis server version. | `Install_Redis` | May downgrade for old GCC | Medium. |
| `Memcached_Ver` | `include/version.sh` | `memcached-1.6.41` | Memcached server version. | `Install_Memcached` | Static | Medium. |
| `OpenSSL` vars | `include/version.sh` | `Openssl_Ver`, `Openssl_New_Ver`, `Openssl_3_Ver`, `Openssl_35_Ver` | Custom OpenSSL sources. | nginx/PHP/Apache/library helpers | Static | High. |
| `ICU` vars | `include/version.sh` | multiple ICU releases | ICU compatibility sources. | PHP intl helpers | Static | High. |
| `Curl_Ver`, `Libxml2_Ver`, `Libzip_Ver`, `Pcre_Ver`, `Pcre2_Ver`, `Freetype_*` | `include/version.sh` | source package names | Library source versions. | build helpers | Static | High for source compilation. |
| PHP extension version vars | `include/version.sh` | `PHPRedis_Ver`, `PHPMemcached_Ver`, `PHP8Memcached_Ver`, `PHPSwoole_Ver`, etc. | Add-on extension versions. | add-on installers | Static | Medium. |

## 4. Path Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `cur_dir` | entry scripts | `$(pwd)` | Project root/source directory. | almost all installers | entry scripts | High: wrong value breaks copies/downloads. |
| `MySQL_Data_Dir` | `lnmp.conf` | `/usr/local/mysql/data` | MySQL data directory. | MySQL install/upgrade/checks | User config | High: data loss risk if changed. |
| `MariaDB_Data_Dir` | `lnmp.conf` | `/usr/local/mariadb/data` | MariaDB data directory. | MariaDB install/upgrade/checks | User config | High: data loss risk if changed. |
| `Default_Website_Dir` | `lnmp.conf` | `/home/wwwroot/default` | Default web root. | nginx, Apache, PHP tools, add-ons | User config | High: config replacement and file writes. |
| `PHP_Path` | `addons.sh` | `/usr/local/php`, `/usr/local/php7.3`-`/usr/local/php8.5` | Target PHP for add-ons. | add-on installers | `Select_PHP` | High: wrong target loads extension into wrong PHP. |
| `PHPFPM_Initd` | `addons.sh` | `php-fpm`, `php-fpm7.3`, etc. | PHP-FPM service to restart. | `Restart_PHP` | `Select_PHP` | Medium. |
| `Backup_Home` | `tools/backup.sh` | `/home/backup/` | Backup destination. | backup tool | User edits | Medium. |
| `MySQL_Dump` | `tools/backup.sh` | `/usr/local/mysql/bin/mysqldump` | mysqldump path. | backup tool | User edits | Medium. |

## 5. Build Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `Nginx_Modules_Options` | `lnmp.conf` | empty/custom configure flags | Extra nginx configure flags. | `Install_Nginx` | User config | High. |
| `PHP_Modules_Options` | `lnmp.conf` | empty/custom configure flags | Extra PHP configure flags. | PHP installers | User config | High. |
| `CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS`, `PKG_CONFIG_PATH` | environment/PHP helpers | dynamic | Compiler/linker behavior. | source builds | PHP/library helpers | High. |
| `Nginx_With_Openssl`, `Nginx_With_Pcre`, `Nginx_Module_Lua`, `NginxMAOpt`, `Ngx_FancyIndex` | nginx helpers | configure fragments | nginx configure options. | `Install_Nginx` | nginx module helpers | High. |
| `BUILD_TLS`, `BUILD_WITH_MODULES`, `INSTALL_RUST_TOOLCHAIN`, `DISABLE_WERRORS` | `Compile_Redis` | exported temporarily | Redis build behavior. | `make` | `Compile_Redis` | Medium. |

## 6. Download/Mirror Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `Download_Mirror` | `lnmp.conf` | `https://lax.getlnmp.com` | Mirror base URL. | `include/downloadlink.sh` | User config | Medium/High for supply chain. |
| `Use_Official` | `lnmp.conf` | `y` | Use upstream official URLs instead of mirror. | `include/downloadlink.sh` | User config | Medium. |
| `CheckMirror` | env/readme | `n` or unset | Skip mirror/source checks when `n`. | `install.sh`, source functions | User environment | Medium. |
| `*_DL` | `include/downloadlink.sh` | Official or mirror URLs | Component download URLs. | download/build helpers | Sourced based on mirror vars | High. |
| `country` | `lnmp.conf` | `US` | Mirror/source behavior for old Ubuntu releases. | `Ubuntu_Modify_Source` | User config/Get_Country | Low/Medium. |

## 7. Credential Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `DB_Root_Password` | environment/menu | user-provided/generated; sensitive | MySQL/MariaDB root password. | DB secure setup, final output | selection/setup helpers | Critical: sensitive and controls DB auth. |
| `MYSQL_UserName` | `tools/backup.sh` | `root` | Backup DB username. | backup tool | User edits | High. |
| `MYSQL_PassWord` | `tools/backup.sh` | placeholder `yourrootpassword`; sensitive | Backup DB password. | backup tool | User edits | Critical if real secret stored. |
| `FTP_Username`, `FTP_Password` | `tools/backup.sh` | placeholders; sensitive | Optional remote FTP backup credentials. | backup tool | User edits | Critical if real secret stored. |
| temp `user`, `password` in heredocs | DB helpers | root/password values | Writes MySQL client config. | mysql clients | heredoc generation | Critical: credentials may be written to temp files. |

Do not print dynamically generated or user-provided secrets in review output unless the user explicitly asks and understands the exposure.

## 8. Service Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `PHPFPM_Initd` | `addons.sh` | `php-fpm`, `php-fpm7.3`-`php-fpm8.5` | PHP-FPM service target for add-ons. | `Restart_PHP` | `Select_PHP` | Medium. |
| `isNginx`, `isDB`, `isPHP`, `isApache` | `include/end.sh` | `ok` or empty | Final install check flags. | `Check_*_Install` | `Check_*_Files` | Low. |
| `LNMP_Installation_Status` | `include/end.sh` | `y` on success | Install completion marker. | unclear | `Print_Sucess_Info` | Low. |
| `Upgrade_Date` | `upgrade.sh` | timestamp | Backup/log suffix for upgrades. | upgrade functions | `upgrade.sh` | Medium: backup identity. |

## 9. Firewall/Network Variables

| Variable | Defined In | Default/Possible Values | Purpose | Read By | Modified By | Risk |
|---|---|---|---|---|---|---|
| `DETECTED_IP` | `include/end.sh` | IPv4 or empty | Detected SSH client IP. | `Get_Managemanet_IP` | `Get_Managemanet_IP` | Medium. |
| `MANAGEMENT_IPS` | `include/end.sh` | IPv4 list or empty | Firewall whitelist source. | `Apply_UFW`, `Apply_Firewalld` | `Get_Managemanet_IP` | High: can lock out management access if wrong/missing. |
| `OldReleasesURL` | `include/init.sh` | Ubuntu old-releases URL | apt source rewrite target. | Ubuntu source helpers | `Ubuntu_Modify_Source` | Medium. |
| `CodeName` | `include/init.sh` | Ubuntu codename | apt source rewrite. | Ubuntu source helpers | Ubuntu helpers | Medium. |

## 10. Risky Global Variables

- `Stack`: controls the entire branch of installation and which service/config templates are installed.
- `PM` and `DISTRO`: route package manager, repository, dependency, and firewall behavior.
- `DBSelect`, `Bin`, `MySQL_Data_Dir`, `MariaDB_Data_Dir`, and `DB_Root_Password`: affect data initialization, backup/restore, credentials, and service names.
- `PHPSelect`, `Php_Ver`, `PHP_Path`, and PHP build flags: affect source patches, ABI, extension compatibility, and Apache/PHP-FPM integration. In the current tree, `PHPSelect` 1-3 are especially risky because their dispatch functions were not found.
- `Default_Website_Dir`: used in nginx, Apache, PHP open_basedir, add-on test files, and phpMyAdmin paths.
- `Download_Mirror`, `Use_Official`, and `*_DL`: control supply-chain source for all downloaded code.
- `MANAGEMENT_IPS`: determines firewall whitelisting and can affect remote access.
- Compiler and linker variables (`CFLAGS`, `CPPFLAGS`, `LDFLAGS`, `PKG_CONFIG_PATH`): can subtly break source builds or link against wrong custom libraries.
