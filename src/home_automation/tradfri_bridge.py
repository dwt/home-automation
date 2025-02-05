#!/usr/bin/env python

import logging
import signal
import subprocess

from pyhap import const
from pyhap.accessory import Accessory, Bridge
from pyhap.accessory_driver import AccessoryDriver

logger = logging.getLogger(__name__)


class Fnordlicht(Accessory):
    """A switch accessory that starts / stops the fnordlicht."""

    category = const.CATEGORY_LIGHTBULB

    def __init__(self, *args, **kwargs):
        """Initialise and set a shutdown callback to the On characteristic."""
        super().__init__(*args, **kwargs)
        serv_light = self.add_preload_service('Lightbulb')
        self.char_on = serv_light.configure_char(
            'On', setter_callback=self.toggle_fnordlicht)

        self.subprocess = None

    def toggle_fnordlicht(self, should_turn_on):
        if should_turn_on:
            self.execute_turn_on()
        else:
            self.execute_turn_off()

    def execute_turn_on(self):
        logger.info("Executing turn on command.")
        self.subprocess = subprocess.Popen(['fnordlicht'])

    def execute_turn_off(self):
        logger.info("Executing turn off command.")
        if self.subprocess is not None:
            self.subprocess.kill()
            self.subprocess = None

    def stop(self):
        super().stop()
        logger.info('stopping')
        self.execute_turn_off()

class PhillipsHueLightStrip(Accessory):
    "A switch to control the Lightstrip"

    category = const.CATEGORY_LIGHTBULB

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        light_service = self.add_preload_service(
            'Lightbulb', chars=['On', 'Hue', 'Saturation', 'Brightness']
        )

        self.char_on = light_service.configure_char(
            'On', setter_callback=self.toggle_on
        )
        self.char_hue = light_service.configure_char(
            'Hue', setter_callback=self.set_hue
        )
        self.char_saturation = light_service.configure_char(
            'Saturation', setter_callback=self.set_saturation
        )
        self.char_brightness = light_service.configure_char(
            'Brightness', setter_callback=self.set_brightness
        )

        self.is_on = False
        self.hue = self.saturation = self.brightness = 0
        self.sync()

    def toggle_on(self, should_be_on):
        self.is_on = should_be_on
        self.sync()

    def set_hue(self, value):
        self.hue = value
        self.sync()

    def set_saturation(self, value):
        self.saturation = value
        self.sync()

    def set_brightness(self, value):
        self.brightness = value
        self.sync()

    def sync(self):
        hue, saturation, brightness = self.hue, self.saturation, self.brightness
        if not self.is_on:
            brightness = 0

        subprocess.run([
            'light_strip',
            '--hue', str(hue),
            '--saturation', str(saturation),
            '--brightness', str(brightness),
            '--transition-seconds', str(1)
        ])




def main():
    logging.basicConfig(level=logging.INFO)

    # The AccessoryDriver preserves the state of the accessory
    # (by default, in the below file), so that you can restart it without pairing again.
    driver = AccessoryDriver(port=51826, persist_file='fnordlicht.state')

    bridge = Bridge(driver, 'Bridge')
    bridge.add_accessory(Fnordlicht(driver, 'Fnordlicht'))
    bridge.add_accessory(PhillipsHueLightStrip(driver, 'Lange Wand'))
    driver.add_accessory(accessory=bridge)

    # We want KeyboardInterrupts and SIGTERM (kill) to be handled by the driver itself,
    # so that it can gracefully stop the accessory, server and advertising.
    signal.signal(signal.SIGINT, driver.signal_handler)
    signal.signal(signal.SIGTERM, driver.signal_handler)

    driver.start()

if __name__ == '__main__':
    main()
