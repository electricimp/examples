// Temperature Humidity sensor Library
#require "Si702x.class.nut:1.0.0"
// Air Pressure sensor Library
#require "LPS25H.class.nut:2.0.1"
// Ambient Light sensor Library
#require "APDS9007.class.nut:2.2.1"

#require "ConnectionManager.class.nut:1.0.1"
#require "promise.class.nut:3.0.0"
#require "bullwinkle.class.nut:2.3.0"


/***************************************************************************************
 * EnvTail Class:
 *      Initializes and enables sensors specified in constructor
 *      Set time interval between readings
 *      Get time interval between readings
 *      Takes sensor readings & stores them to local device storage
 **************************************************************************************/
class EnvTail {
    _tempHumid = null;
    _ambLx = null;
    _press = null;
    _led = null;
    _cm = null;

    _readingInterval = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      enableTempHumid : boolean - if the temperature/humidity sensor should be enabled
     *      enableAmbLx : boolean - if the ambient light sensor should be enabled
     *      enablePressure : boolean - if the air pressure sensor should be enabled
     *      readingInt : second to wait between readings
     **************************************************************************************/
    constructor(enableTempHumid, enableAmbLx, enablePressure, readingInt, cm = null) {
        _cm = cm;
        _configureLED();
        _configureNVTable();
        _enableSensors(enableTempHumid, enableAmbLx, enablePressure);
        setReadingInterval(readingInt);
    }

    /***************************************************************************************
     * takeReadings - takes readings, sends to agent, schedules next reading
     * Returns: null
     * Parameters:
     *      cb (optional) : function - callback that is passed the parsed reading
     **************************************************************************************/
    function takeReadings(cb = null) {
        // Take readings asynchonously if sensor enabled
        local que = _buildReadingQue();

        // When all sensors have returned values store a reading locally
        // Then set timer for next reading
        Promise.all(que)
            .then(function(envReadings) {
                local reading = _parseReadings(envReadings);
                // store reading
                nv.readings.push(reading);
                // pass reading to callback
                if (cb) imp.wakeup(0, function() {
                    cb(reading);
                }.bindenv(this));
                // flash led to let user know a reading was stored
                flashLed();
            }.bindenv(this))
            .finally(function(val) {
                // set timer for next reading
                imp.wakeup(_readingInterval, function() {
                    takeReadings(cb);
                }.bindenv(this));
            }.bindenv(this));
    }

    /***************************************************************************************
     * setReadingInterval
     * Returns: this
     * Parameters:
     *      interval (optional) : the time in seconds to wait between readings,
     *                                     if nothing passed in sets the readingInterval to
     *                                     the default of 300s
     **************************************************************************************/
    function setReadingInterval(interval) {
        _readingInterval = interval;
        return this;
    }

    /***************************************************************************************
     * getReadingInterval
     * Returns: the current reading interval
     * Parameters: none
     **************************************************************************************/
    function getReadingInterval() {
        return _readingInterval;
    }

    /***************************************************************************************
     * flashLed - blinks the led, this function blocks for 0.5s
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function flashLed() {
        led.write(1);
        imp.sleep(0.5);
        led.write(0);
        return this;
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _configureNVTable
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _configureNVTable() {
        local root = getroottable();
        if (!("nv" in root)) root.nv <- { "readings" : [] };
    }

    /***************************************************************************************
     * _buildReadingQue
     * Returns: an array of Promises for each sensor that is taking a reading
     * Parameters: none
     **************************************************************************************/
    function _buildReadingQue() {
        local que = [];
        if (_ambLx) que.push( _takeReading(_ambLx) );
        if (_tempHumid) que.push( _takeReading(_tempHumid) );
        if (_press) que.push( _takeReading(_press) );
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
            sensor.read(function(reading) {
                return resolve(reading);
            }.bindenv(sensor));
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
                (_cm) ? _cm.error(reading.err) : server.error(reading.err);
            } else if ("error" in reading) {
                (_cm) ? _cm.error(reading.error) : server.error(reading.error);
            } else {
                foreach(sensor, value in reading) {
                    data[sensor] <- value;
                }
            }
        }
        return data;
    }

    /***************************************************************************************
     * _enableSensors
     * Returns: this
     * Parameters:
     *      tempHumid: boolean - if temperature/humidity sensor should be enabled
     *      ambLx: boolean - if ambient light sensor should be enabled
     *      press: boolean - if air pressure sensor should be enabled
     **************************************************************************************/
    function _enableSensors(tempHumid, ambLx, press) {
        if (tempHumid || press) _configure_i2cSensors(tempHumid, press);
        if (ambLx) _configureAmbLx();
        return this;
    }

    /***************************************************************************************
     * _configure_i2cSensors
     * Returns: this
     * Parameters:
     *      tempHumid: boolean - if temperature/humidity sensor should be enabled
     *      press: boolean - if air pressure sensor should be enabled
     **************************************************************************************/
    function _configure_i2cSensors(tempHumid, press) {
        local i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        if (tempHumid) _tempHumid = Si702x(i2c);
        if (press) {
            _press = LPS25H(i2c);
            // set up to take readings
            _press.softReset();
            _press.enable(true);
        }
        return this;
    }

    /***************************************************************************************
     * _configureAmbLx
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function _configureAmbLx() {
        local lxOutPin = hardware.pin5;
        local lxEnPin = hardware.pin7;
        lxOutPin.configure(ANALOG_IN);
        lxEnPin.configure(DIGITAL_OUT, 1);

        _ambLx = APDS9007(lxOutPin, 47000, lxEnPin);
        _ambLx.enable();
        return this;
    }

    /***************************************************************************************
     * _configureLED
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function _configureLED() {
        _led = hardware.pin2;
        _led.configure(DIGITAL_OUT, 0);
        return this;
    }
}

/***************************************************************************************
 * Application Class:
 *      Starts off reading loop
 *      Sends readings to agent
 **************************************************************************************/
class Application {
    static DEFAULT_READING_INTERVAL = 3;
    static DEFAULT_REPORTING_INTERVAL = 15;
    static DEFAULT_LX_THRESHOLD = 50; // LX level indicating door open

    _bull = null;
    _cm = null;
    _tail = null;

    _readinInt = null;
    _reportingInt = null;
    _lxThreshold = null;
    _doorOpen = null;
    _reportingTimer = null;

    /***************************************************************************************
     * constructor
     * Returns: null
     * Parameters:
     *      readingInt : integer - time interval in seconds between readings
     *      reportingInt : integer - time interval in seconds between connections to agent
     **************************************************************************************/
    constructor(readingInt = null, reportingInt = null) {
        // configure class variables
        _readinInt = (readingInt == null) ? DEFAULT_READING_INTERVAL : readingInt;
        _reportingInt = (reportingInt == null) ? DEFAULT_REPORTING_INTERVAL : reportingInt;

        _initializeClasses();
        imp.wakeup(0.2, _getLXThreshold.bindenv(this));
    }


    /***************************************************************************************
     * run - starts reading loop, starts reporting loop
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function run() {
        // set doorOpen flag
        _doorOpen = false;

        // start reading loop
        _tail.takeReadings(checkForDoorEvent.bindenv(this));

        // send readings everytime we connect to server
        _cm.onConnect(sendReadings.bindenv(this));

        // wait one cycle then connect and send readings
        _reportingTimer = imp.wakeup(_reportingInt, _cm.connect.bindenv(_cm));
    }

    /***************************************************************************************
     * checkForDoorEvent
     * Returns: null
     * Parameters:
     *      reading : table of sensor readings
     **************************************************************************************/
    function checkForDoorEvent(reading) {
        // set default if no lighting threshold has been received from agent
        if (_lxThreshold == null) _lxThreshold = DEFAULT_LX_THRESHOLD;

        if ("brightness" in reading && reading.brightness > _lxThreshold) {
            // cancel the reporting timer
            imp.cancelwakeup(_reportingTimer);
            _doorOpen = true;
            // wake up now and send change in door status
            _cm.connect();
        } else if (_doorOpen) {
            // door was just closed
            // cancel the reporting timer
            imp.cancelwakeup(_reportingTimer);
            _doorOpen = false;
            // wake up now and send change in door status
            _cm.connect();
        }
    }

    /***************************************************************************************
     * sendReadings - send readings from local storage to agent
     *                then clear local storage & disconnect
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function sendReadings() {
        // check for readings
        if ("nv" in getroottable() && "readings" in nv) {
            // send readings to agent
            _bull.send("readings", nv.readings)
                // if agent receives readings
                // erase them from local storage then disonncet
                .onReply(function(msg) {
                    nv.readings = [];
                    _cm.disconnect();
                }.bindenv(this))
                // if connection fails just disconnect
                // readings will be kept and sent on next connection
                .onFail(function(err, msg, retry) {
                    _cm.disconnect();
                }.bindenv(this));
        } else {
            // if no readings are available disconnect
            _cm.disconnect();
        }

        // schedule next connection
        _reportingTimer = imp.wakeup(_reportingInt, _cm.connect.bindenv(_cm));
    }


    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _initializeClasses
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _initializeClasses() {
        // agent/device communication helper library
        _bull = Bullwinkle();
        // connection helper library
        _cm = ConnectionManager({"blinkupBehavior" : ConnectionManager.BLINK_ALWAYS});
        // Class to manage sensors
        _tail = EnvTail(true, true, false, _readinInt, _cm);
    }


    /***************************************************************************************
     * _getLXThreshold
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function _getLXThreshold() {
        _bull.send("lxThreshold", null)
            .onReply(function(message) {
                if (message.data != null) {
                    _lxThreshold = message.data;
                }
            }.bindenv(this));
    }
}


// RUNTIME
// ----------------------------------------------

// Create instances of our classes
app <- Application();

// Give agent time to come online
// Then start the sensor reading & connection loops
imp.wakeup(5, app.run.bindenv(app));
