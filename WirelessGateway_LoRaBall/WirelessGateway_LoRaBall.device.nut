#require "JSONParser.class.nut:1.0.0"

// LoRa UART Coms Wrapper
class LoRa_RN2903 {

    static BAUD_RATE = 57600;
    static WORD_SIZE = 8;
    static STOP_BITS = 1;

    static LINE_FEED = 0x0A;
    static FIRST_ASCII_PRINTABLE_CHAR = 32;
    static LORA_BANNER = "RN2903"; //"RN2903 or RN2483"
    static ERROR_BANNER_MISMATCH = "LoRa banner mismatch";
    static ERROR_BANNER_TIMEOUT = "LoRa banner timeout";

    // Pins
    _uart = null;
    _reset = null; // active low

    // Variables
    _timeout = null;
    _buffer = null;
    _receiveHandler = null;
    _init = false;
    _initCB = null;

    // Debug logging flag
    _debug = null;

    constructor(uart, reset, debug = false) {
        _debug = debug;
        _reset = reset;
        _uart = uart;
        _clearBuffer();

        _reset.configure(DIGITAL_OUT, 1);
    }

    function init(cb = null) {
        // set init flag
        _init = true;
        _initCB = cb;

        // Reset device
        _reset.write(0);
        // Start timeout error timer
        _timeout = imp.wakeup(5, function() {
            // pass error to callback
            if (_initCB) {
                _initCB(ERROR_BANNER_TIMEOUT);
            } else {
                server.error(ERROR_BANNER_TIMEOUT);
            }
            // clear init variables
            _init = false;
        }.bindenv(this));
        // Configure UART
        _uart.configure(BAUD_RATE, WORD_SIZE, PARITY_NONE, STOP_BITS, NO_CTSRTS, _uartReceive.bindenv(this));
        // Release Reset pin
        _reset.write(1);
    }

    function hwReset() {
        _reset.write(0);
        imp.sleep(0.01);
        _reset.write(1);
    }

    function send(cmd) {
        _debugLog("sent: "+ cmd);
        _uart.write(cmd+"\r\n");
    }

    function setReceiveHandler(cb) {
        _receiveHandler = cb;
    }

    function _uartReceive() {
        local b = _uart.read();
        while(b >= 0) {
            if (b >= FIRST_ASCII_PRINTABLE_CHAR) {
                _buffer += b.tochar();
            } else if (b == LINE_FEED) {
                // we have a line of data
                _debugLog("received: "+_buffer);
                // pass buffer to handler
                if (_init) {
                    _checkBanner(_buffer);
                } else if (_receiveHandler) {
                    _receiveHandler(_buffer);
                }
                _clearBuffer();
            }
            b = _uart.read();
        }
    }

    function _clearBuffer() {
        _buffer = "";
    }

    function _checkBanner(data) {
        // cancel banner timeout timer
        imp.cancelwakeup(_timeout);
        _timeout = null;

        local err = null;
        // check for the expected banner
         if (data.slice(0, LORA_BANNER.len()) != LORA_BANNER) {
            server.log( data.slice(0, LORA_BANNER.len()) );
            err = ERROR_BANNER_MISMATCH;
        }

        // call init callback
        if (_initCB) {
            _initCB(err);
        } else if (err) {
            server.error(err);
        }

        // clear init flag
        _init = false;
    }

    function _debugLog(msg) {
        if (_debug) server.log(msg);
    }

}

// Configure Hardware
class WirelessAccelerator {

    static UART = hardware.uart1;
    static RESET_PIN = hardware.pinH;

    static RED_LED = hardware.pinG;
    static AMBER_LED = hardware.pinF;
    static GREEN_LED = hardware.pinE;

    static LED_ON = 0;
    static LED_OFF = 1;
    static LED_FLASH_TIME = 0.05;

    lora = null;
    flash_callback = null;

    constructor(debug = false, radioInitCB = null) {
        if (typeof debug == "function") {
            radioInitCB = debug;
            debug = false;
        }
        configureLEDs();
        lora = LoRa_RN2903(UART, RESET_PIN, debug);
        loraInit(radioInitCB);
    }

    function loraInit(cb = null) {
        lora.init(cb);
    }

    function loraSend(command) {
        lora.send(command);
    }

    function loraSetReceiveHandler(cb) {
        lora.setReceiveHandler(cb);
    }

    function configureLEDs() {
        RED_LED.configure(DIGITAL_OUT, LED_OFF);
        AMBER_LED.configure(DIGITAL_OUT, LED_OFF);
        GREEN_LED.configure(DIGITAL_OUT, LED_OFF);
    }

    function setLED(led, state) {
        led.write(state);
    }

    function flashLED(led) {
        led.write(LED_ON);

        if (flash_callback != null) {
            imp.cancelwakeup(flash_callback);
        }

        flash_callback = imp.wakeup(LED_FLASH_TIME, function() {
                led.write(LED_OFF);
                flash_callback = null;
            }.bindenv(this));
    }

}

// Application
class Application {

    // LoRa Settings
    static RADIO_MODE = "lora";
    static RADIO_FREQ = 915000000; // (915000000 RN2903, 433575000 RN2483)
    static RADIO_SPREADING_FACTOR = "sf7"; // 128 chips
    static RADIO_BANDWIDTH = 125;
    static RADIO_CODING_RATE = "4/5";
    static RADIO_CRC = "on"; // crc header enabled
    static RADIO_SYNC_WORD = 12;
    static RADIO_WATCHDOG_TIMEOUT = 0;
    static RADIO_POWER_OUT = 14;
    static RADIO_RX_WINDOW_SIZE = 0; // contiuous mode

    // LoRa Commands
    static MAC_PAUSE = "mac pause";
    static RADIO_SET = "radio set";
    static RADIO_RX = "radio rx";
    static RADIO_TX = "radio tx";

    // LoRa Com variables
    static TX_HEADER = "FF000000";
    static TX_FOOTER = "00";
    static ACK_COMMAND = "5458204F4B" // "TX OK"
    static LORA_DEVICE_ID = "Ball_01"; // RED BALL

    // Data Filtering variables
    static EVENT_TIMEOUT = 3; // in sec
    static MOVEMENT_TIMEOUT = 500; // in ms
    static MOVEMENT_FILTER_RANGE = 0.03; // in G
    eventActive = false;
    prevMovementUpdate = null;
    prevX = null;
    prevY = null;
    prevZ = null;

    // LoRa Initialization varaibles
    initCommands = null;
    cmdIdx = null;

    // Application varaibles
    gateway = null;
    _debug = null;


    function constructor(debug = false) {
        _debug = debug;
        setInitCommands();
        gateway = WirelessAccelerator(_debug, loraInitHandler.bindenv(this));
    }

    function loraInitHandler(err) {
        if (err) {
            server.error(err);
        } else {
            // set receive callback
            gateway.loraSetReceiveHandler(sendNextInitCmd.bindenv(this));
            cmdIdx = 0;
            sendNextInitCmd();
        }
    }

    function sendNextInitCmd(data = null) {
        if (data == "invalid_param") {
            // Set init command failed - log it
            server.error("Radio command failed: " + data);
        } else if (cmdIdx < initCommands.len()) {
            local command = initCommands[cmdIdx++];
            server.log(command);
            // send next command to LoRa
            gateway.loraSend(command);
        } else {
            gateway.loraSetReceiveHandler(receive.bindenv(this));
            // Radio ready to receive, green LED on
            gateway.setLED(gateway.GREEN_LED, gateway.LED_ON);
        }
    }

    function setInitCommands() {
        initCommands = [ format("%s mod %s", RADIO_SET, RADIO_MODE),
                         format("%s freq %i", RADIO_SET, RADIO_FREQ),
                         format("%s sf %s", RADIO_SET, RADIO_SPREADING_FACTOR),
                         format("%s bw %i", RADIO_SET, RADIO_BANDWIDTH),
                         format("%s cr %s", RADIO_SET, RADIO_CODING_RATE),
                         format("%s crc %s", RADIO_SET, RADIO_CRC),
                         format("%s sync %i", RADIO_SET, RADIO_SYNC_WORD),
                         format("%s wdt %i", RADIO_SET, RADIO_WATCHDOG_TIMEOUT),
                         format("%s pwr %i", RADIO_SET, RADIO_POWER_OUT),
                         MAC_PAUSE,
                         format("%s %i", RADIO_RX, RADIO_RX_WINDOW_SIZE) ];

        // RADIO_SET responses: ok, invalid_param
        // radio rx responses: ok, invalid_param, busy -- then radio_rx <data>, radio_err
    }

    function receive(data) {
        if (data.len() > 10 && data.slice(0,10) == "radio_rx  ") {
            // We have received a packet
            // Flash amber LED
            gateway.flashLED(gateway.AMBER_LED);

            // Parse data into a table
            local packet = _parse(data);

            // Filter data & send only when movement or event detected
            _filter(packet);

            // Send ACK
            gateway.loraSend( format("%s %s%s%s", RADIO_TX, TX_HEADER, ACK_COMMAND, TX_FOOTER) );
        } else if (data == "radio_tx_ok" || data == "radio_err") {
            // Queue next receive
            gateway.loraSend( format("%s %i", RADIO_RX, RADIO_RX_WINDOW_SIZE) );
        } else if (data != "ok") {
            // Unexpected response - log it
            server.log(data);
        }
    }

    function _filter(packet) {
        // Check that message came from our ball
        if ("id" in packet && packet.id == LORA_DEVICE_ID) {
            if ("event" in packet && !eventActive) {
                // Toggle event flag
                eventActive = true;
                // Turn on red LED
                gateway.setLED(gateway.RED_LED, gateway.LED_ON);
                // Send event to agent
                agent.send("event", {"event": "freefall detected"});
                // Block incoming events while current event is active
                imp.wakeup(EVENT_TIMEOUT, function() {
                    eventActive = false;
                    // Turn off red LED
                    gateway.setLED(gateway.RED_LED, gateway.LED_OFF);
                }.bindenv(this));
            }
            if ("reading" in packet) {
                local newX = packet.reading.x;
                local newY = packet.reading.y;
                local newZ = packet.reading.z;
                // Check for movement
                if (_changed(prevX, newX) || _changed(prevY, newY) || _changed(prevZ, newZ)) {
                    local now = hardware.millis();
                    // Limit movement updates
                    if (prevMovementUpdate == null || now >= MOVEMENT_TIMEOUT + prevMovementUpdate) {
                        // Update last update timestamp
                        prevMovementUpdate = now;
                        // Send reading
                        agent.send("reading", packet.reading);
                    }
                }
                // update stored values
                prevX = newX;
                prevY = newY;
                prevZ = newZ;
            }
        }
    }

    function _changed(prev, new) {
        if (prev == null) return true;
        return (prev + MOVEMENT_FILTER_RANGE < new || prev - MOVEMENT_FILTER_RANGE > new);
    }

    function _parse(data) {
        // Remove radio command ("radio_x ") from data
        // Turn data from hex to binary
        local received = _hextobytes(data.slice(10));

        // Remove Binary Header (FFFF0000)
        received = received.tostring().slice(4);

        // Parse data
        local raw = "";
        local packet = {};
        foreach (val in received) {
            if (val != 0x00) raw += val.tochar();
        }
        if (_debug) server.log(raw);

        try {
            if (raw.find(LORA_DEVICE_ID) != null) {
                raw = split(raw, ",");
                packet.id <- raw[0];
                if (raw[1] == "t") packet.event <- "Freefall Detected";
                if (raw.len() == 5) {
                    packet.reading <- {};
                    packet.reading.x <- raw[2].tofloat();
                    packet.reading.y <- raw[3].tofloat();
                    packet.reading.z <- raw[4].tofloat();
                }
            }
            return packet;
        } catch(e) {
            if (_debug) server.log(e);
            return null;
        }
    }

    function _hextobytes(hex) {
        if (_debug) server.log(hex);
        local b = blob(hex.len()/2);
        local byte;
        for(local i=0; i < hex.len(); i+=2) {
            byte = (hex[i] >= 'A') ? (hex[i] - 'A' + 10) << 4 : (hex[i] - '0') << 4;
            byte += (hex[i+1] >= 'A') ? (hex[i+1] - 'A' + 10) : (hex[i+1] - '0');
            b.writen(byte, 'b');
        }
        return b;
    }

}


// RUNTIME
// -------------------------------------------------------------

server.log(imp.getsoftwareversion());
imp.enableblinkup(true);
local enableDebugLogging = false;

// Initialize LoRa radio, and open a receive listener
    // Green LED will be lit when radio ready
    // Amber LED will flash when radio receives a packet
    // Red LED will be lit when event has been triggered
    // Filter incoming data
        // Send accel data when ball moves
        // Send event when ball throw detected
app <- Application(enableDebugLogging);