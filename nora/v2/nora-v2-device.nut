/*
Copyright (C) 2013 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


// **********************************************************************************************************************************
class sensor {

    i2c       = null;
    pin_en_l  = null;
    pin_drain = null;
    addr      = null;
    ready     = false;
    name      = "sensor";
    static registry = {};
    
    constructor(_i2c=null, _pin_en_l=null, _pin_drain=null, _addr=null) {
        i2c = _i2c;
		pin_en_l = _pin_en_l;
		pin_drain = _pin_drain;
        addr = _addr;
        ::last_activity <- time();
        
        if (i2c) i2c.configure(CLOCK_SPEED_400_KHZ);
		if (pin_en_l) pin_en_l.configure(DIGITAL_OUT);
		if (pin_drain) pin_drain.configure(DIGITAL_OUT);

        // Test the sensor and if its alive then setup a handler to execute all functions of the class
        if (test()) {
            registry[name] <- this;
            agent.on(name, agent_event.bindenv(this));
        }
    }

	function enable() {
		if (pin_en_l) pin_en_l.write(0);
		if (pin_drain) pin_drain.write(1);
		imp.sleep(0.001);
	}

	function disable() {
		if (pin_en_l) pin_en_l.write(1);
		if (pin_drain) pin_drain.write(0);
	}

	function test() {
        if (i2c == null) {
            ready = false;  
        } else {
      		enable();
      		local t = i2c.read(addr, "", 1);
      		ready = (t != null);
      		disable();
        }
    
        return ready;
	}

    function get_nv(key) {
    	if (("nv" in getroottable()) && (key in ::nv)) {
            return ::nv[key];
		} else {
    	    return null;   
		}
    }
    
    function set_nv(key, value) {
        if (!("nv" in getroottable())) ::nv <- {};
        ::nv[key] <- value;
    }


    function dump_nv(root = null) {
        if ("nv" in getroottable()) {
            if (root == null) root = ::nv;
            foreach (k,v in root) {
                if (typeof v == "array" || typeof v == "table") {
                    server.log("NV: " + k + " => " + v)
                    dump_nv(v);
                } else {
                    server.log("NV: " + k + " => " + v)
                }
            }
        } else {
            server.log("NV: Not defined");
        }
        
    }
    
    
    function get_wake_reason() {
        
		switch (hardware.wakereason()) {
		case WAKEREASON_POWER_ON: return "power on"; 
		case WAKEREASON_TIMER: return "timer"; 
		case WAKEREASON_SW_RESET: return "software reset";
		case WAKEREASON_PIN1: return "pin1 interrupt";
		case WAKEREASON_NEW_SQUIRREL: return "new squirrel";
		default: return "unknown";
		}
    }
    
    
	function get_bootreason() {
        // server.log("GET bootreason: " + get_nv("reason"));
        return get_nv("reason");
	}


	function set_bootreason(_reason = null) {
        set_nv("reason", _reason);
        // server.log("SET bootreason to " + _reason);
	}
    
    function agent_event(data) {
        last_activity = time();
        if (data.method in this && typeof this[data.method] == "function") {
      
            // Formulate the function and the callback
            local method = this[data.method];
            local params = [this];
            local callback = remote_response(name, data.method).bindenv(this);
            
            if ("params" in data) {
                if (typeof data.params == "array") {
                    params.extend(data.params);
                } else {
                    params.push(data.params);
                }
            }
            params.push(callback);
        
            // Execute the function call with the parameters and callbacks
            try {
                method.acall(params);
            } catch (e) {
                server.log(format("Exception while executing '%s.%s': %s", name, data.method, e))
            }
        }
    }

    function reset() {
        if (i2c) {
            i2c.write(0x00,format("%c",RESET_VAL));
            imp.sleep(0.01);
        }
    }


	function sleep(dur = 600, delay = 0, callback = null) {

		switch (hardware.wakereason()) {
		case WAKEREASON_POWER_ON:
		case WAKEREASON_NEW_SQUIRREL:
			delay = delay >= 10 ? delay : 10;
			break;
		}

		server.log("Sleeping in " + delay + " for " + dur + ". Last wake reason: " + get_wake_reason());
		imp.wakeup(delay, function() {
			if (i2c) i2c.read(addr, lis3dh.INT1_SRC, 1); // Clear the interupt pin
			if (i2c) i2c.read(addr, lis3dh.TAP_SRC, 1); // Clear the interupt pin
			server.expectonlinein(dur);
			imp.deepsleepfor(dur);
		}.bindenv(this))

	}


    function remote_response(dev, method) {
        return function(data = null) {
            agent.send(dev + "." + method, data);
        }
    }
	
}


// **********************************************************************************************************************************
class lis3dh extends sensor {
    
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
	static FLAG_SEQ_READ = "\x80";

    last_state = {x = null, y = null, z = null};
    
    static name = "accelerometer";
    
    constructor(_i2c, _addr = 0x30) {
        base.constructor(_i2c, null, null, _addr);
    }
    
	function stop(callback = null) {
		hardware.pin1.configure(DIGITAL_IN);
		set_bootreason();
        if (callback) callback();
	}


    function read(callback = null, initialise = true) {
        
		if (!ready) return null;
        
        // Configure settings of the accelerometer
		if (initialise) {
			i2c.write(addr, CTRL_REG1 + "\x47");  // Turn on the sensor, enable X, Y, and Z, ODR = 50 Hz
			i2c.write(addr, CTRL_REG2 + "\x00");  // High-pass filter disabled
			i2c.write(addr, CTRL_REG3 + "\x40");  // Interrupt driven to INT1 pad
			i2c.write(addr, CTRL_REG4 + "\x00");  // FS = 2g
			i2c.write(addr, CTRL_REG5 + "\x00");  // Interrupt Not latched
			i2c.write(addr, CTRL_REG6 + "\x00");  // Interrupt Active High (not actually used)
			i2c.read(addr, INT1_SRC, 1);          // Clear any interrupts
		}
        
        local data = i2c.read(addr, (DATA_X_L[0] | FLAG_SEQ_READ[0]).tochar(), 6);
        local x = 0, y = 0, z = 0;
        if (data != null) {
            x = (data[1] - (data[1]>>7)*256) / 64.0;
            y = (data[3] - (data[3]>>7)*256) / 64.0;
            z = (data[5] - (data[5]>>7)*256) / 64.0;
            
            if (callback) callback({x = x, y = y, z = z});
            return {x = x, y = y, z = z};
        }
        
        return null;        
    }


  function free_fall_detect(callback) {

		if (!ready) return null;

		// Setup the accelerometer for sleep-polling
		i2c.write(addr, CTRL_REG1 + "\xA7");		// Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
		i2c.write(addr, CTRL_REG2 + "\x00");		// High-pass filter disabled
		i2c.write(addr, CTRL_REG3 + "\x40");		// Interrupt driven to INT1 pad
		i2c.write(addr, CTRL_REG4 + "\x00");		// FS = 2g
		i2c.write(addr, CTRL_REG5 + "\x08");		// Interrupt latched
		i2c.write(addr, CTRL_REG6 + "\x00");  		// Interrupt Active High
		i2c.write(addr, INT1_THS + "\x16");			// Set free-fall threshold = 350 mg
		i2c.write(addr, INT1_DURATION + "\x05");	// Set minimum event duration (5 samples @ 100hz = 50ms)
		i2c.write(addr, INT1_CFG + "\x95");			// Configure free-fall recognition
		i2c.read(addr, INT1_SRC, 1);          		// Clear any interrupts

		// Record the mode as free_fall for boot checks
		set_bootreason(name + ".free_fall_detect");

		// Configure pin1 for handling the interrupt
		hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {

			// Handle only active high transitions
			if (hardware.pin1.read() == 1) {

				// Call the callback 
				callback();

				imp.wakeup(1, function() {
					// Clear the interrupt after a small delay
					i2c.read(addr, INT1_SRC, 1);
				}.bindenv(this));
			}
		}.bindenv(this));
	}


  function inertia_detect(callback) {

		if (!ready) return null;

		// Work out which axes to exclude
		local init_pos = read();
		local axes = { };
		axes.x <- (math.fabs(init_pos.x) < 0.5);
		axes.y <- (math.fabs(init_pos.y) < 0.5);
		axes.z <- (math.fabs(init_pos.z) < 0.5);
		axes.cfg <- ((axes.x ? 0x02 : 0x00) | (axes.y ? 0x08 : 0x00) | (axes.z ? 0x20 : 0x00)).tochar();
		// server.log(format("Initial orientation:  X: %0.02f, Y: %0.02f, Z: %0.02f  =>  0x%02x", init_pos.x, init_pos.y, init_pos.z, axes.cfg[0]));

		// Setup the accelerometer for sleep-polling
		i2c.write(addr, CTRL_REG1 + "\xA7");		// Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
		i2c.write(addr, CTRL_REG2 + "\x00");		// High-pass filter disabled
		i2c.write(addr, CTRL_REG3 + "\x40");		// Interrupt driven to INT1 pad
		i2c.write(addr, CTRL_REG4 + "\x00");		// FS = 2g
		i2c.write(addr, CTRL_REG5 + "\x08");		// Interrupt latched
		i2c.write(addr, CTRL_REG6 + "\x00");  		// Interrupt Active High
		i2c.write(addr, INT1_THS + "\x20");			// Set movement threshold = 500 mg
		i2c.write(addr, INT1_DURATION + "\x00");	// Duration not relevant
		i2c.write(addr, INT1_CFG + axes.cfg);		// Configure intertia detection axis/axes
		i2c.read(addr, INT1_SRC, 1);          		// Clear any interrupts

		// Record the mode as free_fall for boot checks
        set_bootreason(name + ".inertia_detect");

		// Configure pin1 for handling the interrupt
		hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {

			// Handle only active high transitions
			if (hardware.pin1.read() == 1) {

				// Call the callback 
				callback();

				imp.wakeup(0.5, function() {
					// Clear the interrupt after a small delay
					i2c.read(addr, INT1_SRC, 1);
				}.bindenv(this));
			}

		}.bindenv(this));
	}


  function movement_detect(callback) {

		if (!ready) return null;

		// Setup the accelerometer for sleep-polling
		i2c.write(addr, CTRL_REG1 + "\xA7");		// Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
		i2c.write(addr, CTRL_REG2 + "\x00");		// High-pass filter disabled
		i2c.write(addr, CTRL_REG3 + "\x40");		// Interrupt driven to INT1 pad
		i2c.write(addr, CTRL_REG4 + "\x00");		// FS = 2g
		i2c.write(addr, CTRL_REG5 + "\x00");		// Interrupt latched
		i2c.write(addr, CTRL_REG6 + "\x00");  		// Interrupt Active High
		i2c.write(addr, INT1_THS + "\x10");			// Set movement threshold = ? mg
		i2c.write(addr, INT1_DURATION + "\x00");	// Duration not relevant
		i2c.write(addr, INT1_CFG + "\x6A");			// Configure intertia detection axis/axes - all three. Plus 6D.
		i2c.read(addr, INT1_SRC, 1);          		// Clear any interrupts

		// Record the mode as free_fall for boot checks
        set_bootreason(name + ".movement_detect");

		// Configure pin1 for handling the interrupt
		hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {

			// Handle only active high transitions
			if (hardware.pin1.read() == 1) {

				// Call the callback 
				callback();
			}

		}.bindenv(this));
	}


  function position_detect(callback) {

		if (!ready) return null;

		// Setup the accelerometer for sleep-polling
		i2c.write(addr, CTRL_REG1 + "\xA7");		// Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
		i2c.write(addr, CTRL_REG2 + "\x00");		// High-pass filter disabled
		i2c.write(addr, CTRL_REG3 + "\x40");		// Interrupt driven to INT1 pad
		i2c.write(addr, CTRL_REG4 + "\x00");		// FS = 2g
		i2c.write(addr, CTRL_REG5 + "\x00");		// Interrupt latched
		i2c.write(addr, CTRL_REG6 + "\x00");  		// Interrupt Active High
		i2c.write(addr, INT1_THS + "\x21");			// Set movement threshold = ? mg
		i2c.write(addr, INT1_DURATION + "\x21");	// Duration not relevant
		i2c.write(addr, INT1_CFG + "\xEA");			// Configure intertia detection axis/axes - all three. Plus AOI + 6D
		i2c.read(addr, INT1_SRC, 1);          		// Clear any interrupts

		// Configure pin1 for handling the interrupt
		hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {

			// Handle only active high transitions
			if (hardware.pin1.read() == 1) {

				// Call the callback 
				callback();
			}

		}.bindenv(this));

		// Record the mode as free_fall for boot checks
        set_bootreason(name + ".position_detect");

	}


  function click_detect(callback) {

		if (!ready) return null;

		// Setup the accelerometer for sleep-polling
		i2c.write(addr, CTRL_REG1 + "\xA7");		// Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
		i2c.write(addr, CTRL_REG2 + "\x00");		// High-pass filter disabled
		i2c.write(addr, CTRL_REG3 + "\xC0");		// Interrupt driven to INT1 pad with CLICK detection enabled
		i2c.write(addr, CTRL_REG4 + "\x00");		// FS = 2g
		i2c.write(addr, CTRL_REG5 + "\x08");		// Interrupt latched
		i2c.write(addr, CTRL_REG6 + "\x00");  		// Interrupt Active High
		i2c.write(addr, INT1_CFG + "\x00");			// Defaults
		i2c.write(addr, INT1_THS + "\x00");			// Defaults
		i2c.write(addr, INT1_DURATION + "\x00");	// Defaults
		i2c.write(addr, TAP_CFG + "\x10");			// Single click detection on Z
		i2c.write(addr, TAP_THS + "\x7F");			// Single click threshold
		i2c.write(addr, TIME_LIMIT + "\x10");		// Single click time limit
		i2c.read(addr, TAP_SRC, 1);          		// Clear any interrupts

		// Configure pin1 for handling the interrupt
		hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {

			// Handle only active high transitions
			local reason = i2c.read(addr, TAP_SRC, 1);
			if (hardware.pin1.read() == 1) {
				local xtap = (reason[0] & 0x01) == 0x01 ? 1 : 0;
				local ytap = (reason[0] & 0x02) == 0x02 ? 1 : 0;
				local ztap = (reason[0] & 0x04) == 0x04 ? 1 : 0;
				local sign = (reason[0] & 0x08) == 0x08 ? -1 : 1;
                
				// Call the callback 
				// server.log(format("Clickety clack: [X: %d, Y: %d, Z: %d, Sign: %d]", xtap, ytap, ztap, sign))
				callback();
			}
                
		}.bindenv(this));

		// Record the mode as free_fall for boot checks
        set_bootreason(name + ".click_detect");

	}
        
        
    function threshold(thresholds, callback) {
        // Read the accelerometer data
        read(function (res) {
            local state = clone last_state;
            
            if (!("axes" in thresholds) || thresholds.axes.toupper().find("X") != null) {
                if (res.x <= thresholds.low) state.x = "low";
                else if (res.x >= thresholds.high) state.x = "high";
                else state.x = "mid";
            }
            
            if (!("axes" in thresholds) || thresholds.axes.toupper().find("Y") != null) {
                if (res.y <= thresholds.low) state.y = "low";
                else if (res.y >= thresholds.high) state.y = "high";
                else state.y = "mid";
            }

            if (!("axes" in thresholds) || thresholds.axes.toupper().find("Z") != null) {
                if (res.z <= thresholds.low) state.z = "low";
                else if (res.z >= thresholds.high) state.z = "high";
                else state.z = "mid";
            }
            
            if (last_state.x != state.x || last_state.y != state.y || last_state.z != state.z) {
                last_state = clone state;
                callback(res);
            } else {
                imp.wakeup(0.1, function() {
                    threshold(thresholds, callback);
                }.bindenv(this))
            }
        }.bindenv(this))
    }


}


// **********************************************************************************************************************************
class hih6131 extends sensor {

    static WAIT = 80; // milliseconds
    
    pin_en_l = null;
    pin_drain = null;
    name = "thermistor";

    constructor(_i2c, _pin_en_l = null, _pin_drain = null, _addr = 0x4E){
        base.constructor(_i2c, _pin_en_l, _pin_drain, _addr);
    }
  
	function convert(th) {
		local t = ((((th[2]         << 6 ) | (th[3] >> 2)) * 165) / 16383.0) - 40;
		local h = ((((th[0] & 0x3F) << 8 ) | (th[1]     ))        / 163.83 );
	
		//Round to 2 decimal places
		t = (t*100).tointeger() / 100.0;
		h = (h*100).tointeger() / 100.0;

		return { temperature = t, humidity = h};
	}


	function read(callback = null) {

		if (!ready) return null;

		enable();
		i2c.write(addr, "");

		// Do a non-blocking read
		imp.wakeup(WAIT/1000.0, function() {
			local th = i2c.read(addr, "", 4);
			disable();
			if (th == null) {
				callback(null);
			} else {
				callback(convert(th));
			}
		}.bindenv(this));

	}
  
}


// **********************************************************************************************************************************
class mpl115 extends sensor {
  static WAIT = 80; // milliseconds

	a0 = null;
	b1 = null;
	b2 = null;
	c12 = null;
  
    name = "pressure";

    constructor(_i2c, _pin_en_l = null, _pin_drain = null, _addr = 0xC0) {
		base.constructor(_i2c, _pin_en_l, _pin_drain, _addr);
		if (ready) init();
    }

	function init() {
        // Create non-volatile table if it doesn't already exist
        local cache = get_nv("mpl115");
        if (cache) {
            a0  = cache.a0;
            b1  = cache.b1;
            b2  = cache.b2;
            c12 = cache.c12;
        } else {

			enable();

            // get a0, b1, b2, and c12 environmental coefficients from Freescale barometric pressure sensor U5
            local a0_msb  = i2c.read(addr, "\x04", 1);
            local a0_lsb  = i2c.read(addr, "\x05", 1);
            local b1_msb  = i2c.read(addr, "\x06", 1);
            local b1_lsb  = i2c.read(addr, "\x07", 1);
            local b2_msb  = i2c.read(addr, "\x08", 1);
            local b2_lsb  = i2c.read(addr, "\x09", 1);
            local c12_msb = i2c.read(addr, "\x0a", 1);
            local c12_lsb = i2c.read(addr, "\x0b", 1);

			disable();

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
            set_nv("mpl115", {a0 = a0, b1 = b1, b2 = b2, c12 = c12})
        }
	}


	function convert(pr) {
		local padc = ((pr[0] & 0xff) << 2) | (pr[1] & 0x03);
		local tadc = ((pr[2] & 0xff) << 2) | (pr[3] & 0x03);

		// Calculate compensated pressure from coefficients and padc
		local pcomp = a0 + ((b1 + (c12 * tadc)) * padc) + (b2 * tadc);

		// Pcomp is 0 at 50 kPa and full-scale (1023) at 115 kPa, so we scale to get kPa
		// Patm = 50 + (pcomp * ((115 - 50) / 1023))
		local p = 50 + (pcomp * (65.0 / 1023.0));
		return {pressure = p};
	}


  function read(callback = null) {
		if (!ready) return null;

		enable();
		i2c.write(addr, "\x12\xFF");
		imp.wakeup(WAIT/1000.0, function() {
			// Read out temperature and pressure ADC values from Freescale sensor
			// Both values are 10 bits, unsigned, with the high 8 bits in the MSB value
			local pr = i2c.read(0xc0, "\x00", 4);
			disable();

			if (pr == null) {
				callback(null);
			} else {
				callback(convert(pr));
			}
		}.bindenv(this));
  }

} 


// **********************************************************************************************************************************
class tsl2561 extends sensor {

    static WAIT = 450;
    static name = "ambient";
    
    constructor(_i2c, _pin_en_l = null, _pin_drain = null, _addr = 0x52) {
        base.constructor(_i2c, _pin_en_l, _pin_drain, _addr);
    }
    

    function convert(reg0, reg1) {

        local ch0 = ((reg0[1] & 0xFF) << 8) + (reg0[0] & 0xFF);
        local ch1 = ((reg1[1] & 0xFF) << 8) + (reg1[0] & 0xFF);
    
        local ratio = ch1 / ch0.tofloat();
        local lux = 0.0;
        if (ratio <= 0.5){
            lux = 0.0304*ch0 - 0.062*ch0*math.pow(ratio,1.4);
        } else if( ratio <= 0.61){
            lux = 0.0224 * ch0 - 0.031 * ch1;
        } else if( ratio <= 0.8){
            lux = 0.0128*ch0 - 0.0153*ch1;
        } else if( ratio <= 1.3){
            lux = 0.00146*ch0 - 0.00112*ch1;
        } else {
    			throw "Invalid lux calculation: " + ch0 + ", " + ch1;
          return null;
        }

		// Round to 2 decimal places
		lux = (lux*100).tointeger() / 100.0;

        // server.log(format("Ch0: 0x%04X Ch1: 0x%04X Ratio: %f Lux: %f", ch0, ch1, ratio, lux));
        return {lux = lux};
    }


    function read(callback = null) {
		if (!ready) return callback(null);

		enable();
		i2c.write(addr, "\x80\x03");
		imp.wakeup(WAIT/1000.0, function() {
			local reg0 = i2c.read(addr, "\xAC", 2);
			local reg1 = i2c.read(addr, "\xAE", 2);
			disable();

			if (reg0 == null || reg1 == null) {
				callback(null);
			} else {
				callback(convert(reg0, reg1));
			}
		}.bindenv(this));
    }

}


// **********************************************************************************************************************************
class tmp112 extends sensor {

  static WAIT = 35;

	static TEMP_REG      = 0x00;
	static CONF_REG      = 0x01;
	static T_LOW_REG     = 0x02;
	static T_HIGH_REG    = 0x03;
	static RESET_VAL     = 0x06;
	static DEG_PER_COUNT = 0.0625;
  
    static name = "temperature";

    constructor(_i2c, _addr = 0x92) {
		base.constructor(_i2c, null, null, _addr);
    }


	function read_temp(reg = 0x00, callback = null) {

		local result = i2c.read(addr, reg.tochar(), 2);
		if (result == null) return null;

		// Read a 12 bit integer for the temperature
		local temp = (result[0] << 4) | (result[1] >> 4);

		// Negate negative numbers
		if (temp & 0x800) {
			temp = -1.0 * twos_comp(temp, 0xFFF);
		}

		// Convert measured temperatures to float degrees C
		temp = temp * DEG_PER_COUNT;

		// Round to two decimal places
		temp = (temp*100).tointeger() / 100.0;

        if (callback) callback({temperature=temp});
        
		return temp;
	}


	function write_temp(reg, temp) {
		temp = (temp / DEG_PER_COUNT).tointeger();

		// Cap the mininum and maximum values to the possible range (11 bits plus a sign)
		if (temp < -2047) temp = -2047; 
		if (temp > 2047) temp = 2047;

		if (temp < 0) temp = twos_comp(temp, 0xFFF);
		temp = (temp & 0xFFF) << 4;
		return i2c.write(addr, format("%c%c%c", reg, (temp & 0xFF00) >> 8, (temp & 0x00FF)));
	}


	function twos_comp(value, mask) {
		value = ~(math.abs(value) & mask) + 1;
		return value & mask;
	}


	function print_conf(callback = null) {
        server.log("/-----------------------------------------------\\");
		local conf = i2c.read(addr, CONF_REG.tochar(), 2);
        if (conf == null) {
            server.log("TMP112 not responding");
        } else {
    		server.log(format("TMP112 Conf Reg at 0x%02x: 0x%02x%02x", addr, conf[0], conf[1]));

    		// Extended Mode
    		if (conf[1] & 0x10) {
    			server.log("TMP112 Extended Mode Enabled.");
    		} else {
    			server.log("TMP112 Extended Mode Disabled.");
    		}
    
    		// Shutdown Mode
    		if (conf[0] & 0x01) {
    			server.log("TMP112 Shutdown Enabled.");
    		} 
    		else {
    			server.log("TMP112 Shutdown Disabled.");
    		}
    
    		// One-shot Bit (Only care in shutdown mode)
    		if (conf[0] & 0x80) {
    			server.log("TMP112 One-shot Bit Set.");
    		} else {
    			server.log("TMP112 One-shot Bit Not Set.");
    		}
    
    		// Thermostat or Comparator Mode
    		if (conf[0] & 0x02) {
    			server.log("TMP112 in Interrupt Mode.");
    		} else {
    			server.log("TMP112 in Comparator Mode.");
    		}
    
    		// Alert Polarity
    		if (conf[0] & 0x04) {
    			server.log("TMP112 Alert Pin Polarity Active-High.");
    		} else {
    			server.log("TMP112 Alert Pin Polarity Active-Low.");
    		}
    
    		// Alert Pin
    		if (hardware.pin1.read()) {
    			if (conf[0] & 0x04) {
    				server.log("TMP112 Alert Pin Asserted (high).");
    			} else {
    				server.log("TMP112 Alert Pin Not Asserted (high).");
    			}
    		} else {
    			if (conf[0] & 0x04) {
    				server.log("TMP112 Alert Pin Not Asserted (low).");
    			} else {
    				server.log("TMP112 Alert Pin Asserted (low).");
    			}
    		}
    
    		// Alert Bit
    		if (conf[1] & 0x20) {
    			if (conf[0] & 0x04) {
    				server.log("TMP112 Alert Bit Set (high).");
    			} else {
    				server.log("TMP112 Alert Bit Not Set (high).");
    			}
    		} else {
    			if (conf[0] & 0x04) {
    				server.log("TMP112 Alert Bit Not Set (low).");
    			} else {
    				server.log("TMP112 Alert Bit Set (low).");
    			}
    		}
    
    		// Conversion Rate
    		local cr = (conf[1] & 0xC0) >> 6;
    		switch (cr) {
    			case 0:
    				server.log("TMP112 Conversion Rate Set to 0.25 Hz.");
    				break;
    			case 1:
    				server.log("TMP112 Conversion Rate Set to 1 Hz.");
    				break;
    			case 2:
    				server.log("TMP112 Conversion Rate Set to 4 Hz.");
    				break;
    			case 3:
    				server.log("TMP112 Conversion Rate Set to 8 Hz.");
    				break;
    			default:
    				server.error("TMP112 Conversion Rate Invalid: " + format("0x%02x",cr));
    		}
    
    		// Fault Queue
    		local fq = (conf[0] & 0x18) >> 3;
    		server.log(format("TMP112 Fault Queue shows %d Consecutive Fault(s).", fq));
    
    		// T-low register
    		local t_low = read_temp(T_LOW_REG);
    		server.log(format("TMP112 Low Temperate is %0.02f deg C.", t_low));
    
    		// T-high register
    		local t_high = read_temp(T_HIGH_REG);
    		server.log(format("TMP112 High Temperate is %0.02f deg C.", t_high));
        }
        
        server.log("\\-----------------------------------------------/");
        if (callback) callback();
	}
	

	// OS = One Shot
	// R = Converter resolution (read only)
	// F = Fault queue
	// POL = Polarity of alert pin
	// TM = Thermostat mode
	// SD = Shutdown mode
	// CR = Conversion rate
	// AL = Alert bit (read only)
	// EM = Extended mode
	function config(OS=1, F1=0, F0=0, POL=1, TM=0, SD=1, CR1=1, CR0=0, EM=0) {
		local conf = (OS<<15) | (F1<<12) | (F0<<11) | (POL<<10) | (TM<<9) | (SD<<8) | (CR1<<7) | (CR0<<6) | (EM<<4);
		i2c.write(addr, format("%c%c%c", CONF_REG, (conf & 0xFF00) >> 8, (conf & 0x00FF)));
	}


    function read(callback = null) {
		if (!ready) return callback(null);

		// Configure it for one shot read in shutdown mode
		config(1, 0, 0, 1, 0, 1, 1, 0, 0);
		imp.wakeup(WAIT/1000.0, function() {

			local result = read_temp();
			if (result == null) {
				callback(null);
			} else {
				callback({ temperature = result });
			}

		}.bindenv(this));
    }


	function thermostat(low, high, callback) {

		// Record the mode as free_fall for boot checks
        set_bootreason(name + ".thermostat");

        // Reset the device first
        reset();
        
		// Set the low and high register
		write_temp(T_LOW_REG, low);
		write_temp(T_HIGH_REG, high);

		// Turn off extended and shutdown modes, turn on thermostat mode and set the pin polarity.
		config(0, 0, 0, 0, 1, 0, 1, 0, 0);

        // Monitor pin1 for changes
        imp.wakeup(0.5, function() {
            print_conf();
        	hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {
        		// Handle only active high transitions
    			if (hardware.pin1.read() == 1) {
    				// Read the temperature which will call the callback 
    				read_temp(0x00, callback);
    			}
    		}.bindenv(this));
        }.bindenv(this));
        
	}

}


// **********************************************************************************************************************************
class battery extends sensor {

    pin = null;
    name = "battery"

    constructor(_pin) {
        base.constructor();
		pin = _pin;
		pin.configure(ANALOG_IN);
    }


    function test() {
        return true;
    }
  
    function read(callback = null) {
		local r = pin.read() / 65535.0;
		local v = hardware.voltage() * r;
		local p = 100.0 * r;
		callback({volts = v, capacity = p});
    }

}


// **********************************************************************************************************************************
class nora extends sensor {

    name = "nora"
    
    constructor() {
        base.constructor();
        
        screen_saver();
        agent.on("ping", function(data) {
            last_activity = time();
            agent.send("pong", data);
        })
    }
    
    function test() {
        return true;
    }
    
    function configure(key, val, callback = null) {
        switch (key) {
        case "timeoutpolicy": 
            local policy = (key == "RETURN_ON_ERROR") ? RETURN_ON_ERROR : SUSPEND_ON_ERROR;
            server.setsendtimeoutpolicy(policy, WAIT_TIL_SENT, 30);
            break;
    
        default:
            server.log("Unknown configuration request: " + key + " => " + val);
        }
    }


    function screen_saver() {
        imp.wakeup(10, screen_saver.bindenv(this));
        if (time() - last_activity > 60) {
            last_activity = time();
            set_bootreason(name + ".screen_saver");
            sleep();
        }
    }
    
    
    function read(sleepfor=60, offlinesamples=5, _callback = null) {
        
        // Get the default values
        local nora_data = get_nv(name + ".read");
        if (nora_data == null) {
            nora_data = {};
            nora_data.sleepfor <- sleepfor;
            nora_data.offlinesamples <- offlinesamples;
            nora_data.results <- [];
        }
        
        // Copy the list of sensors to work through
        local readlist = [];
        foreach (type,obj in registry) {
            // Skip nora and busy devices
            if (obj.ready && obj.name != "nora") {
                readlist.push(obj);
            }            
        }
        
        // Iterate through each, reading their data
        read_all(readlist, function (results) {
            // Store the results
            nora_data.results.push(results);
            // server.log("We have " + nora_data.results.len() + " samples in the buffer.")
            
            // We have results, lets process them
            if (false && server.isconnected()) {
                // We are connected, so send the results
                connected(SERVER_CONNECTED, nora_data, _callback);
            } else {
                // We are not connected, but should be
                if (nora_data.results.len() % nora_data.offlinesamples == 0) {
                    // connect, send and clear
                    server.connect(function(status) {
                        connected(status, nora_data, _callback);
                    }.bindenv(this), 30)
                } else {
                    connected(NO_SERVER, nora_data, _callback);
                }
            }
        });
    }
    
    
    function read_all(_readlist, _callback, _results = null) {
        if (_results == null) _results = [];
        if (_readlist.len() > 0) {
            // There are more sensors to read
            local obj = _readlist.pop();
            obj.read(function(res) {
                _results.push({ name = obj.name, value = res });
                read_all(_readlist, _callback, _results);
            }.bindenv(this))
        } else {
            _callback(_results);
        }
    }


    function connected(status, nora_data, _callback) {
        
        // Send and clear the results
        if (status == SERVER_CONNECTED) {
            if (_callback) {
                _callback(nora_data.results)
            } else {
                // server.log("We have " + nora_data.results.len() + " samples to send")
                agent.send(name + ".read", nora_data.results);
            }
            nora_data.results = [];
        }
            
        // Write back the results and configuration
        set_nv(name + ".read", nora_data);
        set_bootreason(name + ".read");
        
        // Go back to sleep but disconnect first
        // server.log("Sleeping for " + nora_data.sleepfor + " seconds with " + nora_data.results.len() + " sample set in the buffer.");
		sleep(nora_data.sleepfor);
    }
}


// ==================================================================================================================================
// Setup the environment 
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 30);
imp.configure("Nora v2", [], []);

// Some debug stuff
// server.log("Wake reason: " + nora.get_wake_reason());
// nora.dump_nv();

// Load up individual sensors
nora <- nora();
accel <- lis3dh(hardware.i2c89);
thermistor <- hih6131(hardware.i2c89, hardware.pin2, hardware.pin5);
pressure <- mpl115(hardware.i2c89, hardware.pin2, hardware.pin5);
ambient <- tsl2561(hardware.i2c89, hardware.pin2, hardware.pin5);
battery <- battery(hardware.pin7);
temperature <- tmp112(hardware.i2c89);

// Check if we are waking from an interrupt
local bootreason = sensor.get_bootreason();
sensor.set_bootreason();

if (hardware.wakereason() == WAKEREASON_PIN1) {
    // Send an event to the device
    switch (bootreason) {
    case null:
        break;
    case "temperature.thermostat":    
        agent.send(bootreason, {temperature=temperature.read_temp()});
        break
    default:
        agent.send(bootreason, null);
    }
} else {
	switch (bootreason) {
    case null:
        break;
	case "nora.read":
		// Don't fall through 
		return nora.read();
	}
}

// Let the device know we are ready
agent.send("ready", true);
server.log("Device started.");

