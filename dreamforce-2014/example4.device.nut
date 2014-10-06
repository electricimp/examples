
// -----------------------------------------------------------------------------
// PIN mux
irtrx <- hardware.spi189;
btn1 <- hardware.pin1;
btn2 <- hardware.pin2;
led <- hardware.pin5;
irpwm <- hardware.pin7;
irtx <- hardware.pin8;
irrx <- hardware.pin9;


// -----------------------------------------------------------------------------
class IR_tranceiver {
    /* Note that the receive loops runs at about 160 us per iteration */

	/* IR Receive Timeouts
	 * IR_RX_DONE is the max time to wait after a pulse before determining that the 
	 * pulse train is complete and stopping the reciever. */
	IR_RX_DONE					= 10000; // us

	/* The receiver is disabled between codes to prevent firing the callback multiple times (as 
	 * most remotes send the code multiple times per button press). IR_RX_DISABLE determines how
	 * long the receiver is disabled after successfully receiving a code. */
	IR_RX_DISABLE				= 0.2500; // seconds

	/* The Vishay TSOP6238TT IR Receiver IC is active-low, while a simple IR detector circuit with a
	 * IR Phototransistor and resistor will be active-high. */
	IR_INITIAL_STATE			= 0x00;
	IR_FINAL_STATE				= 0xFF;

	// PWM carrier frequency (typically 38 kHz in US, some devices use 56 kHz, especially in EU)
	CARRIER 					= 38000.0;

	// Number of times to repeat a code when sending
	CODE_REPEATS  				= 2;

	// Time to wait (in seconds) between code sends when repeating
	PAUSE_BETWEEN_SENDS 		= 0.05;

	// Limit the buffer for storing incoming codes
	NEWCODE_MAX_SIZE = 1024;

    // The pins connected to the IR receiver and transmitter 
	rx_pin = null;
	spi_pin = null;
	pwm_pin = null;

	// Callback function to execute with every IR packet received.
	callback = null;
	
	// Clock rate after SPI is configured
	clkrate = 0;

	/* 
	 * Instantiate a new IR Code Reciever
	 * 
	 * Input: 
	 * 		_rx_pin: (pin object) pin to listen to for codes. Requires a pin that supports state-change callbacks.
	 * 		_rx_idle_state: (integer) 1 or 0. State of the RX Pin when idle (no code being transmitted).
	 * 		_callback: (function) called with every IR packet received
	 */
	constructor(_rx_pin, _spi_pin, _pwm_pin, _callback) {
	    
		rx_pin = _rx_pin;
		rx_pin.configure(DIGITAL_IN, receive.bindenv(this));

        spi_pin = _spi_pin;
		clkrate = 1000.0 * spi_pin.configure(SIMPLEX_TX | NO_SCLK, 117);

        pwm_pin = _pwm_pin;
		pwm_pin.configure(PWM_OUT, 1.0/CARRIER, 0.0);

		callback = _callback;

	}

	function enable_rx() {
		rx_pin.configure(DIGITAL_IN, receive.bindenv(this));
	}

	function disable_rx() {
		rx_pin.configure(DIGITAL_IN);
	}


	/* 
	 * Receive a new IR Code on the input pin. 
	 */
	function receive() {

		
        // This makes these functions much quicker to execute
        local micros = hardware.micros.bindenv(hardware);
        local read = rx_pin.read.bindenv(rx_pin);
        
		// It took us a notional amount of time to get to here. Offset the start by this time.
		local start = micros() - 300; 
        
		// Code is stored as a string of 1's and 0's as the pulses are measured.
		local newcode = blob(NEWCODE_MAX_SIZE);
        local state = 0; // dummy value; will be set again before being used
		local dur = 0;

		local now;
		local last_change_time = start;
		local loopstart = micros();
		local last_state = read();
		
		// Loop reading the duration between state changes.
		while (true) {

			/* determine if pin has changed state since last read
			 * get a timestamp in case it has; we don't want to wait for code to execute before getting the
			 * timestamp, as this will make the reading less accurate. */
			state = read();
			now = micros();
			dur = now - last_change_time;

			if (state == last_state) {
			    // last state change was over IR_RX_DONE ago; we're done with code; quit.
				if (dur > IR_RX_DONE) break;
			} else {
			    // We have a state change, record the duration.
                newcode.writen(dur, 'w');
    			last_state = state;
    			last_change_time = now;
			}
		}
		
		// codes are sent multiple times, so disable the receiver briefly before re-enabling
        disable_rx();
        imp.wakeup(IR_RX_DISABLE, enable_rx.bindenv(this));
    
        local len = newcode.tell();
        if (len >= 5) { // Minimum length

            // Trim down the blob
            newcode.seek(0);
            newcode = newcode.readblob(len);
            
            // Check we have a start bit to work fith
            local start_high = newcode.readn('w');
            local start_low = newcode.readn('w');
            if (start_high >= 1000 && start_low >= 1000) {
        		callback(newcode);
            } else {
                server.log(format("Rejected (%d bits): %s", (newcode.len()/2), stringify(newcode)));
            }
        }
	}
	
	
	/* 
	 * Send am IR Code on the output pin. 
	 */
	function transmit(code) {
		
		// Initialise the loop
		local bytetime = 8 * (1000000.0 / clkrate);
		local level = IR_INITIAL_STATE;
	    code.seek(0);

		// now encode each bit in the code
		local carry = 0;
		local code_blob = blob();
    	for (local i = 0; i < code.len(); i+=2) {
    	    local last_carry = carry;
    	    local bit = code.readn('w');
    	    local bit_carried = bit - carry;
			local bytes = (bit_carried / bytetime).tointeger(); // Round down
			local error = (8 * ((bit_carried / bytetime) - bytes) + 0.3).tointeger(); // Round down to 0.7
		    local correction = (0xFF << (8-error)) & 0xFF; // Count the number of bits from the left
		    if (level == 0x00) correction = (~correction) & 0xFF; // Invert the correction if its a low signal
		    
			for (local k = 0; k < bytes; k++) {
				code_blob.writen(level, 'b');
			}
			if (correction != 0x00 && correction != 0xFF) {
			    code_blob.writen(correction, 'b');
    		    carry = (8 - error) * bytetime / 8;
			} else {
			    carry = 0;
			}
			
            // server.log(format("Bit length of %d (%d) µs requires %0.02f bytes, rounded to %d bytes + %d bits and %d µs carried over [%d x 0x%02X, 0x%02X]", bit, bit_carried, bit_carried/bytetime, bytes, error, carry, bytes, level, correction));
			
			// Toggle the level
			level = 0xFF - level;
		}
		
		// Clean up at the end with IR_RX_DONE µs of quiet
		local bytes = ((IR_RX_DONE*1.1) / bytetime).tointeger();
		for (local k = 0; k < bytes; k++) {
			code_blob.writen(level, 'b');
		}
		code_blob.writen(IR_FINAL_STATE, 'b')


		// the code is now written into the blob. Time to send it. 

		// ensure SPI lines are low
		spi_pin.write("\x00");

		// enable PWM carrier
		pwm_pin.write(0.5);

		// send code as many times as we've specified
		for (local i = 0; i < CODE_REPEATS; i++) {
			if (i != 0) imp.sleep(PAUSE_BETWEEN_SENDS);
			spi_pin.write(code_blob);
		}
		
		// disable pwm carrier
		pwm_pin.write(0.0);
		
		// clear the SPI lines
		spi_pin.write("\x00");
	    
	}

}


// -----------------------------------------------------------------------------
// Handles a new IR code being received
function ir_newcode(newcode) {
    local len = newcode.len();
	local newcodestr = stringify(newcode, len);
    if (learning && (len == 134 || len == 614)) {
        server.log(format("Recorded (%d bits): %s", len/2, newcodestr));
        codes[learning] <- newcode;
        agent.send("learn", newcode)
    
        // Blink the LED briefly and leave it on at the end
        blink(0.5, 10, 1);
    } else {
        server.log(format("Skipped (%d bits): %s", len/2, newcodestr));
    }
}

// Handle the stage change for button 1 - learn
function btn1_change() {
    imp.sleep(0.01);
    if (btn1.read()) {
        if ("1" in buttons) {
            transmit(buttons["1"]);
        }
    }
}


// Handle the stage change for button 2 - transmit
function btn2_change() {
    imp.sleep(0.01);
    if (btn2.read()) {
        if ("2" in buttons) {
            transmit(buttons["2"]);
        }
    }
}

// Start the learning process
function learn(key) {
    
    if (learning_timer) imp.cancelwakeup(learning_timer);
    if (key && !learning) {
        ir.enable_rx();
        blink(0.4, 2, 1);
    }
    
    if (key) {
        learning = key;
        learning_timer = imp.wakeup(60, function() {
            learning = false;
            ir.disable_rx();
            blink(0.5, 3, 0);
        })
    } else if (learning) {
        learning = false;
        ir.disable_rx();
        blink(0.5, 3, 0);
    }
}


// Store the codes from the agent
function setcodes(newcodes) {
    if (typeof newcodes == "table") {
        codes = newcodes;
    } else {
        server.log("No valid codes where stored.")
    }
}

// Store the button configuration from the agent
function setbuttons(newbuttons) {
    if (typeof newbuttons == "table") {
        buttons = newbuttons;
    } else {
        server.log("No valid buttons where stored.")
    }
}

// Transmit the provided code
function transmit(code) {
    if (code in codes) {
        ir.transmit(::codes[code]);
        local newcodestr = stringify(::codes[code]);
        server.log(format("Transmitted %s (%d bits): %s", code, ::codes[code].len()/2, newcodestr));
        blink(0.5, 1);
    } else {
        server.log(code + " is not a valid code.")
    }
}

// Blink the LED for a specified duration for a number of times
function blink(duration=1.0, times=1, final=0) {
    local speed = duration.tofloat() / times;
    for (local i = 0; i < times; i++) {
        led.write(1);
        imp.sleep(1.0*speed/3.0);
        led.write(0);
        imp.sleep(2.0*speed/3.0);
    }
    led.write(final);
}

// Takes a blob of 16-bit bytes and outputs a json array
function stringify(data, len = null) {
	data.seek(0);
	if (len == null) len = data.len();
	
	local result = "[";
	for (local i = 0; i < len; i+=2) {
		result += format("%d,", data.readn('w'));
	}
	result = result.slice(0, -1) + "]";
	return result;
}



// -----------------------------------------------------------------------------
// Configure the environment
imp.enableblinkup(true);

// Configure the IR pins
ir <- IR_tranceiver(irrx, irtrx, irpwm, ir_newcode);

// Configure the LED pin
led.configure(DIGITAL_OUT, 0);

// Configure button 1 - learn
btn1.configure(DIGITAL_IN_PULLDOWN, btn1_change);

// Configure button 2 - transmit
btn2.configure(DIGITAL_IN_PULLDOWN, btn2_change);

// Respond to various agent requests
agent.on("buttons", setbuttons);
agent.on("codes", setcodes);
agent.on("learn", learn);
agent.on("transmit", transmit);

// Setup some globals
codes <- {};
buttons <- {};
learning <- false
learning_timer <- null;

// Let the agent know the device is online and reread the configuration
agent.send("codes", "all");
agent.send("buttons", "all");

