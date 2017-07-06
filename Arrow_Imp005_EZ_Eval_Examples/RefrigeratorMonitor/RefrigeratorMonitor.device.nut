// Refrigerator Monitor Application Device Code
// ---------------------------------------------------

// SENSOR LIBRARIES
// ---------------------------------------------------
// Libraries must be required before all other code

// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.0.0"

// HARDWARE ABSTRACTION LAYER
// ---------------------------------------------------
// HAL's are tables that map human readable names to 
// the hardware objects used in the application. 

IMP005_EZ_EVAL <- {
    "SENSOR_AND_IOH_I2C"  : hardware.i2c0,
    "TEMP_HUMID_I2C_ADDR" : 0xBE,
    "ACCEL_I2C_ADDR"      : 0x32,
    "ACCEL_INT"           : hardware.pinXA,

    "USB_EN"              : hardware.pinR,
    "USB_LOAD_FLAG"       : hardware.pinW,

    "ADC_SPI"             : hardware.spi0,

    "SHIELD_RESET"        : hardware.pinJ,

    "LED_RGB_CLOCK"       : hardware.pinT,
    "LED_RGB_DATA"        : hardware.pinY,

    "IOL_UART"            : hardware.uart1,
    "IOL_2"               : hardware.pinH, 
    "IOL_3"               : hardware.pinE, 
    "IOL_4"               : hardware.pinL,
    "IOL_5"               : hardware.pinF,
    "IOL_6"               : hardware.pinG,
    "IOL_7"               : hardware.pinM,  

    "IOH_8"               : hardware.pinN,
    "IOH_9"               : hardware.pinP,
    "IOH_10"              : hardware.pinD, 
    "IOH_11"              : hardware.pinB, 
    "IOH_12"              : hardware.pinC, 
    "IOH_13"              : hardware.pinA, 
    "IOH_SPI"             : hardware.spiBCAD
}


// REFRIGERATOR MONITOR APPLICATION CODE
// ---------------------------------------------------
// Application code, take readings from our temperature
// humidity and light sensors. Use the light level to 
// determine if the door is open (true or false) and send
// the door status, temperature and humidity to the agent 

class SmartFridge {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC     = 5;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC   = 300; 
    // Time to wait after boot before turning off WiFi
    static BOOT_TIMER_SEC           = 60;

    // When tempertaure is above this threshold add an alert
    static TEMP_THRESHOLD           = 30;

    // The lx level at which we know the door is open
    static LX_THRESHOLD             = 3000;

    // Hardware variables
    i2c             = IMP005_EZ_EVAL.SENSOR_AND_IOH_I2C; 
    tempHumidAddr   = IMP005_EZ_EVAL.TEMP_HUMID_I2C_ADDR;

    // Sensor variables
    tempHumid = null;

    // Message Manager variable
    mm = null;

    // An array to store readings between connections
    readings = [];

    // Track current door status so we know when there is a
    // there is a change
    doorOpenStatus = false;

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
        // Take an async temp/humid reading
        tempHumid.read(function(result) {
            // Set up the reading table with a timestamp
            local reading = { "time" : time() };

            // Add temperature and humidity readings
            if ("temperature" in result) {
                reading.temperature <- result.temperature;
                // Add boolean temp alert to reading 
                reading.tempAlert <- (reading.temperature >= TEMP_THRESHOLD);
            }
            if ("humidity" in result) reading.humidity <- result.humidity;

            // Check door status using internal LX sensor to 
            // determine if the door is open
            reading.doorOpen <- (hardware.lightlevel() > LX_THRESHOLD);

            // Add table to the readings array for storage til next connection
            readings.push(reading);

            // Only send readings if we have some and are either already
            // connected to WiFi, there is a change in the door status or
            // if it is time to connect
            if (readings.len() > 0 && ((server.isconnected() || doorOpenStatus != reading.doorOpen || timeToConnect()))) {
                sendReadings();
            }

            // update current door status
            doorOpenStatus = reading.doorOpen;
            // Schedule the next reading
            imp.wakeup(READING_INTERVAL_SEC, run.bindenv(this));    
        }.bindenv(this));
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