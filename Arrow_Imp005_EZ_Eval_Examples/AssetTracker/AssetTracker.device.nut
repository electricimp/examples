// Asset Tracker Application Device Code
// ---------------------------------------------------

// SENSOR LIBRARIES
// ---------------------------------------------------
// Libraries must be required before all other code

// Accelerometer Library
#require "LIS3DH.class.nut:1.3.0"


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

class AssetTracker {

    // Movement detection accel settings
    static ACCEL_DATARATE      = 100;
    static ACCEL_INT_THRESHOLD = 0.030;
    static ACCEL_INT_DURATION  = 100;

    // Hardware variables
    i2c        = IMP005_EZ_EVAL.SENSOR_AND_IOH_I2C;
    accelAddr  = IMP005_EZ_EVAL.ACCEL_I2C_ADDR;
    intPin     = IMP005_EZ_EVAL.IOH_12;

    // Sensor variables
    accel = null;

    constructor() {
        // Initialize accelerometer
        i2c.configure(CLOCK_SPEED_400_KHZ);
        accel = LIS3DH(i2c, accelAddr);

        // Configure accelerometer
        accel.init();
        accel.setLowPower(true);
        // Set data (sampling) rate
        accel.setDataRate(ACCEL_DATARATE);
        // Ignore gravity bias
        accel.configureHighPassFilter(LIS3DH.HPF_AOI_INT1, null, LIS3DH.HPF_DEFAULT_MODE);

        // Configure accelerometer interrupt
        configureInterrupt();

        // On boot send a scan to the agent, so we 
        // can determine the devices starting location
        agent.send("wifi.networks", imp.scanwifinetworks());
    }

    function configureInterrupt() {
        // Int flag cleared when interrupt table read
        accel.configureInterruptLatching(true); 
        // When any axis exceeds Xg for at least Y samples, trigger interrupt
        accel.configureInertialInterrupt(true, ACCEL_INT_THRESHOLD, ACCEL_INT_DURATION); 
        // Configure interrupt pin with a state change callback
        intPin.configure(DIGITAL_IN_PULLDOWN, interruptHandler.bindenv(this));
    }

    function interruptHandler() {
        // This callback is called on every pin state change

        // Check for motion
        if (intPin.read()) {
            // Clear the interrupt
            local int = accel.getInterruptTable();
            server.log("motion detected");
            // Send agent Wifi scan results, so we can 
            // Get the location of the device
            agent.send("wifi.networks", imp.scanwifinetworks());
        }

    }
}

// RUNTIME
// ---------------------------------------------------
server.log("Device running...");

// Run the Application
AssetTracker();
