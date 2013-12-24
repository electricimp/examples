/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--------------------------------------------------------------------------------
This code represents all the basic functionality of the Hannah rev2 and rev3 reference designs.
The schematics can be found at http://electricimp.com/docs/hardware/resources/reference-designs/hannah/
Not every function of every device has been coded for but extension of these classes should be easy.
The Hannah class and the application logic are there to tie the individual classes together. They
are not designed to be used as-is in a production environment.

There are two specific areas of further exploration that may be completed at a later date:
- Low power mode and shallow sleep processing (using pin1 for wakeup)
- PWM output functionality in the GPIO class via the IO Expander
--------------------------------------------------------------------------------


------ [ Imp pins ] ------
Pin 1    Digital input      Interrupt from GPIO expander
Pin 2    Analog input       Potentiometer wiper
Pin 5    Digital output     Servo port 1 PWM signal
Pin 7    Digital output     Servo port 2 PWM signal
Pin 8    I2C SCL         
Pin 9    I2C SDA


------ [ I2C Addresses - rev 2 ] ------
0x38/0x1C   LIS331DLTR          3-Axis accelerometer
0xE8/0x74   ADJD-S311-CR999     RGB light sensor
0x98/0x4C   SA56004ED           Temperature sensor
0x7C/0x3E   SX1509BULTRT        IO Expander


------ [ I2C Addresses - rev 3 ] ------
0x30/0x18   LIS3DH              3-Axis accelerometer
0xE8/0x74   ADJD-S311-CR999     RGB light sensor
0x92/0x49   TMP112              Temperature sensor
0x7C/0x3E   SX1509BULTRT        IO Expander


------ [ IO Expander pins ] ------
IO0     Input    Button 1
IO1     Input    Button 2
IO2     Input    Hall switch
IO3     Input    Accelerometer interrupt
IO4     Input    Temperature sensor alert interrupt
IO5     Output   LED Green
IO6     Output   LED Blue
IO7     Output   LED Red
IO8     Output   Potentiometer enable
IO9     Output   RGB light sensor sleep
IO10    Output   Servo ports 1 and 2 power enable
IO11    GPIO     Spare
IO12    GPIO     Spare
IO13    GPIO     Spare
IO14    GPIO     Spare
IO15    GPIO     Spare

*/

const NO_DEVICE_ERR = "The device at I2C address 0x%02x is disabled.";
const I2C_READ_ERR = "I2C Read Failure. Device: 0x%02x Register: 0x%02x";
const BAD_TIMER_ERR = "You have to start %s with an interval and callback";
const WRONG_DEVICE_ERR = "The device at I2C address 0x%02x is not a %s.";

//------------------------------------------------------------------------------
// This class interfaces with the SX1509 IO expander. It sits on the I2C bus and 
// data can be directed to the connected devices via its I2C address. Interrupts
// from the devices can be fed back to the imp via the configured imp hardware pin.
// 
class SX1509 {

    //Private variables
    _i2c       = null;
    _addr      = null;
    _callbacks = null;
    _int_pin   = null;
    
    // I/O Expander internal registers
    static BANK_A = {   REGDATA    = 0x11,
                        REGDIR     = 0x0F,
                        REGPULLUP  = 0x07,
                        REGPULLDN  = 0x09,
                        REGINTMASK = 0x13,
                        REGSNSHI   = 0x16,
                        REGSNSLO   = 0x17,
                        REGINTSRC  = 0x19,
                        REGINPDIS  = 0x01,
                        REGOPENDRN = 0x0B,
                        REGLEDDRV  = 0x21,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D}

    static BANK_B = {   REGDATA    = 0x10,
                        REGDIR     = 0x0E,
                        REGPULLUP  = 0x06,
                        REGPULLDN  = 0x08,
                        REGINTMASK = 0x12,
                        REGSNSHI   = 0x14,
                        REGSNSLO   = 0x15,
                        REGINTSRC  = 0x18,
                        REGINPDIS  = 0x00,
                        REGOPENDRN = 0x0A,
                        REGLEDDRV  = 0x20,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D}

    constructor(i2c, address, int_pin){
        _i2c  = i2c;
        _addr = address;
        _callbacks = [];
        _callbacks.resize(16, null);
        _int_pin = int_pin;

        reset();
        clearAllIrqs();
    }
    

    // ---- Low level functions ----

    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format(I2C_READ_ERR, _addr, register));
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register, data) {
        _i2c.write(_addr, format("%c%c", register, data));
        // server.log(format("Setting device 0x%02X register 0x%02X to 0x%02X", _addr, register, data));
    }
    
    function writeBit(register, bitn, level) {
        local value = readReg(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        writeReg(register, value);
    }
    
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }

    // set or clear a selected GPIO pin, 0-16
    function setPin(gpio, level) {
        writeBit(bank(gpio).REGDATA, gpio % 8, level ? 1 : 0);
    }

    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        writeBit(bank(gpio).REGDIR, gpio % 8, output ? 0 : 1);
    }

    // enable or disable input buffers
    function setInputBuffer(gpio, enable) {
        writeBit(bank(gpio).REGINPDIS, gpio % 8, enable ? 0 : 1);
    }

    // enable or disable open drain
    function setOpenDrain(gpio, enable) {
        writeBit(bank(gpio).REGOPENDRN, gpio % 8, enable ? 1 : 0);
    }
    
    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        writeBit(bank(gpio).REGPULLUP, gpio % 8, enable ? 1 : 0);
    }
    
    // enable or disable internal pull down resistor for specified GPIO
    function setPullDn(gpio, enable) {
        writeBit(bank(gpio).REGPULLDN, gpio % 8, enable ? 1 : 0);
    }

    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, enable ? 0 : 1);
    }

    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, 1);
    }

    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(bank(gpio).REGDATA) & (1<<(gpio%8))) ? 1 : 0);
    }

    // resets the device with a software reset
    function reboot() {
        writeReg(bank(0).REGRESET, 0x12);
        writeReg(bank(0).REGRESET, 0x34);
    }

    // configure which callback should be called for each pin transition
    function setCallback(gpio, _callback) {
        _callbacks.insert(gpio, _callback);
        
        // Initialize the interrupt Pin
        hardware.pin1.configure(DIGITAL_IN_PULLUP, fire_callback.bindenv(this));
    }

    // finds and executes the callback after the irq pin (pin 1) fires
    function fire_callback() {
        local irq = getIrq();
        clearAllIrqs();
        for (local i = 0; i < 16; i++){
            if ( (irq & (1 << i)) && (typeof _callbacks[i] == "function")){
                _callbacks[i](getPin(i)); 
            }
        }
    }

    
    // ---- High level functions ----


    // Write registers to default values
    function reset(){
        writeReg(BANK_A.REGDIR, 0xFF);
        writeReg(BANK_A.REGDATA, 0xFF);
        writeReg(BANK_A.REGPULLUP, 0x00);
        writeReg(BANK_A.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_A.REGSNSHI, 0x00);
        writeReg(BANK_A.REGSNSLO, 0x00);
        
        writeReg(BANK_B.REGDIR, 0xFF);
        writeReg(BANK_B.REGDATA, 0xFF);
        writeReg(BANK_B.REGPULLUP, 0x00);
        writeReg(BANK_B.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_B.REGSNSHI, 0x00);
        writeReg(BANK_B.REGSNSLO, 0x00);
    }

    // Returns the register numbers for the bank that the given gpio is on
    function bank(gpio){
        return (gpio > 7) ? BANK_B : BANK_A;
    }

    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local bank = bank(gpio);
        gpio = gpio % 8;
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? bank.REGSNSHI : bank.REGSNSLO, data, mask);
    }

    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC,0xff);
        writeReg(BANK_B.REGINTSRC,0xff);
    }

    function getIrq(){
        return ((readReg(BANK_B.REGINTSRC) & 0xFF) << 8) | (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
    
    // sets the clock 
    function setClock(gpio, enable) {
        writeReg(bank(gpio).REGCLOCK, enable ? 0x50 : 0x00); // 2mhz internal oscillator 
    }
    
    // enable or disable the LED drivers
    function setLEDDriver(gpio, enable) {
        writeBit(bank(gpio).REGLEDDRV, gpio & 7, enable ? 1 : 0);
        writeReg(bank(gpio).REGMISC, 0x70); // Set clock to 2mhz / (2 ^ (1-1)) = 2mhz, use linear fading
    }
    
    // sets the Time On value for the LED register
    function setTimeOn(gpio, value) {
        writeReg(gpio<4 ? 0x29+gpio*3 : 0x35+(gpio-4)*5, value)
    }
    
    // sets the On Intensity level LED register
    function setIntensityOn(gpio, value) {
        writeReg(gpio<4 ? 0x2A+gpio*3 : 0x36+(gpio-4)*5, value)
    }
    
    // sets the Time Off value for the LED register
    function setOff(gpio, value) {
        writeReg(gpio<4 ? 0x2B+gpio*3 : 0x37+(gpio-4)*5, value)
    }
    
    // sets the Rise Time value for the LED register
    function setRiseTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x38+(gpio-4)*5 : 0x58+(gpio-12)*5, value)
    }
    
    // sets the Fall Time value for the LED register
    function setFallTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x39+(gpio-4)*5 : 0x59+(gpio-12)*5, value)
    }
    
}

//------------------------------------------------------------------------------
// This is a convenience class that simplifies the configuration of a IO Expander GPIO port.
// You can use it in a similar manner to hardware.pin with two main differences:
// 1. There is a new pin type: LED_OUT, for controlling LED brightness (basically PWM_OUT with "breathing")
// 2. The pin events will include the pin state as the one parameter to the callback
//
class ExpGPIO {
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    _mode     = null;  //The mode configured for this pin
    
    // This definition augments the pin configuration constants as defined in:
    // http://electricimp.com/docs/api/hardware/pin/configure/
    static LED_OUT = 1000001;
    
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    
    //Optional initial state (defaults to 0 just like the imp)
    function configure(mode, param1 = null, param2 = null) {
        _mode = mode;
        
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            // Param1 is the initial value of the pin, Param2 is unused.
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if(param1 != null) {
                _expander.setPin(_gpio, param1);    
            } else {
                _expander.setPin(_gpio, 0);
            }
            
            return this;
        } else if (mode == ExpGPIO.LED_OUT) {
            // Param1 is the initial intensity, Param2 is unused.
            _expander.setPullUp(_gpio, 0);
            _expander.setInputBuffer(_gpio, 0);
            _expander.setOpenDrain(_gpio, 1);
            _expander.setDir(_gpio, 1);
            _expander.setClock(_gpio, 1);
            _expander.setLEDDriver(_gpio, 1);
            _expander.setTimeOn(_gpio, 0);
            _expander.setOff(_gpio, 0);
            _expander.setRiseTime(_gpio, 0);
            _expander.setFallTime(_gpio, 0);
            _expander.setIntensityOn(_gpio, param1 > 0 ? param1 : 0);
            _expander.setPin(_gpio, param1 > 0 ? 0 : 1);
            
            return this;
        } else if (mode == DIGITAL_IN) {
            // Param1 is the callback function
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN_PULLUP) {
            // Param1 is the callback function
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (typeof param1 == "function") {
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio, param1);
        } else {
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }
        
        return this;
    }
    
    function read() { 
        return _expander.getPin(_gpio); 
    }
    
    function write(state) { 
        _expander.setPin(_gpio,state); 
    }
    
    function setIntensity(intensity) { 
        _expander.setIntensityOn(_gpio,intensity); 
    }
    
    function blink(ton, toff, ion, ioff, fade=true) { 
        ton = (ton > 0x1F ? 0x1F : ton);
        toff = (toff > 0x1F ? 0x1F : toff);
        ion = ion & 0xFF;
        ioff = (ioff > 0x07 ? 0x07 : ioff);
        _expander.setTimeOn(_gpio, ton);
        _expander.setOff(_gpio, toff << 3 | ioff);
        _expander.setRiseTime(_gpio, fade?5:0);
        _expander.setFallTime(_gpio, fade?5:0);
        _expander.setIntensityOn(_gpio, ion);
        _expander.setPin(_gpio, ion>0 ? 0 : 1)
    }
    
    function fade(on) {
        _expander.setRiseTime(_gpio, on?5:0);
        _expander.setFallTime(_gpio, on?5:0);
    }
}

//------------------------------------------------------------------------------
// This class combined three LED pins into a single RGB LED class. It attempts to synchronise
// the changes to the LEDs so the colour change appears uniform. This works for static colours 
// and for blinking but not for breathing (blinking with fading). The clocks for the different
// LED pins go out of sync in the hardware when fading in and out. 
//
class RGBLED {
    
    _expander = null;
    ledR = null;
    ledG = null;
    ledB = null;
    
    constructor(expander, gpioRed, gpioGreen, gpioBlue) {
        _expander = expander;
        ledR = ExpGPIO(_expander, gpioRed).configure(ExpGPIO.LED_OUT);
        ledG = ExpGPIO(_expander, gpioGreen).configure(ExpGPIO.LED_OUT);
        ledB = ExpGPIO(_expander, gpioBlue).configure(ExpGPIO.LED_OUT);
    }
    
    function set(r, g, b, fade=false) {
        // Turn the LEDs on but blinking off
        ledR.blink(0, 0, r.tointeger(), 0, fade);
        ledG.blink(0, 0, g.tointeger(), 0, fade);
        ledB.blink(0, 0, b.tointeger(), 0, fade);
    }
    
    function blink(r, g, b, fade=true, timeon=1, timeoff=1) {
        // Turn them off and let them sync on their way on
        ledR.write(1); ledG.write(1); ledB.write(1); 
        ledR.blink(timeon.tointeger(), timeoff.tointeger(), r.tointeger(), 0, fade);
        ledG.blink(timeon.tointeger(), timeoff.tointeger(), g.tointeger(), 0, fade);
        ledB.blink(timeon.tointeger(), timeoff.tointeger(), b.tointeger(), 0, fade);
    }
    
}

//------------------------------------------------------------------------------
// This class controls the ADJD-S311-CR999 RGB light sensor. You can configure all capacitors and 
// integration slots to one number or you can pass in an array for each into the initialise() method. 
// From there you can either read values or poll the sensor. If you want to know the general brightness
// look at the forth sensor reading (clear).
//
enum CAP_COLOUR { RED, GREEN, BLUE, CLEAR };
class RGBSensor {

    _i2c  = null;
    _addr = null;
    _expander = null;
    _sleep = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    
    // Capacitors - Lower number = more sensitivity
    static MIN_CAP_COUNT = 0x0; // Min capacitor count
    static MAX_CAP_COUNT = 0xF; // Max capacitor count
    static CAP_ADDRESSES = [0x06, 0x07, 0x08, 0x09];
    
    // Integration slots - Higher number = more sensitivity
    static MIN_INTEGRATION_SLOTS = 0x000;   // Min integration slots
    static MAX_INTEGRATION_SLOTS = 0xfff;   // Max integration slots
    static INT_ADDRESSES = [0x0a, 0x0c, 0x0e, 0x10];
    
    // RGB reading
    static CTRL_ADDRESS       = 0x00
    static GET_COLOUR_READING = 0x01;
    static COL_LOW_ADDRESSES  = [0x40, 0x42, 0x44, 0x46];
    static COL_HI_ADDRESSES   = [0x41, 0x43, 0x45, 0x47];
         
        
    constructor(i2c, address, expander, gpioSleep) {
        _i2c  = i2c;
        _addr = address;  
        _expander = expander;
        _sleep = ExpGPIO(_expander, gpioSleep).configure(DIGITAL_OUT, 0);
        initialise();
    }
    
    function wake() { 
        _sleep.write(0); 
    }    
    
    function sleep() { 
        _sleep.write(1); 
    }
    
    function initialise(caps = 0x0F, timeslots = 0xFF) {
        wake();
        
        local result1 = _i2c.write(_addr, format("%c%c", CTRL_ADDRESS, 0));
        imp.sleep(0.01);
        local result2 = setRGBCapacitorCounts(caps);
        local result3 = setRGBIntegrationTimeSlots(timeslots);
        
        sleep();
        
        return (result1 == 0) && result2 && result3;
    }
    
    function setRGBCapacitorCounts(count)
    {
        for (local capIndex = CAP_COLOUR.RED; capIndex <= CAP_COLOUR.CLEAR; ++capIndex) {
            local thecount = (typeof count == "array") ? count[capIndex] : count;
            if (!setCapacitorCount(CAP_ADDRESSES[capIndex], thecount)) {
                return false;
            }
        }        
        return true;
    }
    
    function setCapacitorCount(address, count) {
        if (count < MIN_CAP_COUNT) {
            count = MIN_CAP_COUNT;
        } else if (count > MAX_CAP_COUNT) {
            count = MAX_CAP_COUNT;
        }
        
        return _i2c.write(_addr, format("%c%c", address, count)) == 0;
    }
    
    function setRGBIntegrationTimeSlots(value) {
        for (local intIndex = CAP_COLOUR.RED; intIndex <= CAP_COLOUR.CLEAR; ++intIndex) {
            local thevalue = (typeof value == "array") ? value[intIndex] : value;
            if (!setIntegrationTimeSlot(INT_ADDRESSES[intIndex], thevalue & 0xff)) {
                return false;
            }
            if (!setIntegrationTimeSlot(INT_ADDRESSES[intIndex] + 1, thevalue >> 8)) {
                return false;
            }
        }        
        return true;
    }

    function setIntegrationTimeSlot(address, value) {
        
        if (value < MIN_INTEGRATION_SLOTS) {
            value = MIN_INTEGRATION_SLOTS;
        } else if (value > MAX_INTEGRATION_SLOTS) {
            value = MAX_INTEGRATION_SLOTS;
        }
        
        return _i2c.write(_addr, format("%c%c", address, value)) == 0;
    }
    
    function read() { 
        
        local rgbc = [0, 0, 0 ,0];
        wake();
        if (_i2c.write(_addr, format("%c%c", CTRL_ADDRESS, GET_COLOUR_READING)) == 0) {
            // Wait for reading to complete
            local count = 0;
            while (_i2c.read(_addr, format("%c", CTRL_ADDRESS), 1)[0] != 0) {
                count++;
            }
            for (local colIndex = CAP_COLOUR.RED; colIndex <= CAP_COLOUR.CLEAR; ++colIndex) {
                rgbc[colIndex] = _i2c.read(_addr,  format("%c", COL_LOW_ADDRESSES[colIndex]), 1)[0];
            }
            
            for (local colIndex = CAP_COLOUR.RED; colIndex <= CAP_COLOUR.CLEAR; ++colIndex) {
                rgbc[colIndex] += _i2c.read(_addr,  format("%c", COL_HI_ADDRESSES[colIndex]), 1)[0] << 8;
            }
        } else {
            server.error("RGBSensor:GET_COLOUR_READING reading failed.")
        }
        sleep();
        return { r = rgbc[0], g = rgbc[1], b = rgbc[2], c = rgbc[3] };
        
    }
    
    function poll(interval = null, callback = null) {
        if (interval != null && callback != null) {
            _poll_callback = callback;
            _poll_interval = interval;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (_poll_interval == null || _poll_callback == null) {
            server.error(format(BAD_TIMER_ERR, RGBSensor::poll()))
        }
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this));
        
        _poll_callback(read())
    }

    function stop() {
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
    }

}

//------------------------------------------------------------------------------
// This class controls the SA56004ED temperature sensor in the Hannah rev2 design. If it is not
// detected, it will throw an error and you can fire up the alternate TempSensor_rev3 class instead.
// The methods are the same although the SA56004ED emulates the temperature alerts in firmware (by 
// polling) that the TMP112 can do in hardware. The temperature readings are not very accurate so
// some calibration in the application layer might be required.
//
class TempSensor_rev2 {

    _i2c  = null;
    _addr = null;
    _expander = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    _alert_lo = null;
    _alert_hi = null;
    _running = false;
    _disabled = false;
    _last_temp = null;
    _last_alert = null;
    
    static REG_LTHB = "\x00"; // Local temp high 
    static REG_LTLB = "\x22";
    static REG_SR   = "\x02";
    static REG_CONR = "\x03";
    static REG_CONW = "\x09";
    static REG_CRR  = "\x04";
    static REG_CRW  = "\x0A";
    static REG_LHSR = "\x05";
    static REG_LHSW = "\x0B";
    static REG_LLSR = "\x06";
    static REG_LLSW = "\x0C";
    static REG_SHOT = "\x0F";
    static REG_LCS  = "\x20";
    static REG_AM   = "\xBF";
    static REG_RMID = "\xFE";
    static REG_RDR  = "\xFF";
    
    
    constructor(i2c, address, expander, gpioAlert) {
        _i2c  = i2c;
        _addr = address;  
        _expander = expander;
        
        local id = _i2c.read(_addr, REG_RMID, 1);
        if (!id || id[0] != 0xA1) {
            server.error(format(WRONG_DEVICE_ERR, _addr, "SA5004X temperature sensor"))
            _disabled = true;
        } else {
            // Clear the config and the status register
            _i2c.write(_addr, REG_CONW + "\xD5"); 
        }
    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error(format(BAD_TIMER_ERR, "TempSensor_rev2::poll()"))
            return false;
        }
        
        local temp = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        if (temp != _last_temp) {
            if (_alert_lo == null || _alert_hi == null || ((temp <= _alert_lo && _last_alert != -1) || (temp >= _alert_hi && _last_alert != 1))) {
                _poll_callback(temp);
                _last_alert = (_alert_lo == null) ? null : ((temp <= _alert_lo) ? -1 : 1);
            }
            _last_temp = temp;
        }
    }
    
    function alert(lo, hi, callback = null) {
        // Alert is an alias for poll
        _alert_lo = lo;
        _alert_hi = hi;
        _last_alert = null;
        if (!callback) callback = _poll_callback;
        poll(1, callback);
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _alert_lo = null;
        _alert_hi = null;
        
        // Power the sensor down
        _i2c.write(_addr, REG_CONW + "\xD5"); 
        _running = false;
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        if (!_running) {
            // Configure a single shot reading
            _i2c.write(_addr, REG_CONW + "\xD5"); 
            
            // Set conversion rate to 1hz
            _i2c.write(_addr, REG_CRW + "\x04"); 
        
            // Ask the sensor to perform a one-shot reading
            _i2c.write(_addr, REG_SHOT + "\x00"); 
        }
        
        // Wait for the sensor to finish the reading
        while ((_i2c.read(_addr, REG_SR, 1)[0] & 0x80) == 0x80);
                    
        // Get 11-bit signed temperature value in 0.125C steps
        local hi = _i2c.read(_addr, REG_LTHB, 1)[0];
        local lo = _i2c.read(_addr, REG_LTLB, 1)[0];
        local temp = (hi << 8) | (lo & 0xFF);
        return int2deg(temp, 0.125, 11);

    }
    
    function check_alerts() {
        local status = _i2c.read(_addr, REG_SR, 1)[0] & 0x60;
        if (status == 0x20) return -1;
        else if (status == 0x40) return 1;
        else return 0;
    }
}

//------------------------------------------------------------------------------
// This class controls the TMP112 temperature sensor in the Hannah rev3 design. If it is not
// detected, it will throw an error and you can fire up the alternate TempSensor_rev2 class instead.
//
class TempSensor_rev3 {

    _i2c  = null;
    _addr = null;
    _expander = null;
    _alert = null;
    _alert_callback = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    _last_temp = null;
    _running = false;
    _disabled = false;
    
    static TEMP_REG      = "\x00";
    static CONF_REG      = "\x01";
    static T_LOW_REG     = "\x02";
    static T_HIGH_REG    = "\x03";
    static RESET_VAL     = "\x06"; // Send this value on general-call address (0x00) to reset device
    
    
    constructor(i2c, address, expander, gpioAlert) {
        _i2c  = i2c;
        _addr = address;  
        _expander = expander;
        
        local id = _i2c.read(_addr, TEMP_REG, 1);
        if (id == null) {
            server.error(format(WRONG_DEVICE_ERR, _addr, "TMP112 temperature sensor"))
            _disabled = true;
        } else {
            // Turn the temperature reading off for now
            _alert = ExpGPIO(_expander, gpioAlert).configure(DIGITAL_IN_PULLUP, alert_callback.bindenv(this));
            
            // Shutdown the sensor for now
            local conf = _i2c.read(_addr, CONF_REG, 2);
            _i2c.write(_addr, CONF_REG + format("%c%c", conf[0] | 0x01, conf[1]));
        }
    }
    
    function alert_callback(state) {
        if (_alert_callback && state == 0) _alert_callback(get());
    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error(format(BAD_TIMER_ERR, "TempSensor_rev2::poll()"))
            return false;
        }
        
        local temp = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        if (temp != _last_temp) {
            _poll_callback(temp);
            _last_temp = temp;
        }
        
    }
    
    function alert(lo, hi, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        callback = callback ? callback : _poll_callback;
        stop();
        _alert_callback = callback;
    
        local tlo = deg2int(lo, 0.0625, 12);
        local thi = deg2int(hi, 0.0625, 12);
        _i2c.write(_addr, T_LOW_REG + format("%c%c", (tlo >> 8) & 0xFF, (tlo & 0xFF)));
        _i2c.write(_addr, T_HIGH_REG + format("%c%c", (thi >> 8) & 0xFF, (thi & 0xFF)));
        _i2c.write(_addr, CONF_REG + "\x62\x80"); // Run continuously

        // Keep track of the fact that we are running continuously
        _running = true;       
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _alert_callback = null;
        _running = false;
        
        // Power the sensor down
        local conf = _i2c.read(_addr, CONF_REG, 2);
        _i2c.write(_addr, CONF_REG + format("%c%c", conf[0] | 0x01, conf[1]));
        
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        if (!_running) {
            local conf = _i2c.read(_addr, CONF_REG, 2);
            _i2c.write(_addr, CONF_REG + format("%c%c", conf[0] | 0x80, conf[1]));
        
            // Wait for conversion to be finished
            while ((_i2c.read(_addr, CONF_REG, 1)[0] & 0x80) == 0x80);
        }
        
        // Get 12-bit signed temperature value in 0.0625C steps
        local result = _i2c.read(_addr, TEMP_REG, 2);
        local temp = (result[0] << 8) + result[1];
        return int2deg(temp, 0.0625, 12);
    }
    
}

//------------------------------------------------------------------------------
// THis class reads and normalises data from the potentiometer (dial) on the Hannah. By default
// it will return data in the range of 0.0 to 1.0 but it can be reconfigured to any range as 
// floats or integers. It will only report events when the value changes.
// 
class Potentiometer {
    
    _expander = null;
    _gpioEnable = null;
    _pinRead = null;
    _poll_callback = null;
    _poll_interval = 0.2;
    _poll_timer = null;
    _last_pot_value = null;
    _min = 0.0;
    _max = 1.0;
    _integer_only = false;

    constructor(expander, gpioEnable, pinRead) {
        _expander = expander;
        _pinRead = pinRead;
        _pinRead.configure(ANALOG_IN);
        _gpioEnable = ExpGPIO(_expander, gpioEnable).configure(DIGITAL_OUT);
    }
    
    function poll(interval = null, callback = null) {
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error(format(BAD_TIMER_ERR, "TempSensor_rev2::poll()"))
            return false;
        }
        
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        local new_pot_value = get();
        if (_last_pot_value != new_pot_value) {
            _last_pot_value = new_pot_value;
            _poll_callback(new_pot_value);
        }
        
    }

    function stop() {
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
    }

    // Enable or disable the potentiometer
    function setenabled(enable = true) {
        _gpioEnable.write(enable ? 0 : 1);
        if (_checkpot_timer) {
            imp.cancelwakeup(_checkpot_timer);
        }
        if (enable && _callback) {
            _checkpot_timer = imp.wakeup(0, checkpot.bindenv(this));
        }
    }
    
    // Get the enabled status
    function enabled() {
        return _gpioEnable.read() == 0;
    }

    // Sets the minimum and maximum of the output scale 
    function scale(min, max, integer_only = false) {
        _min = min;
        _max = max;
        _integer_only = integer_only;
    }
    
    
    // Gets the current value, rounded to three decimal places
    function get () {
        local f = 0.0 + _min + (_pinRead.read() * (_max - _min) / 65535.0);
        if (_integer_only) return f.tointeger();
        else               return format("%0.03f", f).tofloat();
    }
    
}

//------------------------------------------------------------------------------
// This class controls the PWM servos on the imp. There are further GPIO pins on the IO expander
// that can be used for PWM control but this class and the ExpGPIO class would need to be extended 
// to support this configuration.
//
class Servo {
    
    _expander = null;
    _gpioEnable = null;
    _pinWrite = null;
    
    constructor(expander, gpioEnable, pinWrite, period=0.02, dutycycle=0.5) {
        _expander = expander;
        _pinWrite = pinWrite;
        _pinWrite.configure(PWM_OUT, period, dutycycle);
        if (gpioEnable != null) {
            _gpioEnable = ExpGPIO(_expander, gpioEnable).configure(DIGITAL_OUT, 1);
        }
    }

    // Enable or disable the potentiometer
    function setenabled(enable = true) {
        if (_gpioEnable) _gpioEnable.write(enable ? 0 : 1);
    }
    
    // Get the enabled status
    function enabled() {
        return _gpioEnable ? (_gpioEnable.read() == 0) : false;
    }
    
    // Read and write the PWM pin
    function read() { return _pinWrite.read() }
    function write(val) { return _pinWrite.write(val) }
    
}

//------------------------------------------------------------------------------
// This class controls the LIS331DL accelerometer on the Hannah rev2. The alert functionality
// of this device is limited to "click" detection, so we emulate it with a simple call to poll.
// If you want movement detection, use the Hannah rev3 accelerometer instead. The values returned
// are floats between -1.0 and +1.0 and represent a range of 2g. This can be adjusted but this function is
// not provided. This devices measures acceleration only. So in a static state (not moving) the only 
// acceleration it can measure is gravity (so you can tell which way is up).
// 
class Accelerometer_rev2 {
    
    _i2c = null;
    _addr = null;
    _expander = null;
    _gpioInterrupt = null;
    _poll_timer = null;
    _poll_interval = null;
    _poll_callback = null;
    _disabled = false;
    
    static CTRL_REG1     = "\x20";
    static CTRL_REG2     = "\x21";
    static CTRL_REG3     = "\x22";
    static DATA_X        = "\x29";
    static DATA_Y        = "\x2B";
    static DATA_Z        = "\x2D";
    static DATA_ALL      = "\xA8";
    static WHO_AM_I      = "\x0F";
    
    constructor(i2c, addr, expander, gpioInterrupt)
    {
        _i2c  = i2c;
        _addr = addr;  
        _expander = expander;
        local id = _i2c.read(_addr, WHO_AM_I, 1);
        if (!id || id[0] != 0x3B) {
            server.error(format(WRONG_DEVICE_ERR, _addr, "LIS331DL accelerometer"))
            _disabled = true;
        } else {
            _gpioInterrupt = ExpGPIO(_expander, gpioInterrupt).configure(DIGITAL_IN, _callbackHandler.bindenv(this));
        }
    }
    
    function _callbackHandler() {
        server.log("Not implemented yet.")
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        local data = _i2c.read(_addr, DATA_ALL, 6);
        local x = 0, y = 0, z = 0;
        if (data != null) {
            x = data[1];
            if (x & 0x80) x = -((~x & 0x7F) + 1);
            x = x / 128.0;
    
            y = data[3];
            if (y & 0x80) y = -((~y & 0x7F) + 1);
            y = y / 128.0;
    
            z = data[5];
            if (z & 0x80) z = -((~z & 0x7F) + 1);
            z = z / 128.0;
        }

        return {x = x, y = y, z = z};
    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
            _i2c.write(_addr, CTRL_REG1 + "\xC7");      // Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
            _i2c.write(_addr, CTRL_REG2 + "\x00");      // High-pass filter disabled            
        } else if (!_poll_interval || !_poll_callback) {
            server.error(format(BAD_TIMER_ERR, "Accelerometer_rev2::poll()"))
            return false;
        }
        
        local acc = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        _poll_callback(acc.x, acc.y, acc.z);
    }
    
    function alert(callback) {
        // Alert is an alias for poll in this accelerometer
        poll(1, callback);
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr)); 
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _i2c.write(_addr, CTRL_REG1 + "\x00");      // Turn off the sensor
    }
    
}

//------------------------------------------------------------------------------
// This class controls the LIS3DH accelerometer on the Hannah rev3. The default functionality of 
// the "alert" method is movement detection. Other hardware detection techniques are available (such
// as free-fall and click detection) are available but not provided. The methods and results are the
// same as the accelerometer on the Hannah rev2.
// 
class Accelerometer_rev3 {
    
    _i2c = null;
    _addr = null;
    _expander = null;
    _gpioInterrupt = null;
    _poll_timer = null;
    _poll_interval = null;
    _poll_callback = null;
    _alert_callback = null;
    _disabled = false;
    _running = false;
    
    static CTRL_REG1     = "\x20";
    static CTRL_REG2     = "\x21";
    static CTRL_REG3     = "\x22";
    static CTRL_REG4     = "\x23";
    static CTRL_REG5     = "\x24";
    static CTRL_REG6     = "\x25";
    static DATA_X_L      = "\x28";
    static DATA_X_H      = "\x29";
    static DATA_Y_L      = "\x2A";
    static DATA_Y_H      = "\x2B";
    static DATA_Z_L      = "\x2C";
    static DATA_Z_H      = "\x2D";
    static DATA_ALL      = "\xA8";
    static INT1_CFG      = "\x30";
    static INT1_SRC      = "\x31";
    static INT1_THS      = "\x32";
    static INT1_DURATION = "\x33";
    static TAP_CFG       = "\x38";
    static TAP_SRC       = "\x39";
    static TAP_THS       = "\x3A";
    static TIME_LIMIT    = "\x3B";
    static TIME_LATENCY  = "\x3C";
    static TIME_WINDOW   = "\x3D";
    static WHO_AM_I      = "\x0F";
    
    constructor(i2c, addr, expander, gpioInterrupt)
    {
        _i2c  = i2c;
        _addr = addr;  
        _expander = expander;
        
        local id = _i2c.read(_addr, WHO_AM_I, 1);
        if (!id || id[0] != 0x33) {
            server.error(format(WRONG_DEVICE_ERR, _addr, "LIS3DH accelerometer"))
            _disabled = true;
        } else {
            _gpioInterrupt = ExpGPIO(_expander, gpioInterrupt).configure(DIGITAL_IN, interruptHandler.bindenv(this));
            _i2c.write(_addr, CTRL_REG1 + "\x00");      // Turn off the sensor
        }
    }
    
    function interruptHandler(state) {
        if (state == 1 && _alert_callback) {
            local acc = get();
            _alert_callback(acc.x, acc.y, acc.z);
        }
    }
    
    function alert(callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        
        _alert_callback = callback;
        _running = true;

        // Setup the accelerometer for sleep-polling
        _i2c.write(_addr, CTRL_REG1 + "\xA7");      // Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
        _i2c.write(_addr, CTRL_REG2 + "\x00");      // High-pass filter disabled
        _i2c.write(_addr, CTRL_REG3 + "\x40");      // Interrupt driven to INT1 pad
        _i2c.write(_addr, CTRL_REG4 + "\x00");      // FS = 2g
        _i2c.write(_addr, CTRL_REG5 + "\x00");      // Interrupt latched
        _i2c.write(_addr, CTRL_REG6 + "\x00");      // Interrupt Active High
        _i2c.write(_addr, INT1_THS + "\x10");       // Set movement threshold = ? mg
        _i2c.write(_addr, INT1_DURATION + "\x00");  // Duration not relevant
        _i2c.write(_addr, INT1_CFG + "\x6A");       // Configure intertia detection axis/axes - all three. Plus 6D.
        _i2c.read(_addr, INT1_SRC, 1);              // Clear any interrupts

    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error(format(BAD_TIMER_ERR, "Accelerometer_rev3::poll()"))
            return false;
        }
        
        local acc = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        _poll_callback(acc.x, acc.y, acc.z);
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr)); 
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _alert_callback = null;
        _running = false;
        _i2c.write(_addr, CTRL_REG1 + "\x00");      // Turn off the sensor
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE_ERR, _addr));

        // Configure settings of the accelerometer
        if (!_running) {
            _i2c.write(_addr, CTRL_REG1 + "\x47");  // Turn on the sensor, enable X, Y, and Z, ODR = 50 Hz
            _i2c.write(_addr, CTRL_REG2 + "\x00");  // High-pass filter disabled
            _i2c.write(_addr, CTRL_REG3 + "\x40");  // Interrupt driven to INT1 pad
            _i2c.write(_addr, CTRL_REG4 + "\x00");  // FS = 2g
            _i2c.write(_addr, CTRL_REG5 + "\x00");  // Interrupt Not latched
            _i2c.write(_addr, CTRL_REG6 + "\x00");  // Interrupt Active High (not actually used)
            _i2c.read(_addr, INT1_SRC, 1);          // Clear any interrupts
        }
        
        local data = _i2c.read(_addr, DATA_ALL, 6);
        local x = 0, y = 0, z = 0;
        if (data != null) {
            x = (data[1] << 8 | data[0]);
            if (x & 0x8000) x = -((~x & 0x7FFF) + 1);
            x = x / 32767.0;
            
            y = (data[3] << 8 | data[2]);
            if (y & 0x8000) y = -((~y & 0x7FFF) + 1);
            y = y / 32767.0;
            
            z = (data[5] << 8 | data[4]);
            if (z & 0x8000) z = -((~z & 0x7FFF) + 1);
            z = z / 32767.0;
            
            return {x = x, y = y, z = z};
        }

    }
    
    
    
}

//------------------------------------------------------------------------------
// This class maps all the classes above into a representation of the Hannah collection of devices.
// It is presented to demonstrate how you can put everything together but it is not really providing
// any value. Feel free to replace it in your own projects. 
//
class Hannah {
    
    i2c = null;
    ioexp = null;
    pot = null;
    btn1 = null;
    btn2 = null;
    hall = null;
    srv1 = null;
    srv2 = null;
    acc = null;
    led = null;
    light = null;
    temp = null;
    
    on_pot_changed = null;
    on_btn1_changed = null;
    on_btn2_changed = null;
    on_hall_changed = null;
    on_acc_changed = null;
    on_light_changed = null;
    on_temp_changed = null;
    
    constructor() {
        
        // Initialize the I2C bus
        i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        
        // Initialize IO expander
        ioexp = SX1509(i2c, 0x7C, hardware.pin1);
        
        // Potentiometer on pin 2 and enabled on IO pin 8
        pot = Potentiometer(ioexp, 8, hardware.pin2);
        pot.poll(0.1, call_callback("on_pot_changed"));
        
        // Button 1 on IO pin 0
        btn1 = ExpGPIO(ioexp, 0).configure(DIGITAL_IN_PULLUP, call_callback("on_btn1_changed"));
        
        // Button 2 on IO pin 1
        btn2 = ExpGPIO(ioexp, 1).configure(DIGITAL_IN_PULLUP, call_callback("on_btn2_changed"));
        
        // Hall switch on IO pin 2
        hall = ExpGPIO(ioexp, 2).configure(DIGITAL_IN_PULLUP, call_callback("on_hall_changed"));
        
        // RGB Light Sensor on i2c port 0xE8 with the sleep pin on IO pin 9
        light = RGBSensor(i2c, 0xE8, ioexp, 9);
        light.poll(1, call_callback("on_light_changed"));

        // Accelerometer on i2c port 0x38 or 0x30 with alert in pin on IO pin 3
        acc = Accelerometer_rev2(i2c, 0x38, ioexp, 3);
        if (acc._disabled) acc = Accelerometer_rev3(i2c, 0x30, ioexp, 3);
        acc.alert(call_callback("on_acc_changed"));
        
        // Temperature Sensor on i2c port 0x98 or 0x92 with the alert pin on IO pin 4
        temp = TempSensor_rev2(i2c, 0x98, ioexp, 4);
        if (temp._disabled) temp = TempSensor_rev3(i2c, 0x92, ioexp, 4);
        temp.poll(1, call_callback("on_temp_changed"));

        // Servo1 on pin5
        srv1 = Servo(ioexp, 10, hardware.pin5);
        
        // Servo2 on pin7
        srv2 = Servo(ioexp, 10, hardware.pin7);
        
        // RGB LED on IO pins 7 (red), 5 (green) and 6 (blue)
        led = RGBLED(ioexp, 7, 5, 6);
    }
    
    
    function call_callback(callback_name) {
        return function(a=null, b=null, c=null) {
            if ((callback_name in this) && (typeof this[callback_name] == "function")) {
                if (a == null) {
                    this[callback_name]();
                } else if (b == null) {
                    this[callback_name](a);
                } else if (c == null) {
                    this[callback_name](a, b);
                } else {
                    this[callback_name](a, b, c);
                }
            }
        }.bindenv(this)
    }
}


//------------------------------------------------------------------------------
// deg2int and int2deg convert floating point values of temperature into the integer representation
// (and vice versa) used by the two temperature sensors above. 
// 
function deg2int(temp, stepsize = 0.125, left_align_bits = 11) {
    temp = (temp / stepsize.tofloat()).tointeger();
    local mask1 = (0xFFFF << (16 - left_align_bits)) & 0xFFFF;
    local mask2 = mask1 >> (16 - left_align_bits + 1);
    if (temp < 0) temp = -((~temp & mask2) + 1);
    return (temp << (16 - left_align_bits)) & mask1;
}

function int2deg(temp, stepsize = 0.125, left_align_bits = 11) {
    temp = temp >> (16 - left_align_bits);
    local mask1 = (1 << (left_align_bits - 1));
    local mask2 = 0xFFFF >> (16 - left_align_bits + 1);
    if (temp & mask1) temp = -((~temp & mask2) + 1);
    return temp.tofloat() * stepsize.tofloat();
}


//==============================================================================
// Everything below here is sample application code. 
// Mostly this logs values and status changes to server.log() but changes in temperature (above and below 
// the provided thresholds) are displayed as LED colours. Some of the functions are muted as they are 
// very noisy.
//
hannah <- Hannah();
hannah.led.blink(0, 20, 0, true);
hannah.light.initialise([7, 7, 7, 5], 0x30);
hannah.pot.scale(0, 100, true);
hannah.temp.alert(29, 31);

hannah.on_temp_changed = function(state) {
    server.log(format("Temperature has changed to: %0.02f", state))
    if (state <= 29) hannah.led.set(0, 0, 20)
    else if (state >= 31) hannah.led.set(20, 0, 0)
    else hannah.led.set(0, 20, 0, true)
}
hannah.on_pot_changed = function(state) {
    server.log("Pot has changed to: " + state)
}
hannah.on_btn1_changed = function(state) {
    server.log("Button 1 is triggered: " + (state ? "up" : "down"));
}
hannah.on_btn2_changed = function(state) {
    server.log("Button 2 is triggered: " + (state ? "up" : "down"));
}
hannah.on_hall_changed = function(state) {
    server.log("Hall sensor is triggered: " + (state ? "inactive" : "active"));
}
hannah.on_light_changed = function(state) {
    // server.log(format("Light: [%d,%d,%d,%d]", state.r, state.g, state.b, state.c ))
}
hannah.on_acc_changed = function(x, y, z) {
    // server.log(format("Movement: x = %0.2f, y = %0.2f, z = %0.2f", x, y, z));
}

