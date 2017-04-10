#!/bin/bash
#
# Description:
#    This script is intended to aid an administrator in quickly
#    setting up a baseline configuration of the Guacamole
#    management-protocol HTTP-tunneling service. When the script
#    exits successfully:
#    * The Tomcat servlet-service will have been downloaded and
#      enabled
#    * N/A-The Guacamole service will have been configured to tunnel
#      SSH based connections to the Guacamole host to a remote,
#      HTML 5 compliant web browser.
#    * N/A-Apache 2.4 will have been configured to provide a proxy of
#      all public-facing port 80/tcp traffic to the Guacamole
#      servlet listening at localhost port 8080/tcp
#    * Feb-2017 - modified to run script under CentOS6 after running 
#      SystemPrep hardening script
#    * Script relies on preparation of LDAP Schema and object creation
#      for connection configuration
#
#################################################################

usage()
{
    cat << EOT
  Usage:  ${__ScriptName} [options]

  Note:
  If no options are specified, then Guacamole v${__GuacVersion} will be
  installed, but it will not be configured and users will not be able to
  authenticate. Specify -H (and associated options) to configure LDAP
  authentication. Specify -G (and associated options) to configure file-based
  authentication.

  Options:
  -h  Display this message.
  -H  Hostname of the LDAP server to authenticate users against
      (e.g. ldap.example.com). Using the domain DNS name is acceptable as long
      as it resolves to an LDAP server (e.g. example.com). If specified, LDAP
      authentication will be installed and configured. Requires -D.
  -D  Distinguished Name (DN) of the directory (e.g. DN=example,DN=com).
      Required by -H.
  -U  The base of the DN for all Guacamole users. This is prepended to the
      directory DN (-D) to create the full DN to the user container. This will
      be appended to the username when a user logs in. Default is "CN=Users".
  -R  The base of the DN for all Guacamole roles. This is used by the LDAP
      plugin to search for groups the user is a member of. Using this option
      will enable Roles Based Access Control (RBAC) support. This is prepended
      to the directory DN (-D) to create the full DN to the RBAC container.
  -A  The attribute which contains the username and which is part of the DN
      for all Guacamole users. Usually, this will be "uid" or "cn". This is
      used together with the user base DN (-U) to derive the full DN of each
      user logging in. Default is "cn".
  -C  The base of the DN for all Guacamole configurations. Each configuration
      is analogous to a connection. This is prepended to the directory DN (-D)
      to create the full DN to the configuration container. Default is
      "CN=GuacConfigGroups". NOTE: This default value does not exist by
      default in the LDAP directory and will need to be created, or a
      different value will need to be provided.
  -P  Port on which to connect to the LDAP server. Default is "389".
  -v  Version of Guacamole to build, install, and configure.
      Default is "${__GuacVersion}".
  -G  A username authorized to use the Guacamole service that will be
      authenticated using the basic file authentication provider.
  -g  Password for the Guacamole user (-G). If -G is provided, then this
      parameter is required.
  -S  An Operating System (OS) username that will be created and allowed to
      login via SSH. This parameter is only valid if -G is specified, as well.
      If this parameter is not provided but -G is, then the -G username will
      be used for the OS user.
  -s  Password for the OS user (-S). If -S is specified, then this parameter
      is required.
  -L  URL for first link to be included in Guac login page. If -T is specified,
      then this parameter is required for successful modification.
  -T  Text to be displayed for the URL provided with -L.  If -L is specified,
      then this parameter is required for successful modification.
  -l  URL for second link to be included in Guac login page. If -t is specified,
      then this parameter is required for successful modification.
  -t  Text to be displayed for the URL provided with -l.  If -l is specified,
      then this parameter is required for successful modification.
EOT
}  # ----------  end of function usage  ----------


# Define default values
LDAP_HOSTNAME=
LDAP_DOMAIN_DN=
LDAP_USER_BASE="CN=Users"
LDAP_USER_ATTRIBUTE="cn"
LDAP_CONFIG_BASE="CN=GuacConfigGroups"
LDAP_GROUP_BASE="CN=Users"
LDAP_PORT="389"
GUAC_VERSION="${__GuacVersion}"
GUAC_USERNAME=
GUAC_PASSWORD=
SSH_USERNAME=
SSH_PASSWORD=
URL_1=
URLTEXT_1=
URL_2=
URLTEXT_2=


# Parse command-line parameters
while getopts :hH:D:U:R:A:C:P:v:G:g:S:s:L:T:l:t: opt
do
    case "${opt}" in
        h)
            usage
            exit 0
            ;;
        H)
            LDAP_HOSTNAME="${OPTARG}"
            ;;
        D)
            LDAP_DOMAIN_DN="${OPTARG}"
            ;;
        U)
            LDAP_USER_BASE="${OPTARG}"
            ;;
        R)
            LDAP_GROUP_BASE="${OPTARG}"
            ;;
        A)
            LDAP_USER_ATTRIBUTE="${OPTARG}"
            ;;
        C)
            LDAP_CONFIG_BASE="${OPTARG}"
            ;;
        P)
            LDAP_PORT="${OPTARG}"
            ;;
        v)
            GUAC_VERSION="${OPTARG}"
            ;;
        G)
            GUAC_USERNAME="${OPTARG}"
            ;;
        g)
            GUAC_PASSWORD="${OPTARG}"
            ;;
        S)
            SSH_USERNAME="${OPTARG}"
            ;;
        s)
            SSH_PASSWORD="${OPTARG}"
            ;;
        L)
            URL_1="${OPTARG}"
            ;;
        T)
            URLTEXT_1="${OPTARG}"
            ;;
        l)
            URL_2="${OPTARG}"
            ;;
        t)
            URLTEXT_2="${OPTARG}"
            ;;
        \?)
            usage
            echo "ERROR: unknown parameter \"$OPTARG\""
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

yum -y --enablerepo=epel install python-pip wget  
pip install --upgrade pip setuptools watchmaker  
wget https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/make-guac-centos-wcert.sh  
chmod 700 make-guac-centos-wcert.sh  
watchmaker -vv -n --log-dir=/var/log/watchmaker  
./make-guac-centos-wcert.sh -H ${LDAP_HOSTNAME} -D ${LDAP_DOMAIN_DN} -U ${LDAP_USER_BASE} 
shutdown -r +5