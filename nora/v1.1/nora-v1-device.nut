
// -----------------------------------------------------------------------------
// Purpose: Handles the Nora v1 reference design
// Updated: 05/06/2013
// Author(s): Brandan, Hugo and Tom ... cleaned up by Aron.
//

// -----------------------------------------------------------------------------
// Base sensor class for nora sensors
//
class sensor {
    
    i2c      = null;
    addr     = null;
    callback = null;
    ready    = false;

    // .........................................................................
    constructor(_i2c, _callback, _addr) {
        i2c = _i2c;
        callback = _callback;
        addr = _addr;
        
        test();
    }

    // .........................................................................
    function test() {
        if (i2c != null) {
            local t = i2c.read(addr, "", 1);
            ready = (t != null);
        } else {
            ready = true;
        }
        return ready;
    }
    
    // .........................................................................
    function send(_key, _value) {
        // server.log("Sending " + _key + " = " + _value + " to agent.");
        if (_value != null) agent.send(_key, _value);
        if (callback != null) callback(_key, _value);        
    }
}

// -----------------------------------------------------------------------------
// hih6131 - Honeywell HIH-6131 humidity sensor
//
class hih6131 extends sensor {
    static wait = 0.08;
    
    // .........................................................................
    constructor(_i2c, _callback = null, _addr = 0x4e) {
        base.constructor(_i2c, _callback, _addr);
    }

    // .........................................................................
    function convert() {
        if (!ready) {
            return 0;
        } else {
            i2c.write(addr, "");
            imp.wakeup(wait, converted.bindenv(this));
            return 2;
        }
    }
    
    // .........................................................................
    function converted() {
        local th = i2c.read(addr, "", 4);
        if (th == null) {
            server.error("HIH6131 received null");
            send("temp", null);
            send("humidity", null);
        } else {
            local t = ((((th[2]         << 6 ) | (th[3] >> 2)) * 165) / 16383.0) - 40;
            local h = ((((th[0] & 0x3F) << 8 ) | (th[1]     ))        / 163.83 );
        
            //Round to 2 decimal places
            t = (t*100).tointeger() / 100.0;
            h = (h*100).tointeger() / 100.0;
        
            send("temp", t);
            send("humidity", h);
        }
    }
}

// -----------------------------------------------------------------------------
// MPL115 Barometric pressure sensor
//
class mpl115 extends sensor {
    
    static wait = 0.005;
    
    a0    = null;
    b1    = null;
    b2    = null;
    c12   = null;

    // .........................................................................
    constructor(_i2c, _callback = null, _addr = 0xc0) {
        base.constructor(_i2c, _callback, _addr);

        // Create non-volatile table if it doesn't already exist
        if (("nv" in getroottable()) && ("mpl115" in nv)) {
            a0  = nv.a0;
            b1  = nv.b1;
            b2  = nv.b2;
            c12 = nv.c12;
            
        } else {
            
            // get a0, b1, b2, and c12 environmental coefficients from Freescale barometric pressure sensor U5
            local a0_msb  = i2c.read(addr, "\x04", 1);
            local a0_lsb  = i2c.read(addr, "\x05", 1);
            local b1_msb  = i2c.read(addr, "\x06", 1);
            local b1_lsb  = i2c.read(addr, "\x07", 1);
            local b2_msb  = i2c.read(addr, "\x08", 1);
            local b2_lsb  = i2c.read(addr, "\x09", 1);
            local c12_msb = i2c.read(addr, "\x0a", 1);
            local c12_lsb = i2c.read(addr, "\x0b", 1);
            
            // if values (coefficients and ADC values) are less than 16 bits, lsb is padded from low end with zeros
            // a0 is 16 bits, signed, 12 integer, 3 fractional (2^3 = 8)
            a0 = ((a0_msb[0] << 8) | (a0_lsb[0] & 0x00ff));
            // handle 2's complement sign bit
            if (a0 & 0x8000) {
                a0 = (~a0) & 0xffff;
                a0++;
                a0 *= -1;
            }
            a0 = a0/8.0;

            // b1 is 16 bits, signed, 2 integer, 13 fractional (2^13 = 8192)
            b1 = (b1_msb[0] << 8) | (b1_lsb[0] & 0xff);
            if (b1 & 0x8000) {
                b1 = (~b1) & 0xffff;
                b1++;
                b1 *= -1;
            }
            b1 = b1/8192.0;
    
            // b2 is 16 bits, signed, 1 integer, 14 fractional
            b2 = (b2_msb[0] << 8) | (b2_lsb[0] & 0xff);
            if (b2 & 0x8000) {
                b2 = (~b2) & 0xffff;
                b2++;
                b2 *= -1;
            }
            b2 = b2/16384.0;

            // c12 is 14 bits, signed, 13 fractional bits, with 9 zeroes of padding
            c12 = ((c12_msb[0] & 0xff) << 6) | ((c12_lsb[0] & 0xfc) >> 2);
            if (c12 & 0x2000) {
                c12 = (~c12) & 0xffff;
                c12++;
                c12 *= -1;
            }
            c12 = c12/4194304.0;

            //Stash them in the NV table for later use
            ::nv <- {};
            ::nv["a0"]  <- a0;
            ::nv["b1"]  <- b1;
            ::nv["b2"]  <- b2;
            ::nv["c12"] <- c12;
            ::nv["mpl115"] <- 1;
        }
    }
    
    // .........................................................................
    function convert() {
        if (!ready) {
            return 0;
        } else {
            i2c.write(addr,"\x12\xff");
            imp.wakeup(wait, converted.bindenv(this));
            return 1;
        }
    }
    
    // .........................................................................
    function converted() {
        // Read out temperature and pressure ADC values from Freescale sensor
        // Both values are 10 bits, unsigned, with the high 8 bits in the MSB value
        local press_result = this.i2c.read(0xc0, "\x00", 4);
    
        if (press_result == null) {
            server.error("MPL115 received null");
            send("pressure", null); 
        } else {
            local padc = ((press_result[0] & 0xff) << 2) | (press_result[1] & 0x03);
            local tadc = ((press_result[2] & 0xff) << 2) | (press_result[3] & 0x03);
    
            // Calculate compensated pressure from coefficients and padc
            local pcomp = a0 + ((b1 + (c12 * tadc)) * padc) + (b2 * tadc);
    
            // Pcomp is 0 at 50 kPa and full-scale (1023) at 115 kPa, so we scale to get kPa
            // Patm = 50 + (pcomp * ((115 - 50) / 1023))
            local p = 50 + (pcomp * (65.0 / 1023.0));
            send("pressure", p);            
        }
    }
}

// -----------------------------------------------------------------------------
// TMP112 Local temperator sensore
//
class tmp112 extends sensor {
    static wait = 0.035;
    
    // .........................................................................
    constructor(_i2c, _callback = null, _addr = 0x92) {
        base.constructor(_i2c, _callback, _addr);
    }
    
    
    // .........................................................................
    function convert() {
        // OS  R1  R0  F1  F0 POL  TM  SD
        // 1   1   1   0   0   1   1   1 = 0xE7
        //CR1 CR0  AL  EM  X   X   X   X
        // 1   0   1   0   0   0   0   0 = 0xA0
        if (!ready) {
            return 0;
        } else {
            i2c.write(addr, "\x01\xE7\xA0");
            imp.wakeup(wait, converted.bindenv(this));
            return 1;
        }
    }
    
    
    // .........................................................................
    function converted() {
        local result = i2c.read(addr, "\x00", 2);
        if (result == null) {
            server.error("TMP112 received null");
            send("temp", null);
        } else {
            local t = ((result[0] << 4) + (result[1] >> 4)) * 0.0625;
            send("temp", t);
        }
    }
}
    

// -----------------------------------------------------------------------------
class tsl2561 extends sensor {
    static wait = 0.45;
 
    // .........................................................................
    constructor(_i2c, _callback = null, _addr = 0x52) {
        base.constructor(_i2c, _callback, _addr);
    }
    
    
    // .........................................................................
    function convert() {
        if (!ready) {
            return 0;
        } else {
            //Set the power bits in the config register to 11
            i2c.write(addr, "\x80\x03");
            imp.wakeup(wait, converted.bindenv(this));
            return 1;
        }
    }
    
    // .........................................................................
    function converted() {
        
        local reg0 = i2c.read(this.addr, "\xAC", 2);
        local reg1 = i2c.read(this.addr, "\xAE", 2);
        if (reg0 == null || reg1 == null) {
            server.error("TSL2561 Light reading returned null");
            send("ambient", null);
        } else {
            local ch0 = ((reg0[1] & 0xFF) << 8) + (reg0[0] & 0xFF);
            local ch1 = ((reg1[1] & 0xFF) << 8) + (reg1[0] & 0xFF);
            
            local ratio = ch1 / ch0.tofloat();
            local lux = 0.0;
            if( ratio <= 0.5){
                lux = 0.0304*ch0 - 0.062*ch0*math.pow(ratio,1.4); 
            }else if( ratio <= 0.61){
                lux = 0.0224 * ch0 - 0.031 * ch1;
            }else if( ratio <= 0.8){
                lux = 0.0128*ch0 - 0.0153*ch1;
            }else if( ratio <= 1.3){
                lux = 0.00146*ch0 - 0.00112*ch1;
            }else{
                server.error("Invalid Lux calculation: " + ch0 + "," + ch1);
                send("ambient", null);
                return;
            }
 
            send("ambient", lux);
            // server.log(format("Ch0: 0x%04X Ch1: 0x%04X Ratio: %f Lux: %f", ch0, ch1, ratio, lux));
            
        }
    }
        
}
 

    
// -----------------------------------------------------------------------------
class battery extends sensor {
 
    pin = null;
    
    // .........................................................................
    constructor(_pin, _callback = null) {
        base.constructor(null, _callback, null);
        
        // Configure pin for analog battery readings
        pin = _pin;
        pin.configure(ANALOG_IN);
        
    }
    
    
    // .........................................................................
    function convert() {
        // Queues the request for later
        imp.wakeup(0, converted.bindenv(this));
        return 1;
    }
    
    // .........................................................................
    function converted() {
        send("battery", 100.0 * pin.read() / 65535.0);
    }
        
}
 

    
// -----------------------------------------------------------------------------
class nora {
    hih = null;
    tmp = null;
    mpl = null;
    tsl = null;
    bat = null;
    
    counter = 0;
    callback = null;
    results = null;
    
    // .........................................................................
    constructor() {
        
        // Enable Power to all ICs
        hardware.pin2.configure(DIGITAL_OUT);
        hardware.pin2.write(0);
         
        // Configure I2C
        hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

        // Wait for sensor to be ready
        imp.sleep(0.01);

        // Instantiate all the devices
        hih = hih6131(hardware.i2c89, callcounter.bindenv(this));
        mpl = mpl115(hardware.i2c89, callcounter.bindenv(this));
        tmp = tmp112(hardware.i2c89, callcounter.bindenv(this));
        tsl = tsl2561(hardware.i2c89, callcounter.bindenv(this));
        bat = battery(hardware.pin7, callcounter.bindenv(this));
        
    }


    // .........................................................................
    function callcounter(_key, _value) {
        
        // Stash the results away
        results[_key] <- _value;
        
        // Are we finished receiving results yet?
        counter--;
        if (counter == 0) callback(results);
    }
    
    
    // .........................................................................
    function timeout() {
        callback(results);
    }
    
    
    // .........................................................................
    function read(_callback) {
        callback = _callback;
        results = {};
        
        // Begin each of the conversions
        counter += hih.convert();
        counter += mpl.convert();
        counter += tmp.convert();
        counter += tsl.convert();
        counter += bat.convert();
        
        // Timeout - the backup plan
        imp.wakeup(5, timeout.bindenv(this));        
    }

    // .........................................................................
    function sleep(duration = null) {
        
        // Power Senors Off
        hardware.pin2.configure(DIGITAL_OUT);
        hardware.pin2.write(1);
            
        // Use I2C lines to Drain the Rail
        hardware.pin8.configure(DIGITAL_OUT);
        hardware.pin9.configure(DIGITAL_OUT);
        hardware.pin8.write(0);
        hardware.pin9.write(0);
        imp.sleep(0.02);
        
        // If sleep duration isn't specified, then sleep until the next 10 minute mark
        if (duration == null) {
            duration = 1 + 10*60 - (time() % (10*60));
        }
        
        // You are getting sleeeeepy
        imp.onidle(function() { 
            server.sleepfor(duration);
        });
    }
    
}



// -----------------------------------------------------------------------------
// Configure Imp
imp.configure("Nora v1 Multisensor", [], []);

// Instantiate the nora() class and execute a read.
n <- nora();
n.read(function(results) {
    n.sleep();
});

