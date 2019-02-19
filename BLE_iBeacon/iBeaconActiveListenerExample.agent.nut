// iBeacon Active Listener Application

class IBeaconTracker {

    beacons = null;
    loopTime = null;
    expTime = null;

    constructor(checkInInterval, beaconExpire) {
        beacons = {};
        loopTime = checkInInterval;
        expTime = beaconExpire;

        // Register listener for iBeacons and responses collected on device
        device.on("iBeacon", onIBeacon.bindenv(this));
        device.on("iBeaconResp", onIBeaconResp.bindenv(this));

        // Start Loop
        loop();
    }

    function loop() {
        removeInactive();
        logActive();
        imp.wakeup(loopTime, loop.bindenv(this));
    }

    function onIBeacon(iBeacon) {
        if ("mac" in iBeacon) {
            if (iBeacon.mac in beacons) {
                local beacon = beacons[iBeacon.mac];
                foreach(k, v in iBeacon) {
                    beacon[k] <- v;
                }
            } else {
                beacons[iBeacon.mac] <- iBeacon;
            }
        }
    }

    function onIBeaconResp(resp) {
        if ("mac" in resp && resp.mac in beacons) {
            beacons[resp.mac]["devState"] <- resp;
        }
    }

    function removeInactive() {
        local now = time();
        foreach(mac, iBeacon in beacons) {
            local lastSeen = now - iBeacon.ts;
            if (lastSeen >= expTime) {
                beacons.rawdelete(mac);
            }
        }
    }

    function logActive() {
        server.log("Number of matching BLE devices found: " + beacons.len());
        server.log("---------------------------------------------");
        foreach(mac, iBeacon in beacons) {
            server.log("UUID: " );
            server.log(iBeacon.uuid);
            server.log("Major: ");
            server.log(iBeacon.major);
            server.log("Minor: ");
            server.log(iBeacon.minor);
            if ("devState" in iBeacon) {
                server.log("Device State: ");
                server.log(http.jsonencode(iBeacon.devState));
            }
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
