#!/usr/bin/env bash

#Varibles
FullChainFile="fullchain.pem"
WebDirectoryDestination="/usr/local/www/main/certs/"

#Functions
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf "%s" "$var"
}


set -e
for domain in $RENEWED_DOMAINS; do
# Just an example, you can use any non-sensitive storage medium you want
  cp -rL "$RENEWED_LINEAGE/$FullChainFile" $WebDirectoryDestination

  SHA256SUM=$(trim "$(openssl dgst -sha256 "${WebDirectoryDestination}/${FullChainFile}" | cut -d"=" -f2)")
  echo "Creating SHA256 digest for ${FullChainFile}"
  printf "%s" "${SHA256SUM}" > "${WebDirectoryDestination}/${FullChainFile}.sha256"
done

