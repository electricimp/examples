// MIT License
//
// Copyright 2017 Electric Imp
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


// Thermocouple Driver Code

class Thermocouple {
    
    _spi = null;
    _cs = null;

    constructor(spi, cs) {
        // Assign class varaiables
        _spi = spi;
        _cs = cs;
    }

    function configureSPI() {
        // Configure SPI
        _spi.configure(SIMPLEX_RX | CLOCK_IDLE_LOW | MSB_FIRST, 2000);
        _cs.configure(DIGITAL_OUT, 1);
    }

    function read() {
        _cs.write(0);
        local b = _spi.readblob(2);
        _cs.write(1);
    
        // Extract reading, sign extend, divide by 4 to map to celsius
        return (( (b[0] << 6) + (b[1] >> 2) ) << 18) >> 20; 
    }
}

// Fieldbus Gateway Hardware Abstraction Layer
FieldbusGateway_005 <- {
    "LED_RED" : hardware.pinP,
    "LED_GREEN" : hardware.pinT,
    "LED_YELLOW" : hardware.pinQ,

    "MIKROBUS_AN" : hardware.pinM,
    "MIKROBUS_RESET" : hardware.pinH,
    "MIKROBUS_SPI" : hardware.spiBCAD,
    "MIKROBUS_SPI_CS" : hardware.pinD,
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

// Our Application Code 
class Application {

    static RED = 0x00;
    static YELLOW = 0x01;
    static GREEN = 0x02;

    static LED_ON = 0;
    static LED_OFF = 1;

    static READING_INTERVAL = 10;
    static BLINK_SEC = 0.5;

    temp = null;

    constructor() {
        // Configure Temperature Sensor
        local spi = FieldbusGateway_005.MIKROBUS_SPI;
        temp = Thermocouple(spi, FieldbusGateway_005.MIKROBUS_SPI_CS);
        temp.configureSPI();

        // Configure LEDs
        FieldbusGateway_005.LED_RED.configure(DIGITAL_OUT, LED_OFF);
        FieldbusGateway_005.LED_GREEN.configure(DIGITAL_OUT, LED_OFF);
        FieldbusGateway_005.LED_YELLOW.configure(DIGITAL_OUT, LED_OFF);

        // Open listener
        agent.on("blink", blinkLED.bindenv(this));

        // Give the agent time to connect to Azure
        // then start the loop
        imp.wakeup(5, loop.bindenv(this));
    }

    function loop() {
        // Take a temperature reading
        local result = temp.read();
        // Send reading to the agent
        agent.send("event", {"temperature" : result});
        // Schedule next reading
        imp.wakeup(READING_INTERVAL, loop.bindenv(this));
    }

    function blinkLED(color) {
        local led = null;
        switch (color) {
            case RED :
                led = FieldbusGateway_005.LED_RED;
                break;
            case YELLOW :
                led = FieldbusGateway_005.LED_YELLOW;
                break;
            case GREEN : 
                led = FieldbusGateway_005.LED_GREEN;
                break; 
        }

        // Turn LED on 
        led.write(LED_ON);
        // Wait BLINK_SEC then turn LED off
        imp.wakeup(BLINK_SEC, function() {
            led.write(LED_OFF)
        }.bindenv(this))
    }

}

// Start the application running
Application();
