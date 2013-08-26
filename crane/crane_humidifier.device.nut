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

// -----------------------------------------------------------------------------
const BUTTON_STATE_DOWN = 0;
const BUTTON_STATE_UP = 1;
const RELAY_OFF = 0;
const RELAY_ON = 1;
const CONNECT_TIMEOUT = 30;
const BLINKUP_TIMEOUT = 300;
const LONG_PUSH_TIME = 2000;

blinkup_enabled <- false;
function enable_blinkup() {
    if (!blinkup_enabled) {
        blinkup_enabled = true;
        imp.enableblinkup(true);
        imp.wakeup(BLINKUP_TIMEOUT, function() {
            blinkup_enabled = false;
            imp.enableblinkup(false);
        })
    }
}

connecting <- false;
function stay_online() {
    imp.wakeup(1, stay_online);
    if (!server.isconnected() && !connecting) {
        connecting = true;
        server.connect(function(status) {
            connecting = false;
            if (status == SERVER_CONNECTED) {
                server.log("Reconnected")
                send_relay();
            }
        }, CONNECT_TIMEOUT);
    }
}


function send_temp() {
    imp.wakeup(1, send_temp);
    agent.send("temp", tempsensor.read_c());
}

function send_relay() {
    agent.send("poll", water.read());
}
function set_relay(state) {
    local old_state = get_relay();
    if (old_state != state) {
        water.write(state);
        motor.write(state);
        send_relay();
    }
}
function get_relay(dummy=987654321) {
    if (dummy != 987654321) {
        agent.send("get", water.read());
    }
    return water.read();
}
function toggle_relay(dummy=null) {
    local new_state = get_relay() == RELAY_ON ? RELAY_OFF : RELAY_ON;
    set_relay(new_state);
}


// -----------------------------------------------------------------------------
/*
 * simple NTC thermistor
 *
 * Assumes thermistor is the high side of a resistive divider unless otherwise specified in constructor.
 * Low-side resistor is of the same nominal resistance as the thermistor
 */
class thermistor {

    // thermistor constants are shown on your thermistor datasheet
    // beta value (for the temp range your device will operate in)
	b_therm 		= null;
	t0_therm 		= null;
	// nominal resistance of the thermistor at room temperature
	r0_therm		= null;

	// analog input pin
	p_therm 		= null;
    p_enable        = null;
	points_per_read = null;

	high_side_therm = null;

	constructor(pin, enable_pin, b, t0, r, points = 10, _high_side_therm = true) {
        
        // Store the pins
		p_therm = pin;
		p_therm.configure(ANALOG_IN);
        
        p_enable = enable_pin;
        p_enable.configure(DIGITAL_OUT);
        p_enable.write(1);
        

		// force all of these values to floats in case they come in as integers
		this.b_therm = b * 1.0;
		this.t0_therm = t0 * 1.0;
		this.r0_therm = r * 1.0;
		this.points_per_read = points * 1.0;

		this.high_side_therm = _high_side_therm;
	}

	// read thermistor in Kelvin
	function read() {
		local vdda_raw = 0;
		local vtherm_raw = 0;
        
        p_enable.write(0);
		for (local i = 0; i < points_per_read; i++) {
			vdda_raw += hardware.voltage();
			vtherm_raw += p_therm.read();
		}
        p_enable.write(1);
        
		local vdda = (vdda_raw / points_per_read);
		local v_therm = (vtherm_raw / points_per_read) * (vdda / 65535.0);

		local r_therm = 0;	
		if (high_side_therm) {
			r_therm = (vdda - v_therm) * (r0_therm / v_therm);
		} else {
			r_therm = r0_therm / ((vdda / v_therm) - 1);
		}

		local ln_therm = math.log(r0_therm / r_therm);
		local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm);
		return t_therm;
	}

	// read thermistor in Celsius
	function read_c() {
		return this.read() - 273.15;
	}

	// read thermistor in Fahrenheit
	function read_f() {
		local temp = this.read() - 273.15;
		return (temp * 9.0 / 5.0 + 32.0);
	}
}


// -----------------------------------------------------------------------------
// Sense temperature
tempsensor <- thermistor(hardware.pin7, hardware.pin5, 4540, 298.15, 10000, 10, true);

// Turn motor off
motor <- hardware.pin1;
motor.configure(PWM_OUT, 1/300.0, 1.0);
motor.write(0);

// Turn water sensor off
water <- hardware.pin2;
water.configure(DIGITAL_OUT);
water.write(0);

agent.on("toggle", toggle_relay);
agent.on("set", set_relay);
agent.on("get", get_relay);

server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, CONNECT_TIMEOUT)
imp.configure("Crane Humidifier", [],[]);
enable_blinkup();
stay_online();
send_relay();
send_temp();

server.log("Device started");


