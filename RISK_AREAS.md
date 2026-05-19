# RISK_AREAS

## 1. Highest-Risk Areas

| Area | Files | Risk |
|---|---|---|
| Package removal and dependency installation | `include/init.sh` | Removes distro Apache/PHP/MySQL/MariaDB packages, changes package state, and can alter repositories. |
| Repository/source modification | `include/init.sh` | Can overwrite `/etc/apt/sources.list`, enable RHEL-family repos, and affect future package updates. |
| Database install/upgrade | `include/mysql.sh`, `include/mariadb.sh`, `include/upgrade_*.sh` | Initializes data directories, writes `/etc/my.cnf`, changes root credentials, dumps/restores data, and moves old installations. |
| Firewall setup | `include/end.sh`, `pureftpd.sh` | Resets/enables UFW or firewalld and may lock out remote access if management IP detection fails. |
| Service setup | `include/end.sh`, component installers | Writes `/etc/systemd/system/*.service`, enables and starts services. |
| PHP source compatibility | `include/php.sh`, `src/patch/*` | Many version/compiler/OpenSSL/ICU patches; small changes can break old PHP builds. |
| nginx/Apache config generation | `include/nginx.sh`, `include/apache.sh`, `conf/*` | Overwrites runtime configs and controls HTTP/PHP routing. |
| Uninstall scripts | `uninstall.sh`, add-on `Uninstall_*` functions | Remove installed files, services, config, and sometimes data-related paths. |
| Upgrade scripts | `upgrade.sh`, `include/upgrade_*.sh` | Move live installations and restore database dumps; failures can leave services down. |

## 2. Destructive or System-Changing Commands in Source

The project intentionally contains many system-changing commands. Do not execute installer paths casually.

Examples found in source include:

- Package commands: `apt-get`, `yum`, `dnf`, `rpm`, `dpkg`.
- Service commands: `systemctl`, `service`, init scripts.
- Firewall commands: `ufw`, `firewall-cmd`, `iptables`.
- File removal/move: `rm -rf`, `mv`, `dpkg -P`, package purge/remove.
- Permission/account changes: `chmod`, `chown`, `chattr`, `groupadd`, `useradd`.
- Build/install commands: `make install` and `Make_Install`/`PHP_Make_Install` helper paths.
- Database commands: `mysql`, `mariadb`, `mysqldump`, `mariadb-dump`.

## 3. Data-Loss Risks

- `MySQL_Data_Dir` defaults to `/usr/local/mysql/data`.
- `MariaDB_Data_Dir` defaults to `/usr/local/mariadb/data`.
- Upgrade functions move old data directories and installations using timestamp suffixes.
- Uninstall paths should be reviewed carefully before any changes because they remove service and install directories.
- `Deb_RemoveAMP` can remove `/etc/mysql` when purging distro database packages.
- Database root password handling writes temporary client config files and prints final credentials.

## 4. Remote Access Risks

Firewall setup is high risk:

- `Apply_UFW` runs `ufw --force reset`.
- `Apply_UFW` sets default deny incoming.
- `Apply_Firewalld` changes the default zone and reloads rules.
- Management IP detection depends on `SSH_CLIENT` or `who am i`; console/KVM sessions may produce no whitelist.
- TCP 3306 is explicitly denied/rejected.

Any firewall patch must consider active SSH access and cloud provider firewalls.

## 5. Compatibility Risks

- PHP compatibility depends on OS OpenSSL version, ICU version, GCC version, and selected PHP version.
- RHEL 10, Debian 13, and new compiler/library stacks are likely to need special handling.
- Older PHP and database versions rely on local patches under `src/patch`.
- PHP selections 1-3 are unclear/broken in the current tree because `install.sh` references `Install_PHP_52`, `Install_PHP_53`, and `Install_PHP_54`, but those definitions were not found.
- MariaDB 10.4 has a label/version mismatch: `DB_Info` says 10.4.33 while `include/version.sh` sets `mariadb-10.4.34`.
- `DB_ARCH`, `ARCH`, `Is_ARM`, and `Is_64bit` affect binary availability and build flags.
- MySQL/MariaDB binary mode (`Bin`) is architecture- and version-sensitive.

## 6. Supply-Chain Risks

- `Use_Official=y` downloads from upstream project URLs.
- `Use_Official=n` builds URLs from `Download_Mirror`.
- Most components are source tarballs or PECL packages.
- The inspected code did not show a consistent checksum/signature verification flow.
- Any change to `include/downloadlink.sh`, `Download_Files`, or version variables affects the trust boundary for installed code.

## 7. Configuration Overwrite Risks

The installer writes or overwrites:

- `/usr/local/nginx/conf/nginx.conf`
- `/usr/local/nginx/conf/rewrite/*`
- `/usr/local/apache/conf/httpd.conf`
- `/usr/local/apache/conf/extra/httpd-vhosts.conf`
- `/usr/local/php/etc/php.ini`
- PHP extension ini files under `${PHP_Path}/conf.d`
- `/etc/my.cnf`
- `/etc/systemd/system/*.service`
- `/bin/lnmp`
- `/etc/hosts`
- `/etc/resolv.conf`
- `/etc/apt/sources.list`
- `/etc/ufw/before.rules`

Some functions back up selected files first, but backup behavior is not uniform.

## 8. Unclear Areas To Mark Carefully

- OpenResty support is unclear. nginx Lua module support exists, but no clear OpenResty installer was found.
- acme.sh/SSL request and renewal flow is unclear from the inspected main install path. Variables and example configs exist.
- Exact current support status for older detected distros is unclear. Detection exists for many distributions, but `Block_Dist_Name` allows only Debian/Ubuntu and RHEL/Rocky/Alma/Oracle in the main installer flow.
- Disk-space validation is unclear.

## 9. Review Checklist

Before editing installer logic:

- Identify every stack mode affected: LNMP, LNMPA, LAMP, nginx-only, db-only, mphp.
- Check both Debian/Ubuntu and RHEL-family branches.
- Check install, upgrade, uninstall, and add-on paths if a shared path/service/version changes.
- Preserve unattended install variables.
- Confirm whether the change touches data directories, firewall rules, package repositories, or systemd services.
- Prefer static validation first: `bash -n`, `shfmt -d`, `git diff`.
- Do not run the installer or system-changing commands unless the user explicitly approves.
