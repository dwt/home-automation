# The Problem

a. I want an easy way to play around with automating HomeKit and Tradfri devices from python
b. I have Phillips Hue devices linked to my Ikea Tradfri Bridge - which the Hub refuses to push to HomeKit - even though it does it fine for all other devices.

# Building libcoap

- braucht `asciidoc` via brew
- braucht `export XML_CATALOG_FILES=/Users/dwt/Library/Homebrew/etc/xml/catalog` damit xmllint funktioniert

# Building / Deploying HomeKit Accessory Protocol Custom Bridge

1. venv with requirements.txt
1. Binaries from libcoap/examples symlinked in the bin folder of the venv
1. Manual start of tradfri_bridge.py once to configure it for the tradfri bridge
1. Manual checks of the `fnordlicht.py` and `light_strip.py` shell tools to check that they are working
1. SystemD / LaunchD Services that starts `tradfri_bridge.py`

# Design overview

`tradfri_bridge.py` implements a custom HomeKit <-> Tradfri Bridge to push the missing Hue device to Homekit. It also allows easy triggering of custom shell scripts to add functionality to HomeKit.

Fnordlicht is just an old CCC name for a random color changing LED Project, so there.

# Documentation

- [Ikea Tradfri CoAP Docs](https://github.com/glenndehaan/ikea-tradfri-coap-docs)
- [Debugging CoAPs with Tradfri](https://github.com/Jan21493/Debugging-COAPS-with-IKEA-Tradfri-gateway)
- [What to do if fritz.box gives wrong ip addresses](https://marcowue.wordpress.com/2012/07/29/abhilfe-fritzbox-dns-lost-lokale-namen-falsch-auf/)
  - Change DHCP IP-Allocation range to not include faulty adrdress
  - Remove faulty entry from network
  - Change DHCP-Range back
  - Wait for device to reconnect
  - Rename

# TODO Debug why pytradfri cannot talk to the tradfri device

- [Tradfricoap can](https://pypi.org/project/tradfricoap/)
  - This worked, and now all the other code works too. ¿¿¿
