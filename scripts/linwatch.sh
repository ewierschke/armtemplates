#!/bin/bash
# Watchmaker
(
    printf "yum -y update\n"
    printf "shutdown -r now\n"
) > /root/update.sh
chmod 777 /root/update.sh
service=firewalld
chkconfig $service on
if (( $(pgrep $service | wc -l) > 0 ))
then
    echo "$service is running"
else
    /bin/systemctl start $service
fi
yum -y install at
yum -y install epel-release && yum -y --enablerepo=epel install python-pip wget && pip install --upgrade pip setuptools watchmaker && watchmaker -n --log-level debug --log-dir=/var/log/watchmaker --config=/usr/lib/python2.7/site-packages/watchmaker/static/config.yaml 
salt-call --local ash.fips_disable
at now + 2 minutes -f /root/update.sh

exit 0