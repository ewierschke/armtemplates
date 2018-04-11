
#create 3yr cert
echo "Creating self-signed app cert"
cd /root/
openssl req -nodes -sha256 -newkey rsa:2048 -keyout app1.key -out app1.csr -subj "/C=US/ST=ST/L=Loc/O=Org/OU=OU/CN=app1"
openssl x509 -req -sha256 -days 1095 -in app1.csr -signkey app1.key -out app1.pem
cp app1.pem /etc/pki/tls/certs/

# Configure Apache to require app1 cert
echo "Configuring Apache HTTP for cert auth"
mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.authbak
cd /etc/httpd/conf.d/

#add app1.pem as httpd trusted ca
sed -i '/SSLCertificateKeyFile*/a \
SSLCACertificateFile \/etc\/pki\/tls\/certs\/app1.pem' /etc/httpd/conf.d/ssl.conf

#add virtualhost settings and auth requiring app1 cn
sed -i 's|</VirtualHost>|SSLVerifyClient require\nSSLVerifyDepth 1\n</VirtualHost>\n\n<Location "/">\nSSLOptions +FakeBasicAuth\nSSLRequireSSL\nSSLRequire %{SSL_CLIENT_S_DN_CN}  eq "app1"\n</Location>\n|' /etc/httpd/conf.d/ssl.conf

#restart httpd
service httpd restart

#create p12
openssl pkcs12 -export -in /root/app1.pem -inkey /root/app1.key -out /root/app1.p12

#upload p12 to app svc?
