//line 1 "device.nut"
// Utility Libraries
#require "promise.class.nut:3.0.0"
#require "bullwinkle.class.nut:2.3.2"

// Sensor Libraries
// Accelerometer Library
#require "LIS3DH.class.nut:1.3.0"
// Temperature Humidity sensor Library
#require "HTS221.class.nut:1.0.0"

// Class to configure and take readings from Explorer Kit sensors
//line 1 "ExplorerKitSensors.class.nut"
/***************************************************************************************
 * ExplorerKitSensors Class:
 *      Initializes specified sensors
 *      Configures initialized sensors
 *      Checks light level to determine doorStatus
 *      Take & store(in nv) sensor readings (returns a promise, so can schedule async flow)
 *      Configures/enables click interrupt
 *      Disables click interrupt
 *      Checks/clears click interrupt
 *
 * Dependencies
 *      Promise
 *      HTS221 (optional) if using the TempHumid sensor
 *      LPS22HB (optional) if using the AirPressure sensor
 *      LIS3DH (optional) if using the Aceelerometer
 **************************************************************************************/
class ExplorerKitSensors {
    // Accel i2c Address
    static LIS3DH_ADDR = 0x32;

    // Sensor Identifiers
    static TEMP_HUMID = 0x01;
    static AIR_PRESSURE = 0x02;
    static ACCELEROMETER = 0x04;

    // Event polarity
    static ALERT_EVENT = 1;

    // Accel settings
    static ACCEL_DATARATE = 100;
    // High Sensitivity set, so we alway wake on a door event
    static ACCEL_THRESHOLD = 0.1;
    static ACCEL_DURATION = 1;

    // Class instances
    tempHumid = null;
    press = null;
    accel = null;

    alertPin = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      sensors : array of sensor statics to be enabled
     *      cm (optional) : connection manager instance if offline error logs desired
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
            // When all sensors have returned values store a reading locally
            // Then resolve
            Promise.all(que)
                .then(function(envReadings) {
                    local reading = _parseReadings(envReadings);
                    // store reading
                    nv.readings.push(reading);
                }.bindenv(this))
                .finally(function(val) {
                    return resolve(nv.readings)
                }.bindenv(this));
        }.bindenv(this));
    }

    /***************************************************************************************
     * getLightLevel
     * Returns: a light reading from the imp001 hardware light sensor
     * Parameters: none
     **************************************************************************************/
    function getLightLevel() {
        // imp.sleep(0.2);
        return hardware.lightlevel();
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

    /***************************************************************************************
     * enableAccelerometerClickInterrupt
     * Returns: this
     * Parameters:
                cb (optional) : optional interrupt callback function (passed to the wake pin configure)
     **************************************************************************************/
    function enableAccelerometerClickInterrupt(cb = null) {
        // Configure Alert Pin
        alertPin = hardware.pin1;
        if (cb == null) {
            alertPin.configure(DIGITAL_IN_WAKEUP);
        } else {
            alertPin.configure(DIGITAL_IN_WAKEUP, function() {
                if (alertPin.read() == 0) return;
                cb();
            }.bindenv(this));
        }


        // enable and latch interrupt
        accel.configureInterruptLatching(true);
        accel.configureClickInterrupt(true, LIS3DH.SINGLE_CLICK, ACCEL_THRESHOLD, ACCEL_DURATION);

        return this;
    }

    /***************************************************************************************
     * disableInterrupt
     * Returns: this
     * Parameters:
     **************************************************************************************/
    function disableInterrupt() {
        accel.configureClickInterrupt(false);
        return this;
    }

    /***************************************************************************************
     * checkAccelInterrupt, checks and clears the interrupt
     * Returns: boolean, if single click event detected
     * Parameters: none
     **************************************************************************************/
    function checkAccelInterrupt() {
        local event = accel.getInterruptTable();
        return (event.singleClick) ? true : false;
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _buildReadingQue
     * Returns: an array of Promises for each sensor that is taking a reading
     * Parameters: none
     **************************************************************************************/
    function _buildReadingQue() {
        local que = [];
        // we are not interrested in accel reading data for this app, so it is not included here
        if (tempHumid) que.push( _takeReading(tempHumid) );
        if (press) que.push( _takeReading(press) );
        que.push(_takeReading("lx"));
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
            if (sensor == "lx") {
                return resolve({"lxLevel" : getLightLevel()});
            } else if (sensor == accel) {
                sensor.getAccel(function(reading) {
                    return resolve(reading);
                }.bindenv(sensor));
            } else {
                sensor.read(function(reading) {
                    return resolve(reading);
                }.bindenv(sensor));
            }
        }.bindenv(this))
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
        local i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);

        if (sensors.find(TEMP_HUMID) != null) {
            tempHumid = HTS221(i2c);
        }

        if (sensors.find(AIR_PRESSURE) != null) {
            press = LPS22HB(i2c);
        }

        if (sensors.find(ACCELEROMETER) != null) {
            accel = LIS3DH(i2c, LIS3DH_ADDR);
        }

        return this;
    }

}//line 13 "device.nut"
// Smart Refrigerator Application class
//line 1 "SmartFridgeApp.class.nut"
/***************************************************************************************
 * SmartFridgeApp Class:
 *      Configures sleep/wake behavior, and interrupts
 *      Takes readings
 *      Sends readings to agent
 *      Reports changes to fridge door status (open, closed) to agent
 *      Sends alerts to agent if
 *              door open too long
 *              temp above threshold
 *              humidity above threshold
 *
 * Dependencies
 *      Promise Library
 *      Bullwinkle Library
 *      ExplorerKitSensors Class
 **************************************************************************************/
class SmartFridgeApp {
    // Update the static variables to customize app for your refrigerator

    // Note on power efficiency and battery life:
    // Short intervals are useful for development and debugging
    // For regular operation and longer battery life, intervals should be increased
    // Wake and connection time in seconds
    static READING_INTERVAL = 15;
    static REPORTING_INTERVAL = 60;

    // Time in seconds to wait before sleeping after boot
    // This leaves time to do a BlinkUp after bootup
    static BOOT_TIMEOUT = 60;

    // When device is awake, time to wait between checks for change in door status
    static DOOR_CHECK_TIMER = 1;

    // Thresholdes used to determine events
    static LIGHT_THRESHOLD = 9000; // door open/closed
    static TEMP_THRESHOLD = 11;
    static HUMID_THRESHOLD = 70;

    // Time in seconds that door is open for before door alert triggered
    static DOOR_ALERT_TIMEOUT = 30;
    // Number of seconds the conditon must be over threshold before triggering env event
    static TEMP_ALERT_CONDITION = 900;
    static HUMID_ALERT_CONDITION = 900;
    // Time in seconds after door close event before env events will be checked (prevents temperature or humidity alerts right after is opened)
    static DOOR_CONDITION_TIMEOUT = 180;

    // Event types (these should match agent side event types in SmartFrigDataManager)
    static EVENT_TYPE_TEMP_ALERT = "temperaure alert";
    static EVENT_TYPE_HUMID_ALERT = "humidity alert";
    static EVENT_TYPE_DOOR_ALERT = "door alert";
    static EVENT_TYPE_DOOR_STATUS = "door status";

    // Door status strings
    static DOOR_OPEN = "open";
    static DOOR_CLOSED = "closed";

    // Debug logging flags, note logging requires a connection to the server, so logging will decrease battery life
    static DEBUG_LOGGING = true;
    static LX_LOGGING = false;

    // Class instances
    _bull = null;
    _exKit = null;

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
                if (DEBUG_LOGGING) nv.logs.push("Woke on int pin.");
                clearInterrupt();
                break;
            case WAKEREASON_TIMER:
                if (DEBUG_LOGGING) nv.logs.push("Woke on timer.");
                break;
            case WAKEREASON_POWER_ON:
                _boot = imp.wakeup(BOOT_TIMEOUT, function() {
                    _boot = null;
                }.bindenv(this));
            default :
                if (DEBUG_LOGGING) {
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
        takeReadings()
            .then(function(msg) {
                if (DEBUG_LOGGING) nv.logs.push(msg);
                // Check whether to connect
                if (server.isconnected() || _connectTime() || nv.events.len() > 0) {
                    return sendUpdate();
                } else {
                    return "Not connection time yet.";
                }
            }.bindenv(this))
            .then(function(msg) {
                if (DEBUG_LOGGING) nv.logs.push(msg);
                powerDown();
            }.bindenv(this));
    }

    /***************************************************************************************
     * takeReadings, takes readings and checks for env events
     * Returns: promise
     * Parameters: none
     **************************************************************************************/
    function takeReadings() {
        // Take readings and check env thresholds
        return Promise(function(resolve, reject) {
            _exKit.takeReadings()
                .then(function(readings) {
                    checkForEnvEvents(readings);
                    return resolve("Env readings stored and checked.");
                }.bindenv(this));
        }.bindenv(this))
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
            if (DEBUG_LOGGING) _logStoredMsgs();

            // Send update to agent
            _bull.send("update", update)
                .onReply(function(msg) {
                    return resolve("Agent received update.");
                }.bindenv(this)) // onReply closure
                .onFail(function(err, msg, retry) {
                    // Agent didn't receive data, so store to send on next connect
                    nv.readings.extend(update.readings);
                    nv.events.extend(update.events);
                    return resolve("Connection attempt failed. Readings kept.");
                }.bindenv(this)); // onFail closure

            setNextConnect();

        }.bindenv(this)); // Promise closure
    }

    /***************************************************************************************
     * checkForEnvEvents, checks for door, temp or humidity events
     * Returns: null
     * Parameters: readings array
     **************************************************************************************/
    function checkForEnvEvents(readings) {
        if (readings.len() > 0) {
            local now = time();
            local reading = readings.top();

            if ("lxLevel" in reading) {
                _updateDoorStatus(reading.lxLevel);
            }

            if (nv.env.doorTimeout != null && time() >= nv.env.doorTimeout) {
                // Stop blocking env threshold events if door timeout has expired
                nv.env.doorTimeout = null;
            }

            if ("temperature" in reading) {
                if (reading.temperature < TEMP_THRESHOLD) {
                    // reset event flag if set, b/c we have dropped back to acceptable range
                    if (nv.env.eventReported.temperature) nv.env.eventReported.temperature = false;
                } else if (nv.door.currentStatus == DOOR_CLOSED && nv.env.doorTimeout == null && !nv.env.eventReported.temperature) {
                    // We have met all conditions, so check for temp event
                    _checkEnvTimer("temperature", now, reading.temperature);
                }
            }

            if ("humidity" in reading) {
                if (reading.humidity < HUMID_THRESHOLD) {
                    // reset event flag if set, b/c we have dropped back to acceptable range
                    if (nv.env.eventReported.humidity) nv.env.eventReported.humidity = false;
                } else if (nv.door.currentStatus == DOOR_CLOSED && nv.env.doorTimeout == null && !nv.env.eventReported.humidity) {
                    // We have met all conditions, so check for humid event
                    _checkEnvTimer("humidity", now, reading.humidity);
                }
            }
        }

    }

    /***************************************************************************************
     * clearInterrupt
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function clearInterrupt() {
        _exKit.checkAccelInterrupt();
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
            readingTimer = READING_INTERVAL;
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
        nv.timers.nextConnectTime <- now + REPORTING_INTERVAL;
    }

    /***************************************************************************************
     * powerDown - if cold boot stay connected, if door is open turn off WiFi, otherwise sleep
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function powerDown() {
        local nextReading = setNextReadingTime();

        if (_boot) {
            // Start loop to check for changes in door status
            _startWakeLoop();
        } else if (nv.door.currentStatus == DOOR_OPEN) {
            // Disconnect from WiFi
            imp.onidle(function() {
                server.disconnect();
            }.bindenv(this));

            // Start loop to check for Door Close event
            _startWakeLoop();
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
        if (timer == null) timer = READING_INTERVAL;

        // Put imp to sleep when it becomes idle
        if (DEBUG_LOGGING) nv.logs.push("Going to sleep for " + timer + " sec.");
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
        _bull = Bullwinkle();
        // Class to manage sensors
        _exKit = ExplorerKitSensors(sensors);
    }

    /***************************************************************************************
     * _configureDevice
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _configureDevice() {
        imp.setpowersave(true); // will slow connection time when true
        // Configure sensors and interrupts
        _exKit.configureSensors();
        _exKit.enableAccelerometerClickInterrupt(_startWakeLoop.bindenv(this));
    }

    /***************************************************************************************
     * _configureNVTable
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _configureNVTable() {
        local root = getroottable();
        local door = { "currentStatus" : DOOR_CLOSED,
                              "openAlertSent" : false,
                              "ts" : time() };
        local env = { "doorTimeout" : null,
                             "tempTimer" : null,
                             "humidTimer" : null,
                             "eventReported" : {"temperature": false , "humidity" : false} };
        if (!("nv" in root)) root.nv <- { "readings" : [],
                                          "events" : [],
                                          "timers" : {},
                                          "logs" : [],
                                          "door" : door,
                                          "env" : env };
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
     * _checkEnvTimer, checks/sets timers and creates alert if conditions met
     * Returns: null
     * Parameters:
     *          type: string with name of sensor
     *          now: integer, current timestamp
     *          reading: latest reading from sensor
     **************************************************************************************/
    function _checkEnvTimer(type, now, reading) {
        local timeout, eventType, timer

        if (type == "humidity") {
            timeout = HUMID_ALERT_CONDITION;
            eventType = EVENT_TYPE_HUMID_ALERT;
            timer = "humidTimer";
        }
        if (type == "temperature") {
            timeout = TEMP_ALERT_CONDITION;
            eventType = EVENT_TYPE_TEMP_ALERT;
            timer = "tempTimer";
        }

        if (nv.env[timer] == null) {
            // Reading above threshold for first time, so set alert condition time
            nv.env[timer] = now + timeout;
        } else if (now >= nv.env[timer]) {
             // Alert time passed, so trigger event
            nv.events.push({ "type" : eventType,
                                        "ts" : now,
                                        "description": format("%s above threshod.", type),
                                        "latestReading" : reading });
            // Update env alert flag (so we don't continue to send same alert)
            nv.env.eventReported[type] = true;
            // Reset stored alert time
            nv.env[timer] = null;
        }

    }

    /***************************************************************************************
     * _startWakeLoop -
     *             loops until door close detected, then runs connection
     *             flow to notify agent of the change, and then sleep
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _startWakeLoop() {
        _updateDoorStatus(_exKit.getLightLevel());
        if (nv.events.len() > 0 || _readingTime()) {
            // Door event was found or time for a reading, connect and send
            runWakeUpFlow();
        } else {
            // No change in door status, so check again in a bit
            imp.wakeup(DOOR_CHECK_TIMER, _startWakeLoop.bindenv(this));
        }
    }

    /***************************************************************************************
     * _updateDoorStatus, stores current door status and event triggered flag in nv
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _updateDoorStatus(lxReading) {
        local doorStatus = ( LIGHT_THRESHOLD < lxReading ) ?  DOOR_OPEN : DOOR_CLOSED;

        if (LX_LOGGING) {
            nv.logs.push("Lx level: " + lxReading);
            nv.logs.push("NEW DOOR STATUS: " + doorStatus);
            nv.logs.push("STORED DOOR STATUS: " +  nv.door.currentStatus);
        }

        // Door state changed - Event triggered
        if (doorStatus != nv.door.currentStatus) {
            // Get a time stamp for event
            local ts = time();

            // Door close event has just happened
            if (doorStatus == DOOR_CLOSED) {
                // Set door timeout
                nv.env.doorTimeout = ts + DOOR_CONDITION_TIMEOUT;
                // Reset alert flag
                nv.door.openAlertSent <- false;
            }

            // Update door status
            nv.door.currentStatus <- doorStatus;
            nv.door.ts <- ts;
            // Update events
            nv.events.push({ "type" : EVENT_TYPE_DOOR_STATUS,
                             "description": format("door %s.", doorStatus.tolower()),
                             "ts" : ts });

        } else if (doorStatus == DOOR_OPEN && !nv.door.openAlertSent) {
            // Determine if door alert should be triggered
            local doorOpenDuration = time() - nv.door.ts;
            if (doorOpenDuration >  DOOR_ALERT_TIMEOUT) {
                nv.events.push({ "type" : EVENT_TYPE_DOOR_ALERT,
                                 "description" : format("door has been open for %i seconds", doorOpenDuration),
                                 "ts" : time() });
                // Don't send multiple alerts
                nv.door.openAlertSent <- true;
            }
        }
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

            update.doorStatus <- nv.door;
            update.readings <- _copyArray(nv.readings);
            update.events <- _copyArray(nv.events);

            // clear nv tables, so we don't resend data
            nv.readings <- [];
            nv.events <- [];

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
}//line 15 "device.nut"


// RUNTIME
// ----------------------------------------------

// Select sensors to initialize
local sensors = [ ExplorerKitSensors.TEMP_HUMID,
                  ExplorerKitSensors.ACCELEROMETER ];
// Start Application
SmartFridgeApp(sensors);
