// AS3911 Electric Imp Olive Board
// Pin 1: IRQ
// Pin 2: MISO
// Pin 5: SCLK
// Pin 7: MOSI
// Pin 8: CS_L
// Pin 9: LED_Red
// Pin 6: GPIO_TX
// Pin A: Button 1
// Pin B: Button 2
// Pin C: LED_Green
// Pin D: GPIO
// Pin E: GPIO_RX



// =============================================================================
// Timer class: Implements a simple timer class with one-off and interval timers
//              all of which can be cancelled.
//
// Author: Aron
// Created: October, 2013
//
class timer {

    cancelled = false;
    paused = false;
    running = false;
    callback = null;
    interval = 0;
    params = null;
    send_self = false;
    static timers = [];

    // -------------------------------------------------------------------------
    constructor(_params = null, _send_self = false) {
        params = _params;
        send_self = _send_self;
        timers.push(this); // Prevents scoping death
    }

    // -------------------------------------------------------------------------
    function _cleanup() {
        foreach (k,v in timers) {
            if (v == this) return timers.remove(k);
        }
    }
    
    // -------------------------------------------------------------------------
    function update(_params) {
        params = _params;
        return this;
    }

    // -------------------------------------------------------------------------
    function set(_duration, _callback) {
        assert(running == false);
        callback = _callback;
        running = true;
        imp.wakeup(_duration, alarm.bindenv(this))
        return this;
    }

    // -------------------------------------------------------------------------
    function repeat(_interval, _callback) {
        assert(running == false);
        interval = _interval;
        return set(_interval, _callback);
    }

    // -------------------------------------------------------------------------
    function cancel() {
        cancelled = true;
        return this;
    }

    // -------------------------------------------------------------------------
    function pause() {
        paused = true;
        return this;
    }

    // -------------------------------------------------------------------------
    function unpause() {
        paused = false;
        return this;
    }

    // -------------------------------------------------------------------------
    function alarm() {
        if (interval > 0 && !cancelled) {
            imp.wakeup(interval, alarm.bindenv(this))
        } else {
            running = false;
            _cleanup();
        }

        if (callback && !cancelled && !paused) {
            if (!send_self && params == null) {
                callback();
            } else if (send_self && params == null) {
                callback(this);
            } else if (!send_self && params != null) {
                callback(params);
            } else  if (send_self && params != null) {
                callback(this, params);
            }
        }
    }
}




// =============================================================================
// Constants
// SPI Clock Frequency in kHz
// (2MHz may be unstable due to bug in AS3911, check errata document)
const FREQ = 6000;
const SLEEP_TIME = 20;     // Number of seconds to wait before we go to sleep
const CARD_RESET_TIME = 1; // Number of seconds after inactivity before we assume no card is present and we are ready to detect again
const OFFLINE_MODE = 1;    // Set to 1 to put the imp into sleep and offline as quickly as possible
const SKIP_CAP_SENSE = 0;  // Set to 1 to avoid cap sense and continuously poll for cards (chews memory)


// Log levels
enum LOGS {
    TRACE = 0,
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATAL
}
VERBOSITY <- LOGS.INFO;


// Receive types
enum RECEIVE_TYPE {
    UNKNOWN = 0
    ATQA = 1
    ANTICOLLISION = 2
    SAK = 3
    ATS = 4
    PPSR = 5
}

class AS3911
{
    receiveType = null;     // Type of Recieved data
    atqa = null;            // Answer to REQA
	cardPresent = null;	    // Flag for detectomg physical presence of tag through cap sensor, etc.
	UID = null;			    // Unique ID for RFID card
    CID = null;        	    // Card ID chosen by the reader for the card we are Working with (our AS3911)
	cascadeLevel = null;	// Cascade level during select / anticollision process
    UIDsize = null;         // size of UID; should be 1, 2, 3 for single, double, triple respectively. Single = 4 bytes, double = 7 bytes, triple = 10 bytes
    resetTime = null; 		// Time counter before we sleep
    interfaceBytes = null; 	// Interface Bytes for ISO 14443 A card
    historicalBytes = null; // Historical Bytes for ISO 14443 A card
    stopCapInterrupt = null;// Flag used to prevent Capacitance measurements from interrupting protocol flow
    errorDetected = false;  // A bit collision has been detected
    irq_timer = null;       // Holds the timer for polling the IRQ

	// Alias objects
	irq = null;	// interrupt pin
	spi = null;	// serial port
	cs_l = null;	// chip select

	constructor(interruptPin, serialPort, chipSelect){

		receiveType = 0;
		atqa = 0;      
		cardPresent = 0;
		UID = blob();
        CID = 1; 
		cascadeLevel = 1;
        UIDsize = 0;
        resetTime = time() + CARD_RESET_TIME;
        interfaceBytes = blob();
        historicalBytes = blob();
        stopCapInterrupt = false;
        errorDetected = false;

		irq = interruptPin;
		spi = serialPort;
		cs_l = chipSelect;
		
        // Configure I/O
        irq.configure(DIGITAL_IN_WAKEUP, interruptHandler.bindenv(this));
        spi.configure(CLOCK_IDLE_LOW | CLOCK_2ND_EDGE, FREQ);
        cs_l.configure(DIGITAL_OUT);
        cs_l.write(1);
		
		initialize();
        irq_timer = timer().repeat(1, pollIRQ.bindenv(this));
	}
	
	// Initializes the device
	function initialize() {

        directCommand(0xC1);    // (C1) Set Default
        directCommand(0xC2);    // (C2) Clear
        regWrite(0x00, 0x0F);   // IO Config 1 - Disable MCU_CLK output
        regWrite(0x01, 0x80);   // IO Config 2 - Defaults
        regWrite(0x02, 0x00);   // Operation Control - Defaults, power-down mode
        regWrite(0x03, 0x08);   // Mode Definition - ISO14443a (no auto rf collision)
        regWrite(0x04, 0x00);   // Bit Rate Definition - fc/128 (~106kbit/s) lowest
        regWrite(0x0E, 0x04);   // Mask Receive Timer - 4 steps, ~19us (minimum)
        regWrite(0x0F, 0x00);   // No-response Timer - 21 steps, ~100us (MSB)
        regWrite(0x10, 0x15);   // No-response Timer - 21 steps, ~100us (LSB)
        directCommand(0xCC);    // Analog Preset
        
        stopCapInterrupt = false;
        cardPresent = 1;        // To handle the case where we are sleeping and a card is held over the device, we assume we are in this case on wakeup
        
        calibrateCapSense();    // Calibrate Capacitive Sensor
        enterReady();           // Send out a pulse immediately to see if there has been a card waiting for us.
	}

	// Read a register and return its value
	function regRead(addr) {
		addr = addr | 0x40;             // Set mode bits to Register Read
		cs_l.write(0);                  // Select AS3911
		spi.write(format("%c",addr));   // Write mode+address
		local reg = spi.readblob(1);    // Read byte from register
		cs_l.write(1);                  // Deselect AS3911
		
		return reg[0];                  // Return register value
	}

	// Read a register and log its value to the server
	function regPrint(addr) {
		log(format("Register 0x%02X: 0x%02X", addr, regRead(addr)), LOGS.ERROR); 
	}

	// Write to a register
	function regWrite(addr, byte) {
		// Mode bits for Register Write are '00', so no action required there
		cs_l.write(0);                          // Select AS3911
		spi.write(format("%c%c", addr, byte));  // Write address+data
		cs_l.write(1);                          // Deselect AS3911
	}

	// Set one bit in a register
	function setBit(reg, bitNum) {
		if (bitNum < 0 || bitNum > 7) {
			log("Error: Invalid bit #" + bitNum, LOGS.ERROR);
			return;
		}
		local newVal = regRead(reg) | 0x01 << bitNum;
		regWrite(reg, newVal);
	}

	// Clear one bit in a register
	function clearBit(reg, bitNum) {
		if (bitNum < 0 || bitNum > 7) {
			log("Error: Invalid bit #" + bitNum, LOGS.ERROR);
			return;
		}
		local newVal = regRead(reg) & ~(0x01 << bitNum);
		regWrite(reg, newVal);
	}

	// Send a direct command
	function directCommand(cmd) {
		// Direct Command mode bits are '11' and already included in command code
		cs_l.write(0);                  // Select AS3911
		spi.write(format("%c", cmd));   // Write command
		cs_l.write(1);                  // Deselect AS3911
	}
    
	// Read bytes from FIFO
	function FIFORead() {
		local bytesToRead = regRead(0x1A);      // Number of unread bytes in FIFO
		local FIFOStatusReg = regRead(0x1B);    // For debugging purposes
		
		cs_l.write(0);                      // Select AS3911
		spi.write(format("%c", 0xBF));      // Write "FIFO Read" mode bits
		local receivedFIFO = spi.readblob(bytesToRead);  // Read entire FIFO into a blob
		cs_l.write(1);                      // Deselect AS3911
		
		return receivedFIFO;
	}

	// Write bytes to FIFO
	function FIFOWrite(dataBlob) {
		if (dataBlob.len() > 96) {
			log("FIFO must be 96 bytes or less!", LOGS.ERROR);
			return;
		}
		cs_l.write(0);                      // Select AS3911
		spi.write(format("%c", 0x80));      // Write "FIFO Write" mode bits
		spi.write(dataBlob);                    // Write contents of FIFO
		cs_l.write(1);                      // Deselect AS3911
	}

	// Anticollision
	function anticollision(nvb, isSelect, isFinal) {
		local FIFOBlob = blob();
		local sel = 0x93 + (cascadeLevel - 1) * 2
		FIFOBlob.writen(sel, 'b');  // SEL
		FIFOBlob.writen(nvb, 'b');  // NVB
		
		if(!isSelect) {
			log("Transmitting anticollision packet", LOGS.INFO);
			
			receiveType = RECEIVE_TYPE.ANTICOLLISION;   // Expect anticollision frame
			local length = (nvb >> 4) - FIFOBlob.len();
			log(format("NVB: %i, Length: %i, FIFO length: %i", nvb >> 4, length, FIFOBlob.len()), LOGS.DEBUG);
			for (local i = 0; i < length && i < UID.len(); i++) {
				FIFOBlob.writen(UID[i], 'b');
			}
			directCommand(0xC2);    // Clear FIFO / status registers
			regWrite(0x1D, FIFOBlob.len() >> 8);    // Write # of Transmitted Bytes (MSB)
			regWrite(0x1E, FIFOBlob.len() << 3);    // Write # of Transmitted Bytes (LSB)
			FIFOWrite(FIFOBlob);
			setBit(0x09, 7);        // Make sure no_CRC_rx is set
			setBit(0x05, 0);        // Set antcl
			directCommand(0xC5);    // Transmit contents of FIFO without CRC
		} else {
			log("Transmitting select packet", LOGS.INFO);
			
			clearBit(0x09, 7);      // Make sure no_CRC_rx is cleared
			clearBit(0x05, 0);      // Clear antcl
			receiveType = RECEIVE_TYPE.SAK; // Expect to receive SAK
			if (isFinal) {
			    assert(UID.len() >= 4);
			    if (UID.len() == 4) {
    				FIFOBlob.writen(UID[0], 'b');
    				FIFOBlob.writen(UID[1], 'b');
    				FIFOBlob.writen(UID[2], 'b');
    				FIFOBlob.writen(UID[3], 'b');
    				FIFOBlob.writen(UID[0] ^ UID[1] ^ UID[2] ^ UID[3], 'b');// BCC
			    } else {
    				FIFOBlob.writen(UID[3], 'b');
    				FIFOBlob.writen(UID[4], 'b');
    				FIFOBlob.writen(UID[5], 'b');
    				FIFOBlob.writen(UID[6], 'b');
    				FIFOBlob.writen(UID[3] ^ UID[4] ^ UID[5] ^ UID[6], 'b');// BCC
			    }
			}
			else {
				FIFOBlob.writen(0x88, 'b');                             // CT
				FIFOBlob.writen(UID[0], 'b');
				FIFOBlob.writen(UID[1], 'b');
				FIFOBlob.writen(UID[2], 'b');
				FIFOBlob.writen(0x88 ^ UID[0] ^ UID[1] ^ UID[2], 'b');  // BCC
			}
			directCommand(0xC2);    // Clear FIFO / status registers
			regWrite(0x1D, FIFOBlob.len() >> 8);    // Write # of Transmitted Bytes (MSB)
			regWrite(0x1E, FIFOBlob.len() << 3);    // Write # of Transmitted Bytes (LSB)
			FIFOWrite(FIFOBlob);
			directCommand(0xC4);    //Transmit contents of FIFO with CRC
		}
	}

    // Send REQA
    function sendREQA() {
        log("Sending REQA", LOGS.DEBUG);
        stopCapInterrupt = true;
    	receiveType = RECEIVE_TYPE.ATQA;    // Expect ATQA in response
    	directCommand(0xC2);    // Clear (not necessary, but what the hell)
    	directCommand(0xC6);    // Send REQA
    }
  
    // Send RATS
    function sendRATS() {
    	log("Sending RATS", LOGS.INFO);
    	receiveType = RECEIVE_TYPE.ATS;    // Expect ATQA in response
        local FIFOBlob = blob();
        FIFOBlob.writen(0xE0, 'b'); // Start Byte
        FIFOBlob.writen(0x41, 'b'); // b7-b4 FSDI = 4 (48 bytes), b3-b0 CID = 0
        directCommand(0xC2);    // Clear FIFO
        regWrite(0x1D, FIFOBlob.len() >> 8);    // Write # of Transmitted Bytes (MSB)
        regWrite(0x1E, FIFOBlob.len() << 3);    // Write # of Transmitted Bytes (LSB)
        FIFOWrite(FIFOBlob);    //write to the FIFO
    	directCommand(0xC4);    // Send with CRC
	}
  
    // Send PPS
    function sendPPS() {
        log("Sending PPS", LOGS.INFO);
      	receiveType = RECEIVE_TYPE.PPSR;    // Expect ATQA in response
        local FIFOBlob = blob();
        FIFOBlob.writen(0xD1, 'b'); // Start Byte (1101)b, CID = 0
        FIFOBlob.writen(0x11, 'b'); // PPS0 - nothing special, although bit is set to show that we send PPS1
        FIFOBlob.writen(0x0F, 'b'); // PPS1 - we send the DRI and DSI to be 8 (max bitrate)
        directCommand(0xC2);    // Clear FIFO
        regWrite(0x1D, FIFOBlob.len() >> 8);    // Write # of Transmitted Bytes (MSB)
      	regWrite(0x1E, FIFOBlob.len() << 3);    // Write # of Transmitted Bytes (LSB)
        FIFOWrite(FIFOBlob);    //write to the FIFO
		directCommand(0xC4);    // Send with CRC
    }
  
	// Receive Handler
	function receiveHandler() {
		local FIFO = FIFORead();
		if (receiveType == RECEIVE_TYPE.ATQA) {
			if (!(atqa & 0xF020) && FIFO.len() == 2) {
				atqa = FIFO[1] << 8 | FIFO[0];
                UIDsize = (FIFO[0] >> 6) + 1;   // 1 = single, 2 = double, 3 = triple
				log(format("Valid ATQA Received: %04X", atqa), LOGS.INFO);
				imp.sleep(0.005);   // Wait 5ms for card to be ready (maybe)
				cascadeLevel = 1;
				anticollision(0x20, false, false);
			}
			else {
				log("Invalid ATQA!", LOGS.ERROR);
			}
		}
		else if (receiveType == RECEIVE_TYPE.ANTICOLLISION) {

            if (errorDetected) {
                errorDetected = false;
    			log("Collision receiving the anticollision frame", LOGS.INFO);
                return;
            }
            
            if (FIFO.len() < 5) {
    			log("Incomplete anticollision frame: " + FIFO.len() + " bytes", LOGS.INFO);
                return;
            }
            
			log("Received anticollision frame: " + FIFO.len() + " bytes", LOGS.INFO);
			
			local final = false;
			if (FIFO[0] != 0x88) {  // Check for cascade tag
				UID.writen(FIFO[0], 'b');
				final = true;
			}
			UID.writen(FIFO[1], 'b');
			UID.writen(FIFO[2], 'b');
			UID.writen(FIFO[3], 'b');
			
			local BCC = FIFO[0] ^ FIFO[1] ^ FIFO[2] ^ FIFO[3];
			if(BCC == FIFO[4]){
				//send next anticollision frame to get the rest of the UID
				log("Valid BCC", LOGS.INFO);
				anticollision(0x70, true, final);
			}else{
				log("Invalid BCC", LOGS.INFO);
				return;
			}
		}
		else if (receiveType == RECEIVE_TYPE.SAK) {
			log("Received SAK", LOGS.INFO);
			assert(FIFO.len() >= 1);
			
			if (FIFO[0] & 0x04) {
				log("Incomplete UID, increasing cascade level", LOGS.WARN);
				
				cascadeLevel++;
				anticollision(0x20, false, false);
			}
			else {
				log("Completed UID", LOGS.INFO);
				
                local UIDstring = "UID: ";
				foreach (byte in UID) {
					UIDstring += format("0x%02X, ", byte);
				}
                log(UIDstring.slice(0, -2), LOGS.INFO);
                
                radioOFF();
                greenLED.write(1);
                irq_timer.pause();
                connect_send_disconnect("UID", UID, function() {
                    irq_timer.unpause();
                    greenLED.write(0);
                }.bindenv(this));
                
                // We should be sending the RATS now, but we are not implementing it.
                // sendRATS();
                UID = blob();
			}
		}
        else if (receiveType == RECEIVE_TYPE.ATS) {
            log("Received ATS", LOGS.INFO);
            
            assert(FIFO.len() >= 2);
            local ATSlen = FIFO[0];
            local interfaceLen = 0;
            if (~(FIFO[1] & 0x80)){
                log("Valid ATS", LOGS.DEBUG);
                if(FIFO[1] & 0x10){ // Received TA
                  interfaceLen++;
                }
                if(FIFO[1] & 0x20){ // Received TB
                  interfaceLen++;
                }
                if(FIFO[1] & 0x40){ // Received TC
                  interfaceLen++;
                }
                for(local i = 2; i<2+interfaceLen; i++){  // Load interface bytes
                  interfaceBytes.writen(FIFO[i], 'b');
                } 
                for(local i = 2+interfaceLen; i<ATSlen; i++){ // Load historical bytes
                  historicalBytes.writen(FIFO[i], 'b');
                }
                imp.sleep(0.005); // Can use SFGT defined in interface byte TB (Guard time needed for card to be ready)
                sendPPS();
            }else{
                log("Invalid ATS", LOGS.ERROR);
            }
        }
        else if (receiveType == RECEIVE_TYPE.PPSR) {
            blinkLED(greenLED);
            log("Received PPSR", LOGS.INFO);
            local PPSRstring = "PPSR: "
            foreach (byte in FIFO) {
                PPSRstring += format("0x%02X, ", byte);
        	}
            stopCapInterrupt == false;
            log(PPSRstring, LOGS.INFO);
        }
		else {
			log("Receive type [" + receiveType + "] unknown!", LOGS.WARN);
		}
	}

	// Interrupt Handler
	function interruptHandler() {
		if (irq.read()) {
			// Read main interrupt register first
			local mainInterruptReg = regRead(0x17);
			if (mainInterruptReg & 0x80) {
				// Oscillator frequency has stabilized
				log("IRQ: Oscillator frequency stable", LOGS.DEBUG);
			}
			if (mainInterruptReg & 0x40) {
				// FIFO water level (full or empty)
				log("IRQ: FIFO water level!", LOGS.DEBUG)
				//local fifo_contents = FIFORead();
			}
			if (mainInterruptReg & 0x20) {
				// Start of receive
				log("IRQ: Receive start", LOGS.DEBUG)
			}
			if (mainInterruptReg & 0x10) {
				// End of receive
				log("IRQ: Receive end", LOGS.DEBUG)
				imp.wakeup(0.01, receiveHandler.bindenv(this));
			}
			if (mainInterruptReg & 0x08) {
				// End of transmit
				log("IRQ: Transmit end", LOGS.DEBUG);
			}
			if (mainInterruptReg & 0x04) {
				// Bit collision
				log("IRQ: Bit collision!", LOGS.WARN);
				regPrint(0x1C); // Print Collision Display Register
                blinkLED(redLED);
                errorDetected = true;
			}
			if (mainInterruptReg & 0x02) {
				// Timer or NFC interrupt
				local timerInterruptReg = regRead(0x18);
				if (timerInterruptReg & 0x80) {
					// Termination of direct command
					log("IRQ: Direct command complete", LOGS.DEBUG);
				}
				if (timerInterruptReg & 0x40) {
					// No-response timer expire
				    log("IRQ: No-response timer expired", LOGS.DEBUG);
				}
				if (timerInterruptReg & 0x20) {
					// General purpose timer expire
					log("IRQ: General purpose timer expired", LOGS.DEBUG);
				}
				if (timerInterruptReg & 0x10) {
					// NFC: External field greater than Target activation level
					log("IRQ: NFC: External field > target activation level", LOGS.DEBUG);
				}
				if (timerInterruptReg & 0x08) {
					// NFC: External field less than Target activation level
					log("IRQ: NFC: External field dropped below target activation level", LOGS.DEBUG);
				}
				if (timerInterruptReg & 0x04) {
					// NFC: Collision detected during RF Collision Avoidance
					log("IRQ: NFC: Collision detected", LOGS.DEBUG);
				}
				if (timerInterruptReg & 0x02) {
					// NFC: Minimum guard time expire
					log("IRQ: NFC: Minimum guard time expired", LOGS.DEBUG);
				}
				if (timerInterruptReg & 0x01) {
					// NFC: Initiator bit rate recognized
					log("IRQ: NFC: Initiator bit rate recognized", LOGS.DEBUG);
				}
			}
			if (mainInterruptReg & 0x01) {
				// Error or Wake-up interrupt
				local wakeInterruptReg = regRead(0x19);
				if (wakeInterruptReg & 0x80) {
					// CRC error
					log("IRQ: CRC error!", LOGS.ERROR);
                    errorDetected = true;
                    blinkLED(redLED);
				}
				if (wakeInterruptReg & 0x40) {
					// Parity error
					log("IRQ: Parity error!", LOGS.ERROR);
                    errorDetected = true;
                    blinkLED(redLED);
				}
				if (wakeInterruptReg & 0x20) {
					// Soft framing error
					log("IRQ: Soft framing error!", LOGS.ERROR);
                    errorDetected = true;
                    blinkLED(redLED);
				}
				if (wakeInterruptReg & 0x10) {
					// Hard framing error
					log("IRQ: Hard framing error!", LOGS.ERROR);
                    errorDetected = true;
                    blinkLED(redLED);
				}
				if (wakeInterruptReg & 0x08) {
					// Wake-up interrupt
					log("IRQ: Wake-up interrupt", LOGS.DEBUG);
				}
				if (wakeInterruptReg & 0x04) {
					// Wake-up interrupt due to Amplitude Measurement
					log("IRQ: Wake-up interrupt due to Amplitude Measurement", LOGS.DEBUG);
				}
				if (wakeInterruptReg & 0x02) {
					// Wake-up interrupt due to Phase Measurement
					log("IRQ: Wake-up interrupt due to Phase Measurement", LOGS.DEBUG);
				}
				if (wakeInterruptReg & 0x01) {
					// Wake-up interrupt due to Capacitance Measurement
                    resetTime = time() + CARD_RESET_TIME;
				    if (stopCapInterrupt == false) {
					    log("IRQ: Wake-up interrupt due to Capacitance Measurement", LOGS.INFO);
    					if (cardPresent == 0) {
                            log("Card presence detected, start reading", LOGS.INFO);
                            cardPresent=1;
                            enterReady();
                        }  
				    }
				}            
			}
		}
	}

	// Calibrate capacitive sensor
	function calibrateCapSense() {
		log("Calibrating cap sensor ...", LOGS.DEBUG);
        regWrite(0x2E, 0x00);   // Enable automatic calibration, gain 6.5V/pF
        directCommand(0xDD);    // Calibrate to parasitic capacitance
        
		local capSenseDisplayReg = regRead(0x2F);
		if (capSenseDisplayReg & 0x04) {
            measureCapSense();
		} else if (capSenseDisplayReg & 0x02) {
			log("Calibration error!", LOGS.ERROR);
		}
	}

	// Measure the capacitive sensor once - this happens automatically in wakeup mode. Mostly for debug
	function measureCapSense() {
		directCommand(0xDE);
		local capResult = regRead(0x20);
		log(format("Calibration: "
		        +  "Current value: 0x%02x, "
		        +  "Auto-Avg Reg: 0x%02x => "
		        +  "Cap Display Reg: 0x%02x",
		        capResult, 
		        regRead(0x3C), 
		        regRead(0x3D)
		        ), LOGS.INFO);
		        
		 // If the result is crap, do it again.
		 if (capResult == 0) imp.wakeup(0.5, calibrateCapSense.bindenv(this));
	}
  
    // Turn Radios off (RX and TX)
    function radioOFF(){
        clearBit(0x02, 6);
        clearBit(0x02, 3);
        log("Radios off", LOGS.INFO);
    }

	function enterReady() {
	    UID = blob();
		regWrite(0x05, 0x01);   // Anticollision bit set (antcl)
    	regWrite(0x02, 0x80);   // Operation Control - Enable ready mode (en -> 1)
		log("Ready mode enabled", LOGS.DEBUG);
		// Should technically wait for oscillator to stabilize here - hasn't caused any trouble though
		
		directCommand(0xD6);    // Adjust Regulators
		directCommand(0xD8);    // Calibrate Antenna
		regWrite(0x02, 0xC8);   // Tx/Rx Enable
		imp.sleep(0.005);       // Wait 5ms for reader field to stabilize
		
	    blinkLED(redLED, 24, 0.5);
	    
		sendREQA();             // Send REQA
	}

	function enterWakeup(){
	    if (SKIP_CAP_SENSE) return;

        log("Wakeup mode enabled", LOGS.INFO);
		regWrite(0x31, 0x01); // Wake-up timer Control - CapSense at every 100ms (wcap -> 1)
        regWrite(0x2E, 0x01); // Enable automatic calibration, gain 6.5V/pF
    	regWrite(0x3A, 0x29); // Set delta and auto-avg settings
		regWrite(0x02, 0x04); // Operation Control - Enable wakeup mode (wu -> 1), disable radios
        //NOTE: this command to enter wakeup mode must be made AFTER setting all registers with capacitance settings / calibration values
	}
    
    
  
    // Check to make sure the IRQ pin isn't stuck high
    function pollIRQ() {
        if (irq.read()) {
            interruptHandler();
        } else {
            if (SKIP_CAP_SENSE) {
                cardPresent=1;
                enterReady();
            } else if ((time() > resetTime) && (cardPresent ==  1)) {
                log("Resetting card presence to None", LOGS.DEBUG)
                stopCapInterrupt = false;
                cardPresent = 0;
                enterWakeup();
            } else if (resetTime + SLEEP_TIME < time()) {
                resetTime = time() + SLEEP_TIME;
                enterWakeup();
                if (OFFLINE_MODE) {
                    if (server.isconnected()) {
                        imp.onidle(function() { server.sleepfor(24*60*60-60-clock().tointeger()); });
                    } else {
                        imp.onidle(function() { imp.deepsleepfor(24*60*60-60-clock().tointeger()); });
                    }
                }
            }
        }
    }
    
}


// =============================================================================
log_counter <- 1;
function log(message, level = LOGS.TRACE) 
{
    if (level >= VERBOSITY) {
        log_counter++;
        if (server.isconnected()) {
            if (level >= LOGS.ERROR) {
                server.error(format("%04d: %s", log_counter, message));
            } else {
                server.log(format("%04d: %s", log_counter, message));
            }
        } 
    }
}


// =============================================================================
function connect_send_disconnect(key, value, callback = null) {
    
    imp.setpowersave(false);
    if (server.isconnected()) {
        agent.send(key, value);
        imp.onidle(function() {
            if (OFFLINE_MODE) server.expectonlinein(24*60*60-60);
            if (callback) callback();
        })
    } else {
        server.connect(function(state) {
            if (state == SERVER_CONNECTED) {
                agent.send(key, value);
                imp.onidle(function() {
                    if (OFFLINE_MODE) server.expectonlinein(24*60*60-60);
                    if (callback) callback();
                })
            } else {
                log("Connecting to Electric Imp failed: " + state, LOGS.ERROR);
                server.disconnect();
                if (callback) callback();
            }
        }, 30)
    }
}

// =============================================================================
// Connect to the server
function connect(callback = null)  {
    imp.setpowersave(true);
    if (server.isconnected()) {
        if (callback) callback();
    } else {
        try {
            server.connect(function(reason) {
                imp.configure("RFID AS3911", [], []);
                if (callback) callback();
            }, 30)
        } catch (e) {
            server.connect();
            if (callback) callback();
        }
    }
}


// =============================================================================
// Blink an LED
function blinkLED(led, speed = 0, duration = 1.0){
    local stop_at = hardware.millis() + (duration * 1000.0);
    timer(null, true).repeat(1.0 / speed, function(t) {
        if ((speed > 0) && (stop_at - hardware.millis()) > 0) {
            led.write(led.read() == 1 ? 0 : 1);
        } else {
            led.write(0);
            t.cancel(); t = null;
        }
    })
}


// =============================================================================
function bootstrap() {
    
    // Welcome
    log("", LOGS.TRACE);
    log("AS3911 Imp Olive Board Started", LOGS.TRACE);
    log("", LOGS.TRACE);
    
    // LEDs
    redLED <- hardware.pin9;
    redLED.configure(DIGITAL_OUT);
    redLED.write(0);
    greenLED <- hardware.pinC;
    greenLED.configure(DIGITAL_OUT);
    greenLED.write(0);
    
    // Buttons
    /*
    btnScan <- hardware.pinA;
    btnScan.configure(DIGITAL_IN_PULLUP, function() {
        if (btnScan.read() == 0) return;
        RFID.resetTime = time() + CARD_RESET_TIME;
        RFID.cardPresent = 1;
        RFID.enterReady();
    })
    btnConnect <- hardware.pinB;
    btnConnect.configure(DIGITAL_IN_PULLUP, function() {
        if (btnConnect.read() == 0) return;
        connect();
    })
    */
    
    // RFID after a tiny delay
    RFID <- AS3911(hardware.pin1, hardware.spi257, hardware.pin8);
}


// =============================================================================
// Imp and connection
imp.setpowersave(true);
server.setsendtimeoutpolicy(OFFLINE_MODE ? RETURN_ON_ERROR : SUSPEND_ON_ERROR, WAIT_TIL_SENT, 30);
if (hardware.wakereason() == WAKEREASON_PIN1) {
    bootstrap();
} else {
    connect(bootstrap);
}


