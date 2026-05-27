#!/usr/bin/env bash




# Not updated for a long time, may not work with the latest version of DenyHosts
# Use at your risk, and please check the official documentation of DenyHosts for any changes in configuration or installation steps.






HOST=$1
if [ -z "${HOST}" ]; then
    echo "Usage:$0 IP"
    exit 1
fi

echo "Remove IP:${HOST} from denyhosts..."
/etc/init.d/denyhosts stop
echo '
/etc/hosts.deny
/var/lib/denyhosts/hosts
/var/lib/denyhosts/hosts-restricted
/var/lib/denyhosts/hosts-root
/var/lib/denyhosts/hosts-valid
/var/lib/denyhosts/users-hosts
' | grep -v "^$" | xargs sed -i "/${HOST}/d"

#iptables -D INPUT -s ${HOST} -p tcp -m tcp --dport 22 -j DROP
echo " done"
/etc/init.d/denyhosts start