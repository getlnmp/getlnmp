# AGENTS.md

This is a large Bash-based LNMP/LNMPA/LAMP installer and manager.

Before reviewing or editing code, read:

- PROJECT_OVERVIEW.md
- FUNCTION_MAP.md
- INSTALL_FLOW.md
- GLOBAL_VARIABLES.md
- AI_REVIEW_RULES.md
- RISK_AREAS.md

Rules:

- Do not run the installer on the current machine.
- Do not run apt, apt-get, dnf, yum, systemctl, ufw, firewall-cmd, iptables, nft, mysql, mariadb, make install, rm -rf, chmod -R, or chown -R unless explicitly approved.
- Prefer read-only/static commands: grep, find, awk, sed, cat, bash -n, shellcheck, shfmt -d, git status, git diff.
- Preserve Debian-family and RHEL-family compatibility.
- Preserve LNMP/LNMPA/LAMP modes.
- Preserve legacy PHP/MySQL/MariaDB support unless explicitly requested.
- Be very careful with OpenSSL, ICU, libcurl, libxml2, libzip, RUNPATH, LD_LIBRARY_PATH, and ldconfig logic.
- Prefer small patches.
- Do not mix formatting-only changes with logic changes.
- After every edit, show git diff and explain the risk.