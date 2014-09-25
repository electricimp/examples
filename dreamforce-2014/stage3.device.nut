
// -----------------------------------------------------------------------------
// PIN mux
irtrx <- hardware.uart1289;
irpwm <- hardware.pin7;
btn1 <- hardware.pin1;
btn2 <- hardware.pin2;
led <- hardware.pin5;

// -----------------------------------------------------------------------------
// CRC calculation function
function CRC (data, offset = 0) {
	local LRC = 0x00;
	for (local i = offset; i < data.len(); i++) {
		LRC = (LRC + data[i]) & 0xFF;
	}
	return ((LRC ^ 0xFF) + 1) & 0xFF;
}

// Blink the LED for a specified duration for a number of times
function blink(duration=1.0, times=1) {
    local speed = duration.tofloat() / times;
    for (local i = 0; i < times; i++) {
        led.write(0);
        imp.sleep(1.0*speed/3.0);
        led.write(1);
        imp.sleep(2.0*speed/3.0);
    }
}

// Stores the agent ID alone
function set_agentid(agentid) {
    nv.agentid <- format("%c%c%c%c%s", 0x00, 0xFF, CRC(agentid), agentid.len(), agentid);
}

// Stores the agent ID _and_ fires the IR
function fire(agentid = null) {
    if (agentid) set_agentid(agentid);
    irtrx.write(nv.agentid);
    irtrx.write(nv.agentid);
    blink(0.5, 10);
    // server.log("Fire!")
}

// Handle result reports from the agent
function handle_result(result) {
    if (result) {
        blink(1.5);
    } else {
        blink(1.5, 4);
    }
}



// -----------------------------------------------------------------------------
// This event is fired when the IR receiver has data put data in the uart buffer
// The protocol we have defined here is:
//   [0x00] [0xFF] [CRC] [LEN] [...... agentid ......]
//
rxbuf <- blob();
seen <- {};
function uart_data() {
    // Receive the string
    local rx = irtrx.readstring();
    if (rx.len() == 0) return;
    
    // Look for the two start bytes, the CRC, the length and the body.
    local sender = null;
    for (local i = 0; i < rx.len(); i++) {
        local ch = rx[i];
        switch (rxbuf.len()) {
            case 0: // Looking for a 0x00 byte
                if (ch == 0x00) rxbuf.writen(ch, 'b');
                break;
            case 1: // Looking for a 0xFF byte
                if (ch == 0xFF) rxbuf.writen(ch, 'b');
                else rxbuf.resize(0);
                break;
            case 2: // Looking for the CRC
            case 3: // Looking for the length
                rxbuf.writen(ch, 'b');
                break;
            default:
                rxbuf.writen(ch, 'b');
                if (rxbuf[3]+4 == rxbuf.len()) {
                    // Check for echos
                    if (rxbuf.tostring() != nv.agentid) {
                        // Extract the CRC and body for checking
                        local crc = rxbuf[2];
                        rxbuf.seek(4);
                        local body = rxbuf.readstring(rxbuf.len());
                        if (crc == CRC(body)) {
                            sender = body;
                        } else {
                            server.log("CRC mismatch.")
                        }
                    } else {
                        // server.log("Echo detected and discarded.");
                    }
                    rxbuf.resize(0);
                }
                break;
        }
    }
    
    
    // If we have an agentid that we haven't seen before ...
    if (sender && !(sender in seen)) {
        // Send the agent ID to the agent
        agent.send("zap", sender);
        
        // Mark that agent ID as seen for 10 seconds
        seen[sender] <- true;
        imp.wakeup(10, function() {
            delete seen[sender];
        })
    }
    
    // Blink the LED once whenever there is a UART event
    blink(0.15);

}


// -----------------------------------------------------------------------------
// Handle the stage change for button 1
function btn1_change() {
    imp.sleep(0.01);
    if (btn1.read()) {
        if (nv.agentid) {
            fire();
        } else {
            blink(3, 3);
            server.log("No agent id yet. Requesting it from the agent.");
            agent.send("getid", true);
        }
    }
}


// Handle the stage change for button 2
function btn2_change() {
}


// -----------------------------------------------------------------------------
// Initialise the environment
imp.setpowersave(true);
server.setsendtimeoutpolicy(SUSPEND_ON_ERROR, WAIT_TIL_SENT, 30);

// Make sure we have nv ram ready
if (!("nv" in getroottable())) nv <- { agentid = null };

// Capture an agent ID update from the agent. Expect this on boot of agent or device.
agent.on("agentid", set_agentid);

// Save the agent ID and fire the event
agent.on("fire", fire);

// Handle result reports from the agent
agent.on("result", handle_result)

// Configure the LED to display the result of the last request
led.configure(DIGITAL_OUT, 1);

// Configure the IR transceiver
irpwm.configure(PWM_OUT, 1.0 / 38000, 0.5);
irtrx.configure(2400, 8, PARITY_NONE, 1, NO_CTSRTS, uart_data);

// Configure button 1 to transmit the agentid
btn1.configure(DIGITAL_IN_PULLDOWN, btn1_change);

// Configure button 2 to ...
btn2.configure(DIGITAL_IN_PULLDOWN, btn2_change);

