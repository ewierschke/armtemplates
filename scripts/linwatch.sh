# Watchmaker
(
    printf "yum -y update\n"
    printf "shutdown -r now\n"
) > /root/update.sh
chmod 777 /root/update.sh
yum -y install at
yum -y install epel-release && yum -y --enablerepo=epel install python-pip wget && pip install --upgrade pip setuptools watchmaker && watchmaker -n --log-level debug --log-dir=/var/log/watchmaker
at now + 2 minutes -f /root/update.sh

exit 0