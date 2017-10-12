// Modbus Libraries
#require "CRC16.class.nut:1.0.0"
#require "ModbusRTU.class.nut:1.0.0"
#require "ModbusMaster.class.nut:1.0.0"
#require "Modbus485Master.class.nut:1.0.0"

// Printing Utility Library
#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONEncoder.class.nut:1.0.0"

// Helper for printing tables and arrays
pp <- PrettyPrinter(null, false);
print <- pp.print.bindenv(pp);

// -------------------------------------------------------

// Message names

const PUMP_EVENT = "pump";
const TANK_LEVEL_EVENT = "tank_level";
const TANK_THRESHOLD = "tank_threshold";
const LOCATION = "location";

// Autodesk IoT Discovery Gateway Hardware Abstraction Layer

AutodeskGateway_005 <- {
  "LED_RED" : hardware.pinE,
  "LED_GREEN" : hardware.pinF,
  "LED_YELLOW" : hardware.pinG,

  "RS485_UART" : hardware.uart1,
  "RS485_nRE" : hardware.pinL,

  "WIZNET_SPI" : hardware.spi0,
  "WIZNET_RESET" : hardware.pinQ,
  "WIZNET_INT" : hardware.piH,

  "USB_EN" : hardware.pinR,
  "USB_LOAD_FLAG" : hardware.pinW
}

// Application Code

class App {

  static DEVICE_ADDRESS = 0x01;
  static BAUD_RATE = 38400;
  static PARITY = PARITY_ODD;

  static CLICK_ANALOG_IN_AD1V_ADDR = 0x7000; // Tank Level
  static CLICK_OUTPUT_Y1_ADDR = 8192; // Green Stack Light
  static CLICK_OUTPUT_Y2_ADDR = 8193; // Amber Stack Light
  static CLICK_OUTPUT_Y3_ADDR = 8194; // Red Stack Light
  static CLICK_OUTPUT_Y4_ADDR = 8195; // Pump
  static CLICK_INPUT_X1_ADDR = 0x0001; // Button

  static CLICK_OUT_ON = true;
  static CLICK_OUT_OFF = false;

  static FB_LED_ON = 0;
  static FB_LED_OFF = 1;

  static COIL_READ_BYTES = 1;
  static ANALOG_READ_BYTES = 2;
  static DEFAULT_POLLING_INT_SEC = 0.5;

  static LEVEL_RED_MIN = 80.0;
  static LEVEL_AMBER_MIN = 45.0;
  static LEVEL_GREEN_MIN = 5.0;
  static BLINK_DURATION_SEC = 0.25;
  static BLINKS = 3;

  static MOVEMENT_THRESHOLD = 0.5;
  static DEFAULT_LEVEL_MAX = 100.0;
  static DEFAULT_LEVEL_MIN = 0.0;

  // Variables to track state
  pump_btn = false;
  tank_level = null;

  modbus = null;

  _tankLevelThreshold = null;
  _pollingInt = null;

  _blinking = false;
  _blinkCounter = 0;

  constructor(tankLevelThreshold, pollingInt = null, debug = false) {
    imp.enableblinkup(true);
    logImpInfo();

    // Configure modbus master
    local opts = (debug) ? {"debug" : true} : {};
    opts.baudRate <- BAUD_RATE;
    opts.parity <- PARITY;
    modbus = Modbus485Master(AutodeskGateway_005.RS485_UART, AutodeskGateway_005.RS485_nRE, opts);

    // Configure button polling rate
    _pollingInt = (pollingInt) ? pollingInt : DEFAULT_POLLING_INT_SEC;

    // On boot re-set tank threshold
    _tankLevelThreshold = tankLevelThreshold;
    agent.send(TANK_THRESHOLD, _tankLevelThreshold);

    // Open listener for changes to tank level threshold
    agent.on(TANK_THRESHOLD, updateTankThreshold.bindenv(this));

    configureFielbusLEDs();

    // Send agent wifi scan to determine location
    agent.send(LOCATION, imp.scanwifinetworks());
  }

  function run() {
    modbus.read(DEVICE_ADDRESS, MODBUSRTU_TARGET_TYPE.COIL, CLICK_INPUT_X1_ADDR, COIL_READ_BYTES, buttonReadHandler.bindenv(this));
    modbus.read(DEVICE_ADDRESS, MODBUSRTU_TARGET_TYPE.INPUT_REGISTER, CLICK_ANALOG_IN_AD1V_ADDR, ANALOG_READ_BYTES, analogReadHandler.bindenv(this));
    imp.wakeup(_pollingInt, run.bindenv(this));
  }

  function configureFielbusLEDs() {
    AutodeskGateway_005.LED_YELLOW.configure(DIGITAL_OUT, FB_LED_OFF);
    AutodeskGateway_005.LED_RED.configure(DIGITAL_OUT, FB_LED_OFF);
    AutodeskGateway_005.LED_GREEN.configure(DIGITAL_OUT, FB_LED_OFF);
  }

  function logImpInfo() {
    server.log(imp.getmacaddress())
    server.log(imp.getsoftwareversion());
    server.log("SSID: " + imp.getssid());
    server.log("RSSI: " + imp.getrssi());
  }

  function buttonReadHandler(err, res) {
    if (err) {
      server.error(err);
    } else {
      local state = (typeof res == "array") ? res[0] : res;
      AutodeskGateway_005.LED_YELLOW.write(FB_LED_OFF);
      if (state != null && state != pump_btn) {
        // Button has changed state
        pump_btn = state;
        // Toggle Fieldbus Red LED with button state
        (state) ? AutodeskGateway_005.LED_RED.write(FB_LED_ON) : AutodeskGateway_005.LED_RED.write(FB_LED_OFF);

        // Start Pump if the last reading is less than max level
        if (tank_level < DEFAULT_LEVEL_MAX) {
          setOutput(CLICK_OUTPUT_Y4_ADDR, state);
          // Send new pump state to agent
          agent.send(PUMP_EVENT, state);
          // Toggle Fieldbus Green LED with pump state
          (state) ? AutodeskGateway_005.LED_GREEN.write(FB_LED_ON) : AutodeskGateway_005.LED_GREEN.write(FB_LED_OFF);
        }
      }
      imp.wakeup(0.05, function() { AutodeskGateway_005.LED_YELLOW.write(FB_LED_ON) }.bindenv(this));
    }
  }

  function analogReadHandler(err, res) {
    if (err) {
      server.error(err);
      return;
    }
    if (typeof res == "array" && res.len() == 2) {
      // Read registers
      local b = blob(4);
      foreach (item in res) { b.writen(item, 's'); }
      b.seek(0, 'b');
      local reading = b.readn('f');

      // Adjust reading to 0-100 scale
      reading = translateLevel(reading);

      // Check for change
      if (filter(reading)) {
        // Check threshold
        if (reading >= _tankLevelThreshold) {
          // Turn off pump
          setOutput(CLICK_OUTPUT_Y4_ADDR, CLICK_OUT_OFF);
          // Turn off Fieldbus green LED
          AutodeskGateway_005.LED_GREEN.write(FB_LED_OFF);
          _blinking = true;
          blinkStackLight();
        }

        // Update stack light
        if (!_blinking) setStackLight(reading);

        // Send Agent new tank level
        agent.send(TANK_LEVEL_EVENT, reading);
      }

      // Update tank_level tacker
      tank_level = reading;
    } else {
      print(res);
    }
  }

  function blinkStackLight() {
    allStackLXOn();
    imp.wakeup(BLINK_DURATION_SEC, function() {
      allStackLXOff();
      _blinkCounter++;
      if (_blinkCounter < BLINKS) {
        imp.wakeup(BLINK_DURATION_SEC, blinkStackLight.bindenv(this));
      } else {
        _blinking = false;
        _blinkCounter = 0;
      }
    }.bindenv(this))
  }

  function setStackLight(level) {
    if (level >= LEVEL_GREEN_MIN) {
      setOutput(CLICK_OUTPUT_Y1_ADDR, CLICK_OUT_ON);
    }
    if (level >= LEVEL_AMBER_MIN) {
      setOutput(CLICK_OUTPUT_Y2_ADDR, CLICK_OUT_ON);
    }
    if (level >= LEVEL_RED_MIN) {
      setOutput(CLICK_OUTPUT_Y3_ADDR, CLICK_OUT_ON);
    }
    if (level < LEVEL_GREEN_MIN) {
      setOutput(CLICK_OUTPUT_Y1_ADDR, CLICK_OUT_OFF);
    }
    if (level < LEVEL_AMBER_MIN) {
      setOutput(CLICK_OUTPUT_Y2_ADDR, CLICK_OUT_OFF);
    }
    if (level < LEVEL_RED_MIN) {
      setOutput(CLICK_OUTPUT_Y3_ADDR, CLICK_OUT_OFF);
    }
  }

  function allStackLXOn() {
    setOutput(CLICK_OUTPUT_Y1_ADDR, CLICK_OUT_ON);
    setOutput(CLICK_OUTPUT_Y2_ADDR, CLICK_OUT_ON);
    setOutput(CLICK_OUTPUT_Y3_ADDR, CLICK_OUT_ON);
  }
  function allStackLXOff() {
    setOutput(CLICK_OUTPUT_Y1_ADDR, CLICK_OUT_OFF);
    setOutput(CLICK_OUTPUT_Y2_ADDR, CLICK_OUT_OFF);
    setOutput(CLICK_OUTPUT_Y3_ADDR, CLICK_OUT_OFF);
  }

  function updateTankThreshold(threshold) {
    if (threshold > DEFAULT_LEVEL_MAX) threshold = DEFAULT_LEVEL_MAX;
    if (threshold < DEFAULT_LEVEL_MIN) threshold = DEFAULT_LEVEL_MIN;
    _tankLevelThreshold = threshold;
  }

  function filter(current) {
    if (tank_level == null) return true;
    // server.log(tank_level);
    return (math.fabs(current - tank_level) > MOVEMENT_THRESHOLD);
  }

  function translateLevel(input) {
    local level;
    if (input > 27) {
      level = 0.0;
    } else if (input <= 27 && input > 23) {
      level = 7.7;
    } else if (input <= 23 && input > 19) {
      level = 15.4;
    } else if (input <= 19 && input > 17) {
      level = 23.1;
    } else if (input <= 17 && input > 16) {
      level = 30.8;
    } else if (input <= 16 && input > 15) {
      level = 38.5;
    } else if (input <= 15 && input > 13.8) {
      level = 46.2;
    } else if (input <= 13.8 && input > 12.7) {
      level = 53.9;
    } else if (input <= 12.7 && input > 11) {
      level = 61.6;
    } else if (input <= 11 && input > 10) {
      level = 69.3;
    } else if (input <= 10 && input > 9) {
      level = 77.0;
    } else if (input <= 9 && input > 7.7) {
      level = 84.7;
    } else if (input <= 7.7 && input > 6) {
      level = 92.4;
    } else {
      level = 100.0;
    }
    return level + keepDecimals(input);
  }

  function keepDecimals(num) {
     return num - num.tointeger();
  }

  function setOutput(addr, state) {
    // TODO: add check for max and min here
    modbus.write(DEVICE_ADDRESS, MODBUSRTU_TARGET_TYPE.COIL, addr, 1, state, function(err, res) {
      if (err) server.error(err);
    });
  }
}


// RUNTIME
// -------------------------------------------------------

// Logs Modbus Library UART Traffic
local DEBUG = false;

// How often (in sec) to check for button and tank level changes
local POLLING_INT = 0.5;

// Threshold setting on boot up
local TANK_LEVEL_THRESHOLD = 100;

// Initialize Application
// P1 - threshold, P2 (opt) - polling int, P3 (opt) modbus debug logging
local app = App(TANK_LEVEL_THRESHOLD, POLLING_INT, DEBUG);

// Start polling inputs
app.run();
