// Cellular Breakout Example - Reading a Sensor Device Code
// --------------------------------------------------------

// SENSOR LIBRARY
// --------------------------------------------------------
// Libraries must be included before all other code, only
// comments are ok to precede library require statements.

// Accelerometer Library
#require "LIS3DH.device.lib.nut:2.0.1"


// SETUP
// --------------------------------------------------------
// The LIS3DH library uses the sensor's i2c interface
// To initialize the library we need to configure the
// i2c and pass in the accelerometer's i2c address.

// The i2c address for the accelerometer is 0x32.
const ACCEL_I2C_ADDR = 0x32;

// Configure i2c
local i2c = hardware.i2cXCD;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Initialize the accelerometer.
local accel = LIS3DH(i2c, ACCEL_I2C_ADDR);

// Before we can take a reading we need to configure
// the sensor. Note: These steps vary for different
// sensors.

// We are going to set up the sensor to take continuous
// readings at the Rate of 10 per second.
accel.setDataRate(10);

// Enable the x, y, and z axes on the accelerometer.
accel.enable(true);


// APPLICATION FUNCTION(S)
// --------------------------------------------------------
// The sensor is now configured to taking readings.
// Lets set up a loop to take readings and send the
// result to the agent.
function loop() {
    // Grab the latest reading
    local result = accel.getAccel();

    // Check the result
    if ("error" in result) {
        // We had an issue taking the reading, lets log it
        server.error(result.error);
    } else {
        // Log the reading
        server.log(format("Accelerometer x: %0.4f g, y: %0.4f g, z: %0.4f g.", result.x, result.y, result.z));
        // Send the reading to the agent
        agent.send("reading", result);
    }

    // Schedule next reading sample in 1sec
    // Change the first parameter to imp.wakeup to
    // adjust the loop time
    imp.wakeup(1, loop);
}

// RUNTIME
// --------------------------------------------------------
server.log("Device running...");

// Start the readings loop
loop();