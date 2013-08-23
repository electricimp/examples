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
server.log("");
server.log("AS3911 Imp Olive Board Started");

// Constants
// SPI Clock Frequency in kHz
// (2MHz may be unstable due to bug in AS3911, check errata document)
const FREQ = 6000;
// Receive types
enum RECEIVE_TYPE {
    UNKNOWN = 0
    ATQA = 1
    ANTICOLLISION = 2
    SAK = 3
    ATS = 4
    PPSR = 5
}
const SLEEP_TIME = 10; // Number of seconds to wait before we go to sleep
const CARD_RESET_TIME = 1; // Number of seconds after inactivity before we assume no card is present and we are ready to detect again
const VERBOSE = 1; // For outputing logs

class AS3911
{
    receiveType = null; // Type of Recieved data
    atqa = null;        // Answer to REQA
	cardPresent = null;	// Flag for detectomg physical presence of tag through cap sensor, etc.
	UID = null;			// Unique ID for RFID card
    CID = null;        	// Card ID chosen by the reader for the card we are Working with (our AS3911)
	cascadeLevel = null;	// Cascade level during select / anticollision process
    UIDsize = null;     // size of UID; should be 1, 2, 3 for single, double, triple respectively. Single = 4 bytes, double = 7 bytes, triple = 10 bytes
    resetTime = null; 		// Time counter before we sleep
    interfaceBytes = null; 	// Interface Bytes for ISO 14443 A card
    historicalBytes = null; // Historical Bytes for ISO 14443 A card
    stopCapInterrupt = null;// Flag used to prevent Capacitance measurements from interrupting protocol flow
	
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

		irq = interruptPin;
		spi = serialPort;
		cs_l = chipSelect;
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
		server.log(format("Register 0x%02X: 0x%02X", addr, regRead(addr))); 
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
			server.log("Error: Invalid bit #" + bitNum);
			return;
		}
		local newVal = regRead(reg) | 0x01 << bitNum;
		regWrite(reg, newVal);
	}

	// Clear one bit in a register
	function clearBit(reg, bitNum) {
		if (bitNum < 0 || bitNum > 7) {
			server.log("Error: Invalid bit #" + bitNum);
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
    
    // Blink Red LED
    function blinkRed(){
        hardware.pin9.write(1);
        imp.wakeup(0.3, function(){hardware.pin9.write(0)});
    }
    
    // Blink Green LED
    function blinkGreen(){
        hardware.pinC.write(1);
        imp.wakeup(0.3, function(){hardware.pinC.write(0)});
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
			server.log("FIFO must be 96 bytes or less!");
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
		
		if(isSelect) {
			clearBit(0x09, 7);      // Make sure no_CRC_rx is cleared
			clearBit(0x05, 0);      // Clear antcl
			receiveType = RECEIVE_TYPE.SAK; // Expect to receive SAK
			if (isFinal) {
				FIFOBlob.writen(UID[3], 'b');
				FIFOBlob.writen(UID[4], 'b');
				FIFOBlob.writen(UID[5], 'b');
				FIFOBlob.writen(UID[6], 'b');
				FIFOBlob.writen(UID[3] ^ UID[4] ^ UID[5] ^ UID[6], 'b');// BCC
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
			if(VERBOSE) server.log("Transmitting select packet:");
		} else {
			receiveType = RECEIVE_TYPE.ANTICOLLISION;   // Expect anticollision frame
			local length = (nvb >> 4) - FIFOBlob.len();
			if(VERBOSE) server.log(format("NVB: %i, Length: %i, FIFO length: %i", nvb >> 4, length, FIFOBlob.len()));
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
			if(VERBOSE) server.log("Transmitting anticollision packet:");
		}
	}

    // Send REQA
    function sendREQA() {
        if(VERBOSE) server.log("Sending REQA");
        stopCapInterrupt = true;
    	receiveType = RECEIVE_TYPE.ATQA;    // Expect ATQA in response
    	directCommand(0xC2);    // Clear (not necessary, but what the hell)
    	directCommand(0xC6);    // Send REQA
    }
  
    // Send RATS
    function sendRATS() {
    	if(VERBOSE) server.log("Sending RATS");
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
        if(VERBOSE) server.log("Sending PPS");
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
                if(VERBOSE) server.log(format("UIDsize: %01X", UIDsize));
				if(VERBOSE) server.log(format("Valid ATQA Received: %04X", atqa));
				imp.sleep(0.005);   // Wait 5ms for card to be ready (maybe)
				cascadeLevel = 1;
				anticollision(0x20, false, false);
			}
			else {
				server.log("Invalid ATQA!");
			}
		}
		else if (receiveType == RECEIVE_TYPE.ANTICOLLISION) {
			if(VERBOSE) server.log("Received anticollision frame.");
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
				if(VERBOSE) server.log("valid BCC!");
				//send next anticollision frame to get the rest of the UID
				anticollision(0x70, true, final);
			}else{
				server.log("invalid BCC!");
				return;
			}
		}
		else if (receiveType == RECEIVE_TYPE.SAK) {
			if(VERBOSE) server.log("Received SAK");
			if (FIFO[0] & 0x04) {
				if(VERBOSE) server.log("Incomplete UID");
				cascadeLevel++;
				anticollision(0x20, false, false);
			}
			else if (FIFO[0] & 0x20) {
				if(VERBOSE) server.log("Completed UID");
                local UIDstring = "UID: ";
				foreach (i, byte in UID) {
					UIDstring += format("%i 0x%02X, ", i, byte);
				}
                if(VERBOSE) server.log(UIDstring);
                sendRATS();
                UID = blob();
			}
		}
        else if (receiveType == RECEIVE_TYPE.ATS) {
            if(VERBOSE) server.log("RECEIVED ATS");
            local ATSlen = FIFO[0];
            local interfaceLen = 0;
            if (~(FIFO[1] & 0x80)){
                if(VERBOSE) server.log("VALID ATS");
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
                server.error("INVALID ATS");
            }
        }
        else if (receiveType == RECEIVE_TYPE.PPSR) {
            blinkGreen();
            if(VERBOSE) server.log("RECEIVED PPSR")
            local PPSRstring = "PPSR: "
            foreach (byte in FIFO) {
                PPSRstring += format("0x%02X, ", byte);
        	}
            stopCapInterrupt == false;
            if(VERBOSE) server.log(PPSRstring);
        }
		else {
			if(VERBOSE) server.log("Receive type [" + receiveType + "] unknown!");
		}
	}

	// Interrupt Handler
	function interruptHandler() {
		if (irq.read()) {
			// Read main interrupt register first
			local mainInterruptReg = regRead(0x17);
			if (mainInterruptReg & 0x80) {
				// Oscillator frequency has stabilized
				if(VERBOSE) server.log("Oscillator frequency stable.");
			}
			if (mainInterruptReg & 0x40) {
				// FIFO water level (full or empty)
				if(VERBOSE) server.log("FIFO water level!")
				//local fifo_contents = FIFORead();
			}
			if (mainInterruptReg & 0x20) {
				// Start of receive
				if(VERBOSE) server.log("Receive start.")
			}
			if (mainInterruptReg & 0x10) {
				// End of receive
				if(VERBOSE) server.log("Receive end.")
				imp.wakeup(0.01, receiveHandler.bindenv(this));
			}
			if (mainInterruptReg & 0x08) {
				// End of transmit
				if(VERBOSE) server.log("Transmit end.");
			}
			if (mainInterruptReg & 0x04) {
				// Bit collision
				server.error("Bit collision!");
                blinkRed();
				regPrint(0x1C); // Print Collision Display Register
			}
			if (mainInterruptReg & 0x02) {
				// Timer or NFC interrupt
				local timerInterruptReg = regRead(0x18);
				if (timerInterruptReg & 0x80) {
					// Termination of direct command
					if(VERBOSE) server.log("Direct command complete.");
				}
				if (timerInterruptReg & 0x40) {
					// No-response timer expire
				    if(VERBOSE) server.log("No-reponse timer expired");
				}
				if (timerInterruptReg & 0x20) {
					// General purpose timer expire
					if(VERBOSE) server.log("General purpose timer expired");
				}
				if (timerInterruptReg & 0x10) {
					// NFC: External field greater than Target activation level
					if(VERBOSE) server.log("NFC: External field > target activation level");
				}
				if (timerInterruptReg & 0x08) {
					// NFC: External field less than Target activation level
					if(VERBOSE) server.log("NFC: External field dropped below target activation level");
				}
				if (timerInterruptReg & 0x04) {
					// NFC: Collision detected during RF Collision Avoidance
					if(VERBOSE) server.log("NFC: Collision detected");
				}
				if (timerInterruptReg & 0x02) {
					// NFC: Minimum guard time expire
					if(VERBOSE) server.log("NFC: Minimum guard time expired");
				}
				if (timerInterruptReg & 0x01) {
					// NFC: Initiator bit rate recognized
					if(VERBOSE) server.log("NFC: Initiator bit rate recognized");
				}
			}
			if (mainInterruptReg & 0x01) {
				// Error or Wake-up interrupt
				local wakeInterruptReg = regRead(0x19);
				if (wakeInterruptReg & 0x80) {
					// CRC error
					server.error("CRC error!");
                    blinkRed();
				}
				if (wakeInterruptReg & 0x40) {
					// Parity error
					server.error("Parity error!");
                    blinkRed();
				}
				if (wakeInterruptReg & 0x20) {
					// Soft framing error
					server.error("Soft framing error!");
                    blinkRed();
				}
				if (wakeInterruptReg & 0x10) {
					// Hard framing error
					server.error("Hard framing error!");
                    blinkRed();
				}
				if (wakeInterruptReg & 0x08) {
					// Wake-up interrupt
					if(VERBOSE) server.log("Wake-up interrupt");
				}
				if (wakeInterruptReg & 0x04) {
					// Wake-up interrupt due to Amplitude Measurement
					if(VERBOSE) server.log("Wake-up interrupt due to Amplitude Measurement");
				}
				if (wakeInterruptReg & 0x02) {
					// Wake-up interrupt due to Phase Measurement
					if(VERBOSE) server.log("Wake-up interrupt due to Phase Measurement");
				}
				if (wakeInterruptReg & 0x01 && stopCapInterrupt == false) {
					// Wake-up interrupt due to Capacitance Measurement
					if(VERBOSE) server.log("Wake-up interrupt due to Capacitance Measurement");
                    blinkRed();
					if(cardPresent==0) {
                        if(VERBOSE) server.log("NEW CARD!");
                        cardPresent=1;
                        enterReady();
                        resetTime = time() + CARD_RESET_TIME;
                    }  
				}            
			}
		}
		else {
		}
	}

	// Calibrate capacitive sensor
	function calibrateCapSense() {
		server.log("Calibrating cap sensor...");
		regWrite(0x2E, 0x0);    // Enable automatic calibration, gain 6.5V/pF
		regWrite(0x3A, 0x79);   //Set delta and auto-avg settings
    	directCommand(0xDD);    // Calibrate to parasitic capacitance
		local capSenseDisplayReg = regRead(0x2F);
		if (capSenseDisplayReg & 0x04) {
			server.log("Capacitive sensor calibrated. Value: ");
            measureCapSense();
		}
		else if (capSenseDisplayReg & 0x02) {
			server.log("Calibration error!");
		}
	}

	// Measure the capacitive sensor once - this happens automatically in wakeup mode. Mostly for debug
	function measureCapSense() {
		directCommand(0xDE);
		local capResult = regRead(0x20);
		server.log("ADC: " + capResult + ", Cap Display Reg: " + regRead(0x3D) + ", Auto-Avg Reg: " + regRead(0x3C) + ", Reference Reg: " + regRead(0x3B));
	}
  
    // Turn Radios off (RX and TX)
    function radioOFF(){
        clearBit(0x02, 6);
        clearBit(0x02, 3);
        if(VERBOSE) server.log("Radios off.");
    }

	function enterReady() {
		regWrite(0x05, 0x01);   // Anticollision bit set (antcl)
    	regWrite(0x02, 0x80);   // Operation Control - Enable ready mode (en -> 1)
		if(VERBOSE) server.log("Ready mode enabled.");
		// Should technically wait for oscillator to stabilize here - hasn't caused any trouble though
		
		directCommand(0xD6);    // Adjust Regulators
		directCommand(0xD8);    // Calibrate Antenna
		regWrite(0x02, 0xC8);   // Tx/Rx Enable
		imp.sleep(0.005);       // Wait 5ms for reader field to stabilize
		
		sendREQA();             // Send REQA
	}

	function enterWakeup(){
        if(VERBOSE) server.log("Wakeup mode enabled");
		regWrite(0x31, 0x01); //Wake-up timer Control - CapSense at every 100ms (wcap -> 1)
        regWrite(0x2E, 0x0);   // Enable automatic calibration, gain 6.5V/pF
    	regWrite(0x3A, 0x79);   //Set delta and auto-avg settings
		regWrite(0x02, 0x04); //Operation Control - Enable wakeup mode (wu -> 1) 
        //NOTE: this command to enter wakeup mode must be made AFTER setting all registers with capacitance settings / calibration values
	}
    
    
  
    // Check to make sure the IRQ pin isn't stuck high
    function pollIRQ() {
        if (irq.read()) {
            interruptHandler();
        }else{
            if(resetTime < time() && cardPresent==1){
                if(VERBOSE) server.log("TURNED RESET CARDPRESENT=0")
                stopCapInterrupt = false;
                cardPresent = 0;
                enterWakeup();
            }else if(resetTime + SLEEP_TIME < time()){
                radioOFF();
                imp.onidle(function() { server.sleepfor(24*60*60-60); });
            }
        }
    }
}


imp.configure("RFID AS3911", [], []);
imp.setpowersave(true);

RFID <- AS3911(hardware.pin1, hardware.spi257, hardware.pin8);

// Configure I/O
RFID.irq.configure(DIGITAL_IN_WAKEUP, RFID.interruptHandler.bindenv(RFID));
RFID.cs_l.configure(DIGITAL_OUT);
RFID.cs_l.write(1);
// SPI Mode 1: CPOL = 0, CPHA = 1
RFID.spi.configure(CLOCK_IDLE_LOW | CLOCK_2ND_EDGE, FREQ);

//LED
hardware.pin9.configure(DIGITAL_OUT);
hardware.pin9.write(0);
hardware.pinC.configure(DIGITAL_OUT);
hardware.pinC.write(0);

RFID.blinkRed();

// Initialization
RFID.directCommand(0xC1);    // (C1) Set Default
RFID.directCommand(0xC2);    // (C2) Clear
RFID.regWrite(0x00, 0x0F);   // IO Config 1 - Disable MCU_CLK output
RFID.regWrite(0x01, 0x80);   // IO Config 2 - Defaults
RFID.regWrite(0x02, 0x00);   // Operation Control - Defaults, power-down mode
RFID.regWrite(0x03, 0x08);   // Mode Definition - ISO14443a (no auto rf collision)
RFID.regWrite(0x04, 0x00);   // Bit Rate Definition - fc/128 (~106kbit/s) lowest
RFID.regWrite(0x0E, 0x04);   // Mask Receive Timer - 4 steps, ~19us (minimum)
RFID.regWrite(0x0F, 0x00);   // No-response Timer - 21 steps, ~100us (MSB)
RFID.regWrite(0x10, 0x15);   // No-response Timer - 21 steps, ~100us (LSB)

RFID.directCommand(0xCC);    // Analog Preset
RFID.calibrateCapSense();    // Calibrate Capacitive Sensor

function poll(){
    RFID.pollIRQ();
    imp.wakeup(1 , poll);
}

RFID.stopCapInterrupt = false;
RFID.cardPresent = 1;   // To handle the case where we are sleeping and a card is held over the device, we assume we are in this case on wakeup
RFID.enterReady();      // Send out a pulse immediately to see if there has been a card waiting for us.
poll();

server.log("End of code.");

