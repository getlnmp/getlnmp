# AI_REVIEW_RULES

## 1. Project Identity

This is a large Bash-based LNMP/LNMPA/LAMP installer and manager for Debian-family and RHEL-family Linux systems. It compiles and installs nginx, Apache, PHP, MySQL, MariaDB, and optional add-ons, then writes service, firewall, and application configuration.

Treat it as a system installer with high operational risk. Many functions modify `/usr/local`, `/etc`, `/bin`, package repositories, package state, firewall rules, systemd services, database data directories, and user accounts.

## 2. Core Compatibility Requirements

Future AI assistants must preserve:

- Debian-family compatibility.
- Ubuntu-family compatibility.
- RHEL-family compatibility, including RHEL/Rocky/Alma 8/9/10 behavior where present.
- Oracle Linux behavior where present.
- LNMP, LNMPA, and LAMP modes.
- nginx-only, database-only, and multiple-PHP modes if touched.
- Legacy PHP compatibility and patch logic where present.
- The current-source caveat that PHP selections 1-3 map to version variables and dispatch names, but `Install_PHP_52`, `Install_PHP_53`, and `Install_PHP_54` definitions were not found during static validation.
- Current PHP 7.x/8.x behavior and any still-reachable PHP 5.x code unless explicitly removed by the user.
- MySQL and MariaDB version support present in menus, installers, and upgrade scripts.
- nginx and Apache configuration choices.
- Optional nginx Lua/fancyindex module behavior.
- Source-compilation logic.
- Generic binary database install logic.
- Custom OpenSSL, ICU, libcurl, libxml2, libzip, freetype, PCRE/PCRE2, and compiler compatibility handling.
- Existing install paths unless the user explicitly asks to change them.
- Existing user-facing menus and unattended environment variables unless the user explicitly asks to change them.
- The `ApacheSelect` discrepancy: it is documented in `readme.md`, but the current source does not appear to read it.

## 3. Editing Rules

Future AI assistants must:

- Read the relevant files before editing; do not rely on generic LNMP assumptions.
- Use minimal patches.
- Avoid large rewrites without explicit approval.
- Avoid formatting-only changes mixed with logic changes.
- Keep existing function names unless the task is explicitly a refactor.
- Preserve `lnmp.conf` variable names and meanings unless asked.
- Preserve current install paths unless asked.
- Preserve existing menu/user-facing behavior unless asked.
- Keep Debian-family and RHEL-family branches aligned when changing shared behavior.
- Check both install and upgrade/uninstall paths when changing component layout, service names, or config paths.
- Treat generated system paths such as `/etc/my.cnf`, `/etc/systemd/system/*.service`, `/bin/lnmp`, `/usr/local/*`, and data directories as high risk.
- Show `git diff` after edits.
- Explain the risk of every patch.

## 4. Safety Rules

Future AI assistants must not run destructive or system-changing commands unless explicitly approved by the user.

Do not run the installer unless explicitly asked. Do not run commands such as:

- `apt`, `apt-get`, `dnf`, `yum`
- `systemctl`, `service`
- `ufw`, `firewall-cmd`, `iptables`, `nft`
- `rm -rf`
- `chmod -R`, `chown -R`
- `make install`
- `mysql`, `mariadb`

Prefer static/read-only commands while reviewing:

- `find`
- `grep`
- `awk`
- `sed`
- `cat`
- `head`
- `tail`
- `wc`
- `bash -n`
- `shellcheck`
- `shfmt -d`
- `git status`
- `git diff`

Never modify `.sh` files during documentation-only tasks. If behavior is unclear after static inspection, mark it as unclear instead of guessing.
