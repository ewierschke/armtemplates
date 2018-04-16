__ScriptName="kibananodeldapsauth.sh"

log()
{
    logger -i -t "${__ScriptName}" -s -- "$1" 2> /dev/console
    echo "$1"
}  # ----------  end of function log  ----------

die()
{
    [ -n "$1" ] && log "$1"
    log "httpd config failed"'!'
    exit 1
}  # ----------  end of function die  ----------

retry()
{
    local n=0
    local try=$1
    local cmd="${@: 2}"
    [[ $# -le 1 ]] && {
    echo "Usage $0 <number_of_retry_attempts> <Command>"; }

    until [[ $n -ge $try ]]
    do
        $cmd && break || {
            echo "Command Fail.."
            ((n++))
            echo "retry $n ::"
            sleep $n;
            }
    done
}  # ----------  end of function retry  ----------

usage()
{
    cat << EOT
  Usage:  ${__ScriptName} [options]

  Note:
  If no options are specified, HTTPD cannot be configured for ldaps auth. This 
  script assumes previous execution of httpdrevproxyselfsigned.sh

  Options:
  -h  Display this message.
  -C  URL from which to download LDAP server public certificate to be added to 
      HTTPD configuration for LDAPS authentication.
  -E  URL from which to download environment specific content zip file.
  -L  DN of the LDAP group to allow access to HTTPD
EOT
}  # ----------  end of function usage  ----------


# Define default values
LDAPS_CERT=
ENV_CONTENT_URL=
LDAP_GROUP_DN=

# Parse command-line parameters
while getopts :h:P:E:L: opt
do
    case "${opt}" in
        h)
            usage
            exit 0
            ;;
        C)
            LDAPS_CERT="${OPTARG}"
            ;;
        E)
            ENV_CONTENT_URL="${OPTARG}"
            ;;
        L)
            LDAP_GROUP_DN="${OPTARG}"
            ;;
        \?)
            usage
            echo "ERROR: unknown parameter \"$OPTARG\""
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

# Validate parameters
if [ -z "${LDAPS_CERT}" ]
then
    echo "No LDAPS_CERT (-c) was provided, can't configure HTTPD for LDAPS auth"
    exit 1
fi

yum -y install wget unzip 
if [ -n "${LDAPS_CERT}" ]
then
    # download LDAPS certificate not in public chain
    log "Downloading cert for LDAP DCs not in public chain"
    retry 5 wget --timeout=10 \
    "${LDAPS_CERT}" -O /etc/pki/tls/certs/envCA.cer|| \
    die "Could not download ldap cert"
fi

JOIN_TRIM=https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/join-trim.sh
retry 5 wget --timeout=10 \
    "${JOIN_TRIM}" -O /root/join-trim.sh|| \
    die "Could not download join-trim.sh"
chmod 755 /root/join-trim.sh

retry 5 wget --timeout=10 \
    "${ENV_CONTENT_URL}" -O /root/content.zip|| \
    die "Could not download ldap cert"
unzip /root/content.zip -d /root

#get content into variables
yum -y install epel-release
yum -y install python-pip jq
pip install pyyaml
python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < /root/env.sls > /root/env.json
key1=$(jq '.key' /root/env.json)
pass1=$(jq '.encrypted_password' /root/env.json)
key1=$(sed -e 's/^"//' -e 's/"$//' <<<"$key1")
pass1=$(sed -e 's/^"//' -e 's/"$//' <<<"$pass1")
clearpass=$(/root/join-trim.sh ${pass1} ${key1})
user=$(jq '.username' /root/env.json)
user=$(sed -e 's/^"//' -e 's/"$//' <<<"$user")

#get current suffix from network
yum -y install bind-utils
domain=$(nmcli dev show | grep DOMAIN | awk '{print $2}')
dcarray=($(host -t srv _ldap._tcp.${domain} | awk '{print $8}'))
dc1=${dcarray[0]::-1}
dc2=${dcarray[1]::-1}
#convert to dn format
dn=$(sed -e 's/\./,dc=/' <<<"$domain")
fulldn=dc=${dn}

#to-do add check to validate LDAP_GROUP_DN against dn of domain

#adjust httpd config
log "Configuring Apache HTTP for cert auth"
yum -y install mod_ldap
cp /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.authbak
cd /etc/httpd/conf.d/

#add ldap cert as httpd trusted globalcert
sed -i 's|LoadModule ssl_module modules/mod_ssl.so|LoadModule ssl_module modules/mod_ssl.so\n\nLDAPVerifyServerCert off\nLDAPTrustedMode SSL\nLDAPTrustedGlobalCert CA_BASE64 /etc/pki/tls/certs/envCA.cer\n|' /etc/httpd/conf.d/ssl.conf

#add virtualhost settings and auth requiring app1 cn
sed -i 's|</VirtualHost>|</VirtualHost>\n\n<Location "/">\nAuthName "AD authentication"\nAuthBasicProvider ldap\nAuthType Basic\nAuthLDAPGroupAttribute member\nAuthLDAPGroupAttributeIsDN On\nAuthLDAPURL ldaps://<dc1>:636/<fulldn>?sAMAccountName?sub?(objectClass=*)\nAuthLDAPURL ldaps://<dc2>:636/<fulldn>?sAMAccountName?sub?(objectClass=*)\nAuthLDAPBindDN <user><fulldn>\nAuthLDAPBindPassword <password>\nrequire ldap-group <groupfulldn>\n</Location>\n|' /etc/httpd/conf.d/ssl.conf

#replace placeholders with variables
##to-do need to check for variable population before executing sed
sed -i "s|<dc1>|${dc1}|" /etc/httpd/conf.d/ssl.conf
sed -i "s|<dc2>|${dc2}|" /etc/httpd/conf.d/ssl.conf
sed -i "s|<fulldn>|${fulldn}|g" /etc/httpd/conf.d/ssl.conf
sed -i "s|<user>|${user}|" /etc/httpd/conf.d/ssl.conf
sed -i "s|<password>|${clearpass}|" /etc/httpd/conf.d/ssl.conf
sed -i "s|<groupfulldn>|${LDAP_GROUP_DN}|" /etc/httpd/conf.d/ssl.conf
####

## syntax must be correct, cert file has to exist, module has to be installed for successfull restart
#restart httpd
service httpd restart

