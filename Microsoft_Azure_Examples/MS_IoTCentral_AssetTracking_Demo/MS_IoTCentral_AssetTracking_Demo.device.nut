// MIT License
//
// Copyright 2015-2018 Electric Imp
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
// THE SOFTWARE IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
 
// Temperature Humidity Sensor driver
#require "HTS221.device.lib.nut:2.0.1"
// Explorer Kit RGB LED driver
#require "WS2812.class.nut:3.0.0"
// Accelerometer driver
#require "LIS3DH.device.lib.nut:2.0.2"
// impCBreakout board RGB LED 
#require "APA102.device.lib.nut:2.0.0"

// GPS Location Libraries
#require "GPSParser.device.lib.nut:1.0.0"
#require "GPSUARTDriver.device.lib.nut:1.1.0"

// Hardware abstraction layer
const TYPE_IMPEXPLORER = 1;
const TYPE_IMPCBREAKOUT = 2;
impType <- 0;
if (imp.info().type == "imp001") {
    impType = TYPE_IMPEXPLORER;
} else if (imp.info().type == "impC001") {
    impType = TYPE_IMPCBREAKOUT;
} else {
    server.error("unsupported imp type");
}
HAL <- {};

// Location monitoring class for Pixhawk GPS
class LocationMonitor {

    _gps          = null;

    _lastLat      = null;
    _lastLng      = null;
    _locCheckedAt = null;

    _geofenceCB   = null;
    _gfCtr        = null;
    _distFromCtr  = null;
    _inBounds     = null;

    constructor(configurePixHawk) {
        // Configure class constants
        const GPS_BAUD_RATE    = 9600; // This is the default for ublox, but if it doesn't work try 38400
        const GPS_RX_FIFO_SIZE = 4096;
        // Use to reduce niose, so gps isn't jumping around when asset is not moving
        const LOC_THRESHOLD    = 0.00030;

        // delay a bit to ensure any previous I2C transactions have completed
        // as Pixhawk may corrupt I2C transactions during power-on
        imp.sleep(0.5);
        HAL.POWER_GATE.configure(DIGITAL_OUT, 1);
        HAL.GPS_UART.setrxfifosize(GPS_RX_FIFO_SIZE);
        // Configure UART
        HAL.GPS_UART.configure(GPS_BAUD_RATE, 8, PARITY_NONE, 1, NO_CTSRTS);
        // Ensure Pixhawk tx line is high and stable
        imp.sleep(0.5);

        // Pixhawk may not be in the correct mode when booted, send command
        // to configure GPS to send NMEA sentences
        // Note this doesn't change the boot state of the pixhawk, so will need
        // to be called on every boot if needed.
        if (configurePixHawk) {
            _sendPixhawkConfigCommand(HAL.GPS_UART, GPS_BAUD_RATE);
        }

        // Initialize GPS UART Driver
        local gpsOpts = { "gspDataReady" : gpsHandler.bindenv(this),
                          "parseData"    : true,
                          "baudRate"     : GPS_BAUD_RATE };
        _gps = GPSUARTDriver(HAL.GPS_UART, gpsOpts);
    }

    function getLocation() {
        return {"lat" : _lastLat, "lng" : _lastLng, "ts" : _locCheckedAt};
    }

    function gpsHandler(hasLoc, data) {
        // server.log(data);
        if (hasLoc) {
            // print(data);
            local lat = _gps.getLatitude();
            local lng = _gps.getLongitude();

            // Updated location if it has changed
            if (locChanged(lat, lng) ) {
                _lastLat = lat;
                _lastLng = lng;
            }
            // Update location received timestamp
            _locCheckedAt = time();

            // XX Bug: Do not calculate distence when no geofence
            // if ("sentenceId" in data && data.sentenceId == GPS_PARSER_GGA) {
            //     calculateDistance(data);
            // } 

        } else if (!_gps.hasFix() && "numSatellites" in data) {
            // This will log a ton - use to debug only, not in application
            // server.log("GSV data received. Satellites: " + data.numSatellites);
        }
    }

    function inBounds() {
        return _inBounds;
    }

    function enableGeofence(distance, ctrLat, ctrLng, cb) {
        _distFromCtr = distance;
        _geofenceCB = cb;

        // use a hardcoded altitude, 30 meters
        local alt = 30.00;
        try {
            local lat = ctrLat.tofloat();
            local lng = ctrLng.tofloat();
            _gfCtr = _getCartesianCoods(lat, lng, alt);
        } catch(e) {
            server.error("Error configuring geofence coordinates: " + e);
        }

    }

    function disableGeofence() {
        _geofenceCB = null;
        _gfCtr = null;
        _distFromCtr = null;
        _inBounds = null;
    }

    // Use location threshold to filter out noise when not moving
    function locChanged(lat, lng) {
        local changed = false;

        if (_lastLat == null || _lastLng == null) {
            changed = true;
        } else {
            local latDiff = math.fabs(lat.tofloat() - _lastLat.tofloat());
            local lngDiff = math.fabs(lng.tofloat() - _lastLng.tofloat());
            if (latDiff > LOC_THRESHOLD) changed = true;
            if (lngDiff > LOC_THRESHOLD) changed = true;
        }
        return changed;
    }

    function calculateDistance(data) {
        // Only calculate if we have altitude, latitude and longitude
        if (!("altitude" in data) || !("latitude" in data) || !("longitude" in data)) return;

        try {
            local lat = data.latitude.tofloat();
            local lng = data.longitude.tofloat();
            local alt = data.altitude.tofloat();

            local new  = _getCartesianCoods(lat, lng, alt);
            local dist = math.sqrt((new.x - _gfCtr.x)*(new.x - _gfCtr.x) + (new.y - _gfCtr.y)*(new.y - _gfCtr.y) + (new.z - _gfCtr.z)*(new.z - _gfCtr.z));

            // server.log("New distance: " + dist + " M");
            local inBounds = (dist <= _distFromCtr);
            if (_geofenceCB != null && inBounds != _inBounds) {
                _geofenceCB(inBounds);
            }
            // Track previous state, so we only trigger callback on a change
            _inBounds = inBounds;
        } catch (e) {
            // Couldn't calculate
            server.error("Error calculating distance: " + e);
        }
    }

    function _getCartesianCoods(lat, lng, alt) {
        local latRad = lat * PI / 180;
        local lngRad = lng * PI / 180;
        local cosLat = math.cos(latRad);
        local result = {};

        result.x <- alt * cosLat * math.sin(lngRad);
        result.y <- alt * math.sin(latRad);
        result.z <- alt * cosLat * math.cos(lngRad);

        return result;
    }

    function _sendPixhawkConfigCommand(uart, baudrate) {
        server.log("Configuring pixhawk...");

        // UBX CFG-PRT command values
        local header          = 0xb562;     // Not included in checksum
        local portConfigClass = 0x06;
        local portConfigId    = 0x00;
        local length          = 0x0014;
        local port            = 0x01;       // uart port
        local reserved1       = 0x00;
        local txReady         = 0x0000;     // txready not enabled
        local uartMode        = 0x000008c0; // mode 8 bit, no parity, 1 stop
        local brChars         = (baudrate > 57600) ? format("%c%c%c%c", baudrate, baudrate >> 8, baudrate >> 16, 0) : format("%c%c%c%c", baudrate, baudrate >> 8, 0, 0);
        local inproto         = 0x0003;     // inproto NMEA and UBX
        local outproto        = 0x0002;     // outproto NMEA
        local flags           = 0x0000;     // default timeout
        local reserved2       = 0x0000;

        // Assemble UBX payload
        local payload = format("%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c",
            portConfigClass,
            portConfigId,
            length,
            length >> 8,
            port,
            reserved1,
            txReady,
            txReady >> 8,
            uartMode,
            uartMode >> 8,
            uartMode >> 16,
            uartMode >> 24,
            brChars[0],
            brChars[1],
            brChars[2],
            brChars[3],
            inproto,
            inproto >> 8,
            outproto,
            outproto >> 8,
            flags,
            flags >> 8,
            reserved2,
            reserved2 >> 8);

        // Send UBX CFG-PRT (UBX formatted) to configure input NMEA mode
        uart.write(format("%c%c", header >> 8, header));
        uart.write(payload);
        uart.write(_calcUbxChecksum(payload));
        uart.flush();
        imp.sleep(1);

        // Assemble NMEA payload
        local nmeaCmd = format("$PUBX,41,%d,%04d,%04d,%04d,0*", port, inproto, outproto, baudrate);
        // Send UBX CFG-PRT (NMEA formatted) to configure input NMEA mode
        uart.write(nmeaCmd);
        uart.write(format("%02x", GPSParser._calcCheckSum(nmeaCmd)));
        uart.write("\r\n");
        uart.flush();
        imp.sleep(1);
    }

    function _calcUbxChecksum(pkt) {
        local cka=0, ckb=0;
        foreach(a in pkt) {
            cka += a;
            ckb += cka;
        }
        cka = cka&0xff;
        ckb = ckb&0xff;

        return format("%c%c", cka, ckb);
    }

}

// Device code to implement IoT Central Asset Tracking Demo
// It supports:
// - impC001 Breakout and location via Pixhawk GPS (UBlox M8N module)
// - imp001 impExplorer and location via WiFi and Google places
//
// Note: This application is demo quaility and kept simple to illustrate the key concepts
// Is not optimized for power consumption/battery life, optimized communication, or connectivity handling
class Application {

    // Same as in agent
    static RED = 0x00;
    static YELLOW = 0x01;
    static GREEN = 0x02;

    static BLINK_SEC = 0.5;
    static DEFAULT_REPORTING = 10;
    static ACCEL_LIMIT = 1.2;
    static AGENT_STARTUP_DELAY = 10;
    
    _reportingInterval = 0;
    _blinkColor = 0;
    _tempHumid = null;
    _led = null;
    _accel = null;
    _currMaxAccel = 0;
    _sendLoopTimer = null;
    _accelLoopTimer = null;
    _pixhawkGps = null;
    
    constructor() {
        
        _populateHAL();
        _init();
        
        _blinkColor = YELLOW;
        _reportingInterval = DEFAULT_REPORTING;

        agent.on("color", setColor.bindenv(this));
        agent.on("reporting", setReportingInterval.bindenv(this));
        agent.on("ping", ping.bindenv(this));
        agent.on("restart", restart.bindenv(this));

    }

    // Populate Hardware Abstraction Layer based on imp type
    function _populateHAL() {
        
        if (impType == TYPE_IMPEXPLORER) {
            // ExplorerKit Hardware Abstraction Layer
            HAL = {
                "LED_SPI" : hardware.spi257,
                "SENSOR_AND_GROVE_I2C" : hardware.i2c89,
                "TEMP_HUMID_I2C_ADDR" : 0xBE,
                "ACCEL_I2C_ADDR" : 0x32,
                "PRESSURE_I2C_ADDR" : 0xB8,
                "POWER_GATE_AND_WAKE_PIN" : hardware.pin1,
                "AD_GROVE1_DATA1" : hardware.pin2,
                "AD_GROVE2_DATA1" : hardware.pin5
            }
        } else {
            // impC Breakout Hardware Abstraction Layer
            HAL = {
                "LED_SPI" : hardware.spiYJTHU,
                "SENSOR_AND_GROVE_I2C" : hardware.i2cKL,
                "TEMP_HUMID_I2C_ADDR" : 0xBE,
                "ACCEL_I2C_ADDR" : 0x32,
                "POWER_GATE" : hardware.pinYG,
                "GPS_UART" : hardware.uartNU
            }
        }
        
    }

    // Initialization
    function _init() {
        
        local i2c = null;
        local tempHumidAddr = null;
        local accelAddr = null;
        local spi = null;


        i2c = HAL.SENSOR_AND_GROVE_I2C;
        tempHumidAddr = HAL.TEMP_HUMID_I2C_ADDR;
        accelAddr = HAL.ACCEL_I2C_ADDR;

        i2c.configure(CLOCK_SPEED_400_KHZ);
        
        _tempHumid = HTS221(i2c, tempHumidAddr);
        _tempHumid.setMode(HTS221_MODE.ONE_SHOT);
  
        _accel = LIS3DH(i2c, accelAddr);
        _accel.setDataRate(100);
        
        spi = HAL.LED_SPI;
        if (impType == TYPE_IMPEXPLORER) {
            _led = WS2812(spi, 1);
            HAL.POWER_GATE_AND_WAKE_PIN.configure(DIGITAL_OUT, 1);
        } else {
            HAL.POWER_GATE.configure(DIGITAL_OUT, 1);
            HAL.LED_SPI.configure(SIMPLEX_TX, 7500);
            _led = APA102(spi, 1);
        }

        if (impType == TYPE_IMPCBREAKOUT) {
            _pixhawkGps = LocationMonitor(false);
        }

    }
    
    // Run the application
    function run() {

        // Start periodic _sendLoop
        _sendLoopTimer = imp.wakeup(AGENT_STARTUP_DELAY, _sendLoop.bindenv(this));
        if (_sendLoopTimer == null) {
            server.error("_sendLoopTimer fail");
        }
        
        // Start periodic _locationLoop
        if (imp.wakeup(AGENT_STARTUP_DELAY, _locationLoop.bindenv(this)) == null) {
            server.error("_locationLoop timer fail");
        }
        
        // Start periodic _accelLoop
        _accelLoopTimer = imp.wakeup(5, _accelLoop.bindenv(this));
        if (_accelLoopTimer == null) {
            server.error("_accelLoopTimer fail");
        }
        
        // Send info when connected
        if (imp.wakeup(AGENT_STARTUP_DELAY, function() {
                agent.send("connect", imp.net.info());
            }.bindenv(this)) == null) {
            server.error("_sendNetworkInfo timer fail");
        }
        
    }

    // For connection status check
    function ping(time) {
        agent.send("pong", time);
    }

    // Restart the device
    function restart(param) {
        server.log("Restarting device ...");
        server.restart();
    }

    // Set reporting interval
    function setReportingInterval(interval) {
        server.log("Set reporting interval: " + interval);
        (interval < 1) ? _reportingInterval = 1 : _reportingInterval = interval;

        if (_sendLoopTimer != null) {
            imp.cancelwakeup(_sendLoopTimer);
            _sendLoopTimer = imp.wakeup(_reportingInterval, _sendLoop.bindenv(this));
            if (_sendLoopTimer == null) {
                server.error("_sendLoopTimer fail");
            }
        }
    }

    // Get max acceleration since last time
    function _getMaxAccel() {
        local tmp = _currMaxAccel; 
        _currMaxAccel = 0;
        return tmp;
    }
    
    // Send data immediately if there was an acceleration alert
    function _accelAlert() {
        server.log("*** Acceleration alert: " + _currMaxAccel);
        
        // Delay acceleration loop so that alert doesn't fire too often
        if (_accelLoopTimer != null) {
            imp.cancelwakeup(_accelLoopTimer);
            _accelLoopTimer = imp.wakeup(1, _accelLoop.bindenv(this));
            if (_sendLoopTimer == null) {
                server.error("_accelLoopTimer fail");
            }

        }
        
        // Then call sendLoop right away 
        if (_sendLoopTimer != null) {
            imp.cancelwakeup(_sendLoopTimer);
            _sendLoopTimer = imp.wakeup(0.1, _sendLoop.bindenv(this));
            if (_sendLoopTimer == null) {
                server.error("_sendLoopTimer fail");
            }

        }
    }
    
    // Get max acceleration during a time period by polling accelerometer 
    // Naive implementation: Should not poll but use LIS3DH thresholds and interrupts
    function _accelLoop() {
        _accel.getAccel(function(result) {
            local abs = math.sqrt((result.x * result.x * 1.0) + 
                (result.y * result.y * 1.0) + 
                (result.z * result.z * 1.0));
            // store max value
            if (abs > _currMaxAccel) {
                _currMaxAccel = abs;
            }
            _accelLoopTimer = imp.wakeup(0.1, _accelLoop.bindenv(this));
            if (_accelLoopTimer == null) {
                server.error("_accelLoopTimer fail");
            }
            // if current value is larger than limit, do alert right away
            if (abs > ACCEL_LIMIT) {
                _accelAlert();
            }
        }.bindenv(this));
    }

    // Periodically send telemetry data, or immediately upon acceleration alert
    // Naive implementation: Should send only when change in data occurs
    function _sendLoop() {
        
        local telemetryData = null;
        server.log("Sending telemetry data");
        
        // Read temp and humidity and process asynchronously
        _tempHumid.read(function(result) {
            if ("error" in result) {
                server.error(result.error);
            } else {
                telemetryData = result;
                
                // add acceleration data and alert
                telemetryData.acceleration <- _getMaxAccel();
                if (telemetryData.acceleration > ACCEL_LIMIT) {
                    telemetryData.acclerationAlert <- "true";
                }
                
                // Uncomment if you want to send add light level as well
                // telemetryData.light <- readLightLevel();

                _blinkLED();
                agent.send("telemetry", telemetryData)
            }
            _sendLoopTimer = imp.wakeup(_reportingInterval, _sendLoop.bindenv(this));
            if (_sendLoopTimer == null) {
                server.error("_sendLoopTimer fail");
            }
        }.bindenv(this));

    }
    
    // Periodically send location data
    // Naive implementation: Should send only when change in location occurs
    function _locationLoop() {
        server.log("Sending location data");
        _sendLocation();
        if (imp.wakeup(60, _locationLoop.bindenv(this)) == null) {
            server.error("_locationLoop fail");
        }
    }
    
    // Send location data
    function _sendLocation() {
        
        local locationData = {};
        
        // if impExplorer, use WiFi location
        if (impType == TYPE_IMPEXPLORER) {
            locationData.type <- "wifi";
            locationData.networks <- imp.scanwifinetworks();
        } else {
            // cellular ...
            local gpsLoc = _pixhawkGps.getLocation();
            // If we have a gps fix, then that, else do cellular triangulation
            if (gpsLoc.lng == null) {
                local netInfo = imp.net.info();
                local cellinfo = netInfo.interface[netInfo.active].cellinfo;
                locationData.type <- "cell";
                locationData.cellinfo <- cellinfo;
            } else {
                locationData.type <- "gps";
                locationData.location <- { "lng" : gpsLoc.lng.tofloat(), "lat" : gpsLoc.lat.tofloat() };
            } 
        }
        agent.send("location", locationData);
    }

    // Read level of onboard light sensor
    function readLightLevel() {
            // reading needs a bit of time to stabilize, so read, wait a bit, and read again
            local level = hardware.lightlevel();
            imp.sleep(0.2);
            level = hardware.lightlevel();
            server.log("Light level: " + level);
            return level;
    }
    
    // Set blink color
    function setColor(color) {
        _blinkColor = color;
        _blinkLED();
    }
    
    // Blink LED
    function _blinkLED() {
        local off = [0, 0, 0];
        local colorArr = null;

        switch (_blinkColor) {
            case RED :
                colorArr = [50, 0, 0];
                break;
            case YELLOW :
                colorArr = [50, 45, 0];
                break;
            case GREEN :
                colorArr = [0, 50, 0];
                break;
        }

        if (impType == TYPE_IMPEXPLORER) {
            // Turn the LED on
            _led.fill(colorArr).draw();
            // Wait BLINK_SEC then turn LED off
            imp.wakeup(BLINK_SEC, function() {
                _led.fill(off).draw();
            }.bindenv(this))
        } else {
            _led.set(0, colorArr).draw();
            imp.wakeup(BLINK_SEC, function() {
                _led.set(0, off).draw();
            }.bindenv(this))
        }
    }

    // Utility to print a table
    function _printTable(table) {
        foreach (key, value in table) {
            server.log(key + ": " + value);
            if ((typeof value) == "table") {
                foreach (k, v in value) {
                    server.log("{ " + k + ": " + v + " }");
                }
            }
        }
    }
    
} // Application

imp.enableblinkup(true); 

if (impType == TYPE_IMPEXPLORER) {
    server.log("*** Device starting (imp001) ...");
    server.log(imp.getsoftwareversion());
} else {
    server.log("*** Device starting (impC001) ...");
    server.log(imp.getsoftwareversion());
} 

// Start the Application 
app <- Application();
app.run();