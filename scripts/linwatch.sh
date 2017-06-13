# Watchmaker
yum -y install epel-release && yum -y --enablerepo=epel install python-pip wget && pip install --upgrade pip setuptools watchmaker && watchmaker -n --log-level debug --log-dir=/var/log/watchmaker
yum -y update
shutdown -r +2

exit 0