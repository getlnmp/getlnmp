# Copilot instructions for GetLNMP

This repository is a shell-based LNMP installer (Nginx/MySQL/MariaDB/PHP). The guidance below highlights the project architecture, developer workflows, conventions, and concrete examples you can use when making changes.

- **Big picture:** This is a collection of coordinated shell scripts that compile and install software from source (or use binaries). The entrypoint is [install.sh](install.sh). Main logic and version lists live in [include/main.sh](include/main.sh). OS-specific setup and package installation is in [include/init.sh](include/init.sh). Build sources and patches are under [src/](src/) and [src/patch/](src/patch/).

- **Key integration points:**
  - **Configuration:** [lnmp.conf](lnmp.conf) provides user-visible defaults and toggles (download mirror, feature flags like `Enable_PHP_Fileinfo`, default web/db dirs).
  - **Download & patches:** `src/` holds source tarballs and `src/patch/` contains patches applied during builds. Changes to compilation flags or patches must be synced here.
  - **Service files:** `init.d/` and scripts like `Add_LNMP_Startup` in `include/` are responsible for creating systemd/init scripts and service behavior.
  - **Tools & helpers:** `tools/` contains maintenance utilities (reset mysql password, check502, log rotation). Use or adapt them rather than adding duplicate scripts.

- **Developer workflows (practical commands):**
  - Run the installer locally as root to exercise flows (use `screen` for long runs):
    - `./install.sh lnmp` or `./install.sh nginx` or `./install.sh db`
  - Unattended install examples (used by CI or automation):
    - `LNMP_Auto="y" DBSelect="2" DB_Root_Password="secret" PHPSelect="12" ./install.sh lnmp`
  - Logs: install output is tee'd to `/root/getlnmp-install.log` (or `/root/nginx-install.log` for `nginx`), check those when debugging.

- **Patterns & conventions to follow:**
  - **Function naming:** install functions use `Install_<Component>_<Version>` (e.g. `Install_PHP_81`) and selection flows in `include/main.sh`. Add new versions by updating the arrays and adding the corresponding `Install_*` function.
  - **Central variables:** `cur_dir` points at repository root; code often sources files with `. include/<file>.sh`. Avoid relative path confusion—use `cur_dir` when constructing absolute paths.
  - **Binary vs source:** Many DB/PHP installs offer `Bin="y"` (use prebuilt binaries) or source compilation. Respect existing `Bin`/`CheckMirror` logic; adding a new binary distribution requires updating download logic and checks.
  - **Config overrides:** Prefer exposing toggles via `lnmp.conf` (user-facing) instead of hardcoding values deep in scripts.
  - **Patches:** Any patch in `src/patch/` is expected to be applied to specific upstream tarballs—document the reason and the exact upstream version in the patch filename or an adjacent comment.

- **Files to inspect when modifying a component:**
  - Installer + config: [install.sh](install.sh), [lnmp.conf](lnmp.conf)
  - Orchestration & version lists: [include/main.sh](include/main.sh)
  - OS prep + deps: [include/init.sh](include/init.sh)
  - Component-specific build scripts: [include/nginx.sh](include/nginx.sh), [include/php.sh](include/php.sh), [include/mysql.sh](include/mysql.sh), [include/mariadb.sh](include/mariadb.sh)
  - Source patches: [src/patch/](src/patch/)
  - Utilities: [tools/](tools/)

- **Testing and debugging tips:**
  - Run targeted installs with the appropriate stack argument to limit scope: `./install.sh nginx` or `./install.sh db`.
  - Inspect the install log in `/root/*.log` and rerun the failing step interactively to capture precise errors.
  - When changing compile flags, iterate in a disposable VM/container with the same distro/version combinations the scripts detect.

- **Do / Don’t (repo-specific):**
  - **Do** add new feature toggles to `lnmp.conf` for user control. Example: `Enable_PHP_Fileinfo='y'`.
  - **Do** update `include/main.sh` arrays when adding supported versions, and implement corresponding `Install_*` functions.
  - **Don't** change `src/patch/` filenames silently—keep a short rationale in the patch or a README in that folder.
  - **Don't** assume system package names are stable across Debian/RHEL families; use the apt/yum branches in `include/init.sh`.

- **What to ask the reviewer if unclear:**
  - Which distributions and version combinations must remain supported? (affects compile flags & patching)
  - Should new builds prefer binaries or always compile from source for reproducibility?

If anything here is unclear or you'd like me to include specific examples from a particular `include/*.sh` file or patch, tell me which area to expand and I'll update the file.
