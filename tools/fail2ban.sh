#!/usr/bin/env bash
# website: https://getlnmp.com

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Modern check if user is root
if [[ $EUID -ne 0 ]]; then
    echo "Error: You must be root to run this script. Please use sudo or root."
    exit 1
fi

# Source LNMP framework
. ../lnmp.conf
. ../include/main.sh
Get_Dist_Name
Get_Dist_Version

FAIL2BAN_VER="fail2ban-1.1.0"
FAIL2BAN_VER_SHORT=$(echo "${FAIL2BAN_VER}" | cut -d- -f2)

if [[ "${Use_Official}" == "y" ]]; then
    FAIL2BAN_DL="https://github.com/fail2ban/fail2ban/archive/refs/tags/${FAIL2BAN_VER_SHORT}.tar.gz"
else
    FAIL2BAN_DL="${Download_Mirror}/security/fail2ban/${FAIL2BAN_VER_SHORT}.tar.gz"
fi

Press_Start

echo "-> Installing dependencies..."
# Account for both yum and dnf for modern RHEL compatibility
if [[ "${PM}" == "yum" || "${PM}" == "dnf" ]]; then
    for pkg in python3 python3-setuptools python3-systemd iptables rsyslog; do
        ${PM} install -y "$pkg"
    done
    systemctl restart rsyslog
elif [[ "${PM}" == "apt" ]]; then
    apt-get update
    # Added python3-systemd to Debian/Ubuntu as well so Fail2Ban can parse systemd journals natively
    for pkg in python3 python3-setuptools python3-systemd iptables rsyslog; do
        apt-get install -y "$pkg"
    done
    systemctl restart rsyslog
fi

echo "-> Downloading Fail2Ban..."
mkdir -p ../src/fail2ban
cd ../src/fail2ban || exit 1
Download_Files "${FAIL2BAN_DL}" "${FAIL2BAN_VER_SHORT}.tar.gz"

echo "-> Extracting and Installing Fail2Ban..."
tar zxf "${FAIL2BAN_VER_SHORT}.tar.gz"
cd "${FAIL2BAN_VER}" || exit 1
python3 setup.py install

echo "-> Configuring Fail2Ban..."
\cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Use best-practice jail.d overrides instead of a messy sed injection
mkdir -p /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/sshd.local << 'EOF'
[sshd]
enabled  = true
filter   = sshd
maxretry = 5
bantime  = 604800
EOF

if [[ $(iptables -h | grep -c "\-w") -eq 0 ]]; then
    sed -i 's/lockingopt =.*/lockingopt =/g' /etc/fail2ban/action.d/iptables-common.conf
fi

echo "-> Setting up Systemd unit..."
# Ensure run directory exists for the daemon
mkdir -p /var/run/fail2ban

# Copy the native systemd service file
\cp build/fail2ban.service /etc/systemd/system/fail2ban.service

# Apply RHEL-specific systemd tweaks if necessary
if [[ "${PM}" == "yum" || "${PM}" == "dnf" ]]; then
    sed -i 's#^before = paths-debian.conf#before = paths-fedora.conf#' /etc/fail2ban/jail.local
    sed -i 's/^Environment="PYTHONNOUSERSITE=1"/#Environment="PYTHONNOUSERSITE=1"/' /etc/systemd/system/fail2ban.service
    sed -i 's/-xf start/-x start/' /etc/systemd/system/fail2ban.service
fi

# Reload systemd daemon to recognize the new unit file
systemctl daemon-reload

# Clean up source files
cd ../..
rm -rf "../src/fail2ban/${FAIL2BAN_VER}"

# Execute framework startup tracker
StartUp fail2ban

echo "-> Enabling and starting Fail2Ban service..."
systemctl enable fail2ban
systemctl start fail2ban

echo "-> Installation complete. Service status:"
systemctl status fail2ban --no-pager | grep "Active:"