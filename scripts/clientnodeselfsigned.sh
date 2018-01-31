# Build self signed cert for use on apache httpd as proxy
echo "Creating self-signed cert"
yum -y install mod_ssl openssl httpd
# Gotta make SELinux happy...
if [[ $(getenforce) = "Enforcing" ]] || [[ $(getenforce) = "Permissive" ]]
then
    chcon -R --reference=/var/lib/tomcat/webapps \
        /var/lib/tomcat/webapps/ROOT.war
    if [[ $(getsebool httpd_can_network_relay | \
        cut -d ">" -f 2 | sed 's/[ ]*//g') = "off" ]]
    then
        echo "Enabling httpd-based proxying within SELinux"
        setsebool -P httpd_can_network_relay=1
        setsebool -P httpd_can_network_connect=1
    fi
fi


cd /root/
openssl req -nodes -sha256 -newkey rsa:2048 -keyout selfsigned.key -out selfsigned.csr -subj "/C=US/ST=ST/L=Loc/O=Org/OU=OU/CN=guac"
openssl x509 -req -sha256 -days 365 -in selfsigned.csr -signkey selfsigned.key -out selfsigned.crt
cp selfsigned.crt /etc/pki/tls/certs/
cp selfsigned.key /etc/pki/tls/private/
cp selfsigned.csr /etc/pki/tls/private/
# Configure Apache to use self signed cert
mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.bak
cd /etc/httpd/conf.d/
echo "Writing new /etc/httpd/conf.d/ssl.conf"
(
    printf "LoadModule ssl_module modules/mod_ssl.so\n"
    printf "\n"
    printf "Listen 443\n"
    printf "\n"
    printf "SSLPassPhraseDialog  builtin\n"
    printf "\n"
    printf "SSLSessionCache         shmcb:/var/cache/mod_ssl/scache(512000)\n"
    printf "SSLSessionCacheTimeout  300\n"
    printf "\n"
    printf "SSLRandomSeed startup file:/dev/urandom  256\n"
    printf "SSLRandomSeed connect builtin\n"
    printf "SSLCryptoDevice builtin\n"
    printf "\n"
    printf "<VirtualHost _default_:443>\n"
    printf "ErrorLog logs/ssl_error_log\n"
    printf "TransferLog logs/ssl_access_log\n"
    printf "LogLevel warn\n"
    printf "SSLEngine On\n"
    printf "\n"
    printf "SSLCertificateFile /etc/pki/tls/certs/selfsigned.crt\n"
    printf "SSLCertificateKeyFile /etc/pki/tls/private/selfsigned.key\n"
    printf "\n"
    printf "BrowserMatch \".*MSIE.*\" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0\n"
    printf "\n"
    printf "ServerName client-vm0\n"
    printf "ServerAlias client-vm0\n"
    printf "\n"
    printf "ProxyRequests Off\n"
    printf "ProxyPreserveHost On\n"
    printf "ProxyPass / http://client-vm0:9200/\n"
    printf "ProxyPassReverse / http://client-vm0:9200/\n"
    printf "\n"
    printf "</VirtualHost>\n"
    printf "\n"
    printf "SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH\n"
    printf "SSLProtocol All -SSLv2 -SSLv3\n"
    printf "SSLHonorCipherOrder On\n"
    printf "Header always set Strict-Transport-Security \"max-age=63072000; includeSubdomains; preload\"\n"
    printf "Header always set X-Frame-Options DENY\n"
    printf "Header always set X-Content-Type-Options nosniff\n"
    printf "SSLCompression off\n"
    printf "SSLUseStapling on\n"
    printf "SSLStaplingCache \"shmcb:logs/stapling-cache(150000)\"\n"
) > /etc/httpd/conf.d/ssl.conf
chmod 644 /etc/httpd/conf.d/ssl.conf

service httpd start
chkconfig httpd on
firewall-cmd --zone=public --permanent --add-port=443/tcp
firewall-cmd --zone=public --add-port=443/tcp
