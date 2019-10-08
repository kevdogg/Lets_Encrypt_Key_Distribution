#!/usr/bin/env bash

# Inspiration for script
# https://community.letsencrypt.org/t/automated-deployment-of-key-cert-from-reverse-proxy-to-internal-systems/64491/4
# https://gist.github.com/onnimonni/b49779ebc96216771a6be3de46449fa1

# Put this in crontab for every 12 hours

# Assumptions of script:
  # SSL Certs are obtained through Let's Encrypt
# This script will grab fullchain.pem file from host that renewed the Let's Encrypt certs.  On the host - after updating the LE certs, the fullchain.pem is copied to directory via a --deploy-hook script for distribution within Local LAN computers.  Apache configuration restricts access of this file to IP addresses on the Local LAN
# fullchain.pem file is not secret in that it is normally read and passed in headers during the normal SSL handshake
# Script also assumes the the privkey.pem has previously been distributed since this key is secret.  This script will check for presence of privkey.pem and will exit if key is not found. privkey.pem file should not change with LE certification renewal since certs are renewed with --reuse-key option that reuses the private key.
# Depending on application, script can either restart apache or other service.  Script should work on Linux/BSD operating systems

#For reference the deploy-hook script is referenced here:
##!/usr/bin/env bash
#set -e
#for domain in $RENEWED_DOMAINS; do
#   # Just an example, you can use any non-sensitive storage medium you want
#  cp -rL "$RENEWED_LINEAGE/fullchain.pem" /usr/local/www/main/certs/
#done

#For reference -- this could be placed within Apache Virtual Host section
#   <Directory /usr/local/www/main/certs>
#        Require all denied
#        Options -Indexes
#        <RequireAll>
#              Require ip 10.0.1.0/24
#        </RequireAll>
#   </Directory>

#### VARIABLES SECTION -- PLEASE MODIFY

## Server Variables
## Server where Certs will be Obtained -- LAN SERVER
SERVER="10.0.1.158"
SERVER_PATH="/certs/fullchain.pem"
SERVER_DOMAIN="<DOMAIN NAME HERE>"

## Local Variables
## Local Directory where certs are located
CERTS_DIR="/usr/local/etc/letsencrypt/live/${SERVER_DOMAIN}"
OS=`uname`
## Please specify service name here:
  ## If apache web server SERVICE_NAME="apache"
  ## If other service other than apache use service name -- ie SERVICE_NAME="xo-server.service"
SERVICE_NAME="xo-server.service"

### END VARIABLE SECTION


get_sha256sum() {
	cat $1 | shasum -a 256 | head -c 64
}

error(){
	echo "ERROR: $1"
	exit 1
}

set -euf -o pipefail


# Download the latest certificate to a temporarily location so we can check validity
curl -s -k -o /tmp/fullchain.pem "https://${SERVER}${SERVER_PATH}"

# Verify the certificate is valid for our existing key (should be)
MOD_CRT=$(openssl x509 -noout -modulus -in /tmp/fullchain.pem | openssl md5)

#Check Existence of privkey.pem on local server
if [ ! -f ${CERTS_DIR}/privkey.pem ]; then
	error "File ${CERTS_DIR}/privkey.pem does not exist!. Please install Let's Encrypt privkey.pem to ${CERTS_DIR}"
fi

MOD_KEY=$(openssl rsa -noout -modulus -in ${CERTS_DIR}/privkey.pem | openssl md5)

if [ "$MOD_CRT" != "$MOD_KEY" ]; then
     error "Key didn't match: $MOD_CRT vs $MOD_KEY"
fi

# Deploy the certificate and restart service if new fullchain.pem is different than old fullchain.pem

SHA256_OLD=0
if [ -f "${CERTS_DIR}/fullchain.pem" ]; then
	SHA256_OLD=$(get_sha256sum "${CERTS_DIR}/fullchain.pem")
fi
SHA256_NEW=$(get_sha256sum "/tmp/fullchain.pem")

#echo "SHA256 current file: $SHA256_OLD"
#echo "SHA256 new file: $SHA256_NEW"

if [ ${SHA256_OLD} != ${SHA256_NEW} ]
then
     echo "New certificate: $(openssl x509 -in /tmp/fullchain.pem -noout -subject -dates -issuer)"

     DATE=`date +"%m-%d-%Y-%T"`
     mv ${CERTS_DIR}/fullchain.pem ${CERTS_DIR}/fullchain-${DATE}.pem
     cp /tmp/fullchain.pem ${CERTS_DIR}/fullchain.pem
     rm /tmp/fullchain.pem

     if [ $SERVICE_NAME == "apache" ]
     then
          apachectl -k graceful
     elif [[ "${SERVICE_NAME}" =~ \.service$ ]]
     then 
	   if [ $OS == "Linux" ]
           then
                systemctl stop ${SERVICE_NAME}
                sleep 20
                systemctl start ${SERVICE_NAME}
                echo -n "Restarting xo server..."
                #echo "In restart Linux service"
           elif [ $OS == "FreeBSD" ]
	   then
	        service ${SERVICE_NAME} stop
	        sleep 20
	        service ${SERVICE_NAME} start
	        #echo "In restart BSD service"
           fi
     fi
#else 
#     echo "SHA256 sums for fullchain.pem's match"
fi

echo "Done"
