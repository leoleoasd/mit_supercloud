#!/usr/bin/env bash

fwname="job"
port=3000

while getopts p:n:h flag
do
    case "${flag}" in
        p) port=${OPTARG};;
        n) fwname=${OPTARG};;
        h|*) echo "usage: $0 [-n name]"; exit 1;;
    esac
done

RANDOM_ID=$(uuidgen | cut -c1-8)
PORTAL_FWNAME="$(id -un | tr '[A-Z]' '[a-z]')-$fwname-$RANDOM_ID"
PORTAL_FWFILE="/home/gridsan/portal-url-fw/${PORTAL_FWNAME}"

echo "Forward name is: ${PORTAL_FWNAME}"
echo "Portal URL is: https://${PORTAL_FWNAME}.fn.txe1-portal.mit.edu/"
echo "http://$(hostname -s):${port}/" > $PORTAL_FWFILE
# cat \$PORTAL_FWFILE
chmod u+x ${PORTAL_FWFILE}
