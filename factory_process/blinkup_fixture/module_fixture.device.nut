/*
Copyright (C) 2013 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* ========================================================================================
Sample application: Factory blinkup fixture (factory imp to imp card)

Author: Aron

Date: 1st August, 2013

This example code is for blessing devices in a factory using a factory blinkup fixture.
For this example:
- the factory blinkup fixture is a factory imp in an April board
  mounted on an enclosure with an LED on pin9 and a button on pin8. When the
  button is pressed it triggers the LED to flash factory BlinkUp code
- the example device receiving factory BlinkUp is an Lala board with a button on pin1 and an LED on pinD.
- when the fixture is used to successfully blink the Lala board, it will reboot with this firmware and 
  flash the green LED rapidly. If the button is pressed within 10 seconds, the device testing is marked 
  as "pass" and the blessing proceeds. If the button is not pressed the device is marked us
  failed and therefore not blessed.
- the LED on the device's imp card (not the factory blinkup fixure) will turn solid green indicating pass/bless or
  turn solid red indicating fail/no blessing
- the webhooks will then be notified of the blessing event and take further actions
========================================================================================== */

const SSID = "yourSSID";
const PASSWORD = "yourWifiPW";
const FIXTURE_MAC = "themacofthefixture";
const THROTTLE_TIME = 10;
const SUCCESS_TIMEOUT = 20;

imp.configure("Factory Blinkup", [], []);
server.show("");

throttle_protection <- false;
finished <- false;

mac <- imp.getmacaddress();
impeeid <- hardware.getimpeeid();

bless_success <- false;

switch (mac) {
    case FIXTURE_MAC:
        server.log("This is the factory imp with mac " + mac + " and factory blinkup fixture impee ID " + impeeid + ". It will blinkup to SSID " + SSID);

        hardware.pin9.configure(DIGITAL_OUT);
        hardware.pin9.write(0);
        hardware.pin8.configure(DIGITAL_IN_PULLUP, function() {
            local buttonState = hardware.pin8.read();
            if (buttonState == 0 && !throttle_protection) {

                // Don't allow this to happen more than once per XXX seconds
                throttle_protection = true;
                imp.wakeup(THROTTLE_TIME, function() { throttle_protection = false })

                // Start the actual blinkup (which includes asking the server for a factory token)
                server.log("Starting factory blinkup.")
                hardware.pin9.write(1);
                imp.wakeup(0.2, function() {
                    hardware.pin9.write(0);                    
                    server.factoryblinkup(SSID, PASSWORD, hardware.pin9, BLINKUP_ACTIVEHIGH);
                    agent.send("testresult", {device_id = impeeid, mac = mac, msg = "Starting factory blinkup."})
                })
            }
        })
        break;

    default:
        // This code is specific to the target hardware and would need to be customised and expanded as appropriate.
        server.log("This is the impee to be tested and (maybe) blessed.");

        // Setup a timeout function which reports failure back to the factory process
        imp.wakeup(SUCCESS_TIMEOUT, function () {
            if (!throttle_protection) {

                // Don't allow this to happen more than once
                throttle_protection = true;
                led_state = null; // Stop the blinking

                // Notify the server of the success and handle the response
                server.log("Testing timed out with 0.")
                server.bless(0, function(bless_success) {
                    server.log("Blessing (negative) " + (bless_success ? "PASSED" : "FAILED") + " for impee " + impeeid + " and mac " + mac)
                    agent.send("testresult", {device_id = impeeid, mac = mac, passed = false, success = bless_success})
                })
            }
        })

        // Setup a button handler to indicate that the factory blinkup was successful.
        // There should probably be some code that actually does stuff (such as light up LEDs or play audio).
        hardware.pin1.configure(DIGITAL_IN_PULLUP, function() {
            // We have an push down or push up event
            local buttonState = hardware.pin1.read();
            if (buttonState == 0 && !throttle_protection) {

                // Don't allow this to happen more than once
                throttle_protection = true;
                led_state = null; // Stop the blinking

                // Notify the server of the success and handle the response
                server.log("Testing passed.")
                server.bless(true, function(bless_success) {
                    server.log("Blessing " + (bless_success ? "PASSED" : "FAILED") + " for impee " + impeeid + " and mac " + mac)
                    agent.send("testresult", {device_id = impeeid, mac = mac, passed = true, success = bless_success})
                    if (bless_success) {
                        imp.wakeup(10, function() { imp.clearconfiguration(); })
                    }
                })
            }
        });
        
        // Flash the LED quickly so the user knows its testing and waiting for the button to be pressed
        led_state <- 0;
        led <- hardware.pinD;
        led.configure(DIGITAL_OUT);
        led.write(0);
        function blinkled() {
            if (led_state == null) {
                led.write(0);
                return;
            }
            led_state = led_state == 1 ? 0 : 1;
            led.write(led_state);
            imp.wakeup(0.1, blinkled);
        }
        blinkled();

        
}

