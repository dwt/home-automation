#!/usr/bin/env python

import sys
import os
import socket
import random

from pytradfri import Gateway
from pytradfri.api.aiocoap_api import APIFactory
from pytradfri.error import PytradfriError
from pytradfri.util import load_json, save_json

from colormath.color_conversions import convert_color
from colormath.color_objects import sRGBColor, XYZColor

import asyncio
import uuid
import argparse

CONFIG_FILE = 'tradfri_standalone_psk.conf'


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', type=str, default=socket.gethostbyname('tradfri'),
                        help='IP Address of your Tradfri gateway')
    parser.add_argument('--key', '-k', dest='key',
                        help='Key found on your Tradfri gateway')
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

def find_light_by_id(light_id, lights):
    for light in lights:
        if light.id == light_id:
            return light

    raise LookupError('Bulb with id %s not found' % light_id)

async def main():
    args = parse_arguments()
    gateway, api = await connect_gateway(args)
    lights = await get_lights(gateway, api)
    # print(lights) # if I want to choose another light

    color_light_id = 65548 # <65548 - Wohnzimmer farbig (TRADFRI bulb E27 CWS opal 600lm)>
    color_light_id = 65559 # <65559 - Lange Wand (LCL001)>

    #  Assuming lights[0] is a RGB bulb
    color_bulb = find_light_by_id(color_light_id, lights)

    while True:
        new_color = random_color(
            color_bulb,
            should_change_hue=False,
            should_change_saturation=True,
            should_change_brightness=False
        )
        await set_color(color_bulb, new_color, api, transition_seconds=6)
        await asyncio.sleep(9)

    # rgb = (244, 0, 0)
    # await set_color(color_bulb, rgb, api)
    # await asyncio.sleep(3)
    # print(get_color(color_bulb))

def run():
    asyncio.run(main())

if __name__ == '__main__':
    run()
