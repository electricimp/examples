// Reading a Sensor Device Code
// ---------------------------------------------------

// SENSOR LIBRARY
// ---------------------------------------------------
// Libraries must be included before all other code

// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"


// SETUP
// ---------------------------------------------------
// The HTS221 library uses the sensor's i2c interface
// To initialize the library we need to configure the 
// i2c and pass in the 12c address for our hardware.

// The i2c address for the Explorer Kits and the 
// Battery Powered Sensor Node are all 0xBE.
const I2C_ADDR = 0xBE;

// Find the i2c for your hardware from the list below. 
// Paste the hardware.i2c for your hardware into the 
// i2c variable on line 32.

// impExplorer Dev Kit 001                     i2c = hardware.i2c89
// impExplorer Dev Kit 004m                    i2c = hardware.i2cNM
// impAccelerator Battery Powered Sensor Node  i2c = hardware.i2cAB

// Configure i2c 
// Paste your i2c hardware in the variable below 
local i2c = hardware.i2c89; 
i2c.configure(CLOCK_SPEED_400_KHZ);

// Initialize the temperature/humidity sensor
local tempHumid = HTS221(i2c, I2C_ADDR);

// Before we can take a reading we need to configure 
// the sensor. Note: These steps vary for different 
// sensors. This sensor we just need to set the mode.

// We are going to set up the sensor to take a single
// reading when we call the read method.
tempHumid.setMode(HTS221_MODE.ONE_SHOT);


// APPLICATION FUNCTION(S)
// ---------------------------------------------------
// The sensor is now configured to taking readings.
// Lets set up a loop to take readings and send the
// result to the agent.
function loop() {
    // Take a reading
    local result = tempHumid.read();

    // Check the result
    if ("error" in result) {
        // We had an issue taking the reading, lets log it
        server.error(result.error);
    } else {
        // Let's log the reading
        server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", result.humidity, "%", result.temperature));
        // Send the reading to the agent
        agent.send("reading", result);
    }

    // Schedule next reading in 10sec
    // Change the first parameter to imp.wakeup to 
    // adjust the loop time
    imp.wakeup(10, loop);
}

// RUNTIME
// ---------------------------------------------------
server.log("Device running...");

// Start the readings loop
loop();
