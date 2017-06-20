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

// Basic Example of Serial Communication with the imp
// Shows input on parallax 16x2 UART display
// This example includes a hook for an agent to send strings to the device

class parDisplay
{
    serPort = null;
    // clear screen
    CTRL_CLEAR = 0x0C;
    // new line
    CTRL_NEWL = 0x0D;
    // backlight on
    CTRL_BLON = 0x11;
    // backlight off
    CTRL_BLOFF = 0x12;
    // sound tone at concert A (440 Hz)
    CTRL_SNDA = 0xDC;

    constructor(port)
    {
        if (port == UART_57) {
            serPort = hardware.uart57
            server.log("Configured UART 57")
        } else if (port == UART_12) {
            serPort = hardware.uart12;
            server.log("Configured UART 12")
        } else {
            server.log("Invalid UART port specified.")
        }

        // set up the UART that we've selected
        // 9600 baud, 8 data bits, no parity bits, 1 stop bit, no flow control
        serPort.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);

        // start with cleared screen
        clear();
    }

    function clear() {
        serPort.write(CTRL_CLEAR);
    }

    function newl() {
        serPort.write(CTRL_NEWL);
    }

    function toneA() {
        serPort.write(CTRL_SNDA);
    }

    function light(state) {
        if (state == 0) {
            server.log("Light off")
            serPort.write(CTRL_BLOFF);
        } else {
            server.log("Light on")
            serPort.write(CTRL_BLON);
        }
    }

    function print(inputString) {
        serPort.write(inputString);
    }
}

// instantiate our parallax display class
display <- local display = parDisplay(UART_57);

// here we create a hook for an electric imp agent to send us strings
// agent.on() takes two parameters:
// first: a string to identify which callback the device should use to handle the event
// second: data to be used by the event handler (if there is any)
agent.on("newData", function(value) {
    display.light(1);
    display.print(value);
    imp.sleep(5);
    display.light(0);
})


// print to the log to show we're up and running
server.log("Disp UART: Start");
