/*
Copyright (C) 2014 Electric Imp, Inc
 
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

Date: 11th August, 2014

This example code is for blessing devices in a factory using a factory blinkup fixture.
For this example:
- the factory blinkup fixture is a factory imp in an April board
  mounted on an enclosure with an LED on pin9. Every 10 seconds the factory blinkup fixture
  will start the blinkup procedure automatically.
- the target device will automatically and immediately be blessed as soon as it runs this code
- the LED on the device's imp card (not the factory blinkup fixure) will turn solid green 
  indicating pass/bless or turn solid red indicating fail/no blessing
- the webhooks will then be notified of the blessing event and take further actions
========================================================================================== */


const SSID = "yourSSID"; 
const PASSWORD = "yourWifiPW"; 
const FIXTURE_MAC = "0c2a690xxxxx";  // NOTE this format of this value

mac <- imp.getmacaddress(); 
deviceid <- hardware.getdeviceid(); 

function factoryblinkup() {
    imp.wakeup(10, factoryblinkup);
    server.factoryblinkup(SSID, PASSWORD, hardware.pin9, BLINKUP_ACTIVEHIGH); 
}

function factorybless() {
    server.bless(true, function(bless_success) { 
        server.log("Blessing " + (bless_success ? "PASSED" : "FAILED")); 
        agent.send("testresult", {device_id = deviceid, mac = mac, success = bless_success});
        if (bless_success) imp.clearconfiguration();
    }); 
}

if (imp.getssid() != SSID) return; // Don't run the factory code if not in the factory
if (mac == FIXTURE_MAC) {
    factoryblinkup();
} else {
    factorybless();
}
