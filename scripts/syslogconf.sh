#!/bin/bash
#
# Description:
#    This script is intended configure rsyslog to accept syslog messages

#Install rsyslog
yum -y install rsyslog rsyslog-doc

#configure rsyslog to listen on udp and/or tcp
sed -i "s|#\$ModLoad imudp|\$ModLoad imudp|g" /etc/rsyslog.conf
sed -i "s|#\$UDPServerRun 514|\$UDPServerRun 514|g" /etc/rsyslog.conf
#sed -i "s|#\$ModLoad imtcp|\$ModLoad imtcp|g" /etc/rsyslog.conf
#sed -i "s|#\$InputTCPServerRun 514|\$InputTCPServerRun 514|g" /etc/rsyslog.conf

#Start rsyslog service
service rsyslog restart
chkconfig rsyslog on

#open fireall port for udp 514
#default syslog service definition in /usr/lib/firewalld/services/ only covers udp
firewall-offline-cmd --zone=public --add-service=syslog
#firewall-offline-cmd --zone=public --permanent --add-service=syslog

#ensure varVol is large enough for extensions
varsize=$(lvdisplay | awk '/varVol/{found=1}; /LV Size/ && found{print $3; exit}')
thisvarsize=${varsize%%.*}
if [ "$thisvarsize" -ge 800 ]
    then lvextend -L+2G /dev/VolGroup00/varVol
    resize2fs /dev/VolGroup00/varVol
fi

#schedule yum update and reboot
(
    printf "yum -y update\n"
    printf "shutdown -r now\n"
) > /root/update.sh
chmod 777 /root/update.sh
yum -y install at
service atd start
chkconfig atd on
at now + 3 minutes -f /root/update.sh
