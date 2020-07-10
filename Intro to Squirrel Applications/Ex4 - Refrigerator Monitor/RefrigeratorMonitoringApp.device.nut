// Refrigerator Monitor Application Device Code
// ---------------------------------------------------

// SENSOR LIBRARIES
// ---------------------------------------------------
// Libraries must be required before all other code

// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.2"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.4.0"

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
    static READING_INTERVAL_SEC     = 5;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC   = 300;
    // Time to wait after boot before first disconection
    // This allows time for blinkup recovery on cold boots
    static BOOT_TIMER_SEC           = 60;

    // The lx level at which we know the door is open
    static LX_THRESHOLD             = 3000;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr

    // Sensor variables
    tempHumid       = null;

    // Message Manager variable
    mm = null;

    // An array to store readings between connections
    readings = [];

    // Track current door status so we know when there is a
    // there is a change
    currentDoorOpenStatus = false;

    // Varaible to track when to connect
    nextConnectTime = null;

    // Flag to track first disconnection
    _boot = true;

    constructor() {
        // Power save mode will reduce power consumption when the radio
        // is idle, a good first step for saving power for battery
        // powered devices.
        // NOTE: Power save mode will add latency when sending data.
        // Power save mode is not supported on impC001 and is not
        // recommended for imp004m, so don't set for those types of imps.
        local type = imp.info().type;
        if (type != "imp004m" && type != "impC001") {
            imp.setpowersave(true);
        }

        // Use the current time and the REPORTING_INTERVAL_SEC
        // to set a timestamp, so we know when we should connect
        // and send the stored readings
        setNextConnectTime();

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message
        // has been delivered. We will use this to know when it is ok
        // to delete locally stored readings and disconnect
        mm.onAck(readingsAckHandler.bindenv(this));

        initializeSensors();

        // We want to make sure we can always blinkUp a device
        // when it is first powered on, so we do not want to
        // immediately disconnect after boot
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
            if ("temperature" in result) reading.temperature <- result.temperature;
            if ("humidity" in result) reading.humidity <- result.humidity;

            // Check door status using internal LX sensor to
            // determine if the door is open
            reading.doorOpen <- (hardware.lightlevel() > LX_THRESHOLD);

            // Add table to the readings array for storage til next connection
            readings.push(reading);

            // Only send readings if we have some and are either already
            // connected, there is a change in the door status or if it
            // is time to connect
            if (readings.len() > 0 && (server.isconnected() || currentDoorOpenStatus != reading.doorOpen || timeToConnect())) {
                sendReadings();
            }

            // update current door status
            currentDoorOpenStatus = reading.doorOpen;
            // Schedule the next reading
            imp.wakeup(READING_INTERVAL_SEC, run.bindenv(this));
        }.bindenv(this));
    }

    function sendReadings() {
        // Connect device
        server.connect();
        // Send readings to the agent
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
