// Power Efficient Remote Monitoring Application Device Code
// ---------------------------------------------------
// NOTE: This code doesn't support imp004m or imp005 devices,
// since it makes use of nv table
// See developer docs - https://developer.electricimp.com/api/nv

// SENSOR LIBRARIES
// ---------------------------------------------------
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
// ---------------------------------------------------
// HAL's are tables that map human readable names to
// the hardware objects used in the application.

// Copy and Paste Your HAL here
// YOUR_HAL <- {...}


// POWER EFFICIENT REMOTE MONITORING APPLICATION CODE
// ---------------------------------------------------
// Application code, take readings from our sensors
// and send the data to the agent

class Application {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC = 30;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC = 300;
    // Max number of stored readings
    static MAX_NUM_STORED_READINGS = 23;
    // Time to wait after boot before first disconection
    // This allows time for blinkup recovery on cold boots
    static BOOT_TIMER_SEC = 60;
    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 1;
    static ACCEL_SHUTDOWN = 0;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr
    accelAddr       = null; // Replace with your accel i2c addr

    // Sensor variables
    tempHumid = null;
    accel = null;

    // Message Manager variable
    mm = null;

    // Flag to track first disconnection
    _boot = false;

    constructor() {
        // Power save mode will reduce power consumption when the radio
        // is idle, a good first step for saving power for battery
        // powered devices.
        // NOTE: Power save mode will add latency when sending data.
        // Power save mode is not supported on impC001 and is not
        // recommended for imp004m, so don't set for those types of imps.
        local type = imp.info().type;
        if (type != "impC001") {
            imp.setpowersave(true);
        }

        // Change default connection policy, so our application
        // continues to run even if the connection fails
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message
        // has been delivered. We will use this to know when it is ok
        // to disconnect
        mm.onAck(readingsAckHandler.bindenv(this));
        // Message Manager allows us to call a function if a message
        // fails to be delivered. We will use this to condense data
        mm.onFail(sendFailHandler.bindenv(this));

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
                // No extra config needed.
                break;
            case WAKEREASON_PIN :
                // We woke up because an interrupt pin was triggered.
                // No extra config needed.
                break;
            case WAKEREASON_SNOOZE :
                // We woke up after connection timeout.
                // No extra config needed.
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
                // immediately disconnect from WiFi after boot
                // Set up first disconnect
                _boot = true;
                imp.wakeup(BOOT_TIMER_SEC, function() {
                    _boot = false;
                    powerDown();
                }.bindenv(this));
        }

        // Configure Sensors to take readings
        initializeSensors();
        // Start readings loop
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
                nv.readings.push(reading);

                return("Readings Done");
            }.bindenv(this))
            .finally(function(value) {
                // Grab a timestamp
                local now = time();

                // Update the next reading time varaible
                setNextReadTime(now);

                // Only send readings if we have some and are either
                // already connected to WiFi or if it is time to connect
                if (nv.readings.len() > 0 && (server.isconnected() || timeToConnect())) {

                    // Update the next connection time varaible
                    setNextConnectTime(now);

                    if (server.isconnected()) {
                        // We connected let's send readings
                        sendReadings();
                    } else {
                        // We changed the default connection policy, so we need to
                        // use this method to connect
                        server.connect(function(reason) {
                            if (reason == SERVER_CONNECTED) {
                                // We connected let's send readings
                                sendReadings();
                            } else {
                                // We were not able to connect
                                // Let's make sure we don't run out
                                // of meemory with our stored readings
                                failHandler();
                            }
                        }.bindenv(this));
                    }
                } else {
                    // Not time to connect, let's sleep until
                    // next reading time
                    powerDown();
                }
            }.bindenv(this))
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

    function sendReadings() {
        // Send readings to the agent
        mm.send("readings", nv.readings);

        // If this message is acknowleged by the agent
        // the readingsAckHandler will be triggered

        // If the message fails to send we will handle
        // in the sendFailHandler handler
    }

    function readingsAckHandler(msg) {
        // We connected successfully & sent data
        // Clear readings we just sent
        nv.readings.clear();

        // Reset numFailedConnects
        nv.numFailedConnects <- 0;

        // Disconnect from server
        powerDown();
    }

    function sendFailHandler(msg, error, retry) {
        // Readings did not send, call the
        // connection failed handler, so readings
        // can be condensed and re-stored
        failHandler();
    }

    function powerDown() {
        // Power Down sensors
        powerDownSensors();

        // Calculate how long before next reading time
        local timer = nv.nextReadTime - time();

        // Check that we did not just boot up and are
        // not about to take a reading
        if (!_boot && timer > 2) {
            // Go to sleep
            if (server.isconnected()) {
                imp.onidle(function() {
                    // This method flushes server before sleep
                    server.sleepfor(timer);
                }.bindenv(this));
            } else {
                // This method just put's the device to sleep
                imp.deepsleepfor(timer);
            }
        } else {
            // Schedule next reading, but don't go to sleep
            imp.wakeup(timer, function() {
                powerUpSensors();
                takeReadings();
            }.bindenv(this))
        }
    }

    function powerDownSensors() {
        tempHumid.setMode(HTS221_MODE.POWER_DOWN);
        accel.setDataRate(ACCEL_SHUTDOWN);
        accel.enable(false);
    }

    function powerUpSensors() {
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        accel.setDataRate(ACCEL_DATARATE);
        accel.enable(true);
    }

    function failHandler() {
        // We are having connection issues
        // Let's condense and re-store the data

        // Find the number of times we have failed
        // to connect (use this to determine new readings
        // vs. previously condensed readings)
        local failed = nv.numFailedConnects;

        // Make a copy of the stored readings
        readings = nv.readings.slice(0);
        // Clear stored readings
        nv.readings.clear();

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
        if (nv.readings.len() > 0) {
            foreach(item in nv.readings) {
                condensed.push(item);
            }
        }

        // Replace the stored readings with the condensed readings
        nv.readings <- condensed;

        // Update the number of failed connections
        nv.numFailedConnects <- failed++;
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
        local root = getroottable();
        if (!("nv" in root)) root.nv <- {};

        local now = time();
        setNextConnectTime(now);
        setNextReadTime(now);
        nv.readings <- [];
        nv.numFailedConnects <- 0;
    }

    function setNextConnectTime(now) {
        nv.nextConectTime <- now + REPORTING_INTERVAL_SEC;
    }

    function setNextReadTime(now) {
        nv.nextReadTime <- now + READING_INTERVAL_SEC;
    }

    function timeToConnect() {
        // return a boolean - if it is time to connect based on
        // the current time
        return (time() >= nv.nextConectTime);
    }

    function initializeSensors() {
        // Configure i2c
        i2c.configure(CLOCK_SPEED_400_KHZ);

        // Initialize sensors
        tempHumid = HTS221(i2c, tempHumidAddr);
        accel = LIS3DH(i2c, accelAddr);

        // Configure sensors to take readings
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        accel.reset();
        accel.setMode(LIS3DH_MODE_LOW_POWER);
        accel.setDataRate(ACCEL_DATARATE);
        accel.enable(true);
    }
}


// RUNTIME
// ---------------------------------------------------

// Initialize application to start readings loop
app <- Application();