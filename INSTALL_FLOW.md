# INSTALL_FLOW

## 1. Main Entry Point

The main installation entry point is `install.sh`.

- It requires root by checking `id -u`.
- It sets `cur_dir=$(pwd)`.
- It reads the first argument into `Stack`, defaulting to `lnmp`.
- It sources `lnmp.conf` and the main include files. `include/version.sh` and `include/downloadlink.sh` are sourced later by `Press_Install`, not at the top of `install.sh`.
- It calls `Get_Dist_Name`, rejects unknown distributions, and runs `Block_Dist_Name`.
- It prevents reinstall of full stack modes if `/bin/lnmp` exists.
- It runs `Check_LNMPConf`.
- It dispatches by `Stack`.

Argument modes:

- `lnmp`
- `lnmpa`
- `lamp`
- `nginx`
- `db`
- `mphp`

Interactive menus are used through `Dispaly_Selection`, `Database_Selection`, `PHP_Selection`, `MemoryAllocator_Selection`, and `Apache_Selection`. Non-interactive mode exists through environment variables described in `readme.md`, including `LNMP_Auto`, `DBSelect`, `DB_Root_Password`, `InstallInnodb`, `PHPSelect`, `SelectMalloc`, `ServerAdmin`, `RHELRepo`, `CheckMirror`, and `Bin`. `ApacheSelect` is mentioned in `readme.md`, but the current `Apache_Selection` function does not read it and always states Apache 2.4 from source.

Important current-source caveat: `install.sh` dispatches `Install_PHP_52`, `Install_PHP_53`, and `Install_PHP_54` for `PHPSelect` 1-3, but those function definitions were not found. Selections 1-3 are therefore unclear/broken in the inspected tree.

## 2. Startup Checks

Early checks include:

- Root permission in `install.sh`.
- Distribution detection with `Get_Dist_Name`.
- Unsupported distribution exit when `DISTRO=unknow`.
- OS allowlist handling in `Block_Dist_Name`: apt-family systems must be Debian or Ubuntu; yum-family systems must be RHEL, Rocky, Alma, or Oracle.
- Existing installation check using `/bin/lnmp`.
- `lnmp.conf` validation with `Check_LNMPConf`.
- Package manager lock handling with `Stop_Package_Manager`, `Check_PM_Lock`, `Wait_For_PM_Lock`, and `Kill_PM`.
- Host/DNS checks in `Check_Hosts`.
- Compatibility checks in `Check_CMPT`.
- OpenSSL compatibility in `Check_Openssl`.
- WSL/Docker checks exist as `Check_WSL` and `Check_Docker`; exact placement in the main flow should be confirmed before changing them.
- Swap creation with `Add_Swap` when enabled.

Disk space and memory checks are partially unclear. Memory is used for decisions and upgrade menu output, but a single obvious early disk-space gate was not found.

## 3. OS Detection Flow

```text
install.sh
 └── Get_Dist_Name
      ├── inspect /etc/issue and /etc/*-release
      ├── set DISTRO
      ├── set PM to yum or apt
      └── Get_OS_Bit
           ├── set Is_64bit
           ├── set ARCH
           ├── set DB_ARCH
           └── set Is_ARM for ARM/aarch64
```

Later, `Get_Dist_Version` sets `DISTRO_Version` and a dynamic variable such as `Debian_Version`, `Ubuntu_Version`, or `RHEL_Version`. `Get_RHEL_Version` separately sets `RHEL_Ver` and `RHEL_Version` for RHEL.

Although `Get_Dist_Name` detects many other distributions, `Block_Dist_Name` rejects apt-based distributions other than Debian/Ubuntu and yum-family distributions other than RHEL/Rocky/Alma/Oracle in the main install flow.

Firewall system is not detected generically. `Add_Firewall_Rules` chooses UFW for `PM=apt` and firewalld for `PM=yum`.

## 4. Source/Repository Setup Flow

During `Init_Install`, repository setup runs only if `CheckMirror` is not `n`:

```text
Init_Install
 └── if CheckMirror != n
      └── Modify_Source
```

Repository behavior includes:

- Ubuntu old release detection and `/etc/apt/sources.list` rewrite through `Ubuntu_Modify_Source`.
- RHEL-family CRB/PowerTools/CodeReady handling through `Enable_RHEL_CRB`, `Check_PowerTools`, and `Check_Codeready`.
- EPEL and other repository package setup appears inside dependency/repository helpers; exact per-version behavior should be reviewed before edits.

This step is skipped when `CheckMirror=n`.

## 5. Installation Mode Selection

`install.sh` selects stack mode from `$1`:

- Empty argument defaults to `lnmp`.
- `lnmp`, `lnmpa`, and `lamp` call `Dispaly_Selection`.
- `nginx`, `db`, and `mphp` call single-purpose installers.

`Dispaly_Selection` calls the interactive selectors for database, PHP, and memory allocator. `LNMPA_Stack` and `LAMP_Stack` additionally call `Apache_Selection`.

Database selection maps `DBSelect` to MySQL/MariaDB versions. `include/version.sh` currently maps `DBSelect=1-5` to MySQL 5.5.62, 5.6.51, 5.7.44, 8.0.37, 8.4.7 and `DBSelect=6-12` to MariaDB 5.5.68, 10.4.34, 10.5.29, 10.6.24, 10.11.15, 11.4.9, 11.8.5. `DB_Info` labels MariaDB 10.4 as 10.4.33, which does not match `Mariadb_Ver`.

PHP selection maps `PHPSelect=1-16` to PHP 5.2.17 through 8.5.5 in `include/version.sh`, but only installer functions for PHP 5.5 through 8.5 were found. Binary/source database installation is controlled by `Bin`, with architecture and mirror state influencing defaults.

## 6. Dependency Installation Flow

`Init_Install` installs dependencies after source and host setup:

```text
if PM = yum
 ├── RHEL_RemoveAMP
 └── RHEL_Dependent
elif PM = apt
 ├── Deb_RemoveAMP
 └── Deb_Dependent
```

After base dependencies, the installer disables SELinux, checks OpenSSL, checks downloads, installs freetype, optionally installs jemalloc or tcmalloc, sets distro library options, and prepares database binary/source behavior.

## 7. Web Server Installation Flow

### nginx Flow

```text
Install_Nginx
 ├── create www group/user
 ├── Install_Nginx_Openssl
 ├── Install_Nginx_Pcre2
 ├── Install_Nginx_Lua
 ├── Install_Ngx_FancyIndex
 ├── extract nginx source
 ├── apply gcc8 patch when needed
 ├── configure with HTTP/2, HTTP/3, stream, SSL, realip, module options
 ├── Make_Install
 ├── symlink /usr/bin/nginx
 ├── copy nginx or LNMPA proxy config
 ├── copy rewrite, pathinfo, enable-php, and example configs
 ├── create website root and logs
 ├── create vhost directory
 ├── write open_basedir restrictions for LNMP
 ├── copy nginx.service to /etc/systemd/system
 ├── systemctl daemon-reload
 └── clean source directories
```

### OpenResty Flow

No clear OpenResty install flow was found. The source supports optional lua-nginx modules, but OpenResty-specific installation is unclear.

### Apache Flow

```text
Install_Apache_24
 ├── for LAMP: create www user/group, website root, logs
 ├── for LAMP: install OpenSSL and nghttp2
 ├── extract Apache source
 ├── download/copy APR and APR-util
 ├── configure Apache for LAMP or LNMPA
 ├── Make_Install
 ├── back up /usr/local/apache/conf/httpd.conf
 ├── copy stack-specific httpd and vhost configs
 ├── copy SSL/default/remoteip configs
 ├── apply ServerAdmin and default path replacements
 ├── remove php5 module line for newer PHP selections
 ├── copy httpd.service
 ├── systemctl daemon-reload
 └── systemctl enable --now httpd
```

### LNMPA Integration Flow

LNMPA installs Apache first, then PHP, then nginx. nginx uses `conf/nginx_a.conf`, `conf/proxy.conf`, and `conf/proxy-pass-php.conf` to proxy PHP/backend traffic to Apache.

## 8. PHP Installation Flow

```text
Init_Install
 └── Check_PHP_Option

Install_PHP
 ├── dispatch by PHPSelect
 ├── PHPSelect 1-3 -> Install_PHP_52/53/54 references, definitions not found
 ├── PHPSelect 4-16 -> Install_PHP_55/56/70/71/72/73/74/80/81/82/83/84/85
 └── Clean_PHP_Src_Dir
```

PHP build behavior includes:

- Version selection through `PHPSelect`.
- Custom OpenSSL handling through `PHP_with_openssl`, `PHP_Openssl_Export`, and OpenSSL patch helpers.
- ICU/intl handling through `Get_ICU_Version`, `PHP_Install_ICU`, `PHP_Install_Intl`, and ICU patch helpers.
- libcurl, libxml2, and libzip handling through `PHP_with_curl`, `PHP_With_Libxml2`, and `PHP_with_Libzip`.
- Configure fragments for exif, fileinfo, LDAP, bz2, sodium, imap, iconv, and intl.
- Source patches for old PHP on newer GCC/OpenSSL/ICU/freetype/libc combinations.
- PHP-FPM systemd setup with `PHP_Set_Systemd`.
- php.ini and PHP config setup with `PHP_CP_Ini`, `PHP_Set_Ini`, and `PHP_Create_Conf`.
- LNMP-specific post-install via `LNMP_PHP_Opt`.
- Tool/test file generation via `Creat_PHP_Tools`.

## 9. Database Installation Flow

```text
Database_Selection
 ├── choose DBSelect
 └── choose Bin for supported arch/version

Init_Install
 ├── DB_BIN_Opt
 ├── Install_MySQL_* or Install_MariaDB_*
 ├── TempMycnf_Clean
 └── Clean_DB_Src_Dir
```

MySQL selections install MySQL 5.5, 5.6, 5.7, 8.0, or 8.4. MariaDB selections install MariaDB 5.5, 10.4, 10.5, 10.6, 10.11, 11.4, or 11.8. `Install_MySQL_51` and `Install_MariaDB_103` exist but do not appear reachable from current `DBSelect` mappings in `include/version.sh` and `install.sh`.

Database flow includes:

- Source/binary selection.
- Dependency and library setup.
- User/group creation.
- Data directory checks using `MySQL_Data_Dir` or `MariaDB_Data_Dir`.
- Initialization.
- root password setup using `DB_Root_Password`.
- `/etc/my.cnf` generation.
- service file installation.
- startup through `Add_*_Startup`.

## 10. Cache/Extension Component Flow

Add-ons are driven by `addons.sh`:

```text
addons.sh
 ├── root check
 ├── source config/includes
 ├── Display_Addons_Menu if args missing
 ├── Select_PHP
 ├── Addons_Get_PHP_Ext_Dir
 └── install/uninstall selected add-on
```

Redis flow installs Redis server, compiles the PHP Redis extension, writes `${PHP_Path}/conf.d/007-redis.ini`, installs `redis.service`, restarts PHP, starts Redis, and copies `redis.php`.

Memcached flow lets the user choose php-memcache or php-memcached, installs memcached server, installs required PHP extension and optional libmemcached, writes `${PHP_Path}/conf.d/005-memcached.ini`, installs `memcached.service`, restarts PHP, restarts memcached, and copies a test file.

Other PHP extensions have install/uninstall scripts under `include/php_*.sh`.

## 11. SSL Flow

SSL support is partly visible through:

- `Acmesh_Ver` in `include/version.sh`.
- `Acmesh_DL` in `include/downloadlink.sh`.
- nginx and Apache SSL example configs under `conf/example`.
- Apache SSL config copy in LAMP mode.

The actual acme.sh install, certificate request, renewal, and web server SSL vhost generation flow is unclear from the inspected main installer path.

## 12. Firewall Flow

```text
Add_Firewall_Rules
 ├── Get_Managemanet_IP
 ├── if PM=apt -> Apply_UFW
 └── if PM=yum -> Apply_Firewalld
```

UFW flow:

- Installs UFW if missing.
- Resets UFW rules.
- Whitelists detected management IP if available.
- Sets default deny incoming and allow outgoing.
- Allows SSH, HTTP, and HTTPS.
- Denies TCP 3306.
- Edits `/etc/ufw/before.rules` to allow ping.
- Enables UFW.

firewalld flow:

- Installs firewalld if missing.
- Enables and starts firewalld.
- Sets default zone to public.
- Adds management IPs to trusted zone.
- Allows SSH, HTTP, and HTTPS.
- Removes direct 3306/tcp port opening and adds reject rich rules for IPv4/IPv6.
- Ensures echo-request is not blocked.
- Reloads firewall.

Firewall changes are not skipped in the main full-stack flow unless the function is edited or the flow exits earlier.

## 13. systemd Service Flow

Components copy unit files from `init.d/` into `/etc/systemd/system`, then run some combination of:

- `systemctl daemon-reload`
- `systemctl enable`
- `systemctl enable --now`
- `systemctl start`
- `systemctl restart`

Main startup functions:

- `Add_LNMP_Startup`: installs `/bin/lnmp`, enables/starts nginx, database service, and php-fpm.
- `Add_LNMPA_Startup`: installs `/bin/lnmp`, enables/starts nginx, database service, and httpd.
- `Add_LAMP_Startup`: installs `/bin/lnmp`, enables/starts httpd and database service.

## 14. Finalization Flow

Full-stack finalization runs one of:

- `Check_LNMP_Install`
- `Check_LNMPA_Install`
- `Check_LAMP_Install`

These check expected files for nginx, Apache, PHP, and the selected database. On success, `Print_Sucess_Info` cleans web source directories, prints management URLs, prints the default website directory, prints the database root password if a DB was installed, runs `lnmp status`, prints listening ports with `ss` or `netstat`, prints elapsed time, and sets `LNMP_Installation_Status=y`.

On failure, `Print_Failed_Info` removes `/bin/lnmp` if present and points users to the install log.

## 15. Text Flowchart

```text
install.sh
 ├── root check
 ├── set Stack
 ├── source lnmp.conf and include files
 ├── Get_Dist_Name
 │    └── Get_OS_Bit
 ├── Block_Dist_Name
 ├── existing /bin/lnmp check
 ├── Check_LNMPConf
 └── case Stack
      ├── lnmp
      │    ├── Dispaly_Selection
      │    └── LNMP_Stack
      │         ├── Init_Install
      │         ├── Install_PHP
      │         ├── LNMP_PHP_Opt
      │         ├── Install_Nginx
      │         ├── Creat_PHP_Tools
      │         ├── Add_Firewall_Rules
      │         ├── Add_LNMP_Startup
      │         └── Check_LNMP_Install
      ├── lnmpa
      │    ├── Dispaly_Selection
      │    └── LNMPA_Stack
      │         ├── Apache_Selection
      │         ├── Init_Install
      │         ├── Install_Apache_24
      │         ├── Install_PHP
      │         ├── Install_Nginx
      │         ├── Creat_PHP_Tools
      │         ├── Add_Firewall_Rules
      │         ├── Add_LNMPA_Startup
      │         └── Check_LNMPA_Install
      ├── lamp
      │    ├── Dispaly_Selection
      │    └── LAMP_Stack
      │         ├── Apache_Selection
      │         ├── Init_Install
      │         ├── Install_Apache_24
      │         ├── Install_PHP
      │         ├── Creat_PHP_Tools
      │         ├── Add_Firewall_Rules
      │         ├── Add_LAMP_Startup
      │         └── Check_LAMP_Install
      ├── nginx -> Install_Only_Nginx
      ├── db -> Install_Only_Database
      └── mphp -> Install_Multiplephp
```
