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
*/

/* 
 * Tom Buttner
 * tom@electricimp.com
 */

/* Globals and Constants ----------------------------------------------------*/
// button polling interval
const BTNINTERVAL 			= 0.15;
// temp measurement interval;
const TMPINTERVAL 			= 60.0;

/* Class and Function Definitions -------------------------------------------*/

/*
 * simple NTC thermistor
 *
 * Assumes thermistor is the high side of a resistive divider.
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
	points_per_read = null;

	high_side_therm = null;

	constructor(pin, b, t0, r, points = 10, _high_side_therm = true) {
		this.p_therm = pin;
		this.p_therm.configure(ANALOG_IN);

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
		for (local i = 0; i < points_per_read; i++) {
			vdda_raw += hardware.voltage();
			vtherm_raw += p_therm.read();
		}
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

/*
 * TMP112 Digital Temperature Sensor
 * 
 * Communicates via I2C
 * http://www.ti.com/lit/ds/symlink/tmp112.pdf
 *
 */
class tmp112 {
	// static values (address offsets)
	static TEMP_REG 		= 0x00;
	static CONF_REG 		= 0x01;
	static T_LOW_REG		= 0x02;
	static T_HIGH_REG		= 0x03;
	// Send this value on general-call address (0x00) to reset device
	static RESET_VAL 		= 0x06;
	// ADC resolution in degrees C
	static DEG_PER_COUNT 	= 0.0625;

	// i2c address
	addr 	= null;
	// i2c bus (passed into constructor)
	i2c		= null;
	// interrupt pin (configurable)
	int_pin = null;
	// configuration register value
	conf 	= null;

	// Default temp thresholds
	T_LOW 	= 75; // Celsius
	T_HIGH 	= 80; 

	// Default mode
	EXTENDEDMODE 	= false;
	SHUTDOWN 		= false;

	// conversion ready flag
	CONV_READY 		= false;

	// interrupt state - some pins require us to poll the interrupt pin
	LAST_INT_STATE 	= null;
	POLL_INTERVAL 	= null;
	INT_CALLBACK 	= null;

	// generic temp interrupt
	function tmp112_int(state) {
		server.log("Device: TMP112 Interrupt Occurred. State = "+state);
	}

	/*
	 * Class Constructor. Takes 3 to 5 arguments:
	 * 		_i2c: 					Pre-configured I2C Bus
	 *		_addr:  				I2C Slave Address for device. 8-bit address.
	 * 		_int_pin: 				Pin to which ALERT line is connected
	 * 		_alert_poll_interval: 	Interval (in seconds) at which to poll the ALERT pin (optional)
	 *		_alert_callback: 		Callback to call on ALERT pin state changes (optional)
	 */
	constructor(_i2c, _addr, _int_pin, _alert_poll_interval = 1, _alert_callback = null) {
		this.addr = _addr;
		this.i2c = _i2c;
		this.int_pin = _int_pin;

		/* 
		 * Top-level program should pass in Pre-configured I2C bus.
		 * This is done to allow multiple devices to be constructed on the bus
		 * without reconfiguring the bus with each instantiation and causing conflict.
		 */
		//this.i2c.configure(CLOCK_SPEED_100_KHZ);
		this.int_pin.configure(DIGITAL_IN);
		LAST_INT_STATE = this.int_pin.read();
		POLL_INTERVAL = _alert_poll_interval;
		if (_alert_callback) {
			INT_CALLBACK = _alert_callback;
		} else {
			INT_CALLBACK = this.tmp112_int;
		}
		read_conf();
	}

	/* 
	 * Check for state changes on the ALERT pin.
	 *
	 * Not all imp pins allow state-change callbacks, so ALERT pin interrupts are implemented with polling
	 *
	 */ 
	function poll_interrupt() {
		imp.wakeup(POLL_INTERVAL, poll_interrupt);
		local int_state = int_pin.read();
		if (int_state != LAST_INT_STATE) {
			LAST_INT_STATE = int_state;
			INT_CALLBACK(state);
		}
	}

	/* 
	 * Take the 2's complement of a value
	 * 
	 * Required for Temp Registers
	 *
	 * Input:
	 * 		value: number to take the 2's complement of 
	 * 		mask:  mask to select which bits should be complemented
	 *
	 * Return:
	 * 		The 2's complement of the original value masked with the mask
	 */
	function twos_comp(value, mask) {
		value = ~(value & mask) + 1;
		return value & mask;
	}

	/* 
	 * General-call Reset.
	 * Note that this may reset other devices on an i2c bus. 
	 *
	 * Logging is included to prevent this from silently affecting other devices
	 */
	function reset() {
		server.log("TMP112 Class issuing General-Call Reset on I2C Bus.");
		i2c.write(0x00,format("%c",RESET_VAL));
		// update the configuration register
		read_conf();
		// reset the thresholds
		T_LOW = 75;
		T_HIGH = 80;
	}

	/* 
	 * Read the TMP112 Configuration Register
	 * This updates several class variables:
	 *  - EXTENDEDMODE (determines if the device is in 13-bit extended mode)
	 *  - SHUTDOWN 	   (determines if the device is in low power shutdown mode / one-shot mode)
	 * 	- CONV_READY   (determines if the device is done with last conversion, if in one-shot mode)
	 */
	function read_conf() {
		conf = i2c.read(addr,format("%c",CONF_REG), 2);
		// Extended Mode
		if (conf[1] & 0x10) {
			EXTENDEDMODE = true;
		} else {
			EXTENDEDMODE = false;
		}
		if (conf[0] & 0x01) {
			SHUTDOWN = true;
		} else {
			SHUTDOWN = false;	
		}
		if (conf[1] & 0x10) {
			CONV_READY = true;
		} else {
			CONV_READY = false;
		}
	}

	/*
	 * Read, parse and log the current state of each field in the configuration register
	 *
	 */
	function print_conf() {
		conf = i2c.read(addr,format("%c",CONF_REG), 2);
		server.log(format("TMP112 Conf Reg at 0x%02x: %02x%02x",addr,conf[0],conf[1]));
		
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
		if (int_pin.read()) {
			if (conf[0] & 0x04) {
				server.log("TMP112 Alert Pin Asserted.");
			} else {
				server.log("TMP112 Alert Pin Not Asserted.");
			}
		} else {
			if (conf[0] & 0x04) {
				server.log("TMP112 Alert Pin Not Asserted.");
			} else {
				server.log("TMP112 Alert Pin Asserted.");
			}
		}

		// Alert Bit
		if (conf[1] & 0x20) {
			server.log("TMP112 Alert Bit  1");
		} else {
			server.log("TMP112 Alert Bit: 0");
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
				server.error("TMP112 Conversion Rate Invalid: "+format("0x%02x",cr));
		}

		// Fault Queue
		local fq = (conf[0] & 0x18) >> 3;
		server.log(format("TMP112 Fault Queue shows %d Consecutive Fault(s).", fq));
	}

	/* 
	 * Enter or exit low-power shutdown mode
	 * In shutdown mode, device does one-shot conversions
	 * 
	 * Device comes up with shutdown disabled by default (in continuous-conversion/thermostat mode)
	 * 
	 * Input: 
	 * 		State (bool): true to enable shutdown/one-shot mode.
	 */
	function shutdown(state) {
		read_conf();
		local new_conf = 0;
		if (state) {
			new_conf = ((conf[0] | 0x01) << 8) + conf[1];
		} else {
			new_conf = ((conf[0] & 0xFE) << 8) + conf[1];
		}
		i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
		// read_conf() updates the variables for shutdown and extended modes
		read_conf();
	}

	/* 
	 * Enter or exit 13-bit extended mode
	 *
	 * Input:
	 * 		State (bool): true to enable 13-bit extended mode
	 */
	function set_extendedmode(state) {
		read_conf();
		local new_conf = 0;
		if (state) {
			new_conf = ((conf[0] << 8) + (conf[1] | 0x10));
		} else {
			new_conf = ((conf[0] << 8) + (conf[1] & 0xEF));
		}
		i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
		read_conf();
	}

	/*
	 * Set the T_low threshold register
	 * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
	 * 
	 * Input: 
	 * 		t_low: new threshold register value in degrees Celsius
	 *
	 */
	function set_t_low(t_low) {
		t_low = (t_low / DEG_PER_COUNT).tointeger();
		local mask = 0x0FFF;
		if (EXTENDEDMODE) {
			mask = 0x1FFF;
			if (t_low < 0) {
				twos_comp(t_low, mask);
			}
			t_low = (t_low & mask) << 3;
		} else {
			if (t_low < 0) {
				twos_comp(t_low, mask);
			}
			t_low = (t_low & mask) << 4;
		}
		server.log(format("set_t_low setting register to 0x%04x (%d)",t_low,t_low));
		i2c.write(addr, format("%c%c%c",T_LOW_REG,(t_low & 0xFF00) >> 8, (t_low & 0xFF)));
		T_LOW = t_low;
	}

	/*
	 * Set the T_high threshold register
	 * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
	 * 
	 * Input:
	 *		t_high: new threshold register value in degrees Celsius
	 *
	 */
	function set_t_high(t_high) {
		t_high = (t_high / DEG_PER_COUNT).tointeger();
		local mask = 0x0FFF;
		if (EXTENDEDMODE) {
			mask = 0x1FFF;
			if (t_high < 0) {
				twos_comp(t_high, mask);
			}
			t_high = (t_high & mask) << 3;
		} else {
			if (t_high < 0) {
				twos_comp(t_high, mask);
			}
			t_high = (t_high & mask) << 4;
		}
		server.log(format("set_t_high setting register to 0x%04x (%d)",t_high,t_high));
		i2c.write(addr, format("%c%c%c",T_HIGH_REG,(t_high & 0xFF00) >> 8, (t_high & 0xFF)));
		T_HIGH = t_high;
	}

	/* 
	 * Read the current value of the T_low threshold register
	 *
	 * Return: value of register in degrees Celsius
	 */
	function get_t_low() {
		local result = i2c.read(addr, format("%c",T_LOW_REG), 2);
		local t_low = (result[0] << 8) + result[1];
		//server.log(format("get_t_low got: 0x%04x (%d)",t_low,t_low));
		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (EXTENDEDMODE) {
			//server.log("get_t_low: TMP112 in extended mode.")
			sign_mask = 0x1000;
			mask = 0x1FFF;
			offset = 3;
		}
		t_low = (t_low >> offset) & mask;
		if (t_low & sign_mask) {
			//server.log("get_t_low: Tlow is negative.");
			t_low = -1.0 * (twos_comp(t_low,mask));
		}
		//server.log(format("get_t_low: raw value is 0x%04x (%d)",t_low,t_low));
		T_LOW = (t_low.tofloat() * DEG_PER_COUNT);
		return T_LOW;
	}

	/*
	 * Read the current value of the T_high threshold register
	 *
	 * Return: value of register in degrees Celsius
	 */
	function get_t_high() {
		local result = i2c.read(addr, format("%c",T_HIGH_REG), 2);
		local t_high = (result[0] << 8) + result[1];
		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (EXTENDEDMODE) {
			sign_mask = 0x1000;
			mask = 0x1FFF;
			offset = 3;
		}
		t_high = (t_high >> offset) & mask;
		if (t_high & sign_mask) {
			t_high = -1.0 * (twos_comp(t_high,mask));
		}
		T_HIGH = (t_high.tofloat() * DEG_PER_COUNT);
		return T_HIGH;
	}

	/* 
	 * If the TMP112 is in shutdown mode, write the one-shot bit in the configuration register
	 * This starts a conversion. 
	 * Conversions are done in 26 ms (typ.)
	 *
	 */
	function start_conversion() {
		read_conf();
		local new_conf = 0;
		new_conf = ((conf[0] | 0x80) << 8) + conf[1];
		i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
	}

	/*
	 * Read the temperature from the TMP112 Sensor
	 * 
	 * Returns: current temperature in degrees Celsius
	 */
	function read_c() {
		if (SHUTDOWN) {
			start_conversion();
			CONV_READY = false;
			local timeout = 30; // timeout in milliseconds
			local start = hardware.millis();
			while (!CONF_READY) {
				if ((hardware.millis() - start) > timeout) {
					server.error("Device: TMP112 Timed Out waiting for conversion.");
					return 0;
				}
			}
		}
		local result = i2c.read(addr, format("%c", TEMP_REG), 2);
		local temp = (result[0] << 8) + result[1];

		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (EXTENDEDMODE) {
			mask = 0x1FFF;
			sign_mask = 0x1000;
			offset = 3;
		}

		temp = (temp >> offset) & mask;
		if (temp & sign_mask) {
			temp = -1.0 * (twos_comp(temp, mask));
		}

		return temp * DEG_PER_COUNT;
	}

	/* 
	 * Read the temperature from the TMP112 Sensor and convert
	 * 
	 * Returns: current temperature in degrees Fahrenheit
	 */
	function read_f() {
		return (read_c() * 9.0 / 5.0 + 32.0);
	}
}

/*
 * Generic Class to learn IR Remote Control Codes 
 * Useful for:
 * 		- TV Remotes
 *		- Air conditioner / heater units
 * 		- Fans / remote-control light fixtures
 *		- Other things not yet attempted!
 *
 * For more information on Differential Pulse Position Modulation, see
 * http://learn.adafruit.com/ir-sensor
 *
 */
class IR_receiver {

	/* Receiver Thresholds in us. Inter-pulse times < THRESH_0 are zeros, 
	 * while times > THRESH_0 but < THRESH_1 are ones, and times > THRESH_1 
	 * are either the end of a pulse train or the start pulse at the beginning of a code */
	THRESH_0					= 600;
	THRESH_1					= 1500;

	/* IR Receive Timeouts
	 * IR_RX_DONE is the max time to wait after a pulse before determining that the 
	 * pulse train is complete and stopping the reciever. */
	IR_RX_DONE					= 4000; // us

	/* IR_RX_TIMEOUT is an overall timeout for the receive loop. Prevents the device from
	 * locking up if the IR signal continues to oscillate for an unreasonable amount of time */
	IR_RX_TIMEOUT 				= 1500; // ms

	/* The receiver is disabled between codes to prevent firing the callback multiple times (as 
	 * most remotes send the code multiple times per button press). IR_RX_DISABLE determines how
	 * long the receiver is disabled after successfully receiving a code. */
	IR_RX_DISABLE				= 0.2500; // seconds

	/* The Vishay TSOP6238TT IR Receiver IC is active-low, while a simple IR detector circuit with a
	 * IR Phototransistor and resistor will be active-high. */
	IR_IDLE_STATE				= 1;

	rx_pin = null;

	/* Name of the callback to send to the agent when a new code is recieved. 
	 * This is done instead of just returning the code because this class is called as a state-change callback; 
	 * The main loop will not have directly called receive() and thus will not be prepared to receive the code. */
	agent_callback = null;

	/* 
	 * Receive a new IR Code on the input pin. 
	 * 
	 * This function is configured as a state-change callback on the receive pin in the constructor,
	 * so it must be defined before the constructor.
	 */
	function receive() {

		// Code is stored as a string of 1's and 0's as the pulses are measured.
		local newcode = array(256);
		local index = 0;

		local last_state = rx_pin.read();
		local duration = 0;

		local start = hardware.millis();
		local last_change_time = hardware.micros();

		local state = 0;
		local now = start;

		/* 
		 * This loop runs much faster with while(1) than with a timeout check in the while condition
		 */
		while (1) {

			/* determine if pin has changed state since last read
			 * get a timestamp in case it has; we don't want to wait for code to execute before getting the
			 * timestamp, as this will make the reading less accurate. */
			state = rx_pin.read();
			now = hardware.micros();

			if (state == last_state) {
				// last state change was over IR_RX_DONE ago; we're done with code; quit.
				if ((now - last_change_time) > IR_RX_DONE) {
					break;
				} else {
					// no state change; go back to the top of the while loop and check again
					continue;
				}
			}

			// check and see if the variable (low) portion of the pulse has just ended
			if (state != IR_IDLE_STATE) {
				// the low time just ended. Measure it and add to the code string
				duration = now - last_change_time;
				
				if (duration < THRESH_0) {
					newcode[index++] = 0;
				} else if (duration < THRESH_1) {
					newcode[index++] = 1;
				} 
			}

			last_state = state;
			last_change_time = now;

			// if we're here, we're currently measuring the low time of a pulse
			// just wait for the next state change and we'll tally it up
		}

		// codes have to end with a 1, effectively, because of how they're sent
		newcode[index++] = 1;

		// codes are sent multiple times, so disable the receiver briefly before re-enabling
		disable();
		imp.wakeup(IR_RX_DISABLE, enable.bindenv(this));

		local result = stringify(newcode, index);
		agent.send(agent_callback, result);
	}

	/* 
	 * Instantiate a new IR Code Reciever
	 * 
	 * Input: 
	 * 		_rx_pin: (pin object) pin to listen to for codes. 
	 *			Requires a pin that supports state-change callbacks.
	 * 		_rx_idle_state: (integer) 1 or 0. State of the RX Pin when idle (no code being transmitted).
	 * 		_agent_callback: (string) string to send to the agent to indicate the agent callback for a new code.
	 * 		
	 * 		OPTIONAL:
	 * 
	 * 		_thresh_0: (integer) threshold in microseconds for a "0". Inter-pulse gaps shorter than this will 
	 * 			result in a zero being received.
	 *		_thresh_1: (integer) threshold in microseconds for a "1". Inter-pulse gaps longer than THRESH_0 but
	 * 			shorter than THRESH_1 will result in a 1 being received. Gaps longer than THRESH_1 are ignored.
	 *		_ir_rx_done: (integer) time in microseconds to wait for the next pulse before determining that the end
	 * 			of a pulse train has been reached. 
	 *		_ir_rx_timeout: (integer) max time in milliseconds to listen to a new code. Prevents lock-up if the 
	 *			IR signal oscillates for an unreasonable amount of time.
	 * 		_ir_rx_disable: (integer) time in seconds to disable the receiver after successfully receiving a code.
	 */
	constructor(_rx_pin, _rx_idle_state, _agent_callback, _thresh_0 = null, _thresh_1 = null,
		_ir_rx_done = null, _ir_rx_timeout = null, _ir_rx_disable = null) {
		this.rx_pin = _rx_pin;
		rx_pin.configure(DIGITAL_IN, receive.bindenv(this));

		IR_IDLE_STATE = _rx_idle_state;

		agent_callback = _agent_callback;

		/* If any of the timeouts were passed in as arguments, override the default value for that
		 * timeout here. */
		if (_thresh_0) {
			THRESH_0 = _thresh_0;
		}

		if (_thresh_1) {
			THRESH_1 = _thresh_1;
		}

		if (_ir_rx_done) {
			IR_RX_DONE = _ir_rx_done;
		}

		if (_ir_rx_timeout) {
			IR_RX_TIMEOUT = _ir_rx_timeout;
		}

		if (_ir_rx_disable) {
			IR_RX_DISABLE = _ir_rx_disable;
		}
	}

	function enable() {
		rx_pin.configure(DIGITAL_IN, receive.bindenv(this));
	}

	function disable() {
		rx_pin.configure(DIGITAL_IN);
	}

	function stringify(data, len) {
		local result = "";
		for (local i = 0; i < len; i++) {
			result += format("%d",data[i]);
		}
		return result;
	}
}

/*
 * Generic Class to send IR Remote Control Codes
 * Useful for:
 * 		- TV Remotes
 *		- Air conditioner / heater units
 * 		- Fans / remote-control light fixtures
 *		- Other things not yet attempted!
 * For more information on Differential Pulse Position Modulation, see
 * http://learn.adafruit.com/ir-sensor
 *
 */
class IR_transmitter {

 	/* The following variables set the timing for the transmitter and can be overridden in the constructor. 
 	 * The timing for the start pulse, marker pulses, and 1/0 time will vary from device to device. */

 	// Times for start pulse (in microseconds)
	START_TIME_HIGH 			= 3300.0;
	START_TIME_LOW				= 1700.0;

	/* Pulses are non-information bearing; the bit is encoded in the break after each pulse.
	 * PULSE_TIME sets the width of the pulse in microseconds. */
	PULSE_TIME 					= 420.0;

	// Time between pulses to mark a "1" (in microseconds)
	TIME_LOW_1					= 1200.0;
	// Time between pulses to mark a "0" (in microseconds)
	TIME_LOW_0					= 420.0;

	// PWM carrier frequency (typically 38 kHz in US, some devices use 56 kHz, especially in EU)
	CARRIER 					= 38000.0;

	// Number of times to repeat a code when sending
	CODE_REPEATS  				= 2;

	// Time to wait (in seconds) between code sends when repeating
	PAUSE_BETWEEN_SENDS 		= 0.05;

	spi = null;
	pwm = null;

	/* 
	 * Instantiate a new IR_transmitter
	 *
	 * Input: 
	 * 		_spi (spi object): SPI bus to use when sending codes
	 * 		_pwm (pin object): PWM-capable pin object
	 *
	 * The objects will be configured when this.send() is called.
	 */
	constructor(_spi, _pwm) {
		this.spi = _spi;
		this.pwm = _pwm;
	}

	/* 
	 * Send an IR Code over the IR LED 
	 * 
	 * Input: 
	 * 		IR Code (string). Each bit is represented by a literal character in the string.
	 *			Example: "111000001110000001000000101111111"
	 * 			Both states are represented by a fixed-width pulse, followed by a low time which varies to 
	 * 			indicate the state. 
	 *
	 * Return:
	 * 		None
	 */
	function send(code) {

		/* Configure the SPI and PWM for each send. 
		 * This ensures that they're not in an unknown state if reconfigured by other code between sends */
		this.pwm.configure(PWM_OUT, 1.0/CARRIER, 0.0);
		local clkrate = 1000.0 * spi.configure(SIMPLEX_TX,117);
		local bytetime = 8 * (1000000.0/clkrate);
		// ensure SPI lines are low
		spi.write("\x00");

		// calculate the number of bytes we need to send each signal
		local start_bytes_high = (START_TIME_HIGH / bytetime).tointeger();
		local start_bytes_low =  (START_TIME_LOW / bytetime).tointeger();
		local pulse_bytes = (PULSE_TIME / bytetime).tointeger();
		local bytes_1 = (TIME_LOW_1 / bytetime).tointeger();
		local bytes_0 = (TIME_LOW_0 / bytetime).tointeger();

		local code_blob = blob(pulse_bytes); // blob will grow as it is written

		// Write the start sequence into the blob
		for (local i = 0; i < start_bytes_high; i++) {
			code_blob.writen(0xFF, 'b');
		}
		for (local i = 0; i < start_bytes_low; i++) {
			code_blob.writen(0x00, 'b');
		}

		// now encode each bit in the code
		foreach (bit in code) {
			// this will be set when we figure out if this bit in the code is high or low
			local low_bytes = 0;
			// first, encode the pulse (same for both states)aa
			for (local j = 0; j < pulse_bytes; j++) {
				code_blob.writen(0xFF,'b');
			}

			// now, figure out if the bit is high or low
			// ascii code for "1" is 49 ("0" is 48)
			if (bit == 49) {
				//server.log("Encoding 1");
				low_bytes = bytes_1;
			} else {
				//server.log("Encoding 0");
				low_bytes = bytes_0;
			}

			// write the correct number of low bytes to the blob, then check the next bit
			for (local k = 0; k < low_bytes; k++) {
				code_blob.writen(0x00,'b');
			}
		}
			
		// the code is now written into the blob. Time to send it. 

		// enable PWM carrier
		pwm.write(0.5);

		// send code as many times as we've specified
		for (local i = 0; i < CODE_REPEATS; i++) {
			spi.write(code_blob);
			// clear the SPI bus
			spi.write("\x00");
			imp.sleep(PAUSE_BETWEEN_SENDS);
		}
		
		// disable pwm carrier
		pwm.write(0.0);
		// clear the SPI lines
		spi.write("\x00");
	}

	/* 
	 * Update the timing parameters of the IR_transmitter.
	 *
	 * This is generally necessary when switching between devices or device manufacturers, 
	 * 	as different implementations use different timing.
	 *
	 * Input: 
	 * 		_start_time_high: (integer) High time of start pulse, in microseconds
	 *		_start_time_low:  (integer) Low time of start pulse, in microseconds
	 * 		_pulse_time: 	  (integer) High time (non-data-bearing) of marker pulses, in microseconds
	 * 		_time_low_1: 	  (integer) Low time after marker pulse to designate a 1, in microseconds
	 * 		_time_low_0: 	  (integer) Low time after marker pulse to designate a 0, in microseconds
	 * 		_carrier: 		  (integer) Carrier frequency for the IR signal, in Hz
	 * 		_code_repeats: 	  (integer) Number of times to repeat a code when sending
	 * 		_pause: 		  (float) 	Time to pause between code sends when repeating (in seconds)
	 *
	 */
	function set_timing(_start_time_high, _start_time_low, _pulse_time, _time_low_1, _time_low_0, 
		_carrier, _code_repeats, _pause) {

	 	START_TIME_HIGH 	= _start_time_high * 1.0;
	  	START_TIME_LOW 		= _start_time_low * 1.0;

	  	PULSE_TIME 			= _pulse_time * 1.0;

	  	TIME_LOW_1 			= _time_low_1 * 1.0;
	  	TIME_LOW_0 			= _time_low_0 * 1.0;

	  	CARRIER 			= _carrier * 1.0;

	  	CODE_REPEATS 		= _code_repeats;
	  	PAUSE_BETWEEN_SENDS = _pause;
	 }
}

function poll_btn() {
	imp.wakeup(BTNINTERVAL, poll_btn);
	if (btn.read()) {
		// button released
	} else {
		server.log("Button Pressed");
	}
}

function temp_alert(state) {
	server.log("Temp Alert Occurred, state = "+state);
}

function poll_temp() {
	imp.wakeup(TMPINTERVAL, poll_temp);

	server.log(format("Thermistor Temp: %.1f K (%.1f C, %.1f F)", t_analog.read(), t_analog.read_c(), t_analog.read_f()));
	server.log(format("TMP112 Temp: %.2f C (%.2f F)",t_digital.read_c(),t_digital.read_f()));
}

/* AGENT CALLBACKS ----------------------------------------------------------*/

agent.on("send_code", function(code) {
	sender.send(code);
	server.log("Code sent ("+code.len()+").");
});

agent.on("set_timing", function(target) {
	/*
	server.log("Device: got new target device information");
	foreach (key, value in target) {
		server.log(key+" : "+value);
	}
	*/
	sender.set_timing(target.START_TIME_HIGH, target.START_TIME_LOW, target.PULSE_TIME, target.TIME_LOW_1,
		target.TIME_LOW_0, target.CARRIER, 4, target.PAUSE_BETWEEN_SENDS);
	server.log("Device timing set.");
});

/* RUNTIME STARTS HERE ------------------------------------------------------*/

imp.configure("Sana",[],[]);
imp.enableblinkup(true);

// instantiate sensor classes
t_analog <- thermistor(hardware.pinA, 4250, 298.15, 10000.0, 2);
hardware.i2c89.configure(CLOCK_SPEED_100_KHZ);
t_digital <- tmp112(hardware.i2c89, 0x92, hardware.pinB, 1.0, temp_alert);
t_digital.reset();

btn <- hardware.pin6;
btn.configure(DIGITAL_IN_PULLUP);

// instantiate an IR receiver and supply it with the name of the agent callback to call on a new code
learn <- IR_receiver(hardware.pin2, 1, "newcode");

// instantiate an IR transmitter
sender <- IR_transmitter(hardware.spi257, hardware.pin1);

imp.wakeup(1.0, function() {
	// start the temp polling loop
	poll_temp();

	// pin 6 doesn't support state change callbacks, so we have to poll
	poll_btn();
});

