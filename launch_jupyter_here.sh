#!/usr/bin/env bash
# some environment variables for offline use
export HF_DATASETS_OFFLINE=1 TRANSFORMERS_OFFLINE=1 WANDB_MODE=offline

RANDOM_ID=$(uuidgen | cut -c1-8)
PORTAL_FWNAME="$(id -un | tr '[A-Z]' '[a-z]')-$RANDOM_ID-jupyter"
PORTAL_FWFILE="/home/gridsan/portal-url-fw/${PORTAL_FWNAME}"
PORT=18263
echo "Forward name is: ${PORTAL_FWNAME}"
echo "Portal URL is: https://${PORTAL_FWNAME}.fn.txe1-portal.mit.edu/"
echo "http://$(hostname -s):${PORT}/" > $PORTAL_FWFILE
# cat \$PORTAL_FWFILE
chmod u+x ${PORTAL_FWFILE}
screen -d -m  jupyter lab --port ${PORT} --ip $(hostname -s) --no-browser
