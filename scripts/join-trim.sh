#!/bin/sh
#
# Helper-script to more-intelligently handle joining PBIS client
# to domain. Script replaces "PBIS-join" cmd.run method with
# stateful cmd.script method. Script accepts following arguments:
#
# * PWCRYPT: Obfuscated password for the ${SVCACCT} domain-joiner
#       account. Passed via the Salt-parameter 'svcPasswdCrypt'.
# * PWUNLOCK: String used to return Obfuscated password to clear-
#       text. Passed via the Salt-parameter 'svcPasswdUlk'.
#
#################################################################
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/pbis/bin
PWCRYPT=${1:-UNDEF}
PWUNLOCK=${2:-UNDEF}



# Get clear-text password from crypt
function PWdecrypt() {
   local PWCLEAR
   PWCLEAR=$(echo "${PWCRYPT}" | openssl enc -aes-256-cbc -md sha256 -a -d \
             -salt -pass pass:"${PWUNLOCK}")
   if [[ $? -ne 0 ]]
   then
     echo ""
   else
     echo "${PWCLEAR}"
   fi
}



#########################
## Main program flow...
#########################

# Make sure all were the parms were passed
if [[ ${PWCRYPT} = UNDEF ]] || \
   [[ ${PWUNLOCK} = UNDEF ]]
then
   printf "Usage: $0 <JOIN_PASS_CRYPT> <JOIN_PASS_UNLOCK>\n"
   echo "Failed to pass a required parameter. Aborting."
   exit 1
fi


SVCPASS="$(PWdecrypt)"

echo $SVCPASS