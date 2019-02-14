// Example - iBeacon Listener Agent File

// MIT License
//
// Copyright 2016-2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


class IBeaconTracker {

    beacons = null;
    loopTime = null;
    expTime = null;

    constructor(checkInInterval, beaconExpire) {
        beacons = {};
        loopTime = checkInInterval;
        expTime = beaconExpire;

        // Register listener for iBeacons collected on device
        device.on("iBeacon", onIBeacon.bindenv(this));

        // Start Loop
        loop();
    }

    function loop() {
        removeInactive();
        logActive();
        imp.wakeup(loopTime, loop.bindenv(this));
    }

    function onIBeacon(iBeacon) {
        if ("major" in iBeacon && "minor" in iBeacon) {
            local majMin = iBeacon.major.readstring(2) + iBeacon.minor.readstring(2);
            beacons[majMin] <- iBeacon;
        }
    }

    function removeInactive() {
        local now = time();
        foreach(majMin, iBeacon in beacons) {
            local lastSeen = now - iBeacon.ts;
            if (lastSeen >= expTime) {
                beacons.rawdelete(majMin);
            }
        }
    }

    function logActive() {
        server.log("Number of matching BLE devices found: " + beacons.len());
        server.log("---------------------------------------------");
        foreach(majMin, iBeacon in beacons) {
            server.log("Major: ");
            server.log(iBeacon.major);
            server.log("Minor: ");
            server.log(iBeacon.minor);
        }
        server.log("---------------------------------------------");
    }

}

// RUNTIME
// -------------------------------------------------------------------------------
server.log("Agent running...");

// How often to log active beacon list
const CHECK_IN_INTERVAL_SEC = 5;
// Delete beacon from active list if it has not been seen in
const BEACON_EXPIRE_SEC = 30;

IBeaconTracker(CHECK_IN_INTERVAL_SEC, BEACON_EXPIRE_SEC);
