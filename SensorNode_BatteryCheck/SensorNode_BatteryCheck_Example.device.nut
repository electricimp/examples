// HARDWARE ABSTRACTION LAYER
// ---------------------------------------------------
// HAL's are tables that map human readable names to 
// the hardware objects used in the application. 

SensorNode_003 <- {
    "LED_BLUE"            : hardware.pinP,
    "LED_GREEN"           : hardware.pinU,
    "SENSOR_I2C"          : hardware.i2cAB,
    "TEMP_HUMID_I2C_ADDR" : 0xBE,
    "ACCEL_I2C_ADDR"      : 0x32,
    "PRESSURE_I2C_ADDR"   : 0xB8,
    "RJ12_PWR_EN_PIN"     : hardware.pinS,
    "ONEWIRE_BUS_UART"    : hardware.uartDM,
    "RJ12_I2C"            : hardware.i2cFG,
    "RJ12_UART"           : hardware.uartFG,
    "WAKE_PIN"            : hardware.pinW,
    "ACCEL_INT_PIN"       : hardware.pinT,
    "PRESSURE_INT_PIN"    : hardware.pinX,
    "TEMP_HUMID_INT_PIN"  : hardware.pinE,
    "THERMISTER_EN_PIN"   : hardware.pinK,
    "THERMISTER_PIN"      : hardware.pinJ,
    "FTDI_UART"           : hardware.uartQRPW, 
    "PWR_EN_3V3"          : hardware.pinY,
    "BATTERY"             : hardware.pinH
}


// BATTERY CLASS
// ---------------------------------------------------
// The battery class can be used to determine battery 
// voltage and also whether the battery voltage is too  
// low to connect to WiFi

class Battery {
    
    // Use this value to determine the voltage
    static MAX_PIN_VAL = 65535.0;
    // The when voltage drops below this threshold
    // it will have trouble connecting to WiFi, so 
    // logs will no longer appear
    static DEFAULT_THRESHOLD = 2.1;
    
    // Class variables
    _pin = null;
    _threshold = null;
    
    // Pass in an analog pin that is connected directly
    // to the battery, the pin will be configured by the 
    // constructor
    constructor(pin, threshold = null) {
        _pin = pin;
        _pin.configure(ANALOG_IN);
        _threshold = (threshold == null) ? DEFAULT_THRESHOLD : threshold;
    }
    
    // Returns battery voltage 
    function getVoltage() {
        return _pin.read() * hardware.voltage() / MAX_PIN_VAL
    }
    
    // Returns a boolean if battery voltage is getting
    // too low to drive WiFi reliably
    function isLow() {
        return (getVoltage() <= _threshold);
    }
}

// // RUNTIME
// // ---------------------------------------------------
server.log("Device running...");

bat <- Battery(SensorNode_003.BATTERY);
server.log( bat.getVoltage() );
server.log( bat.isLow() );
