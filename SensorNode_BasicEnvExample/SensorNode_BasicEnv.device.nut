// The MIT License (MIT)
//
// Copyright (c) 2017 Electric Imp
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


// Utility Libraries
#require "promise.class.nut:3.0.0"
#require "MessageManager.lib.nut:2.0.0"

// Sensor Libraries
// Accelerometer Library
#require "LIS3DH.class.nut:1.3.0"
// Temperature Humidity sensor Library
#require "HTS221.class.nut:1.0.0"
// Air Pressure sensor Library
#require "LPS22HB.class.nut:1.0.0"

// Sensor Node HAL
SensorNode_003 <- {
    "LED_BLUE" : hardware.pinP,
    "LED_GREEN" : hardware.pinU,
    "SENSOR_I2C" : hardware.i2cAB,
    "TEMP_HUMID_I2C_ADDR" : 0xBE,
    "ACCEL_I2C_ADDR" : 0x32,
    "PRESSURE_I2C_ADDR" : 0xB8,
    "RJ12_ENABLE_PIN" : hardware.pinS,
    "ONEWIRE_BUS_UART" : hardware.uartDM,
    "RJ12_I2C" : hardware.i2cFG,
    "RJ12_UART" : hardware.uartFG,
    "WAKE_PIN" : hardware.pinW,
    "ACCEL_INT_PIN" : hardware.pinT,
    "PRESSURE_INT_PIN" : hardware.pinX,
    "TEMP_HUMID_INT_PIN" : hardware.pinE,
    "NTC_ENABLE_PIN" : hardware.pinK,
    "THERMISTER_PIN" : hardware.pinJ,
    "FTDI_UART" : hardware.uartQRPW,
    "PWR_3v3_EN" : hardware.pinY
}

// Class to configure and take readings from Sensor Node sensors
/***************************************************************************************
 * SensorNode Class:
 *      Initializes specified sensors
 *      Configures initialized sensors
 *      Takes sensor readings (returns a promise, so can schedule async flow)
 *
 * Dependencies
 *      Promise
 *      HTS221 (optional) if using the TempHumid sensor
 *      LPS22HB (optional) if using the AirPressure sensor
 *      LIS3DH (optional) if using the Aceelerometer
 **************************************************************************************/
class SensorNode {

    // Sensor Identifiers
    static TEMP_HUMID = 0x01;
    static AIR_PRESSURE = 0x02;
    static ACCELEROMETER = 0x04;

    // Accel settings
    static ACCEL_DATARATE = 100;

    // Class instances
    tempHumid = null;
    press = null;
    accel = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      sensors : array of sensor statics to be enabled
     **************************************************************************************/
    constructor(sensors) {
        _initializeSensors(sensors);
    }

    /***************************************************************************************
     * takeReadings - takes readings, sends to agent, schedules next reading
     * Returns: A promise
     * Parameters: none
     **************************************************************************************/
    function takeReadings() {
        return Promise(function(resolve, reject) {
            // Take readings asynchonously if sensor enabled
            local que = _buildReadingQue();
            // When all sensors have returned values resolve
            Promise.all(que)
                .finally(function(envReadings) {
                    return resolve(_parseReadings(envReadings));
                }.bindenv(this));
        }.bindenv(this));
    }

    /***************************************************************************************
     * configureSensors
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function configureSensors() {
        if (tempHumid) {
            tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        }
        if (press) {
            press.softReset();
            // set up to take readings
            press.enableLowCurrentMode(true);
            press.setMode(LPS22HB_MODE.ONE_SHOT);
        }
        if (accel) {
            accel.init();
            // set up to take readings
            accel.setLowPower(true);
            accel.setDataRate(ACCEL_DATARATE);
            accel.enable(true);
        }
        return this;
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _buildReadingQue
     * Returns: an array of Promises for each sensor that is taking a reading
     * Parameters: none
     **************************************************************************************/
    function _buildReadingQue() {
        local que = [];
        if (tempHumid) que.push( _takeReading(tempHumid) );
        if (press) que.push( _takeReading(press) );
        if (accel) que.push( _takeReading(accel) );
        return que;
    }

    /***************************************************************************************
     * _takeReading
     * Returns: Promise that resolves with the sensor reading
     * Parameters:
     *      sensor: instance - the sensor to take a reading from
     **************************************************************************************/
    function _takeReading(sensor) {
        return Promise(function(resolve, reject) {
            if (sensor == accel) {
                // Catch I2C errors and log them
                try {
                    sensor.getAccel(function(reading) {
                        return resolve({"accel" : reading});
                    }.bindenv(sensor));
                } catch(err) {
                    server.error(err);
                }
            } else {
                sensor.read(function(reading) {
                    return resolve(reading);
                }.bindenv(sensor));
            }
        }.bindenv(this));
    }

    /***************************************************************************************
     * _parseReadings
     * Returns: a table of successful readings
     * Parameters:
     *      readings: array - with each sensor reading/error
     **************************************************************************************/
    function _parseReadings(readings) {
        // add time stamp to reading
        local data = {"ts" : time()};
        // log error or store value of reading
        foreach(reading in readings) {
            if ("err" in reading) {
                server.error(reading.err);
            } else if ("error" in reading) {
                server.error(reading.error);
            } else {
                foreach(sensor, value in reading) {
                    data[sensor] <- value;
                }
            }
        }
        return data;
    }

    /***************************************************************************************
     * _initializeSensors
     * Returns: this
     * Parameters:
     *      sensors: array of sensor constants for the sensors that should be initialized
     **************************************************************************************/
    function _initializeSensors(sensors) {
        local i2c = SensorNode_003.SENSOR_I2C;
        i2c.configure(CLOCK_SPEED_400_KHZ);

        if (sensors.find(TEMP_HUMID) != null) {
            tempHumid = HTS221(i2c, SensorNode_003.TEMP_HUMID_I2C_ADDR);
        }

        if (sensors.find(AIR_PRESSURE) != null) {
            press = LPS22HB(i2c, SensorNode_003.PRESSURE_I2C_ADDR);
        }

        if (sensors.find(ACCELEROMETER) != null) {
            accel = LIS3DH(i2c, SensorNode_003.ACCEL_I2C_ADDR);
        }

        return this;
    }

}

// Application class
/***************************************************************************************
 * Application Class:
 *      Configures sleep/wake behavior
 *      Takes readings
 *      Sends readings to agent
 *
 * Dependencies
 *      Promise Library
 *      Message Manager
 *      SensorNode Class
 *          HTS221 (optional) if using the TempHumid sensor
 *          LPS22HB (optional) if using the AirPressure sensor
 *          LIS3DH (optional) if using the Aceelerometer
 **************************************************************************************/
class Application {

    // Wake and connection time in seconds
    // Update intervals to customize app for maximum power savings
    static READING_INTERVAL_SEC = 300;
    static REPORTING_INTERVAL_SEC = 1800;

    // Time in seconds to wait before sleeping after boot
    // This leaves time to do a BlinkUp after boot
    static BOOT_TIMEOUT = 60;

    // Logging requires a connection to the server, so logging will decrease battery life
    // Debug logging flag, set this to add logs to nv between connections
    // Note: Storing too many logs will cause imp to run out of memory and reboot,
    //          only use when debugging, and make sure not to store too many readings
    //          between connections
    static DEBUG = true;

    // Class instances
    _mm = null;
    _sensors = null;

    // Flag that indicates if we rebooted the device
    _boot = null;

    /***************************************************************************************
     * constructor
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    constructor(sensors) {
        _configureNVTable();
        _initializeClasses(sensors);
        checkWakereason();
    }

    /***************************************************************************************
     * checkWakereason - checks wake reason then kick of appropriate flow
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function checkWakereason() {
        // Run wakeup flow
        local wakeReason = hardware.wakereason();
        switch( wakeReason ) {
            case WAKEREASON_PIN:
                if (DEBUG) nv.logs.push("Woke on int pin.");
                break;
            case WAKEREASON_TIMER:
                if (DEBUG) nv.logs.push("Woke on timer.");
                break;
            case WAKEREASON_POWER_ON:
                _boot = imp.wakeup(BOOT_TIMEOUT, function() {
                    _boot = null;
                }.bindenv(this));
            default :
                if (DEBUG) {
                    nv.logs.push("Woke on boot, etc.");
                    nv.logs.push("WAKE REASON: " + wakeReason);
                }
                _configureTimers();
        }

        _configureDevice();
        // Take Readings
        runWakeUpFlow();
    }

    /***************************************************************************************
     * runWakeUpFlow
     *          - take readings
     *          - then check if we should connect & send data
     *          - then go to sleep, or start wake loop
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function runWakeUpFlow() {
        _sensors.takeReadings()
            .then(function(reading) {
                // Store reading
                nv.readings.push(reading);

                // Check whether to connect
                if (server.isconnected() || _connectTime()) {
                    return sendUpdate();
                } else {
                    return "Not connection time yet.";
                }
            }.bindenv(this))
            .then(function(msg) {
                if (DEBUG) nv.logs.push(msg);
                powerDown();
            }.bindenv(this));
    }

    /***************************************************************************************
     * sendUpdate - send nv readings and door status to agent
     *                then clear nv readings
     * Returns: promise
     * Parameters: none
     **************************************************************************************/
    function sendUpdate() {
        return Promise(function(resolve, reject) {
            local update = _createUpdateTable();

            // We are connecting so log messages
            server.log("SENDING UPDATE at " + time());
            if (DEBUG) _logStoredMsgs();

            // Send update to agent
            _mm.send("update", update, {
                "onReply" : function(msg, resp) {
                                return resolve("Agent received update.");
                            }.bindenv(this), // onReply closure
                "onFail" :  function(err, msg, retry) {
                                // Agent didn't receive data, so store to send on next connect
                                nv.readings.extend(update.readings);
                                return resolve("Connection attempt failed. Readings kept.");
                            }.bindenv(this) // onFail closure
            })
            setNextConnect();
        }.bindenv(this)); // Promise closure
    }

    /***************************************************************************************
     * setNextReadingTime - sets at timestamp for the next scheduled reading
     * Returns: Time in seconds before next reading
     * Parameters:
     *          now (optional): current time
     **************************************************************************************/
    function setNextReadingTime(now = null) {
        local readingTimer;
        if (now == null) now = time();
        if ("nextWakeTime" in nv.timers) readingTimer = nv.timers.nextReadingTime - now;

        if (readingTimer == null || readingTimer <= 1) {
            // Next wake time has not been configured or we just took a reading
            // Set next wake time to default
            readingTimer = READING_INTERVAL_SEC;
        }

        // Store next readig/wake time
        nv.timers.nextReadingTime <- now + readingTimer;
        // Return time til next reading
        return readingTimer;
    }

    /***************************************************************************************
     * setNextConnect - sets a timestamp for the next time the device should connect to the agent
     * Returns: null
     * Parameters:
     *          now (optional): current time
     **************************************************************************************/
    function setNextConnect(now = null) {
        if (now == null) now = time();
        nv.timers.nextConnectTime <- now + REPORTING_INTERVAL_SEC;
    }

    /***************************************************************************************
     * powerDown - if cold boot stay connected, if door is open turn off WiFi, otherwise sleep
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function powerDown() {
        local nextReading = setNextReadingTime();

        if (_boot) {
            // Schedule next reading/sleep time
            if (BOOT_TIMEOUT > nextReading) {
                imp.wakeup(nextReading, runWakeUpFlow.bindenv(this));
            } else {
                imp.wakeup(BOOT_TIMEOUT, runWakeUpFlow.bindenv(this));
            }
        } else {
            sleep(nextReading);
        }
    }

    /***************************************************************************************
     * sleep
     * Returns: null
     * Parameters:
     *          timer: number of seconds to sleep for
     **************************************************************************************/
    function sleep(timer = null) {
        // Make sure we always have a timer set
        if (timer == null) timer = READING_INTERVAL_SEC;

        // Put imp to sleep when it becomes idle
        if (DEBUG) nv.logs.push("Going to sleep for " + timer + " sec.");
        if (server.isconnected()) {
            imp.onidle(function() {
                server.sleepfor(timer);
            }.bindenv(this));
        } else {
            imp.deepsleepfor(timer);
        }
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _initializeClasses
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _initializeClasses(sensors) {
        // agent/device communication helper library
        _mm = MessageManager();
        // Class to manage sensors
        _sensors = SensorNode(sensors);
    }

    /***************************************************************************************
     * _configureDevice
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _configureDevice() {
        // Note: power save will slow connection time when true
        imp.setpowersave(true);
        // Configure sensors
        _sensors.configureSensors();
    }

    /***************************************************************************************
     * _configureNVTable
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _configureNVTable() {
        local root = getroottable();
        if (!("nv" in root)) root.nv <- { "readings" : [],
                                          "timers" : {},
                                          "logs" : [] };
    }

    /***************************************************************************************
     * _configureTimers - sets nextWakeTime and nextConnectTime
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _configureTimers() {
        local now = time();
        setNextReadingTime(now);
        setNextConnect(now);
    }

    /***************************************************************************************
     * _connectTime - checks current time with connection time
     * Returns: boolean
     * Parameters: none
     **************************************************************************************/
    function _connectTime() {
        return (time() >= nv.timers.nextConnectTime) ? true : false;
    }

    /***************************************************************************************
     * _readingTime - checks current time with next scheduled reading time
     * Returns: boolean
     * Parameters: none
     **************************************************************************************/
    function _readingTime() {
        return (time() >= nv.timers.nextReadingTime) ? true : false;
    }

    /***************************************************************************************
     * _logStoredMsgs
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _logStoredMsgs() {
        // Log each stored message
        server.log("------------------------------------------------");
        foreach (log in nv.logs) {
            server.log(log);
        }
        server.log("------------------------------------------------");
        // Clear logs
        nv.logs = [];
    }


    /***************************************************************************************
     * _createUpdateTable, table to send to agent
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _createUpdateTable() {
            local update = {};
            update.readings <- _copyArray(nv.readings);
            // clear nv tables, so we don't resend data
            nv.readings <- [];
            return update;
    }

    /***************************************************************************************
     * _copyArray
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _copyArray(arr) {
        local copy = [];
        foreach (val in arr) {
            copy.push(val);
        }
        return copy;
    }
}


// RUNTIME
// ----------------------------------------------

// Select sensors to initialize
local sensors = [ SensorNode.TEMP_HUMID,
                  SensorNode.ACCELEROMETER,
                  SensorNode.AIR_PRESSURE ];

// Start Application
Application(sensors);
