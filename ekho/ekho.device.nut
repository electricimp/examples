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

// big digit display - this code is for a 6 digit display
// pin1 clear (active low)
// pin2 rclk
// pin5 srclk
// pin7 data
// pin9 oe_l
 
local function lastclock() {
    imp.sleep(0.001);
    hardware.pin2.write(1);
    hardware.pin2.write(0);
}
 
// Which segments need to be enabled to display each digit
local digits = [ 0x7b, 0x60, 0x5d, 0x75, 0x66, 0x37, 0x3f, 0x61, 0x7f, 0x77 ];
 
server.log("digit6");
 
hardware.configure(SPI_257);
hardware.spi.configure(SIMPLEX_TX | LSB_FIRST | CLOCK_IDLE_HIGH, 4000);
 
// Set Clear high
hardware.pin1.configure(DIGITAL_OUT);
hardware.pin1.write(1);
 
// Set RCLK low
hardware.pin2.configure(DIGITAL_OUT);
hardware.pin2.write(0);
 
// Set OE_L low
hardware.pin9.configure(DIGITAL_OUT);
hardware.pin9.write(0);
 
function show(svalue) {
    // Get number
    local value = math.abs(svalue);
    local sign = (svalue<0) ? "\x04":"\x00";
 
    // Right justified, blank-filled. Note this is for a 6 digit display. We support negative numbers.
    local s = format("%c",digits[(value)%10]);
    if (value>=10)     s+=format("%c", digits[(value/10)%10]);     else { s+=sign; sign="\x00"; }
    if (value>=100)    s+=format("%c", digits[(value/100)%10]);    else { s+=sign; sign="\x00"; }
    if (value>=1000)   s+=format("%c", digits[(value/1000)%10]);   else { s+=sign; sign="\x00"; }
    if (value>=10000)  s+=format("%c", digits[(value/10000)%10]);  else { s+=sign; sign="\x00"; }
    if (value>=100000) s+=format("%c", digits[(value/100000)%10]); else { s+=sign; sign="\x00"; }
 
    hardware.spi.write(s);
    lastclock();
}
 
class Digits extends InputPort {
    name = "Value to show";
    function set(value) {
        show(value);
        server.show(value);
    }
}
 
imp.configure("Digits 6", [ Digits() ], []);
show(0);