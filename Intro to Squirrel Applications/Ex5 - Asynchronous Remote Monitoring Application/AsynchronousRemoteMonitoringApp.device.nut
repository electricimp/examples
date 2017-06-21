// Asynchonous Remote Monitoring Application Device Code
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


// REMOTE MONITORING APPLICATION CODE
// ---------------------------------------------------
// Application code, take readings from our sensors
// and send the data to the agent 

class Application {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC = 30;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC = 300;
    // Time to wait after boot before turning off WiFi
    static BOOT_TIMER_SEC = 60;
    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 1;

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

    // An array to store readings between connections
    readings = [];

    // Varaible to track when to connect
    nextConnectTime = null;
    
    // Flag to track first disconnection
    _boot = true;

    constructor() {
        // Power save mode will reduce power consumption when the 
        // radio is idle. This adds latency when sending data. 
        imp.setpowersave(true);

        // Use the current time and the REPORTING_INTERVAL_SEC 
        // to set a timestamp, so we know when we should connect
        // to WiFi and send the stored readings
        setNextConnectTime();

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message  
        // has been delivered. We will use this to know when it is ok
        // to delete locally stored readings and disconnect from WiFi
        mm.onAck(readingsAckHandler.bindenv(this));
        
        initializeSensors();

        // We want to make sure we can always blinkUp a device
        // when it is first powered on, so we do not want to
        // immediately disconnect from WiFi after boot
        // Set up first disconnect
        imp.wakeup(BOOT_TIMER_SEC, function() {
            _boot = false;
            server.disconnect();
        }.bindenv(this))
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
                readings.push(reading);

                // Only send readings if we have some and are either
                // already connected to WiFi or if it is time to connect
                if (readings.len() > 0 && (server.isconnected() || timeToConnect())) {
                    sendReadings();
                }

                return("Readings Done");
            }.bindenv(this))
            .finally(function(value) {
                // Schedule the next reading
                imp.wakeup(READING_INTERVAL_SEC, run.bindenv(this));
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
        // Update the next connection time varaible
        setNextConnectTime();

        // When this message is acknowleged by the agent
        // the readingsAckHandler will be triggered
    }

    function readingsAckHandler(msg) {
        // The agent received the readings
        // Clear readings we just sent
        readings = [];
        // Disconnect from server if we have not just booted up
        if (!_boot) server.disconnect();
    }

    function timeToConnect() {
        // return a boolean - if it is time to connect based on 
        // the current time
        return (time() >= nextConnectTime);
    }

    function setNextConnectTime() {
        // Update the local nextConnectTime variable
        nextConnectTime = time() + REPORTING_INTERVAL_SEC;
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
