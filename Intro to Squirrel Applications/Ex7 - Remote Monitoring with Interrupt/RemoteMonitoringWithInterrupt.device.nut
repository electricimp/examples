// Remote Monitoring Application With Interrupt Device Code
// ---------------------------------------------------
// NOTE: imp004m, and imp006 devices do not have nv storage. 
// This code will work around this on limitation by using shallow sleep
// See developer docs - https://developer.electricimp.com/api/nv and 
// https://developer.electricimp.com/resources/sleepstatesexplained

// SENSOR LIBRARIES
// --------------------------------------------------------
// Libraries must be required before all other code

// Accelerometer Library
#require "LIS3DH.device.lib.nut:2.0.2"
// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"
// Library to help with asynchonous programming
#require "promise.lib.nut:4.0.0"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.2.0"

// HARDWARE ABSTRACTION LAYER
// --------------------------------------------------------
// HAL's are tables that map human readable names to
// the hardware objects used in the application.

// Copy and Paste Your HAL here
// YOUR_HAL <- {...}


// REMOTE MONITORING INTERRUPT APPLICATION CODE
// --------------------------------------------------------
// Application code, take readings from our sensors
// and send the data to the agent

class Application {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC = 30;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC = 300;
    // Max number of stored readings
    static MAX_NUM_STORED_READINGS = 20;
    // Time to wait after boot before first disconection
    // This allows time for blinkup recovery on cold boots
    static BOOT_TIMER_SEC = 60;
    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 25;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr
    accelAddr       = null; // Replace with your accel i2c addr
    wakePin         = null; // Replace with your wake pin

    // Sensor variables
    tempHumid = null;
    accel = null;

    // Message Manager variable
    mm = null;

    // Flag to track first disconnection
    _boot = false;

    // Flag to track if imp is trying to connect
    _connecting = false;

    constructor() {
        // Power save mode will reduce power consumption when the radio
        // is idle, a good first step for saving power for battery
        // powered devices.
        // NOTE: Power save mode will add latency when sending data.
        // Power save mode is not supported on impC001 and is not
        // recommended for imp004m, so don't set for those types of imps.
        local type = imp.info().type;
        if (!(type == "imp004m" || type == "impC001")) {
            imp.setpowersave(true);
        }

        // Change default connection policy, so our application
        // continues to run even if the connection fails
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message
        // has been delivered. We will use this to know when it is ok
        // to disconnect.
        mm.onAck(readingsAckHandler.bindenv(this));
        // Message Manager allows us to call a function if a message
        // fails to be delivered. We will use this to recover data
        mm.onFail(sendFailHandler.bindenv(this));

        // Initialize sensors
        initializeSensors();

        // Configure different behavior based on the reason the
        // hardware rebooted
        checkWakeReason();
    }

    function checkWakeReason() {
        // We can configure different behavior based on
        // the reason the hardware rebooted.
        switch (hardware.wakereason()) {
            case WAKEREASON_TIMER :
                // We woke up after sleep timer expired.
                restoreNV(); 
                break;
            case WAKEREASON_PIN :
                // We woke up because an interrupt pin was triggered.
                restoreNV(); 
                // Let's check our interrupt
                checkInterrupt();
                break;
            case WAKEREASON_SNOOZE :
                // We woke up after connection timeout.
                restoreNV(); 
                break;
            default :
                // We pushed new code or just rebooted the device, etc. Lets
                // congigure everything.
                server.log("Device running...");

                // NV can persist data when the device goes into sleep mode
                // Set up the table with defaults - note this method will
                // erase stored data, so we only want to call it when the
                // application is starting up.
                configureNV();

                // We want to make sure we can always blinkUp a device
                // when it is first powered on, so we do not want to
                // immediately disconnect after boot
                // Set up first disconnect
                _boot = true;
                imp.wakeup(BOOT_TIMER_SEC, function() {
                    _boot = false;
                    powerDown();
                }.bindenv(this));
        }

        // Configure Sensors to take readings
        configureSensors();
        takeReadings();
    }

    function takeReadings() {
        // Take readings by building an array of functions that all
        // return promises.
        local series = [takeTempHumidReading(), takeAccelReading()];

        // The all method executes the series of promises in parallel
        // and resolves when they are all done. It Returns a promise
        // that resolves with an array of the resolved promise values.
        Promise.all(series)
            .then(function(results) {
                // Create a table to store the results from the sensor readings
                // Add a timestamp
                local reading = {"time" : time()};
                // Add all successful readings
                if ("temperature" in results[0]) reading.temperature <- results[0].temperature;
                if ("humidity" in results[0]) reading.humidity <- results[0].humidity;
                if ("x" in results[1]) reading.accel_x <- results[1].x;
                if ("y" in results[1]) reading.accel_y <- results[1].y;
                if ("z" in results[1]) reading.accel_z <- results[1].z;
                // Add table to the readings array for storage til next connection
                status.readings.push(reading);

                return("Readings Done");
            }.bindenv(this))
            .finally(checkConnectionTime.bindenv(this))
    }

    function takeTempHumidReading() {
        return Promise(function(resolve, reject) {
            tempHumid.read(function(result) {
                return resolve(result);
            }.bindenv(this))
        }.bindenv(this))
    }

    function takeAccelReading() {
        return Promise(function(resolve, reject) {
            accel.getAccel(function(result) {
                return resolve(result);
            }.bindenv(this))
        }.bindenv(this))
    }

    function checkConnectionTime(value = null) {
        // Grab a timestamp
        local now = time();

        // Update the next reading time varaible
        setNextReadTime(now);

        // If we are not currently tring to connect, check if we
        // should connect, send data, or power down
        if (!_connecting) {

            local connected = server.isconnected();
            // Send if we are connected or if it is
            // time to connect
            if (connected || timeToConnect()) {

                // Update the next connection time varaible
                setNextConnectTime(now);

                if (connected) {
                    sendData();
                } else {
                    // Toggle connecting flag
                    _connecting = true;

                    // We changed the default connection policy, so we need to
                    // use this method to connect
                    server.connect(function(reason) {
                        // Connect handler called, we are no longer tring to
                        // connect, so set connecting flag to false
                        _connecting = false;
                        if (reason == SERVER_CONNECTED) {
                            // We connected let's send readings
                            sendData();
                        } else {
                            // We were not able to connect
                            // Let's make sure we don't run out
                            // of memory with our stored readings
                            failHandler();
                        }
                    }.bindenv(this));
                }
            } else {
                // Not time to connect & we are not currently
                // trying to send data, so let's sleep until
                // next reading time
                powerDown();
            }
        } else {
            // Calculate how long before next reading time
            local timer = status.nextReadTime - now;
            // Schedule next reading
            imp.wakeup(timer, takeReadings.bindenv(this));
        }

    }

    function sendData() {
        local data = {};

        if (status.readings.len() > 0) {
            data.readings <- status.readings;
        }
        if (status.alerts.len() > 0) {
            data.alerts <- status.alerts;
        }

        // Send data to the agent
        mm.send("data", data);

        // If this message is acknowleged by the agent
        // the readingsAckHandler will be triggered

        // If the message fails to send we will handle
        // in the sendFailHandler handler
    }

    function readingsAckHandler(msg) {
        // We connected successfully & sent data

        // Clear readings we just sent
        status.readings.clear();

        // Clear alerts we just sent
        status.alerts.clear();

        // Reset numFailedConnects
        status.numFailedConnects <- 0;

        // Disconnect from server
        powerDown();
    }

    function sendFailHandler(msg, error, retry) {
        // Message did not send, call the connection
        // failed handler, so readings can be
        // condensed and stored
        failHandler();
    }

    function setWakeup(timer) {
        imp.wakeup(timer, function() {
            powerUpSensors();
            takeReadings();
        }.bindenv(this))
    }

    function powerDown() {
        // Power Down sensors
        powerDownSensors();

        // Calculate how long before next reading time
        local timer = status.nextReadTime - time();
        local type = imp.info().type;

        // Check that we did not just boot up, are
        // not about to take a reading, and have an 'nv' table
        if (!_boot && timer > 2) {
            if (!(type == "imp004m" || type == "imp006")) { // We have nv, so deep sleep
                imp.onidle(function() {
                    server.sleepfor(timer);
                }.bindenv(this));
            } else { // No nv table, so just disconnect and sleep
                setWakeup(timer);
                imp.onidle(function() {
                    server.disconnect();
                }.bindenv(this));
            }
       } else {
            // Schedule next reading, but don't go to sleep
            setWakeup(timer);
        }
    }


    function powerDownSensors() {
        tempHumid.setMode(HTS221_MODE.POWER_DOWN);
    }

    function powerUpSensors() {
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
    }

    function failHandler() {
        // We are having connection issues
        // Let's condense and re-store the data

        // Find the number of times we have failed
        // to connect (use this to determine new readings
        // vs. previously condensed readings)
        local failed = status.numFailedConnects;
        local readings;

        // Make a copy of the stored readings
        readings = status.readings.slice(0);
        // Clear stored readings
        status.readings.clear();

        if (readings.len() > 0) {
            // Create an array to store condensed readings
            local condensed = [];

            // If we have already averaged readings move them
            // into the condensed readings array
            for (local i = 0; i < failed; i++) {
                condensed.push( readings.remove(i) );
            }

            // Condense and add the new readings
            condensed.push(getAverage(readings));

            // Drop old readings if we are running out of space
            while (condensed.len() >= MAX_NUM_STORED_READINGS) {
                condensed.remove(0);
            }

            // If new readings have come in while we were processing
            // Add those to the condensed readings
            if (status.readings.len() > 0) {
                foreach(item in status.readings) {
                    condensed.push(item);
                }
            }

            // Replace the stored readings with the condensed readings
            status.readings <- condensed;
        }

        // Update the number of failed connections
        status.numFailedConnects <- failed++;

        powerDown();
    }

    function getAverage(readings) {
        // Variables to help us track readings we want to average
        local tempTotal = 0;
        local humidTotal = 0;
        local tCount = 0;
        local hCount = 0;

        // Loop through the readings to get a total
        foreach(reading in readings) {
            if ("temperature" in reading) {
                tempTotal += reading.temperature;
                tCount ++;
            }
            if ("humidity" in reading) {
                humidTotal += reading.humidity;
                hCount++;
            }
        }

        // Grab the last value from the readings array
        // This we allow us to keep the last accelerometer
        // reading and time stamp
        local last = readings.top();

        // Update the other values with an average
        last.temperature <- tempTotal / tCount;
        last.humidity <- humidTotal / hCount;

        // return the condensed single value
        return last
    }

    function configureNV() {
        local type = imp.info().type;
        local root = getroottable();
        // Create a table for storing status and recent readings
        if (!("status" in root)) root.status <- {};

        if (!(type == "imp004m" || type == "imp006")) {
            // There is an nv table, so make the status table a
            // reference to nv so it will be persisted
            if (!("nv" in root)) root.nv <- {};
            status = nv;
        }

        local now = time();
        setNextConnectTime(now);
        setNextReadTime(now);
        status.readings <- [];
        status.alerts <-[];
        status.numFailedConnects <- 0;
    }

    function restoreNV() {
        local root = getroottable();
        local type = imp.info().type;
        if (!("status" in root)) root.status <- {};
        if (!(type == "imp004m" || type == "imp006")) status = nv ;
    }

    function setNextConnectTime(now) {
        status.nextConnectTime <- now + REPORTING_INTERVAL_SEC;
    }

    function setNextReadTime(now) {
        status.nextReadTime <- now + READING_INTERVAL_SEC;
    }

    function timeToConnect() {
        // return a boolean - if it is time to connect based on
        // the current time or alerts
        return (time() >= status.nextConnectTime || status.alerts.len() > 0);
    }

    function configureInterrupt() {
        accel.configureInterruptLatching(true);
        accel.configureFreeFallInterrupt(true);

        // Configure wake pin
        wakePin.configure(DIGITAL_IN_WAKEUP, function() {
            if (wakePin.read() && checkInterrupt()) {
                takeReadings();
            }
        }.bindenv(this));
    }

    function checkInterrupt() {
        local interrupt = accel.getInterruptTable();
        if (interrupt.int1) {
            status.alerts.push({"msg" : "Freefall Detected", "time": time()});
        }
        return interrupt.int1;
    }

    function initializeSensors() {
        // Configure i2c
        i2c.configure(CLOCK_SPEED_400_KHZ);

        // Initialize sensors
        tempHumid = HTS221(i2c, tempHumidAddr);
        accel = LIS3DH(i2c, accelAddr);
    }

    function configureSensors() {
        // Configure sensors to take readings
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        accel.reset();
        accel.setMode(LIS3DH_MODE_LOW_POWER);
        accel.setDataRate(ACCEL_DATARATE);
        accel.enable(true);
        // Configure accelerometer freefall interrupt
        configureInterrupt();
    }
}


// RUNTIME
// ---------------------------------------------------

// Initialize application to start readings loop
app <- Application();
