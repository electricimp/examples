// MIT License
//
// Copyright 2018 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// MODBUS LIBRARIES
#require "CRC16.class.nut:1.0.0"
#require "ModbusRTU.device.lib.nut:1.0.1"
#require "ModbusMaster.device.lib.nut:1.0.1"
#require "ModbusSerialMaster.device.lib.nut:2.0.0"

// LOGGING HELPERS
#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONEncoder.class.nut:1.0.0"

// FIELDBUS GATEWAY HARDWARE ABSTRACTION LAYER
FieldbusGateway_005 <- {
    "LED_RED" : hardware.pinP,
    "LED_GREEN" : hardware.pinT,
    "LED_YELLOW" : hardware.pinQ,

    "MIKROBUS_AN" : hardware.pinM,
    "MIKROBUS_RESET" : hardware.pinH,
    "MIKROBUS_SPI" : hardware.spiBCAD,
    "MIKROBUS_PWM" : hardware.pinU,
    "MIKROBUS_INT" : hardware.pinXD,
    "MIKROBUS_UART" : hardware.uart1,
    "MIKROBUS_I2C" : hardware.i2cJK,

    "XBEE_RESET" : hardware.pinH,
    "XBEE_AND_RS232_UART": hardware.uart0,
    "XBEE_DTR_SLEEP" : hardware.pinXD,

    "RS485_UART" : hardware.uart2,
    "RS485_nRE" : hardware.pinL,

    "WIZNET_SPI" : hardware.spi0,
    "WIZNET_RESET" : hardware.pinXA,
    "WIZNET_INT" : hardware.pinXC,

    "USB_EN" : hardware.pinR,
    "USB_LOAD_FLAG" : hardware.pinW
}

/* APPLICATION CLASS
 *     - Takes temperature readings in a loop from thermistor 
 *       connected to analog input on PLC  
 *     - Reports temperature readings to agent
 *     - Reports an alert if temperature is greater than threshold
 *     - Turns Fieldbus Gateway LEDs and stack light connected to PLC
 *       digital output to GREEN when temperature is below threshold
 *     - Turns Fieldbus Gateway LEDs and stack light connected to PLC 
 *       digital output to RED when temperature is above threshold */
class ClickPLCTempMonitor {

    // RS485 UART SETTINGS
    static RS485_UART_BAUD_RATE                = 38400;
    static RS485_UART_PARITY                   = PARITY_ODD;

    // CLICK PLC ADDRESSES
    static CLICK_PLC_DEVICE_ADDR               = 0x01;
    static CLICK_PLC_ANALOG_IN_ADDR_AD1V       = 0x7000;
    static CLICK_PLC_DIGITAL_OUT_ADDR_Y1_GREEN = 8192; // Green Stack Light
    static CLICK_PLC_DIGITAL_OUT_ADDR_Y2_AMBER = 8193; // Amber Stack Light
    static CLICK_PLC_DIGITAL_OUT_ADDR_Y3_RED   = 8194; // Red Stack Light

    // LED STATE CONSTANTS
    static CLICK_PLC_DIGITAL_OUT_ON            = true;
    static CLICK_PLC_DIGITAL_OUT_OFF           = false;
    static FBG_LED_ON                          = 0;
    static FBG_LED_OFF                         = 1;

    // THEMISTOR CONSTANTS
    static NUM_ANALOG_READ_BYTES               = 2;
    static B_THERM                             = 3988;
    static T0_THERM                            = 265;

    // TEMP ALERT DEFAULT
    static DEFAULT_TEMP_THRESHOLD              = 28;

    // APPLICATION VARIABLES
    modbus                                     = null;
    pp                                         = null;
    print                                      = null;
    analogReadTimeSec                          = null;
    tempThresh                                 = null;

    // Configures modbus RS485 master library to control PLC, Fieldbus 
    // Gateway LEDs, and temperature reading loop and threshold.
    //      
    // Parameters: 
    //      _readTimeSec    (required)      Time in seconds between temperature readings
    //      _tempThresh     (optional)      Temperature threshold used to trigger alerts, 
    //                                      default is set to DEFAULT_TEMP_THRESHOLD
    //      _debug          (optional)      Boolean if Modbus UART traffic logging should be
    //                                      enabled, default is `false`
    // Returns:             Instance of ClickPLCTempMonitor class
    constructor(_readTimeSec, _tempThresh = null, _debug = false) {

        // Set temperature loop time and threshold 
        analogReadTimeSec = _readTimeSec;
        tempThresh = (_tempThresh == null) ? DEFAULT_TEMP_THRESHOLD : _tempThresh;

        // Configure Modbus
        local opts = (_debug) ? {"debug" : true} : {};
        opts.baudRate <- RS485_UART_BAUD_RATE;
        opts.parity <- RS485_UART_PARITY;
        modbus = Modbus485Master(FieldbusGateway_005.RS485_UART, FieldbusGateway_005.RS485_nRE, opts);
        
        // Configure pretty printer, so we can log tables and arrays
        pp = PrettyPrinter(null, false);
        print = pp.print.bindenv(pp);

        // Configure Fieldbus gateway LEDs
        configureFielbusLEDs();
    }

    // Starts the temperature reading loop
    // 
    // Parameters:  None
    // Returns:     Null   
    function run() {
        // Takes a reading from analog input and passes result to callback
        modbus.read(CLICK_PLC_DEVICE_ADDR, MODBUSRTU_TARGET_TYPE.INPUT_REGISTER, CLICK_PLC_ANALOG_IN_ADDR_AD1V, NUM_ANALOG_READ_BYTES, tempReadHandler.bindenv(this))
        // Schedules the next reading
        imp.wakeup(analogReadTimeSec, run.bindenv(this));
    }

    // Processes temperature reading
    // 
    // Parameters: 
    //      err (required)      Error message if error was encountered, `null` if no error was encountered    
    //      res (required)      Results of analog input reading
    // Returns:                 Null
    function tempReadHandler(err, res) {
        // Check for error during analog read
        if (err) {
            server.error(err);
            return;
        }

        // Check for expected data
        if (typeof res == "array" && res.len() == NUM_ANALOG_READ_BYTES) {
            
            // Convert result to float
            local reading = convertReadingToFloat(res);
            // Convert reading to temperature in deg C
            local temp = calculateTemp(reading);

            // Log temperature
            server.log("Temp " + temp + "°C");

            // Check threshold, and set stack light and LEDs accordingly
            local alert = 0;
            if (temp >= tempThresh) {
                alert = 1;
                setStackToRed();
                setFBGLEDsToRed();
            } else {
                setStackToGreen();
                setFBGLEDsToGreen();
            }
            
            // Create data table to send to agent
            local data = { "temperature"      : temp,
                           "temperatureLimit" : tempThresh,
                           "temperatureAlert" : alert };

            // Send data to agent
            agent.send("temp", data);
        } else {
            // Reading was not in expected format, so print the result
            print(res);
        }
    }

    // Sets temperature threshold to the value passed in
    // 
    // Parameters:  
    //      newTempThresh (required)    Integer, new value in deg C that will trigger a 
    //                                  temperature alert 
    // Returns:                         Null
    function setTempThreshold(newTempThresh) {
        tempThresh = newTempThresh;
    }

    // Temperature Reading Helpers
    // -------------------------------------------------------------------------------------------

    // Takes reading results array and coverts to a float
    // 
    // Parameters: 
    //      raw (required)      Takes the results array from analog PLC reading and 
    //                          coverts to float. Note: Array length must be 2, since blob 
    //                          length is set to 4
    // Returns:                 Reading as a float
    function convertReadingToFloat(raw) {
        local b = blob(4);
        foreach (item in raw) {
            b.writen(item, 's');
        }
        b.seek(0, 'b');
        return b.readn('f');
    }

    // Takes results from analog thermistor reading and calculates the temperature in deg C
    // 
    //  Parameters: 
    //      reading (required)      Analog reading, float
    //  Returns:                    Temperature in deg C, float
    function calculateTemp(reading) {
        local v_rat = reading / 100.0;
        local ln_therm = 0;

        ln_therm = math.log((1.0 - v_rat) / v_rat);
        local kelvin = (T0_THERM * B_THERM) / (B_THERM - T0_THERM * ln_therm);
        local celsius = kelvin - 273.15;
        return celsius;
    }


    // Stack Light Helpers
    // -------------------------------------------------------------------------------------------

    // Sets the specified stack light color to the specified state
    // 
    // Parameters:  
    //      addr  (required)    Digital output address of a stack light color
    //      state (required)    Boolean, true or ON, false for OFF
    // Returns:                 Null    
    function setStackLight(addr, state) {
        modbus.write(CLICK_PLC_DEVICE_ADDR, MODBUSRTU_TARGET_TYPE.COIL, addr, 1, state, function(err, res) {
            if (err) server.error(err);
        });
    }

    // Sets all stack light colors to ON
    // 
    // Parameters:  None
    // Returns:     Null   
    function allStackLXOn() {
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y1_GREEN, CLICK_PLC_DIGITAL_OUT_ON);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y2_AMBER, CLICK_PLC_DIGITAL_OUT_ON);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y3_RED, CLICK_PLC_DIGITAL_OUT_ON);
    }

    // Sets all stack light colors to OFF
    // 
    // Parameters:  None
    // Returns:     Null
    function allStackLXOff() {
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y1_GREEN, CLICK_PLC_DIGITAL_OUT_OFF);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y2_AMBER, CLICK_PLC_DIGITAL_OUT_OFF);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y3_RED, CLICK_PLC_DIGITAL_OUT_OFF);
    }
    
    // Sets stack light to green only to ON
    // 
    // Parameters:  None
    // Returns:     Null
    function setStackToGreen() {
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y2_AMBER, CLICK_PLC_DIGITAL_OUT_OFF);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y3_RED, CLICK_PLC_DIGITAL_OUT_OFF);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y1_GREEN, CLICK_PLC_DIGITAL_OUT_ON);
    }

    // Sets stack light to red only to ON
    // 
    // Parameters:  None
    // Returns:     Null
    function setStackToRed() {
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y1_GREEN, CLICK_PLC_DIGITAL_OUT_OFF);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y2_AMBER, CLICK_PLC_DIGITAL_OUT_OFF);
        setStackLight(CLICK_PLC_DIGITAL_OUT_ADDR_Y3_RED, CLICK_PLC_DIGITAL_OUT_ON);
    }


    // Fieldbus Gateway LED Helpers
    // -------------------------------------------------------------------------------------------

    function setFBGLEDsToGreen() {
        FieldbusGateway_005.LED_YELLOW.write(FB_LED_OFF);
        FieldbusGateway_005.LED_RED.write(FB_LED_OFF);
        FieldbusGateway_005.LED_GREEN.write(FB_LED_ON);
    }

    function setFBGLEDsToRed() {
        FieldbusGateway_005.LED_YELLOW.write(FB_LED_OFF);
        FieldbusGateway_005.LED_RED.write(FB_LED_ON);
        FieldbusGateway_005.LED_GREEN.write(FB_LED_OFF);
    }

    // Configures all Fieldbus Gateway LEDs to off
    // 
    // Parameters:  None
    // Returns:     Null
    function configureFielbusLEDs() {
        FieldbusGateway_005.LED_YELLOW.configure(DIGITAL_OUT, FB_LED_OFF);
        FieldbusGateway_005.LED_RED.configure(DIGITAL_OUT, FB_LED_OFF);
        FieldbusGateway_005.LED_GREEN.configure(DIGITAL_OUT, FB_LED_OFF);
    }

}

// RUNTIME
// ---------------------------------------------------------------
server.log("DEVICE RUNNING...");

// Allow Fieldbus gateway to blinkUp at anytime, note this will cause the blinkup LED to blink green
imp.enableblinkup(true);

// Log some network debugging info
server.log("SSID: "+imp.getssid());
server.log("Ch  : "+imp.net.info().interface[0].channel);

// Configure Application Settings
const READING_TIME_SEC =  3;     // Time between temperature readings
const TEMP_THRESHOLD   =  26;    // Temp in deg C that will trigger an alert
DEBUG                  <- false; // Logs Modbus Library UART Traffic

// Initialize Applicataion
app <- ClickPLCTempMonitor(READING_TIME_SEC, TEMP_THRESHOLD, DEBUG);

// Start temperature reading loop
app.run();
