/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/


/*
 * This squirrel code is responsible for controlling the factory imp fixture 
 * as designed and documented here: http://devwiki.electricimp.com/doku.php?id=blinkupfixture
 */

// Set 
const SSID = "";
const PASSWORD = "";
const FIXTURE_MAC = "000000000000";
const THROTTLE_TIME = 5;
const SUCCESS_TIMEOUT = 10;

button <- hardware.pin1
LED <- hardware.pin9
testButton <- hardware.pin8
testLED <- hardware.pin9

throttle_protection <- false;
finished <- false;

mac <- imp.getmacaddress();
impeeid <- hardware.getimpeeid();

bless_success <- false;

switch (mac) {
    case FIXTURE_MAC:
        server.log("This is the factory imp with mac " + mac + " and factory test fixture impee ID " + impeeid + ". It will blinkup to SSID " + SSID);
        
        testLED.configure(DIGITAL_OUT);
        testLED.write(0);
        testButton.configure(DIGITAL_IN_PULLUP, function() {
            local buttonState = testButton.read();
            if (buttonState == 0 && !throttle_protection) {
                
                // Don't allow this to happen more than once per XXX seconds
                throttle_protection = true;
                imp.wakeup(THROTTLE_TIME, function() { throttle_protection = false })
                
                // Start the actual blinkup (which includes asking the server for a factory token)
                server.log("Starting factory blinkup.")
                server.factoryblinkup(SSID, PASSWORD, testLED, BLINKUP_FAST | BLINKUP_ACTIVEHIGH); 
            }
        })
        break;
        
    default:
        server.log("This is the impee to be tested and (maybe) blessed.");
        
        // Setup a timeout function which reports failure back to the factory process
        imp.wakeup(SUCCESS_TIMEOUT, function () {
            if (!throttle_protection) {
                
                // Don't allow this to happen more than once 
                throttle_protection = true;
                
                // The test failed, do nothing.
                server.log("Testing timed out.")
            }
        })

        LED.configure(DIGITAL_OUT);
        LED.write(0);

        // Setup a button handler to indicate that the factory tests where successful. 
		local buttonState = button.read();
        button.configure(DIGITAL_IN_PULLUP, function() {
            // We have an push down or push up event
            local newbuttonState = button.read();
            if (buttonState == 0 && newbuttonState != buttonState && !throttle_protection) {
                
                // Don't allow this to happen more than once 
                throttle_protection = true;
                
                // Notify the server of the success and handle the response
                server.log("Testing passed.")
                LED.write(0);
                
                server.bless(true, function(bless_success) {
                    server.log("Blessing " + (bless_success ? "PASSED" : "FAILED") + " for impee " + impeeid + " and mac " + mac)
                });

                imp.sleep(1);
                LED.write(1);
            }
        });
}
