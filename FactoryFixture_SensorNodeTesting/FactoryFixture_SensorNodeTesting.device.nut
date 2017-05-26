// Temp/Humid Sensor Lib
#require "HTS221.class.nut:1.0.1"
// Air Pressure Sensor Lib
#require "LPS22HB.class.nut:1.0.0"
// Accelerometer Sensor Lib
#require "LIS3DH.class.nut:1.3.0"
// OneWire Lib
#require "Onewire.class.nut:1.0.1"
// Promise Lib
#require "promise.class.nut:3.0.0"
// Factory Tools Lib
#require "FactoryTools.class.nut:2.1.0"
// Factory Fixture Keyboard/Display Lib
#require "CFAx33KL.class.nut:1.1.0"

// Printer Driver
class QL720NW {
    static version = [0,1,0];

    _uart = null;   // A preconfigured UART
    _buffer = null; // buffer for building text

    // Commands
    static CMD_ESCP_ENABLE      = "\x1B\x69\x61\x00";
    static CMD_ESCP_INIT        = "\x1B\x40";

    static CMD_SET_ORIENTATION  = "\x1B\x69\x4C"
    static CMD_SET_TB_MARGINS   = "\x1B\x28\x63\x34\x30";
    static CMD_SET_LEFT_MARGIN  = "\x1B\x6C";
    static CMD_SET_RIGHT_MARGIN = "\x1B\x51";

    static CMD_ITALIC_START     = "\x1b\x34";
    static CMD_ITALIC_STOP      = "\x1B\x35";
    static CMD_BOLD_START       = "\x1b\x45";
    static CMD_BOLD_STOP        = "\x1B\x46";
    static CMD_UNDERLINE_START  = "\x1B\x2D\x31";
    static CMD_UNDERLINE_STOP   = "\x1B\x2D\x30";

    static CMD_SET_FONT_SIZE    = "\x1B\x58\x00";
    static CMD_SET_FONT         = "\x1B\x6B";

    static CMD_BARCODE          = "\x1B\x69"
    static CMD_2D_BARCODE       = "\x1B\x69\x71"

    static LANDSCAPE            = "\x31";
    static PORTRAIT             = "\x30";

    // Special characters
    static TEXT_NEWLINE         = "\x0A";
    static PAGE_FEED            = "\x0C";

    // Font Parameters
    static ITALIC               = 1;
    static BOLD                 = 2;
    static UNDERLINE            = 4;

    static FONT_SIZE_24         = 24;
    static FONT_SIZE_32         = 32;
    static FONT_SIZE_48         = 48;

    static FONT_BROUGHAM        = 0;
    static FONT_LETTER_GOTHIC_BOLD = 1;
    static FONT_BRUSSELS        = 2;
    static FONT_HELSINKI        = 3;
    static FONT_SAN_DIEGO       = 4;

    // Barcode Parameters
    static BARCODE_CODE39       = "t0";
    static BARCODE_ITF          = "t1";
    static BARCODE_EAN_8_13     = "t5";
    static BARCODE_UPC_A = "t5";
    static BARCODE_UPC_E        = "t6";
    static BARCODE_CODABAR      = "t9";
    static BARCODE_CODE128      = "ta";
    static BARCODE_GS1_128      = "tb";
    static BARCODE_RSS          = "tc";
    static BARCODE_CODE93       = "td";
    static BARCODE_POSTNET      = "te";
    static BARCODE_UPC_EXTENTION = "tf";

    static BARCODE_CHARS        = "r1";
    static BARCODE_NO_CHARS     = "r0";

    static BARCODE_WIDTH_XXS    = "w4";
    static BARCODE_WIDTH_XS     = "w0";
    static BARCODE_WIDTH_S      = "w1";
    static BARCODE_WIDTH_M      = "w2";
    static BARCODE_WIDTH_L      = "w3";

    static BARCODE_RATIO_2_1     = "z0";
    static BARCODE_RATIO_25_1    = "z1";
    static BARCODE_RATIO_3_1     = "z2";

    // 2D Barcode Parameters
    static BARCODE_2D_CELL_SIZE_3   = "\x03";
    static BARCODE_2D_CELL_SIZE_4   = "\x04";
    static BARCODE_2D_CELL_SIZE_5   = "\x05";
    static BARCODE_2D_CELL_SIZE_6   = "\x06";
    static BARCODE_2D_CELL_SIZE_8   = "\x08";
    static BARCODE_2D_CELL_SIZE_10  = "\x0A";

    static BARCODE_2D_SYMBOL_MODEL_1    = "\x01";
    static BARCODE_2D_SYMBOL_MODEL_2    = "\x02";
    static BARCODE_2D_SYMBOL_MICRO_QR   = "\x03";

    static BARCODE_2D_STRUCTURE_NOT_PARTITIONED = "\x00";
    static BARCODE_2D_STRUCTURE_PARTITIONED     = "\x01";

    static BARCODE_2D_ERROR_CORRECTION_HIGH_DENSITY             = "\x01";
    static BARCODE_2D_ERROR_CORRECTION_STANDARD                 = "\x02";
    static BARCODE_2D_ERROR_CORRECTION_HIGH_RELIABILITY         = "\x03";
    static BARCODE_2D_ERROR_CORRECTION_ULTRA_HIGH_RELIABILITY   = "\x04";

    static BARCODE_2D_DATA_INPUT_AUTO   = "\x00";
    static BARCODE_2D_DATA_INPUT_MANUAL = "\x01";

    constructor(uart, init = true) {
        _uart = uart;
        _buffer = blob();

        if (init) return initialize();
    }

    function initialize() {
        _uart.write(CMD_ESCP_ENABLE); // Select ESC/P mode
        _uart.write(CMD_ESCP_INIT); // Initialize ESC/P mode

        return this;
    }


    // Formating commands
    function setOrientation(orientation) {
        // Create a new buffer that we prepend all of this information to
        local orientationBuffer = blob();

        // Set the orientation
        orientationBuffer.writestring(CMD_SET_ORIENTATION);
        orientationBuffer.writestring(orientation);

        _uart.write(orientationBuffer);

        return this;
    }

    function setRightMargin(column) {
        return _setMargin(CMD_SET_RIGHT_MARGIN, column);
    }

    function setLeftMargin(column) {
        return _setMargin(CMD_SET_LEFT_MARGIN, column);;
    }

    function setFont(font) {
        if (font < 0 || font > 4) throw "Unknown font";

        _buffer.writestring(CMD_SET_FONT);
        _buffer.writen(font, 'b');

        return this;
    }

    function setFontSize(size) {
        if (size != 24 && size != 32 && size != 48) throw "Invalid font size";

        _buffer.writestring(CMD_SET_FONT_SIZE)
        _buffer.writen(size, 'b');
        _buffer.writen(0, 'b');

        return this;
    }

    // Text commands
    function write(text, options = 0) {
        local beforeText = "";
        local afterText = "";

        if (options & ITALIC) {
            beforeText  += CMD_ITALIC_START;
            afterText   += CMD_ITALIC_STOP;
        }

        if (options & BOLD) {
            beforeText  += CMD_BOLD_START;
            afterText   += CMD_BOLD_STOP;
        }

        if (options & UNDERLINE) {
            beforeText  += CMD_UNDERLINE_START;
            afterText   += CMD_UNDERLINE_STOP;
        }

        _buffer.writestring(beforeText + text + afterText);

        return this;
    }

    function writen(text, options = 0) {
        return write(text + TEXT_NEWLINE, options);
    }

    function newline() {
        return write(TEXT_NEWLINE);
    }

    // Barcode commands
    function writeBarcode(data, config = {}) {
        // Set defaults
        if(!("type" in config)) { config.type <- BARCODE_CODE39; }
        if(!("charsBelowBarcode" in config)) { config.charsBelowBarcode <- true; }
        if(!("width" in config)) { config.width <- BARCODE_WIDTH_XS; }
        if(!("height" in config)) { config.height <- 0.5; }
        if(!("ratio" in config)) { config.ratio <- BARCODE_RATIO_2_1; }

        // Start the barcode
        _buffer.writestring(CMD_BARCODE);

        // Set the type
        _buffer.writestring(config.type);

        // Set the text option
        if (config.charsBelowBarcode) {
            _buffer.writestring(BARCODE_CHARS);
        } else {
            _buffer.writestring(BARCODE_NO_CHARS);
        }

        // Set the width
        _buffer.writestring(config.width);

        // Convert height to dots
        local h = (config.height*300).tointeger();
        // Set the height
        _buffer.writestring("h");               // Height marker
        _buffer.writen(h & 0xFF, 'b');          // Lower bit of height
        _buffer.writen((h / 256) & 0xFF, 'b');  // Upper bit of height

        // Set the ratio of thick to thin bars
        _buffer.writestring(config.ratio);

        // Set data
        _buffer.writestring("\x62");
        _buffer.writestring(data);

        // End the barcode
        if (config.type == BARCODE_CODE128 || config.type == BARCODE_GS1_128 || config.type == BARCODE_CODE93) {
            _buffer.writestring("\x5C\x5C\x5C");
        } else {
            _buffer.writestring("\x5C");
        }

        return this;
    }

    function write2dBarcode(data, config = {}) {
        // Set defaults
        if (!("cell_size" in config)) { config.cell_size <- BARCODE_2D_CELL_SIZE_3; }
        if (!("symbol_type" in config)) { config.symbol_type <- BARCODE_2D_SYMBOL_MODEL_2; }
        if (!("structured_append_partitioned" in config)) { config.structured_append_partitioned <- false; }
        if (!("code_number" in config)) { config.code_number <- 0; }
        if (!("num_partitions" in config)) { config.num_partitions <- 0; }

        if (!("parity_data" in config)) { config["parity_data"] <- 0; }
        if (!("error_correction" in config)) { config["error_correction"] <- BARCODE_2D_ERROR_CORRECTION_STANDARD; }
        if (!("data_input_method" in config)) { config["data_input_method"] <- BARCODE_2D_DATA_INPUT_AUTO; }

        // Check ranges
        if (config.structured_append_partitioned) {
            config.structured_append <- BARCODE_2D_STRUCTURE_PARTITIONED;
            if (config.code_number < 1 || config.code_number > 16) throw "Unknown code number";
            if (config.num_partitions < 2 || config.num_partitions > 16) throw "Unknown number of partitions";
        } else {
            config.structured_append <- BARCODE_2D_STRUCTURE_NOT_PARTITIONED;
            config.code_number = "\x00";
            config.num_partitions = "\x00";
            config.parity_data = "\x00";
        }

        // Start the barcode
        _buffer.writestring(CMD_2D_BARCODE);

        // Set the parameters
        _buffer.writestring(config.cell_size);
        _buffer.writestring(config.symbol_type);
        _buffer.writestring(config.structured_append);
        _buffer.writestring(config.code_number);
        _buffer.writestring(config.num_partitions);
        _buffer.writestring(config.parity_data);
        _buffer.writestring(config.error_correction);
        _buffer.writestring(config.data_input_method);

        // Write data
        _buffer.writestring(data);

        // End the barcode
        _buffer.writestring("\x5C\x5C\x5C");

        return this;
    }

    // Prints the label
    function print() {
        _buffer.writestring(PAGE_FEED);
        _uart.write(_buffer);
        _buffer = blob();
    }

    function _setMargin(command, margin) {
        local marginBuffer = blob();
        marginBuffer.writestring(command);
        marginBuffer.writen(margin & 0xFF, 'b');

        _uart.write(marginBuffer);

        return this;
    }

    function _typeof() {
        return "QL720NW";
    }
}

class SensorNodeFactory {

    constructor(ssid, password) {
        // Use callback, so DUT wake from sleep is handled correctly
        FactoryTools.isFactoryFirmware(function(isFactoryEnv) {
            if (isFactoryEnv) {
                FactoryTools.isFactoryImp() ? RunFactoryFixture(ssid, password) : RunDeviceUnderTest();
            } else {
              server.log("This firmware is not running in the Factory Environment");
            }
        }.bindenv(this))
    }

    RunFactoryFixture = class {

        // How long to wait (seconds) after triggering BlinkUp before allowing another
        static BLINKUP_TIME = 5;

        // Flag used to prevent new BlinkUp triggers while BlinkUp is running
        sendingBlinkUp = false;

        FactoryFixture_005 = null;
        lcd = null;
        printer = null;

        _ssid = null;
        _password = null;

        constructor(ssid, password) {
            imp.enableblinkup(true);
            _ssid = ssid;
            _password = password;

            // Factory Fixture HAL
            FactoryFixture_005 = {
                "LED_RED" : hardware.pinF,
                "LED_GREEN" : hardware.pinE,
                "BLINKUP_PIN" : hardware.pinM,
                "GREEN_BTN" : hardware.pinC,
                "FOOTSWITCH" : hardware.pinH,
                "LCD_DISPLAY_UART" : hardware.uart2,
                "USB_PWR_EN" : hardware.pinR,
                "USB_FAULT_L" : hardware.pinW,
                "RS232_UART" : hardware.uart0,
                "FTDI_UART" : hardware.uart1,
            }

            // Initialize front panel LEDs to Off
            FactoryFixture_005.LED_RED.configure(DIGITAL_OUT, 0);
            FactoryFixture_005.LED_GREEN.configure(DIGITAL_OUT, 0);

            // Intiate factory BlinkUp on either a front-panel button press or footswitch press
            configureBlinkUpTrigger(FactoryFixture_005.GREEN_BTN);
            configureBlinkUpTrigger(FactoryFixture_005.FOOTSWITCH);

            lcd = CFAx33KL(FactoryFixture_005.LCD_DISPLAY_UART);
            setDefaultDisply();
            configurePrinter();

            // Open agent listener
            agent.on("data.to.print", printLabel.bindenv(this));
        }

        function configureBlinkUpTrigger(pin) {
            // Register a state-change callback for BlinkUp Trigger Pins
            pin.configure(DIGITAL_IN, function() {
                // Trigger only on rising edges, when BlinkUp is not already running
                if (pin.read() && !sendingBlinkUp) {
                    sendingBlinkUp = true;
                    imp.wakeup(BLINKUP_TIME, function() {
                        sendingBlinkUp = false;
                    }.bindenv(this));

                    // Send factory BlinkUp
                    server.factoryblinkup(_ssid, _password, FactoryFixture_005.BLINKUP_PIN, BLINKUP_FAST | BLINKUP_ACTIVEHIGH);
                }
            }.bindenv(this));
        }

        function setDefaultDisply() {
            lcd.clearAll();
            lcd.setLine1("Electric Imp");
            lcd.setLine2("SensorNodeTests");
            lcd.setBrightness(100);
            lcd.storeCurrentStateAsBootState();
        }

        function configurePrinter() {
            FactoryFixture_005.RS232_UART.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS, function() {
                server.log(uart.readstring());
            });

            printer = QL720NW(FactoryFixture_005.RS232_UART)
                .setOrientation(QL720NW.PORTRAIT)
                .setFont(QL720NW.FONT_HELSINKI)
                .setFontSize(QL720NW.FONT_SIZE_48);
        }

        function printLabel(data) {
            if (printer == null) configurePrinter();

            printer.setOrientation(QL720NW.PORTRAIT)
                   .setFont(QL720NW.FONT_HELSINKI)
                   .setFontSize(QL720NW.FONT_SIZE_48);

            if ("mac" in data) {
                // Log mac address
                server.log(data.mac);
                // Add 2D barcode of mac address to label
                printer.write2dBarcode(data.mac, {
                    "cell_size": QL720NW.BARCODE_2D_CELL_SIZE_5,
                    "symbol_type": QL720NW.BARCODE_2D_SYMBOL_MODEL_2,
                    "structured_append_partitioned": false,
                    "error_correction": QL720NW.BARCODE_2D_ERROR_CORRECTION_STANDARD,
                    "data_input_method": QL720NW.BARCODE_2D_DATA_INPUT_AUTO
                });
                // Add mac address to label
                printer.write(data.mac);
                // Print label
                printer.print();
                // Log status
                server.log("Printed: "+data.mac);
            }
        }
    }

    // -------------------------------------------

    RunDeviceUnderTest = class {

        static LED_FEEDBACK_AFTER_TEST = 0.5;
        static PAUSE_BTWN_TESTS = 0.2;

        test = null;

        constructor() {
            test = SensorNodeTestSuite(LED_FEEDBACK_AFTER_TEST, PAUSE_BTWN_TESTS, testsDone.bindenv(this));
            test.run();
        }

        function testsDone(passed) {
            // Only print label for passing hardware
            if (passed) {
                local deviceData = {};
                deviceData.mac <- imp.getmacaddress();
                deviceData.id <- hardware.getdeviceid();
                server.log("Sending Label Data: " + deviceData.mac);
                agent.send("set.label.data", deviceData);
            }

            // Bless device
            server.bless(passed, function(blessSuccess) {
                server.log("Blessing " + (blessSuccess ? "PASSED" : "FAILED"));
            }.bindenv(this));

            // Clear wifi credentials on power cycle
            imp.clearconfiguration();
            // clear test results
            agent.send("clear.test.results", null);
        }

        // Sensor Node Tests
        SensorNodeTests = class {

            static LED_ON = 0;
            static LED_OFF = 1;

            _enableAccelInt = null;
            _enablePressInt = null;
            _enableTempHumidInt = null;

            _intHandler = null;

            _wake = null;

            tempHumid = null;
            press = null;
            accel = null;

            ow = null;

            SensorNode_003 = null;

            led_blue = null;
            led_green = null;

            testDone = false;

            constructor(enableAccelInt, enablePressInt, enableTempHumidInt, intHandler) {
                // Sensor Node HAL
                SensorNode_003 = {
                    "LED_BLUE" : hardware.pinP,
                    "LED_GREEN" : hardware.pinU,
                    "SENSOR_I2C" : hardware.i2cAB,
                    "TEMP_HUMID_I2C_ADDR" : 0xBE,
                    "ACCEL_I2C_ADDR" : 0x32,
                    "PRESSURE_I2C_ADDR" : 0xB8,
                    "RJ12_ENABLE_PIN" : hardware.pinS,
                    "ONEWIRE_BUS_UART" : hardware.uartDM,
                    "RJ12_I2C" : hardware.i2cFG,
                    "RJ12_UART" : hardware.uartFG,
                    "WAKE_PIN" : hardware.pinW,
                    "ACCEL_INT_PIN" : hardware.pinT,
                    "PRESSURE_INT_PIN" : hardware.pinX,
                    "TEMP_HUMID_INT_PIN" : hardware.pinE,
                    "NTC_ENABLE_PIN" : hardware.pinK,
                    "THERMISTER_PIN" : hardware.pinJ,
                    "FTDI_UART" : hardware.uartQRPW,
                    "PWR_3v3_EN" : hardware.pinY
                }

                imp.enableblinkup(true);
                _enableAccelInt = enableAccelInt;
                _enablePressInt = enablePressInt;
                _enableTempHumidInt = enableTempHumidInt;

                _intHandler = intHandler;

                _wake = SensorNode_003.WAKE_PIN;

                SensorNode_003.SENSOR_I2C.configure(CLOCK_SPEED_400_KHZ);
                SensorNode_003.RJ12_I2C.configure(CLOCK_SPEED_400_KHZ);

                // initialize sensors
                tempHumid = HTS221(SensorNode_003.SENSOR_I2C, SensorNode_003.TEMP_HUMID_I2C_ADDR);
                press = LPS22HB(SensorNode_003.SENSOR_I2C, SensorNode_003.PRESSURE_I2C_ADDR);
                accel = LIS3DH(SensorNode_003.SENSOR_I2C, SensorNode_003.ACCEL_I2C_ADDR);
                ow = Onewire(SensorNode_003.ONEWIRE_BUS_UART, true);

                // configure leds
                led_blue = SensorNode_003.LED_BLUE;
                led_green = SensorNode_003.LED_GREEN;
                led_blue.configure(DIGITAL_OUT, LED_OFF);
                led_green.configure(DIGITAL_OUT, LED_OFF);

                _checkWakeReason();
            }

            function scanSensorI2C() {
                local addrs = [];
                for (local i = 2 ; i < 256 ; i+=2) {
                    if (SensorNode_003.SENSOR_I2C.read(i, "", 1) != null) {
                        server.log(format("Device at address: 0x%02X", i));
                        addrs.push(i);
                    }
                }
                return addrs;
            }

            function scanRJ12I2C() {
                SensorNode_003.PWR_3v3_EN.configure(DIGITAL_OUT, 1);
                local addrs = [];
                SensorNode_003.RJ12_ENABLE_PIN.configure(DIGITAL_OUT, 1);
                for (local i = 2 ; i < 256 ; i+=2) {
                    if (SensorNode_003.RJ12_I2C.read(i, "", 1) != null) {
                        server.log(format("Device at address: 0x%02X", i));
                        addrs.push(i);
                    }
                }
                SensorNode_003.PWR_3v3_EN.write(0);
                return addrs;
            }

            function testSleep() {
                server.log("At full power...");
                imp.wakeup(10, function() {
                    server.log("Going to deep sleep for 20s...");
                    accel.enable(false);
                    imp.onidle(function() { imp.deepsleepfor(20); })
                }.bindenv(this))
            }

            function testTempHumid() {
                // Take a sync reading and log it
                tempHumid.setMode(HTS221_MODE.ONE_SHOT);
                local thReading = tempHumid.read();
                if ("error" in thReading) {
                    server.error(thReading.error);
                    return false;
                } else {
                    server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", thReading.humidity, "%", thReading.temperature));
                    return ((thReading.humidity > 0 && thReading.humidity < 100) && (thReading.temperature > 10 && thReading.temperature < 50));
                }
            }

            function testAccel() {
                // Take a sync reading and log it
                accel.init();
                accel.setDataRate(10);
                accel.enable();
                local accelReading = accel.getAccel();
                server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));
                return (accelReading.x > -1.5 && accelReading.x < 1.5) && (accelReading.y > -1.5 && accelReading.y < 1.5) && (accelReading.z > -1.5 && accelReading.z < 1.5)
            }

            function testPressure() {
                // Take a sync reading and log it
                press.softReset();
                local pressReading = press.read();
                if ("error" in pressReading) {
                    server.error(pressReading.error);
                    return false;
                } else {
                    server.log("Current Pressure: " + pressReading.pressure);
                    return (pressReading.pressure > 800 && pressReading.pressure < 1200);
                }
            }

            function testOnewire() {
                SensorNode_003.PWR_3v3_EN.configure(DIGITAL_OUT, 1);
                SensorNode_003.RJ12_ENABLE_PIN.configure(DIGITAL_OUT, 1);
                if (ow.reset()) {
                    local devices = ow.discoverDevices();
                    foreach (id in devices) {
                        local str = ""
                        foreach(idx, val in id) {
                            str += val
                            if (idx < id.len() - 1) str += ".";
                        }
                        server.log("Found device with id: " + str);
                    }
                    return (devices.len() > 0);
                }
                SensorNode_003.PWR_3v3_EN.write(0);
                return false;
            }

            function testLEDOn(led) {
                led.configure(DIGITAL_OUT, LED_ON);
                // server.log("Turning LED ON")
            }

            function testLEDOff(led) {
                led.write(LED_OFF);
                // server.log("Turning LED OFF")
            }

            function testInterrupts(testWake = false) {
                clearInterrupts();

                // Configure interrupt pins
                _wake.configure(DIGITAL_IN_WAKEUP, function() {
                    // When awake only trigger on pin high
                    if (!testWake && _wake.read() == 0) return;

                    local accelReading = accel.getAccel();
                    server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));

                    // Determine interrupt
                    if (_enableAccelInt) _accelIntHandler();
                    if (_enablePressInt) _pressIntHandler();

                }.bindenv(this));

                if (_enableAccelInt) _enableAccelInterrupt();
                if (_enablePressInt) _enablePressInterrupt();

                if (testWake) {
                    _sleep();
                }
            }

            function logIntPinState() {
                server.log("Wake pin: " + _wake.read());
                server.log("Accel int pin: " + SensorNode_003.ACCEL_INT_PIN.read());
                server.log("Press int pin: " + SensorNode_003.PRESSURE_INT_PIN.read());
            }

            // Private functions/Interrupt helpers
            // -------------------------------------------------------

            function _checkWakeReason() {
                local wakeReason = hardware.wakereason();
                switch (wakeReason) {
                    case WAKEREASON_PIN:
                        // Woke on interrupt pin
                        server.log("Woke b/c int pin triggered");
                        testDone = true;
                        server.log("nv" in getroottable())
                        if (_enableAccelInt) _accelIntHandler();
                        if (_enablePressInt) _pressIntHandler();
                        break;
                    case WAKEREASON_TIMER:
                        // Woke on timer
                        server.log("Woke b/c timer expired");
                        break;
                    default :
                        // Everything else
                        server.log("Rebooting...");
                }
            }

            function _sleep() {
                if (_wake.read() == 1) {
                    // logIntPinState();
                    imp.wakeup(1, _sleep.bindenv(this));
                } else {
                    // sleep for 24h
                    imp.onidle(function() { server.sleepfor(86400); });
                }
            }

            function clearInterrupts() {
                accel.configureFreeFallInterrupt(false);
                press.configureThresholdInterrupt(false);
                accel.getInterruptTable();
                press.getInterruptSrc();
                // logIntPinState();
            }

            function _enableAccelInterrupt() {
                accel.setDataRate(100);
                accel.enable();
                accel.configureInterruptLatching(true);
                accel.getInterruptTable();
                accel.configureFreeFallInterrupt(true);
                server.log("Free fall interrupt configured...");
                // accel.configureClickInterrupt(true, LIS3DH.DOUBLE_CLICK, 1.5, 5, 10, 50);
                // server.log("Double Click interrupt configured...");
            }

            function _accelIntHandler() {
                local intTable = accel.getInterruptTable();
                if (intTable.int1) server.log("Free fall detected: " + intTable.int1);
                // if (intTable.click) server.log("Click detected: " + intTable.click);
                // if (intTable.singleClick) server.log("Single click detected: " + intTable.singleClick);
                // if (intTable.doubleClick) server.log("Double click detected: " + intTable.doubleClick);
                _intHandler(intTable);
            }

            function _enablePressInterrupt() {
                press.setMode(LPS22HB_MODE.CONTINUOUS, 25);
                local intTable = press.getInterruptSrc();
                // this should always fire...
                press.configureThresholdInterrupt(true, 1000, LPS22HB.INT_LATCH | LPS22HB.INT_HIGH_PRESSURE);
                server.log("Pressure interrupt configured...");
            }

            function _pressIntHandler() {
                local intTable = press.getInterruptSrc();
                if (intTable.int_active) {
                    server.log("Pressure int triggered: " + intTable.int_active);
                    if (intTable.high_pressure) server.log("High pressure int: " + intTable.high_pressure);
                    if (intTable.low_pressure) server.log("Low pressure int: " + intTable.low_pressure);
                }
                _intHandler(intTable);
            }

        }

        // Sensor Node Test Suite
        SensorNodeTestSuite = class {

            // Interrupt settings
            static TEST_WAKE_INT = true;
            static ENABLE_ACCEL_INT = true;
            static ENABLE_PRESS_INT = false;
            static ENABLE_TEMPHUMID_INT = false;

            feedbackTimer = null;
            pauseTimer = null;
            node = null;
            done = null;

            constructor(_feedbackTimer, _pauseTimer, _done) {
                feedbackTimer = _feedbackTimer;
                pauseTimer = _pauseTimer;
                done = _done;
                node = SensorNodeFactory.RunDeviceUnderTest.SensorNodeTests(ENABLE_ACCEL_INT, ENABLE_PRESS_INT, ENABLE_TEMPHUMID_INT, interruptHandler.bindenv(this));
                agent.on("send.test.results", checkTestResults.bindenv(this));
            }

            function checkTestResults(testResults) {
                local passed = testResults.passed.len();
                local failed = testResults.failed.len();
                if (failed > 0) {
                    node.testLEDOn(node.led_blue);
                } else {
                    node.testLEDOn(node.led_green);
                }
                server.log("Number of tests passed: " + passed);
                server.log("Number of test failed: " + failed);
                server.log("Testing Done.");
                done(failed == 0);
            }

            function run() {
                if (!node.testDone) {
                    pause()
                        .then(function(result) {
                            if (result.msg) server.log(result.msg);
                            return testLEDs();
                        }.bindenv(this))
                        .then(function(result) {
                            processTestResult(result);
                            return pause();
                        }.bindenv(this))
                        // Temp humid sensor test
                        .then(function(result) {
                            if (result.msg) server.log(result.msg);
                            return ledFeedback(node.testTempHumid(), "Temp Humid sensor reading");
                        }.bindenv(this))
                        .then(function(result) {
                            processTestResult(result);
                            return pause();
                        }.bindenv(this))
                        // Pressure sensor test
                        .then(function(result) {
                            if (result.msg) server.log(result.msg);
                            return ledFeedback(node.testPressure(), "Pressure sensor reading");
                        }.bindenv(this))
                        .then(function(result) {
                            processTestResult(result);
                            return pause();
                        }.bindenv(this))
                        // Accel sensor test
                        .then(function(result) {
                            if (result.msg) server.log(result.msg);
                            return ledFeedback(node.testAccel(), "Accel sensor reading");
                        }.bindenv(this))
                        .then(function(result) {
                            processTestResult(result);
                            return pause();
                        }.bindenv(this))
                        // Onwire discovery test
                        .then(function(result) {
                            if (result.msg) server.log(result.msg);
                            return ledFeedback(node.testOnewire(), "OneWire discovery");
                        }.bindenv(this))
                        .then(function(result) {
                            processTestResult(result);
                            return pause();
                        }.bindenv(this))
                        // Onewire i2c test
                        .then(function(result) {
                            if (result.msg) server.log(result.msg);
                            local sensors = node.scanRJ12I2C();
                            return ledFeedback(sensors.find(0x80) != null, "OneWire I2C scan");
                        }.bindenv(this))
                        .then(function(result) {
                            processTestResult(result);
                            // give time to process i2c scan before going to sleep
                            local doublePauseLength = true;
                            return pause(doublePauseLength);
                        }.bindenv(this))
                        .then(function(result) {
                            if (result.msg) server.log(result.msg);
                            server.log("Test low power. Then wake by tossing");
                            // configure interrupt, and sleep
                            node.testInterrupts(TEST_WAKE_INT)
                        }.bindenv(this))
                }
            }

            function pause(double = false) {
                local pauseTime = (double) ? pauseTimer * 2 : pauseTimer;
                return Promise(function(resolve, reject) {
                    imp.wakeup(pauseTime, function() {
                        return resolve({"err" : null, "msg" : "Starting next test..."})
                    });
                }.bindenv(this))
            }

            function processTestResult(result) {
                if (result.err) server.error(result.err);
                if (result.msg) server.log(result.msg);
                agent.send("test.result", result);
            }

            function interruptHandler(intTable) {
                if ("int1" in intTable) {
                    imp.wakeup(0, function() {
                        ledFeedback(true, "Freefall detected")
                            .then(function(result) {
                                processTestResult(result);
                                return pause();
                            }.bindenv(this))
                            .then(function(result) {
                                server.log("Checking test results...");
                                agent.send("get.test.results", null);
                            }.bindenv(this))
                    }.bindenv(this))
                }
            }

            function testLEDs() {
                return Promise(function(resolve, reject) {
                    // Green LED on
                    node.testLEDOn(node.led_green);
                    imp.wakeup(feedbackTimer, function() {
                        // Green LED off
                        node.testLEDOff(node.led_green);
                        imp.wakeup(pauseTimer, function() {
                            // Blue LED on
                            node.testLEDOn(node.led_blue);
                            imp.wakeup(feedbackTimer, function() {
                                // Blue led off
                                node.testLEDOff(node.led_blue);
                                return resolve({"err" : null, "msg" : "LED Tesing Passed"});
                            }.bindenv(this));
                        }.bindenv(this))
                    }.bindenv(this));
                }.bindenv(this))
            }

            function ledFeedback(testResult, sensorMsg) {
                return Promise(function (resolve, reject) {
                    local err = null;
                    local msg = null;
                    if (testResult) {
                        // Green LED on
                        node.testLEDOn(node.led_green);
                        msg = sensorMsg + " test passed";
                    } else {
                        // Blue LED on
                        node.testLEDOn(node.led_blue);
                        err = sensorMsg + " test failed"
                    }
                    imp.wakeup(feedbackTimer, function() {
                        node.testLEDOff(node.led_green);
                        node.testLEDOff(node.led_blue);
                        return resolve({"err" : err, "msg" : msg});
                    }.bindenv(this));
                }.bindenv(this));
            }
        }

    }


}

// // Factory Code
// // ------------------------------------------
server.log("Device Running...");

const SSID = "";
const PASSWORD = "";

SensorNodeFactory(SSID, PASSWORD);