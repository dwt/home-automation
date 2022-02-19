#!/usr/bin/env python

import sys
import os
import socket
import random

from pytradfri import Gateway
from pytradfri.api.aiocoap_api import APIFactory
from pytradfri.error import PytradfriError
from pytradfri.util import load_json, save_json
from pytradfri.const import (
    RANGE_HUE, RANGE_SATURATION, RANGE_BRIGHTNESS,
    ATTR_LIGHT_COLOR_SATURATION, ATTR_LIGHT_COLOR_HUE, 
    ATTR_LIGHT_DIMMER, ATTR_TRANSITION_TIME,
)

import asyncio
import uuid
import argparse

CONFIG_FILE = 'tradfri_standalone_psk.conf'


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--host', type=str, default=socket.gethostbyname('tradfri'), help='IP Address of your Tradfri gateway'
    )
    parser.add_argument('--key', '-k',  help='Key found on your Tradfri gateway')
    parser.add_argument('--transition-seconds', type=int, help='number of seconds for transition')
    parser.add_argument('--hue',        type=int, help='Hue: 0-360')
    parser.add_argument('--saturation', type=int, help='Saturation: 0-100')
    parser.add_argument('--brightness', type=int, help='Brightness: 0-100, 0 for off')
    
    args = parser.parse_args()
    
    if args.host not in load_json(CONFIG_FILE) and args.key is None:
        print("Please provide the 'Security Code' on the back of your "
              "Tradfri gateway:", end=" ")
        key = input().strip()
        if len(key) != 16:
            raise PytradfriError("Invalid 'Security Code' provided.")
        else:
            args.key = key
    
    return args

async def connect_gateway(args):
    # Assign configuration variables.
    # The configuration check takes care they are present.
    conf = load_json(CONFIG_FILE)

    try:
        identity = conf[args.host].get('identity')
        psk = conf[args.host].get('key')
        api_factory = await APIFactory.init(host=args.host, psk_id=identity, psk=psk)
    except KeyError:
        identity = uuid.uuid4().hex
        api_factory = await APIFactory.init(host=args.host, psk_id=identity)

        try:
            psk = await api_factory.generate_psk(args.key)
            print('Generated PSK: ', psk)

            conf[args.host] = {'identity': identity,
                               'key': psk}
            save_json(CONFIG_FILE, conf)
        except AttributeError:
            raise PytradfriError("Please provide the 'Security Code' on the "
                                 "back of your Tradfri gateway using the "
                                 "-K flag.")
    
    api = api_factory.request
    gateway = Gateway()
    # print(gateway, api)
    return (gateway, api)

async def get_lights(gateway, api):
    devices_command = gateway.get_devices()
    devices_commands = await api(devices_command)
    devices = await api(devices_commands)
    return [dev for dev in devices if dev.has_light_control]

async def set_color(lamp, hsb, api, *, transition_seconds):
    transition_time = transition_seconds * 10
    hue, saturation, brightness = hsb
    set_hsb_command = lamp.light_control.set_hsb(hue=hue, saturation=saturation, brightness=brightness, transition_time=transition_time)
    await api(set_hsb_command)

def random_color(lamp, should_change_hue=True, should_change_saturation=True, should_change_brightness=True):
    hue, saturation, brightness, x, y = lamp.light_control.lights[0].hsb_xy_color
    from pytradfri.const import (RANGE_HUE, RANGE_SATURATION, RANGE_BRIGHTNESS)
    r = random.randint
    return (
        r(*RANGE_HUE) if should_change_hue else hue,
        r(*RANGE_SATURATION) if should_change_saturation else saturation,
        r(*RANGE_BRIGHTNESS) if should_change_brightness else brightness
    )

def color_from_args(lamp, args):
    hue, saturation, brightness, x, y = lamp.light_control.lights[0].hsb_xy_color
    return (
        scale(RANGE_HUE, args.hue, default=hue, max=360),
        scale(RANGE_SATURATION, args.saturation, default=saturation),
        scale(RANGE_BRIGHTNESS, args.brightness, default=brightness),
    )

def find_light_by_id(light_id, lights):
    for light in lights:
        if light.id == light_id:
            return light
    
    raise LookupError('Bulb with id %s not found' % light_id)

def scale(range, value, default, max=100):
    "all input values are range 1-100 (except hue)"
    if value is None:
        return default
    
    floated = value / max
    return int(range[-1] * floated)

def partial_color_from_args(args):
    color = dict()
    if args.hue is not None:
        assert args.saturation is not None, 'Can only change hue and saturation together'
        color[ATTR_LIGHT_COLOR_HUE] = \
            scale(RANGE_HUE, args.hue, default=0, max=360)
    if args.saturation is not None:
        assert args.hue is not None, 'Can only change hue and saturation together'
        color[ATTR_LIGHT_COLOR_SATURATION] = \
            scale(RANGE_SATURATION, args.saturation, default=0)
    if args.brightness is not None:
        color[ATTR_LIGHT_DIMMER] = \
            scale(RANGE_BRIGHTNESS, args.brightness, default=0)
    
    if args.transition_seconds is not None:
        color[ATTR_TRANSITION_TIME] = \
            args.transition_seconds * 10
    
    return color

async def main():
    args = parse_arguments()
    gateway, api = await connect_gateway(args)
    lights = await get_lights(gateway, api)
    # print(lights) # if I want to choose another light
    
    color_light_id = 65548 # <65548 - Wohnzimmer farbig (TRADFRI bulb E27 CWS opal 600lm)>
    color_light_id = 65559 # <65559 - Lange Wand (LCL001)>
    
    #  Assuming lights[0] is a RGB bulb
    color_bulb = find_light_by_id(color_light_id, lights)
    
    # color = partial_color_from_args(args)
    # await api(color_bulb.light_control.set_values(values=color))
    
    new_color = color_from_args(color_bulb, args)
    await set_color(color_bulb, new_color, api, transition_seconds=args.transition_seconds)

if __name__ == '__main__':
    asyncio.get_event_loop().run_until_complete(main())

"""
Zu lösenden Probleme: Um das an HomeKitBridge anzuschließen
- Muss ich mir irgendwo den last color wert merken bevor das ding ausgeschaltet war,
  da man die Lampe nicht nach der 'current-color' fragen kann wenn sie aus ist.
  TODO check
- Muss irgendwie die current und target-color merken wenn ich transitions haben
  will die in mehreren einzelnen kommandos kommen
- Muss ich die einzelnen Kommandos von Homekit (Set {Hue,Saturation,Brightness})
  irgendwie zusammen kriegen, ohne das sie sich gegenseitig überschreiben.

Lösung: Eigentlich gibts diesen langlaufenden Prozess doch schon im HomekitBridge Daemon.
Der kann den ganzen State halten, und hier gibt es trotzdem immer nur ein ganz simples
shell interface.
"""