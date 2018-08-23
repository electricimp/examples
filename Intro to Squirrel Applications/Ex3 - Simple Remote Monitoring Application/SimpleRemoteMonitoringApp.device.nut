// Simple Remote Monitoring Application Device Code
// ---------------------------------------------------

// SENSOR LIBRARIES
// ---------------------------------------------------
// Libraries must be required before all other code

// Accelerometer Library
#require "LIS3DH.device.lib.nut:2.0.2"
// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"


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
    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 1;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr
    accelAddr       = null; // Replace with your accel i2c addr

    // Sensor variables
    tempHumid = null;
    accel = null;

    constructor() {
        // Power save mode will reduce power consumption when the radio
        // is idle, a good first step for saving power for battery
        // powered devices. Power save mode will add latency when
        // sending data. Power save mode is not supported on impC001
        // and is recommended for imp004m, so don't set for those types
        // of imps.
        local type = imp.info().type;
        if (type != "imp004m" && type != "impC001") {
            imp.setpowersave(true);
        }
        initializeSensors();
    }

    function run() {
        // Set up the reading table with a timestamp
        local reading = { "time" : time() };

        // Add temperature and humidity readings
        result = tempHumid.read();
        if ("temperature" in result) reading.temperature <- result.temperature;
        if ("humidity" in result) reading.humidity <- result.humidity;

        // Add accelerometer readings
        result = accel.getAccel();
        if ("x" in result) reading.accel_x <- result.x;
        if ("y" in result) reading.accel_y <- result.y;
        if ("z" in result) reading.accel_z <- result.z;

        // Send readings to the agent
        agent.send("reading", reading);

        // Schedule the next reading
        imp.wakeup(READING_INTERVAL_SEC, run.bindenv(this))
    }

    function initializeSensors() {
        // Configure i2c
        i2c.configure(CLOCK_SPEED_400_KHZ);

        // Initialize sensors
        tempHumid = HTS221(i2c, tempHumidAddr);
        accel = LIS3DH(i2c, accelAddr);

        // Configure sensors to take readings
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
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
