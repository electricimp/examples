// Power Efficient Remote Monitoring Application Device Code
// ---------------------------------------------------

// SENSOR LIBRARIES
// ---------------------------------------------------
// Libraries must be required before all other code

// Accelerometer Library
#require "LIS3DH.class.nut:1.3.0"
// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"
// Air Pressure sensor Library
#require "LPS22HB.class.nut:1.0.0"
// Library to help with asynchonous programming
#require "promise.class.nut:3.0.1"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.0.0"

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
    // Time to wait after boot before turning off WiFi
    static BOOT_TIMER_SEC = 60;
    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 1;
    static ACCEL_SHUTDOWN = 0;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr
    pressureAddr    = null; // Replace with your pressure i2c addr
    accelAddr       = null; // Replace with your accel i2c addr

    // Sensor variables
    tempHumid = null;
    pressure = null;
    accel = null;

    // Message Manager variable
    mm = null;
    
    // Flag to track first disconnection
    _boot = true;

    constructor() {
        // Power save mode will reduce power consumption when the 
        // radio is idle. This adds latency when sending data. 
        imp.setpowersave(true);

        // Reset default connection policy, so our application 
        // continues to run even if the WiFi connection fails
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

        // On boot/new code etc configure/reset NV table, and prevent
        // device from going to sleep immediately after boot
        checkWakeReason();

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message  
        // has been delivered. We will use this to know when it is ok
        // to disconnect from WiFi
        mm.onAck(readingsAckHandler.bindenv(this));
        // Message Manager allows us to call a function if a message  
        // fails to be delivered. We will use this to recover data 
        mm.onFail(sendFailHandler.bindenv(this));
    }

    function checkWakeReason() {
        // We can configure different behavior based on 
        // the reason the hardware rebooted. 
        switch (hardware.wakereason()) {
            case WAKEREASON_TIMER :
                // We woke up after sleep timer expired.
                // Let's pwer up our sensors.
                powerUpSensors();
                break;
            case WAKEREASON_PIN :
                // We woke up because an interrupt pin was triggerd.
                // Let's pwer up our sensors.
                powerUpSensors();
                break;
            case WAKEREASON_SNOOZE : 
                // We woke up after connection timeout.
                // Let's pwer up our sensors.
                powerUpSensors();
                break;
            default :
                // NV can persist data when the device goes into sleep mode 
                // Set up the table with defaults - note this method will 
                // erase stored data, so we only want to call it when the
                // application is starting up.
                configureNV();

                initializeSensors();

                // We want to make sure we can always blinkUp a device
                // when it is first powered on, so we do not want to
                // immediately disconnect from WiFi after boot
                // Set up first disconnect
                imp.wakeup(BOOT_TIMER_SEC, function() {
                    _boot = false;
                    powerDown();
                }.bindenv(this))
        }
    }

    function run() {
        // Take readings by building an array of functions that all  
        // return promises. 
        local series = [takeTempHumidReading(), takePressureReading(), takeAccelReading()];
        
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
                if ("pressure" in results[1]) reading.pressure <- results[1].pressure;
                if ("x" in results[2]) reading.accel_x <- results[2].x; 
                if ("y" in results[2]) reading.accel_y <- results[2].y; 
                if ("z" in results[2]) reading.accel_z <- results[2].z; 
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
                    });

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

    function takePressureReading() {
        return Promise(function(resolve, reject) {
            pressure.read(function(result) {
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
        // This method calls agent.send, which will 
        // force the server to connect to WiFi            
        mm.send("readings", readings);
        // Clear readings we just sent, we can recover
        // the data if the message send fails
        nv.readings.clear();

        // If this message is acknowleged by the agent
        // the readingsAckHandler will be triggered
        
        // If the message fails to send we will handle 
        // in the sendFailHandler handler
    }

    function readingsAckHandler(msg) {
        // We connected successfully & sent data

        // Reset numFailedConnects
        nv.numFailedConnects <- 0;
        
        // Disconnect from server
        powerDown();
    }

    function sendFailHandler(msg, error, retry) {
        // Readings did not send, pass them the 
        // the connection failed handler, so they
        // can be condensed and stored
        failHandler(msg.payload.data);
    }

    function powerDown() {
        // Power Down sensors
        powerDownSensors();

        // Calculate how long before next reading time
        local timer = nv.nextReadTime - time();
        
        // Check if we just booted up or we are 
        // about to take a reading
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
            imp.wakeup(timer, run.bindenv(this))
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

    function failHandler(readings = null) {
        // We are having connection issues
        // Let's condense and re-store the data

        // Find the number of times we have failed
        // to connect (use this to determine new readings 
        // previously condensed readings) 
        local failed = nv.numFailedConnects;
        
        // Connection failed before we could send
        if (readings == null) {
            // Make a copy of the stored readings
            readings = nv.readings.slice(0);
            // Clear stored readings
            nv.readings.clear();
        }

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
        local pressTotal = 0;
        local tCount = 0;
        local hCount = 0;
        local pCount = 0;

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
            if ("pressure" in reading) {
                pressTotal += reading.pressure;
                pCount++;
            }
        }

        // Grab the last value from the readings array
        // This we allow us to keep the last accelerometer 
        // reading and time stamp
        local last = readings.top();

        // Update the other values with an average 
        last.temperature <- tempTotal / tCount;
        last.humidity <- humidTotal / hCount;
        last.pressure <- pressTotal / pCount;

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
        pressure = LPS22HB(i2c, pressureAddr);
        accel = LIS3DH(i2c, accelAddr);

        // Configure sensors to take readings
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        pressure.softReset();
        pressure.enableLowCurrentMode(true);
        pressure.setMode(LPS22HB_MODE.ONE_SHOT);
        accel.init();
        accel.setLowPower(true);
        accel.setDataRate(ACCEL_DATARATE);
        accel.enable(true);
    }
}


// RUNTIME 
// ---------------------------------------------------
server.log("Device running...");

// Initialize application
app <- Application();

// Start reading loop
app.run();