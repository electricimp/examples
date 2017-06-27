// Simple Refrigerator Monitor Application Device Code
// ---------------------------------------------------

// SENSOR LIBRARIES
// ---------------------------------------------------
// Libraries must be required before all other code

// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"


// HARDWARE ABSTRACTION LAYER
// ---------------------------------------------------
// HAL's are tables that map human readable names to 
// the hardware objects used in the application. 

// Copy and Paste Your HAL here
// YOUR_HAL <- {...}


// REFRIGERATOR MONITOR APPLICATION CODE
// ---------------------------------------------------
// Application code, take readings from our temperature
// humidity and light sensors. Use the light level to 
// determine if the door is open (true or false) and send
// the door status, temperature and humidity to the agent 

class SmartFridge {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC = 5;

    // The lx level at which we know the door is open
    static LX_THRESHOLD         = 3000;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr

    // Sensor variables
    tempHumid = null;

    constructor() {
        // Power save mode will reduce power consumption when the 
        // radio is idle. This adds latency when sending data. 
        imp.setpowersave(true);
        initializeSensors();
    }

    function run() {
        // Set up the reading table with a timestamp
        local reading = { "time" : time() };
        
        // Add temperature and humidity readings
        local result = tempHumid.read();
        if ("temperature" in result) reading.temperature <- result.temperature;
        if ("humidity" in result) reading.humidity <- result.humidity;

        // Check door status using internal LX sensor to 
        // determine if the door is open
        reading.doorOpen <- (hardware.lightlevel() > LX_THRESHOLD);

        // Send readings to the agent
        agent.send("reading", reading);

        // Schedule the next reading
        imp.wakeup(READING_INTERVAL_SEC, run.bindenv(this));
    }

    function initializeSensors() {
        // Configure i2c
        i2c.configure(CLOCK_SPEED_400_KHZ);

        // Initialize sensor
        tempHumid = HTS221(i2c, tempHumidAddr);

        // Configure sensor to take readings
        tempHumid.setMode(HTS221_MODE.ONE_SHOT); 
    }
}


// RUNTIME 
// ---------------------------------------------------
server.log("Device running...");

// Initialize application
fridge <- SmartFridge();

// Start reading loop
fridge.run();
