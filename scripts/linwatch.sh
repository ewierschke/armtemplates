# Watchmaker
yum -y install epel-release && yum -y --enablerepo=epel install python-pip wget && pip install --upgrade pip setuptools watchmaker && watchmaker --log-level debug --log-dir=/var/log/watchmaker
exit 0