#!/bin/bash
#
# Description:
#    This script is intended to be used for configuration of the 
#    Guacamole user-mapping.xml file user entries based on secrets stored
#    in an Azure Key Vault.
#    The secret ID is used as the Guacamole username and secret value as password.
#    This script assumes a Service Principal in Azure AD has already been 
#    created and configured with the appropriate permissions/key vault access
#    policy to read the Azure Key Vault secrets. (PermissionsToSecrets Get,Set,List)
#    This script assumes CentOS 7 and installs Python 3.6 in order to install 
#    the azure-cli.
#
#################################################################
__ScriptName="guac-users-from-keyvault.sh"

log()
{
    logger -i -t "${__ScriptName}" -s -- "$1" 2> /dev/console
    echo "$1"
}  # ----------  end of function log  ----------


die()
{
    [ -n "$1" ] && log "$1"
    log "Users from keyvault setup failed"'!'
    exit 1
}  # ----------  end of function die  ----------


__md5sum()
{
    local pass="${1}"
    echo -n "${pass}" | /usr/bin/md5sum - | cut -d ' ' -f 1
}  # ----------  end of function md5sum  ----------


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
  If no service principal id is specified, the script fails

  Options:
  -h  Display this message.
  -V  Previously created Azure AD Service Principal to be used to query  
      Azure Key Vault.
  -p  Previously created Azure AD Service Principal Password to be used 
      to query Azure Key Vault.
  -e  Azure AD Tenant ID, to be used with Azure AD Service Principal to 
      query Azure Key Vault.
  -r  RDSH FQDN to be configured for user access from key vault script
      entry could be single host or load balancer.
  -k  Azure Key Vault Name that contains secrets.
  -E  Azure Environment Name to use for azure-cli login, defines the azure-cli 
      endpoints to use.  If not provided default AzureCloud is unchanged.
EOT
}  # ----------  end of function usage  ----------


# Define default values
AZAD_SVC_PRIN_ID=
AZAD_SVC_PRIN_PASS=
AZAD_TENANT_ID=
RDP_FQDN=
AZ_KEYVAULT_NAME=
AZ_ENV=

# Parse command-line parameters
while getopts :hV:p:e:r:k:E: opt
do
    case "${opt}" in
        h)
            usage
            exit 0
            ;;
        V)
            AZAD_SVC_PRIN_ID="${OPTARG}"
            ;;
        p)
            AZAD_SVC_PRIN_PASS="${OPTARG}"
            ;;
        e)
            AZAD_TENANT_ID="${OPTARG}"
            ;;
        r)
            RDP_FQDN="${OPTARG}"
            ;;
        k)
            AZ_KEYVAULT_NAME="${OPTARG}"
            ;;
        E)
            AZ_ENV="${OPTARG}"
            ;;
        \?)
            usage
            echo "ERROR: unknown parameter \"$OPTARG\""
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))


# Validate Azure parameters
if [ -z "${AZAD_SVC_PRIN_ID}" ]
then
    die "Azure AD Service Principal was not provided (-V)"
fi

if [ -n "${AZAD_SVC_PRIN_ID}" ]
then
    if [ -z "${AZAD_SVC_PRIN_PASS}" ]
    then
        die "Azure AD Service Principal provided (-V), but the Azure AD Service Principal Password was not (-p)"
    fi
    if [ -z "${AZAD_TENANT_ID}" ]
    then
        die "Azure AD Service Principal provided (-V), but the Azure AD Tenant ID was not (-e)"
    fi
    if [ -z "${RDP_FQDN}" ]
    then
        die "Azure AD Service Principal provided (-V), but the RDP FQDN was not (-r)"
    fi
    if [ -z "${AZ_KEYVAULT_NAME}" ]
    then
        die "Azure AD Service Principal provided (-V), but the Azure Key Vault name was not (-K)"
    fi
elif [ -n "${AZAD_SVC_PRIN_PASS}" ]
then
    die "Azure AD Service Principal Password was provided (-p), but the Azure AD Service Principal provided (-V) was not"
elif [ -n "${AZAD_TENANT_ID}" ]
then
    die "Azure AD Tenant ID was provided (-e), but the Azure AD Service Principal provided (-V) was not"
elif [ -n "${RDP_FQDN}" ]
then
    die "RDP FQDN was provided (-r), but the Azure AD Service Principal provided (-V) was not"
elif [ -n "${AZ_KEYVAULT_NAME}" ]
then
    die "Azure Key Vault name was provided (-K), but the Azure AD Service Principal provided (-V) was not"
fi


# Start the real work
retry 2 yum -y install yum-utils
retry 2 yum -y install https://centos7.iuscommunity.org/ius-release.rpm
# Install Python 3.6 and other azure-cli deps
log "Installing Python 3.6 and Azure CLI deps"
retry 2 yum -y install python36u python36u-pip python36u-devel openssl-devel libffi-devel gcc jq
mkdir environments
cd environments
python3.6 -m venv my_env
source my_env/bin/activate
# Install azure-cli in virtual environment
log "Installing Azure CLI"
pip3.6 install azure-cli
pip3.6 install --upgrade urllib3

# Set Azure Environment 
if [ -n "${AZ_ENV}" ]
then
    az cloud set --name "${AZ_ENV}"
fi
# Login to Azure
az login --service-principal -u "${AZAD_SVC_PRIN_ID}" --password "${AZAD_SVC_PRIN_PASS}" --tenant "${AZAD_TENANT_ID}"
    if [[ $? -ne 0 ]]
    then
        die "Login to azure-cli failed"
    fi

#Collect list of Secrets; to be used as usernames
secrets=$(az keyvault secret list --vault-name "${AZ_KEYVAULT_NAME}")
echo $secrets | jq '. | length' > /tmp/secretcount
count=$(cat /tmp/secretcount)
echo $secrets | jq '.[] | .id' > /tmp/ids1
sed 's\.*/\\g' /tmp/ids1 > /tmp/ids2
sed 's/"//' /tmp/ids2 > /tmp/idsclean
readarray -t usernames < /tmp/idsclean

#Create user-mapping.xml file
log "Writing opening section of /etc/guacamole/user-mapping.xml"
(
    printf "<user-mapping>\n"
    printf "\t<!-- Per-user authentication and config information -->\n"
) >> /etc/guacamole/user-mapping.xml

v=0
for (( c=1; c<=$count; c++ ))
do
    GUAC_PASS=$(az keyvault secret show --vault-name "${AZ_KEYVAULT_NAME}" --name ${usernames[v]} | jq '.value' | sed 's/"//' | sed s'/.$//')
    GUACPASS_MD5=$(__md5sum "${GUAC_PASS}")
    log "Writing user section of /etc/guacamole/user-mapping.xml"
    (
        printf "\t<authorize username=\"%s\" password=\"%s\" encoding=\"%s\">\n" "${usernames[v]}" "${GUACPASS_MD5}" "md5"
        printf "\t\t<protocol>rdp</protocol>\n"
        printf "\t\t\t<param name=\"hostname\">%s</param>\n" "${RDP_FQDN}"
        printf "\t\t\t<param name=\"port\">3389</param>\n"
        printf "\t\t\t<param name=\"ignore-cert\">true</param>\n"
        printf "\t\t\t<param name=\"server-layout\">en-us-qwerty</param>\n"
        printf "\t\t\t<param name=\"security\">nla</param>\n"
        printf "\t\t\t<param name=\"username\">\${GUAC_USERNAME}</param>\n"
        printf "\t\t\t<param name=\"password\">\${GUAC_PASSWORD}</param>\n"
        printf "\t</authorize>\n"

    ) >> /etc/guacamole/user-mapping.xml
    v=$[v+1]
done

log "Writing closing section of /etc/guacamole/user-mapping.xml"
(
    printf "</user-mapping>\n"
) >> /etc/guacamole/user-mapping.xml

#log "Adding the basic user mapping setting to guacamole.properties"
#(
#    echo ""
#    echo "# Properties used by BasicFileAuthenticationProvider"
#    echo "basic-user-mapping: /etc/guacamole/user-mapping.xml"
#) >> /etc/guacamole/guacamole.properties

#clean up
rm -rf /tmp/ids1
rm -rf /tmp/ids2
rm -rf /tmp/idsclean 
rm -rf /tmp/secretcount


