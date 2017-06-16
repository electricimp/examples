//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

const LONG_SLEEP = 400;
const SHORT_SLEEP = 60;
const TEMP_MARGIN = 1;

// Class to read the Si7021 temperature/humidity sensor
// See http://www.silabs.com/Support%20Documents/TechnicalDocs/Si7021.pdf
// These sensors us i2c wire protocol where the imp is the master
// To use:
//  - tie scl and sdas line to pull-up resistors (4.7K)
//  - tie vdd to a decoupling capacitor (0.1uF)
class SI7021 {
    static READ_RH      = "\xF5"; 
    static READ_TEMP    = "\xF3";
    static PREV_TEMP    = "\xE0";
    static RH_MULT      = 125.0/65536.0;
    static RH_ADD       = -6;
    static TEMP_MULT    = 175.72/65536.0;
    static TEMP_ADD     = -46.85;
    
    _i2c  = null;
    _addr  = null;
    
    // class constructor
    // Input: 
    //      _i2c:     hardware i2c bus, must pre-configured
    //      _addr:     slave address (optional)
    // Return: (None)
    constructor(i2c, addr = 0x80) 
    {
        _i2c  = i2c;
        _addr = addr;
    }
    
    // read the humidity
    // Input: (none)
    // Return: relative humidity (float)
    function readRH() { 
        _i2c.write(_addr, READ_RH);
        local reading = _i2c.read(_addr, "", 2);
        while (reading == null) {
            reading = _i2c.read(_addr, "", 2);
        }
        local humidity = RH_MULT*((reading[0] << 8) + reading[1]) + RH_ADD;
        return humidity;
    }
    
    // read the temperature
    // Input: (none)
    // Return: temperature in celsius (float)
    function readTemp() { 
        _i2c.write(_addr, READ_TEMP);
        local reading = _i2c.read(_addr, "", 2);
        while (reading == null) {
            reading = _i2c.read(_addr, "", 2);
        }
        local temperature = TEMP_MULT*((reading[0] << 8) + reading[1]) + TEMP_ADD;
        return temperature;
    }
    
    // read the temperature from previous rh measurement
    // this method does not have to recalculate temperature so it is faster
    // Input: (none)
    // Return: temperature in celsius (float)
    function readPrevTemp() {
        _i2c.write(_addr, PREV_TEMP);
        local reading = _i2c.read(_addr, "", 2);
        local temperature = TEMP_MULT*((reading[0] << 8) + reading[1]) + TEMP_ADD;
        return temperature;
    }
}

// Makes readings and decides wether to connect to the internet
// and update the agent before going back to sleep
function makeReadings (val=null) {
    local humidity = sensor.readRH();
    local temperature  = sensor.readPrevTemp();
    local battery =(bat.read()/65535.0) * hardware.voltage() / 0.03;
    if ("nv" in getroottable() && "temp" in nv) {
        local dif = nv.temp - temperature;
        if (dif < TEMP_MARGIN && dif > -TEMP_MARGIN) {
            imp.onidle(function() {imp.deepsleepfor(SHORT_SLEEP)});
            return;
        } 
    }
    nv <- {temp = temperature};
    agent.send("data",  {temp = temperature, rh = humidity, bat = battery});
    imp.onidle(function() {imp.deepsleepfor(LONG_SLEEP)});
}

bat <- hardware.pinB;
bat.configure(ANALOG_IN);
 
// Configure i2c bus
hardware.i2c12.configure(CLOCK_SPEED_100_KHZ);
// Create SI7021 object
sensor <- SI7021(hardware.i2c12);

// Check Master Status
if ("nv" in getroottable()) {
    makeReadings();
} else {
    agent.send("master", null);
}
agent.on("master", makeReadings);