#!/bin/sh

set -x
# check port is open
# nc -uvz tradfri 5684

# get pre-shared key
coap-client -m post \
    -u "Client_identity" -k "$TRADFRI_SECURITY_CODE" \
    -e "{\"9090\":\"$TRADFRI_USERNAME\"}" \
    "coaps://$TRADFRI_IP:5684/15011/9063"
# coap-client -m get -u "IDENTITY" -k "PRE_SHARED_KEY" "coaps://IP_ADDRESS:5684/15001"
# aiocoap-client coaps://tradfri:5684/.well-known/core
