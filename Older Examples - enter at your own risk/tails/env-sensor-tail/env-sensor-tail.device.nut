/* Environmental Sensor Tail Firmware
 * Ambient Light Sensor: APDS-9007-020 (http://www.avagotech.com/docs/AV02-0512EN)
 * Air Pressure Sensor: LPS25HTR (http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf)
 * Humidity/Temp Sensor: SI7020-A10-GMR (http://www.silabs.com/Support%20Documents/TechnicalDocs/Si7020.pdf)
 */
 
const LPS25HTR_ADDR     = 0xB8; // 8-bit I2C Student Address for LPS25HTR
const SI7020_ADDR       = 0x80; // 8-bit I2C Student Address for SI7020
const ALS_RLOAD         = 47000.0; // load resistor value on ALS
const READING_INTERVAL  = 60; // seconds between readings

/* CLASS AND GLOBAL FUNCTION DEFINITIONS ------------------------------------ */

// Ambient Light Sensor APDS-9007-020
// http://www.avagotech.com/docs/AV02-0512EN
// Logarithmic Analog Current Output; drive into load resistor and buffer
// Read with Analog Input
class APDS9007 {
    static WAIT_BEFORE_READ = 5.0;
    RLOAD = null; // value of load resistor on ALS (device has current output)
    
    _als_pin            = null;
    _als_en             = null;
    _points_per_read    = null;
    
    // -------------------------------------------------------------------------
    constructor(als_pin, rload, als_en = null, points_per_read = 10) {
        _als_pin = als_pin;
        _als_en = als_en;
        RLOAD = rload;
        _points_per_read = points_per_read * 1.0; //force to a float
    }
    
    // -------------------------------------------------------------------------
    // read the ALS and return value in lux
    function read() {
        if (_als_en) {
            _als_en.write(1);
            imp.sleep(WAIT_BEFORE_READ);
        }
        local Vpin = 0;
        local Vcc = 0;
        // average several readings for improved precision
        for (local i = 0; i < _points_per_read; i++) {
            Vpin += _als_pin.read();
            Vcc += hardware.voltage();
        }
        Vpin = (Vpin * 1.0) / _points_per_read;
        Vcc = (Vcc * 1.0) / _points_per_read;
        Vpin = (Vpin / 65535.0) * Vcc;
        local Iout = (Vpin / RLOAD) * 1000000.0; // current in µA
        if (_als_en) _als_en.write(0);
        return (math.pow(10.0,(Iout/10.0)));
    }
}

// Air Pressure Sensor LPS25HTR
// http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf
class LPS25HTR {
    static REF_P_XL     = 0x08;
    static REF_P_L      = 0x09;
    static REF_P_H      = 0x0A;
    static WHO_AM_I     = 0x0F;
    static CTRL_REG1    = 0x20;
    static CTRL_REG2    = 0x21;
    static CTRL_REG3    = 0x22;
    static CTRL_REG4    = 0x23;
    static INT_CFG      = 0x24;
    static INT_SRC      = 0x25;
    static STATUS_REG   = 0x27;
    static PRESS_POUT_XL = 0x28;
    static PRESS_OUT_L  = 0x29;
    static PRESS_OUT_H  = 0x2A;
    static TEMP_OUT_L   = 0x2B;
    static TEMP_OUT_H   = 0x2C;
    static FIFO_CTRL    = 0x2E;
    static FIFO_STATUS  = 0x2F;
    static THS_P_L     = 0x30;
    static THS_P_H     = 0x31;
    static RPDS_L       = 0x39;
    static RPDS_H       = 0x3A;
    
    _i2c        = null;
    _addr       = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0xB8) {
        _i2c = i2c;
        _addr = addr;
    }
    
    // -------------------------------------------------------------------------
    function twos_comp(value, mask) {
		value = ~(value & mask) + 1;
		return value & mask;
	}

    // -------------------------------------------------------------------------
    function get_device_id() {
        return _i2c.read(_addr, WHO_AM_I, 1);
    }
	
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a pressure result
    // Selector field is 2 bits
    function set_press_npts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x01
        } else if (npts <= 128) {
            // Average 128 readings
            npts = 0x02;
        } else {
            // Average 512 readings
            npts = 0x03;
        }
        local val = _i2c.read(_addr, RES_CONF, 1);
        val = ((val & 0xFC) | npts);
        _i2c.write(_addr, RES_CONF, format("%c", val & 0xff));
    }    
    
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a temperature result
    // Selector field is 2 bits
    function set_temp_npts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 16) {
            // Average 16 readings
            npts = 0x01
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x02;
        } else {
            // Average 64 readings
            npts = 0x03;
        }
        local val = _i2c.read(_addr, RES_CONF, 1);
        val = (val & 0xF3) | (npts << 2);
        _i2c.write(_addr, RES_CONF, format("%c", val & 0xff));
    }    

    // -------------------------------------------------------------------------
    function set_power_state(state) {
        local val = _i2c.read(_addr, CTRL_REG1, 1);
        if (state == 0) {
            val = val & 0x7F; 
        } else {
            val = val | 0x80;
        }
        _i2c.write(_addr, CTRL_REG1, format("%c", val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_int_enable(state) {
        local val = _i2c.read(_addr, CTRL_REG1, 1);
        if (state == 0) {
            val = val & 0xF7; 
        } else {
            val = val | 0x08;
        }
        _i2c.write(_addr, CTRL_REG1, format("%c", val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_fifo_enable(state) {
        local val = _i2c.read(_addr, CTRL_REG2, 1);
        if (state == 0) {
            val = val & 0xAF; 
        } else {
            val = val | 0x40;
        }
        _i2c.write(_addr, CTRL_REG2, format("%c", val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function soft_reset(state) {
        _i2c.write(_addr, CTRL_REG2, format("%c", 0x04));
    }
    
    // -------------------------------------------------------------------------
    function set_int_activehigh(state) {
        local val = _i2c.read(_addr, CTRL_REG3, 1);
        if (state == 0) {
            val = val | 0x80; 
        } else {
            val = val & 0x7F;
        }
        _i2c.write(_addr, CTRL_REG3, format("%c", val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_int_pushpull(state) {
        local val = _i2c.read(_addr, CTRL_REG3, 1);
        if (state == 0) {
            val = val | 0x40; 
        } else {
            val = val & 0xBF;
        }
        _i2c.write(_addr, CTRL_REG3, format("%c", val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_int_config(latch, diff_press_low, diff_press_high) {
        local val = _i2c.read(_addr, CTRL_REG1, 1);
        if (latch) {
            val = val | 0x04; 
        } 
        if (diff_press_low) {
            val = val & 0x02;
        }
        if (diff_press_high) {
            val = val | 0x01;
        }
        _i2c.write(_addr, CTRL_REG1, format("%c", val & 0xff));
    }    
    
    // -------------------------------------------------------------------------
    function set_press_thresh(press_thresh) {
        _i2c.write(_addr, THS_P_H, format("%c", (press_thresh & 0xff00) >> 8));
        _i2c.write(_addr, THS_P_L, format("%c", (press_thresh & 0xff)));
    }  
    
    // -------------------------------------------------------------------------
    // Returns Pressure in hPa
    function read_pressure_hPa() {
        local press_xl = _i2c.read(_addr, PRESS_OUT_XL, 1);
        local press_l = _i2c.read(_addr, PRESS_OUT_L, 1);
        local press_h = _i2c.read(_addr, PRESS_OUT_H, 1);
        
        return (((press_h << 16) + (press_l << 8) + press_xl) / 4096);
    }
    
    // -------------------------------------------------------------------------
    // Returns Pressure in kPa
    function read_pressure_kPa() {    
        return read_pressure_hPa() / 10.0;
    }

    
    // -------------------------------------------------------------------------
    // Returns Pressure in inches of Hg
    function read_pressure_inHg() {    
        return read_pressure_hPa * 0.0295333727;
    }    
    
    // -------------------------------------------------------------------------
    function read_temp() {
        local temp_l = _i2c.read(_addr, TEMP_OUT_L, 1);
        local temp_h = _i2c.read(_addr, TEMP_OUT_H, 1);
        
        return (42.5 * (((temp_l << 8) + temp_xl) / 480.0));
    }

}

// Humidity/Temp Sensor 
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

function aps_int() {
    if (press_int.read()) {
        server.log("LPS25HTR threw interrupt");
    }
}

function logloop() {
    imp.wakeup(READING_INTERVAL,logloop);
    h = rh.readRH();
    t = rh.readTemp();
    lx = als.read();
    ll = hardware.lightlevel();
    server.log(format("SI7020: RH = %0.2f, Temp = %0.2fC",h,t));
    server.log(format("APDS-9007: %0.2f Lux",lx));
    server.log(format("LightLevel: %0.2f", ll));
    //server.log(format("LPS25HTR: Press = %0.2f" Hg, Temp = %0.2fC",aps.readPress(),aps.readTemp()));
    
    agent.send("data", {humidity = h, temp = t, lux = lx, lightlevel = ll});
}

/* AGENT CALLBACKS ---------------------------------------------------------- */

/* RUNTIME START ------------------------------------------------------------ */

press_int   <- hardware.pin1; // interrupt from air pressure sensor
led         <- hardware.pin2; // high-side drive for LED
als_out     <- hardware.pin5; // ambient light sensor output (analog)
als_en      <- hardware.pin7; // ambient light sensor enable (active high)
i2c         <- hardware.i2c89;

press_int.configure(DIGITAL_IN, aps_int);
led.configure(PWM_OUT,2,0.2); // blink once every 2 seconds for 400ms
als_out.configure(ANALOG_IN);
als_en.configure(DIGITAL_OUT);
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- APDS9007(als_out, ALS_RLOAD, als_en);
//aps <- LPS25HTR(i2c, LPS25HTR_ADDR);
rh  <- SI7021(i2c, SI7020_ADDR);

server.log("SW:  "+imp.getsoftwareversion());
server.log("Memory Free: "+imp.getmemoryfree());
imp.enableblinkup(true);
imp.setpowersave(true);

logloop();