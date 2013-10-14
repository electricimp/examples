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

// Jane 4-Relay Reference Design
// pin1 Alert
// pin2 OE_L
// pin5 SRCLK
// pin7 Data
// pin8 SCL
// pin9 SDA
 
server.log("Jane Started");
 
const num_relay = 4;
const i2c_temp  = 0x90;  //I2C address of TMP112
 
//Convenience Variables
local spi   = hardware.spi257;
local oe_l  = hardware.pin2;
local srclk = hardware.pin5;
local i2c   = hardware.i2c89;
 
//Setup I2C Bus
hardware.configure(I2C_89);
 
//Setup SPI Bus
hardware.configure(SPI_257);
spi.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_LOW, 4000);
 
//Configure OE_L for output and set high
oe_l.configure(DIGITAL_OUT);
oe_l.write(1);
 
// Output structure for sending temperature to server
local tempOut = OutputPort("Temperature (F)", "number");
local tempOutStr = OutputPort("Temperature (F)", "string");
 
function poll()
{
    //Poll the temperature every n seconds
    imp.wakeup(60,poll);
 
    local result = i2c.read(i2c_temp, "\x00", 2);
 
    if (result == null) {
        server.log("I2C Read Fail: Result == Null");
        return -1;
    }else if(result[0] == null){
        server.log("I2C Read Fail: Result[0] == Null");
        return -1;
    }else if(result[1] == null){
        server.log("I2C Read Fail: Result[1] == Null");
        return -1;
    }
 
    local t = ((result[0] << 4) + (result[1] >> 4)) * 0.0625;
 
 
    tempOut.set(t);
    tempOutStr.set(format("%.1f",t));
    server.show(format("Temp: %.1f",t));
 
}
 
class relay extends InputPort
{
    //Parameters to hold physical offset and current state
    offset = null;
    state  = null;
 
    constructor(r_num, r_state)
    {
        base.constructor("Relay "+(1+r_num), "number");
        offset = r_num;
        if( r_state != null)
        {
            state  = r_state
            this.update();
        }
    }
 
    function set(i)
    {
        if( typeof i == "float")
        {
            if( 0.0 <= i && i < 0.5)
            {
                i = 0;
            }else if( 0.5 <= i && i <= 1.0){
                i = 1;
            }else{
                server.log("Invalid Input: "+i);
                return;
            }
        }
 
        if( typeof i == "integer"){
            if( !(0 == i || 1 == i)){
                server.log("Invalid Input: "+i);
                return;
            }
        }
 
        if(state != i){
            state = i;
            this.update();
        }
    }
 
    function update()
    {
        local b = (0x01 << state) << (2*offset);
 
        //Send the byte via SPI
        spi.write(format("%c",b));
 
        //Send an extra clock pulse to move data in output register
        srclk.configure(DIGITAL_OUT);
        srclk.write(1);
        srclk.write(0);
        spi.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_LOW, 4000);
 
        // Pulse OE_L
        oe_l.write(0);
        imp.sleep(0.01);
        oe_l.write(1);
 
        //Clear the shift register by flushing zeros
        hardware.spi.write(format("%c%c", 0, 0));
    } 
}
 
 
imp.configure("Jane", [relay(0,0), relay(1,0), relay(2,0), relay(3,0)], [tempOut, tempOutStr]);
poll();