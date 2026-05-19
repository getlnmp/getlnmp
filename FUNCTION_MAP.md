# FUNCTION_MAP

This map focuses on important Bash functions. All installer functions that install, remove, upgrade, enable services, write `/etc`, or alter firewall/package state are system-changing unless explicitly marked safe.

## 1. OS Detection Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Get_Dist_Name` | `include/main.sh` | Detect distro and package manager. | `/etc/issue`, `/etc/*-release` | `DISTRO`, `PM`, `isCentosStream` | Safe/read-only; calls `Get_OS_Bit`. |
| `Get_Dist_Version` | `include/main.sh` | Detect distro version. | `DISTRO` | `DISTRO_Version`, `${DISTRO}_Version` | May call `Install_LSB` if version cannot be detected, so potentially system-changing. |
| `Get_RHEL_Version` | `include/main.sh` | Detect RHEL major/full version. | `DISTRO`, `/etc/redhat-release` | `RHEL_Ver`, `RHEL_Version` | Safe/read-only. |
| `Get_OS_Bit` | `include/main.sh` | Detect architecture and ARM status. | `getconf`, `uname` | `Is_64bit`, `ARCH`, `DB_ARCH`, `Is_ARM` | Safe/read-only. |
| `Check_WSL` | `include/main.sh` | Detect WSL. | Kernel/system files | `isWSL` | Safe/read-only. |
| `Check_Docker` | `include/main.sh` | Detect Docker/container environment. | cgroup/files | `isDocker` | Safe/read-only. |
| `Block_Dist_Name` | `include/main.sh` | Reject unsupported/blocked distributions. Allows Debian/Ubuntu for apt and RHEL/Rocky/Alma/Oracle for yum-family. | `DISTRO`, `PM` | None or exit | Safe check, but can terminate installer. |
| `Print_Sys_Info` | `include/main.sh` | Print OS, memory, CPU, disk info. | OS vars | `MemTotal` may be set elsewhere | Safe/read-only. |

## 2. Package Repository Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Ubuntu_Modify_Source` | `include/init.sh` | Rewrite apt sources for old Ubuntu releases. | `country`, `Ubuntu_Version` | `OldReleasesURL`, `CodeName` | System-changing; backs up and overwrites `/etc/apt/sources.list`. |
| `Check_Old_Releases_URL` | `include/init.sh` | Probe old-releases URL. | `OldReleasesURL` | `OR_Status`, `CodeName` | Network read; no local writes. |
| `Ubuntu_Deadline` | `include/init.sh` | Select old-releases mirror when normal release is unavailable. | `OldReleasesURL` | `CodeName` | Network read; may influence source rewrite. |
| `Enable_RHEL_CRB` | `include/init.sh` | Enable CRB/related RHEL-family repo. | `DISTRO`, version vars | Unclear | System-changing; repository management. |
| `Modify_Source` | `include/init.sh` | Dispatch source/repository modifications. | `PM`, `DISTRO`, `CheckMirror` | Repo helper vars | System-changing; can alter package sources and cache. |
| `Check_PowerTools` | `include/init.sh` | Enable/check PowerTools. | RHEL-family vars | Unclear | System-changing. |
| `Check_Codeready` | `include/init.sh` | Enable/check CodeReady Builder. | RHEL-family vars | Unclear | System-changing. |

## 3. Dependency Installation Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `RHEL_Dependent` | `include/init.sh` | Install yum/dnf dependencies. | `DISTRO`, version vars, `DBSelect`, `PHPSelect` | Package state | System-changing; runs package manager. |
| `Deb_Dependent` | `include/init.sh` | Install apt dependencies. | Debian/Ubuntu vars, `DBSelect`, `PHPSelect` | Package state | System-changing; runs package manager. |
| `RHEL_RemoveAMP` | `include/init.sh` | Remove distro httpd/php/mysql packages. | `DBSelect` | Package state | Destructive/system-changing; removes packages. |
| `Deb_RemoveAMP` | `include/init.sh` | Purge distro Apache/PHP/MySQL/MariaDB packages. | `DBSelect`, `Ubuntu_Version` | Package state | Destructive/system-changing; purges packages and removes `/etc/mysql`. |
| `Install_LSB` | `include/main.sh` | Install `lsb_release` provider. | `PM` | Package state | System-changing. |
| `Install_Autoconf`, `Install_Libmcrypt`, `Install_Mcrypt`, `Install_Mhash`, `Install_Freetype`, `Install_Curl`, `Install_OldCurl`, `Install_Pcre`, `Install_Jemalloc`, `Install_TCMalloc`, `Install_Icu*`, `Install_Boost`, `Install_Openssl*`, `Install_Nghttp2`, `Install_Libzip` | `include/init.sh` | Compile/install supporting libraries. | version/download vars, `cur_dir`, compiler vars | `/usr/local/*`, build env | System-changing; compile and install libraries. |
| `Distro_Lib_Opt`, `RHEL_Lib_Opt`, `Deb_Lib_Opt` | `include/init.sh` | Choose compatibility library behavior by distro. | OS/version/PHP vars | Build/link vars | Can trigger system-changing library installs. |

## 4. Download Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Download_Files` | `include/main.sh` | Download source tarballs. | URL args, `cur_dir` | Files in `src` | Writes downloaded files. |
| `Download_O_Files` | `include/main.sh` | Download files with output name. | URL args | Files in `src` | Writes downloaded files. |
| `Tar_Cd` | `include/main.sh` | Extract source tarball and enter directory. | `cur_dir` | Source tree | Writes/extracts under `src`. |
| `Check_Download` | `include/init.sh` | Check/download required archives. | version/download vars | `src` files | Network and filesystem writes. |
| `Download_Boost` | `include/init.sh` | Download Boost for database builds. | Boost vars | `src` files | Network/filesystem writes. |
| `Download_PHP_Src` | `addons.sh` | Download PHP source needed for extension builds. | `PHP_Path`, PHP version vars | `src` files | Network/filesystem writes. |
| `include/downloadlink.sh` | sourced file | Defines official or mirror download URLs. | `Use_Official`, `Download_Mirror`, version vars | `*_DL` variables | Safe when sourced, but affects all downloads. |

## 5. nginx/OpenResty Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Install_Nginx_Openssl` | `include/nginx.sh` | Prepare nginx OpenSSL source option. | OpenSSL vars | `Nginx_With_Openssl`, `Custom_Openssl_Ver` | Downloads/extracts/patches source. |
| `Install_Nginx_Pcre`, `Install_Nginx_Pcre2` | `include/nginx.sh` | Prepare PCRE/PCRE2 for nginx. | PCRE vars | `Nginx_With_Pcre` | Downloads/extracts source. |
| `Install_Nginx_Lua` | `include/nginx.sh` | Add lua-nginx modules when enabled. | `Enable_Nginx_Lua`, lua version vars | `Nginx_Module_Lua` | Downloads/extracts/builds Lua components. |
| `Install_Ngx_FancyIndex` | `include/nginx.sh` | Add fancyindex module when enabled. | `Enable_Ngx_FancyIndex` | `Ngx_FancyIndex` | Downloads/extracts source. |
| `Install_Nginx` | `include/nginx.sh` | Compile and configure nginx. | `Stack`, `Nginx_Ver`, `Default_Website_Dir`, `SelectMalloc`, module vars | `Nginx_Version`, `uname_r` | System-changing; creates user/group, writes `/usr/local/nginx`, `/etc/systemd/system/nginx.service`, `/usr/bin/nginx`, website root, logs. |
| `Nginx_Dependent`, `Install_Only_Nginx` | `include/only.sh` | Dependency and nginx-only install path. | OS vars, nginx vars | Install state | System-changing. |

OpenResty-specific install functions were not found. OpenResty behavior is unclear.

## 6. Apache Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Install_Apache_24` | `include/apache.sh` | Compile Apache 2.4, install APR/APR-util, write configs, install service. | `Stack`, `Apache_Ver`, `APR_Ver`, `Default_Website_Dir`, `ServerAdmin`, `PHPSelect` | Apache files | System-changing; writes `/usr/local/apache`, `/etc/systemd/system/httpd.service`, website root/logs, starts service. |
| `Apache_Selection` | `include/main.sh` | Collect ServerAdmin and state Apache 2.4 source install. `ApacheSelect` is not read in the current function. | `ServerAdmin` | `ServerAdmin` | Interactive/safe until install. |

## 7. PHP Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `PHP_Selection` | `include/main.sh` | Select PHP version. Default is selection 14. Prompt displays 9-16 but the read prompt includes 8-16; cases 1-16 are accepted. | `PHPSelect`, `PHP_Info`, `DBSelect` | `PHPSelect` | Interactive/safe. |
| `Install_PHP` | `install.sh` | Dispatch selected PHP installer. | `PHPSelect` | PHP install state | System-changing. |
| `Install_PHP_55` through `Install_PHP_85` | `include/php.sh` | Compile selected PHP versions. | `Php_Ver`, `Stack`, `PHP_Modules_Options`, library vars | `/usr/local/php`, build vars | System-changing; compile/install PHP. |
| `Install_PHP_52`, `Install_PHP_53`, `Install_PHP_54` | referenced by `install.sh` | Referenced for `PHPSelect` 1-3. | `PHPSelect`, `Php_Ver` | Unclear | Definitions were not found in the inspected source; current behavior is unclear/broken. |
| `Check_PHP_Option` | `include/php.sh` | Build PHP configure fragments and environment after version variables have been sourced by `Press_Install`. | `PHPSelect`, `Php_Ver`, OS/library vars | PHP option vars, compiler/linker env vars | Safe decision logic plus possible dependency/library side effects through helper calls. |
| `PHP_with_curl`, `PHP_with_Libzip`, `PHP_with_openssl`, `PHP_With_Libxml2`, `PHP_with_Intl`, `PHP_with_fileinfo`, `PHP_with_Exif`, `PHP_with_Ldap`, `PHP_with_Bz2`, `PHP_with_Sodium`, `PHP_with_Imap`, `PHP_with_iconv` | `include/php.sh` | Build configure fragments and install prerequisites for PHP features. | PHP/OS/library vars, feature flags | configure option vars | Can be system-changing if they install/compile dependencies. |
| `PHP_Install_ICU`, `PHP_Install_Intl` | `include/php.sh` | Install ICU/intl support. | ICU/PHP vars | ICU install state, PHP opts | System-changing. |
| `PHP_Patch`, `PHP_Openssl3_Patch`, `PHP_ICU70_*`, `PHP_CPP17_Patch`, `PHP_Freetype_Patch`, `PHP_Readdir_r_Patch`, `PHP_Cast_Patch`, `PHP_Main_Phpconfig_Patch`, `PHP_Dom_Iterators_Patch`, `PHP_Autoconf_Patch`, `PHP_GCC14_PATCH` | `include/php.sh` | Apply compatibility patches by PHP/compiler/library version. | `Php_Ver`, compiler and OS vars | Source tree | System-changing within source tree. |
| `PHP_Set_Systemd`, `PHP_Create_Conf`, `PHP_CP_Ini`, `PHP_Set_Ini` | `include/php.sh` | Generate PHP-FPM, php.ini, and service configuration. | `Stack`, `Default_Website_Dir`, PHP vars | PHP config and service files | System-changing. |
| `LNMP_PHP_Opt`, `Creat_PHP_Tools`, `Ln_PHP_Bin`, `Pear_Pecl_Set`, `Install_Composer` | `include/php.sh` | LNMP PHP post-install, helper files, symlinks, PEAR/PECL/composer setup. | `Default_Website_Dir`, `PHP_Path` | Website/PHP files | System-changing. |
| `Install_PHP_*` add-on functions | `include/php_*.sh` | Install exif, fileinfo, ldap, bz2, sodium, imap, swoole extensions. | `PHP_Path`, `Cur_PHP_Version`, download vars | `${PHP_Path}/conf.d`, extension dir | System-changing. |

## 8. Database Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Database_Selection` | `include/main.sh` | Select MySQL/MariaDB version and binary/source mode. | `DBSelect`, `DB_Info`, `DB_ARCH`, `CheckMirror`, `Bin` | `DBSelect`, `Bin` | Interactive/safe. |
| `DB_BIN_Opt` | `include/main.sh` | Adjust database binary/source choice. | `DBSelect`, OS/arch vars | `Bin` | Safe decision logic. |
| `Install_MySQL_51`, `Install_MySQL_55`, `Install_MySQL_56`, `Install_MySQL_57`, `Install_MySQL_80`, `Install_MySQL_84` | `include/mysql.sh` | Install selected MySQL version. `Install_MySQL_51` exists but is not reachable from current `DBSelect` mappings in `include/version.sh`; `DBSelect=1` maps to MySQL 5.5.62. | `Mysql_Ver`, `MySQL_Data_Dir`, `Bin`, `DB_Root_Password` | MySQL install/data/config state | System-changing; writes `/usr/local/mysql`, `/etc/my.cnf`, service files. |
| `MySQL_Initialize_DB`, `MySQL_Add_UG`, `MySQL_Opt`, `MySQL_Sec_Setting`, `Check_MySQL_Data_Dir` | `include/mysql.sh` | Create users/groups, initialize DB, secure root account, validate data dir. | `MySQL_Data_Dir`, `DB_Root_Password`, `InstallInnodb` | DB files, users, temp credentials | System-changing/destructive if run against existing data. |
| `Install_MariaDB_55`, `Install_MariaDB_103`, `Install_MariaDB_104`, `Install_MariaDB_105`, `Install_MariaDB_106`, `Install_MariaDB_1011`, `Install_MariaDB_114`, `Install_MariaDB_118` | `include/mariadb.sh` | Install selected MariaDB version. | `Mariadb_Ver`, `MariaDB_Data_Dir`, `Bin`, `DB_Root_Password` | MariaDB install/data/config state | System-changing; writes `/usr/local/mariadb`, `/etc/my.cnf`, service files. |
| `MariaDB_*` helpers | `include/mariadb.sh` | SSL, InnoDB, startup, initialization, my.cnf, secure setup, data-dir checks. | MariaDB vars, `InstallInnodb`, `DB_Root_Password` | DB config/data/service files | System-changing/destructive if run against existing data. |
| `Make_TempMycnf`, `Verify_DB_Password`, `TempMycnf_Clean`, `Do_Query` | `include/main.sh` | Temporary MySQL client auth and query helpers. | DB password vars | `~/.my.cnf` temp file | System-changing; writes/removes credentials. |

## 9. Redis Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Compile_Redis` | `include/redis.sh` | Build Redis with TLS/modules. | `Is_ARM` | build env vars | System-changing in source tree. |
| `Install_Redis` | `include/redis.sh` | Install Redis server and PHP Redis extension. | `Redis_Stable_Ver`, `PHPRedis_Ver`, `PHP_Path`, `Default_Website_Dir` | Redis/PHP/service files | System-changing; writes `/usr/local/redis`, service, PHP ini, test file. |
| `Uninstall_Redis` | `include/redis.sh` | Remove Redis and extension. | `PHP_Path` | Removes Redis/PHP files | Destructive. |

## 10. Memcached Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Install_PHPMemcache` | `include/memcached.sh` | Compile php-memcache extension. | PHP version/download vars | extension file | System-changing. |
| `Install_PHPMemcached` | `include/memcached.sh` | Install SASL deps, libmemcached, php-memcached. | `PM`, PHP version/download vars | `/usr/local/libmemcached`, extension file | System-changing. |
| `Install_Memcached` | `include/memcached.sh` | Install memcached server and chosen PHP extension. | `Memcached_Ver`, `PHP_Path`, `Default_Website_Dir` | memcached/PHP/service files | System-changing. |
| `Uninstall_Memcached` | `include/memcached.sh` | Remove memcached and extension. | `PHP_Path` | Removes service, binaries, ini | Destructive. |

## 11. SSL/acme Functions

Dedicated acme install/request functions were not found in the inspected main installer files. `Acmesh_Ver` and `Acmesh_DL` are defined, and nginx/Apache SSL example configs exist under `conf/example`. Certificate issuing, installation, and renewal flow is unclear.

## 12. Firewall Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Add_Firewall_Rules` | `include/end.sh` | Dispatch firewall config by package manager. | `PM` | Firewall state | System-changing. |
| `Get_Managemanet_IP` | `include/end.sh` | Detect SSH client IP for whitelist. | `SSH_CLIENT`, `who am i` | `DETECTED_IP`, `MANAGEMENT_IPS` | Safe/read-only. |
| `Apply_Firewalld` | `include/end.sh` | Install/start firewalld and set rules. | `MANAGEMENT_IPS` | firewalld rules | System-changing. |
| `Apply_UFW` | `include/end.sh` | Install/reset/enable UFW and set rules. | `MANAGEMENT_IPS` | UFW rules, `/etc/ufw/before.rules` | System-changing/destructive to existing UFW policy. |
| `Add_Iptables_Rules` | `include/end.sh` | Legacy iptables rule setup. | `PM` | iptables rules/services | System-changing; may disable firewalld. |
| `Open_FTP_Ports` | `pureftpd.sh` | Open FTP ports. | firewall tools | firewall rules | System-changing. |

## 13. systemd/init Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `StartUp`, `Remove_StartUp` | `include/main.sh` | Enable/disable startup entries. | service name args | init/systemd state | System-changing. |
| `StartOrStop` | `include/main.sh` | Service control helper. | service/action args | service state | System-changing. |
| `Add_LNMP_Startup`, `Add_LNMPA_Startup`, `Add_LAMP_Startup` | `include/end.sh` | Install `/bin/lnmp`, enable and start stack services. | `DBSelect`, `cur_dir` | `/bin/lnmp`, systemd state | System-changing. |
| `PHP_Set_Systemd` | `include/php.sh` | Install PHP-FPM unit. | PHP vars | `/etc/systemd/system/php-fpm.service` | System-changing. |
| Component installers | multiple | Copy unit files and run daemon-reload/enable/start. | `cur_dir` | `/etc/systemd/system` | System-changing. |

## 14. Configuration File Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Install_Nginx` | `include/nginx.sh` | Writes nginx configs, rewrites default path, optional Lua config. | `Stack`, `Default_Website_Dir`, feature flags | `/usr/local/nginx/conf/*` | System-changing; overwrite risk. |
| `Install_Apache_24` | `include/apache.sh` | Writes Apache configs and vhost examples. | `Stack`, `ServerAdmin`, `Default_Website_Dir` | `/usr/local/apache/conf/*` | System-changing; backs up only main `httpd.conf`. |
| `PHP_Create_Conf`, `PHP_CP_Ini`, `PHP_Set_Ini` | `include/php.sh` | Generate PHP-FPM and php.ini settings. | PHP vars | `/usr/local/php/etc/*` | System-changing. |
| `MySQL_Opt`, `MariaDB_My_Cnf`, `MariaDB_Set_MyCNF_104` | DB includes | Generate DB configuration. | DB/data/password vars | `/etc/my.cnf` | System-changing; overwrite risk. |
| Add-on installers | `include/*.sh` | Add extension ini files. | `PHP_Path` | `${PHP_Path}/conf.d/*.ini` | System-changing. |
| `Check_Hosts` | `include/init.sh` | Ensure localhost and DNS resolver entries. | `CheckMirror` | `/etc/hosts`, `/etc/resolv.conf` | System-changing; overwrite risk for resolv.conf. |

## 15. User/Menu/Input Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Database_Selection` | `include/main.sh` | Interactive DB choice. | `DBSelect` | `DBSelect`, `Bin` | Safe. |
| `PHP_Selection` | `include/main.sh` | Interactive PHP choice. | `PHPSelect` | `PHPSelect` | Safe. |
| `MemoryAllocator_Selection` | `include/main.sh` | Select none/jemalloc/tcmalloc. | `SelectMalloc` | `SelectMalloc` | Safe. |
| `Apache_Selection` | `include/main.sh` | Collect Apache admin email; current source does not read `ApacheSelect`. | `ServerAdmin` | `ServerAdmin` | Safe. |
| `Dispaly_Selection` | `include/main.sh` | Run main selection menus. | stack vars | selection vars | Safe. |
| `Press_Install`, `Press_Start` | `include/main.sh` | Confirmation prompts. | user input | None | Safe. |
| `Display_Addons_Menu`, `Select_PHP` | `addons.sh` | Add-on and target PHP selection. | installed PHP paths | `action2`, `PHP_Path`, `PHPFPM_Initd` | Safe until invoked install. |
| `Display_Upgrade_Menu` | `upgrade.sh` | Upgrade menu. | user input | `action` | Safe. |

## 16. Logging/Error/Utility Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Color_Text`, `Echo_Red`, `Echo_Green`, `Echo_Yellow`, `Echo_Blue` | `include/main.sh` | Colored output. | text args | None | Safe. |
| `Check_LNMPConf` | `include/main.sh` | Validate config file settings. | `lnmp.conf` vars | None | Safe; can exit. |
| `Print_APP_Ver` | `include/main.sh` | Print selected versions. | version vars | None | Safe. |
| `Check_CMPT` | `include/main.sh` | Compatibility checks. | OS/PHP/DB vars | May exit | Safe/read-only unless helper calls change state; exact internals should be reviewed before edits. |
| `Check_Openssl`, `Get_ICU_Version`, `Gcc14_Check`, `Libaio_Check`, `Ncurses5_Compat_Check` | `include/main.sh` | Library/compiler compatibility checks. | system commands | compatibility vars | Mostly read-only; some helpers can trigger installs. |
| `Make_Install`, `PHP_Make_Install` | `include/init.sh` | Run make/make install and validate. | source tree | installed files | System-changing. |

## 17. Uninstall/Upgrade Functions

| Function | File | Purpose | Reads Vars | Writes Vars | Side Effects |
|---|---|---|---|---|---|
| `Uninstall_LNMP`, `Uninstall_LNMPA`, `Uninstall_LAMP` | `uninstall.sh` | Remove installed stack files and services. | `Stack`, install paths | Removes stack files | Destructive. |
| `Backup_MySQL`, `Backup_MariaDB`, `Backup_MySQL2` | upgrade includes | Dump all databases and move old data. | DB paths/password files | `/root/*backup*.sql`, old dirs | System-changing; backup before destructive upgrade. |
| `Upgrade_Nginx`, `Upgrade_MySQL`, `Upgrade_MariaDB`, `Upgrade_MySQL2MariaDB`, `Upgrade_PHP`, `Upgrade_Multiplephp`, `Upgrade_phpMyAdmin` | upgrade includes | Upgrade selected component. | install/version vars | component files/backups | System-changing/destructive risk. |
| `Uninstall_*` add-on functions | `include/*.sh` | Remove add-ons and extension config. | `PHP_Path` | removes files/services | Destructive. |
| `Uninstall_Pureftpd` | `pureftpd.sh` | Remove PureFTPd. | install paths | removes files/service | Destructive. |

## 18. Unknown/Unclear Functions

- acme.sh/SSL issuance functions are unclear in the inspected source. Version/download variables and example configs exist, but no clear main flow was found.
- OpenResty-specific functions are unclear; nginx Lua module support exists.
- Some compatibility helpers (`Check_CMPT`, `Libaio_Check`, `Install_Ncurses5_Compat`) need local review before changes because their behavior depends heavily on OS version and package availability.

## Function Call Relationships

```text
install.sh
 ├── Get_Dist_Name
 │    └── Get_OS_Bit
 ├── Block_Dist_Name
 ├── Check_LNMPConf
 ├── case Stack
 │    ├── lnmp -> Dispaly_Selection -> LNMP_Stack
 │    ├── lnmpa -> Dispaly_Selection -> LNMPA_Stack
 │    ├── lamp -> Dispaly_Selection -> LAMP_Stack
 │    ├── nginx -> Install_Only_Nginx
 │    ├── db -> Install_Only_Database
 │    └── mphp -> Install_Multiplephp
```

```text
LNMP_Stack
 ├── Init_Install
 │    ├── Press_Install
 │    │    ├── source include/version.sh
 │    │    └── source include/downloadlink.sh
 │    ├── Stop_Package_Manager
 │    ├── Get_Dist_Version
 │    ├── Check_Hosts
 │    ├── Modify_Source
 │    ├── Add_Swap
 │    ├── Set_Timezone
 │    ├── Sync_Time
 │    ├── RHEL_RemoveAMP/Deb_RemoveAMP
 │    ├── RHEL_Dependent/Deb_Dependent
 │    ├── Disable_Selinux
 │    ├── Check_Openssl
 │    ├── Check_Download
 │    ├── Install_Freetype
 │    ├── Install_Jemalloc/Install_TCMalloc
 │    ├── Distro_Lib_Opt
 │    ├── DB_BIN_Opt
 │    ├── Install_MySQL_* or Install_MariaDB_*
 │    ├── TempMycnf_Clean
 │    ├── Clean_DB_Src_Dir
 │    └── Check_PHP_Option
 ├── Install_PHP
 ├── LNMP_PHP_Opt
 ├── Install_Nginx
 ├── Creat_PHP_Tools
 ├── Add_Firewall_Rules
 ├── Add_LNMP_Startup
 └── Check_LNMP_Install
```

```text
LNMPA_Stack/LAMP_Stack
 ├── Apache_Selection
 ├── Init_Install
 ├── Install_Apache_24
 ├── Install_PHP
 ├── Creat_PHP_Tools
 ├── Add_Firewall_Rules
 ├── Add_LNMPA_Startup or Add_LAMP_Startup
 └── Check_LNMPA_Install or Check_LAMP_Install
```
