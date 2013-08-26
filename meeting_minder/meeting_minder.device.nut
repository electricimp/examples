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



//------------------------------------------------------------------------------------------------
// Holtek HT16K33 LED Controller Driver
// for Adafruit 7-segment i2c backpack
class SevenSeg {
  
    static colon  =     0x02;  // :
    static blank  =     0x00;  // _
    static number = [   0x3F,  // 0
                        0x06,  // 1
                        0x5B,  // 2
                        0x4F,  // 3
                        0x66,  // 4
                        0x6D,  // 5
                        0x7D,  // 6
                        0x07,  // 7
                        0x7F,  // 8
                        0x6F,  // 9
                        0x00]; // 10 = null
 
    // Commands
    static OSC_OFF  = "\x20";
    static OSC_ON   = "\x21";
  
    static DISP_OFF        = "\x80";
    static DISP_ON         = "\x81";
    static DISP_BLINK_2HZ  = "\x83";
    static DISP_BLINK_1HZ  = "\x85";
    static DISP_BLINK_05HZ = "\x87";
  
    //Preconfigured I2C device
    i2c = null;  
 
    // 8-bit base address
    baseAddr = null;
    
    // Name
    name = null;
    
    // The current display
    when = null;
    show_colon = true;
    
 
    constructor(_i2c, _baseAddr, _name) {
        this.i2c = _i2c;
        this.baseAddr = _baseAddr;
        this.name = _name;
    
        write(OSC_ON);
        write(DISP_ON);
        
        setBrightness(0.6);
        update();
    }
  
    function write(str){
        local result = i2c.write(baseAddr, str.tostring());
        //server.log("Result ("+baseAddr+"): "+result);
    }
  
    //Float from 0 to 1.0 where 1.0 is max brightness
    function setBrightness(b){
        if(b < 0){ b = 0.0;}
        if(b > 1){ b = 1.0;}
        write( (0xE0 | (b*15.0).tointeger()).tochar() );
    }
 
    function formatTimeDiff(_time, roundup = true) {
        local time = {};
        time.diff <- math.abs(::time() - _time);
        time.hour <- time.diff / 3600;
        time.min <- ((time.diff + (roundup ? 59 : 0)) / 60) % 60; // Round up
        
        // server.log(format("%s: The difference between now (%d) and then (%d) is %d sec (%d:%02d).", name, ::time(), _time, time.diff, time.hour, time.min))
        return time;
    }
    
    function displayClear (){
        //Write enough bits to clear all of memory
        local c = (show_colon ? colon : blank).tochar();
        write("\x00\x00\x00\x00\x00" + c + "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00");
        
        show_colon = !show_colon;
    }
  
    function displayTime(hours, mins){
        local time = blob(11);
        time.writen(0x00, 'b');
        time.writen(number[(hours/10) == 0 ? 10 : (hours/10)], 'b');
        time.writen(0x00, 'b');
        time.writen(number[(hours%10)], 'b');
        time.writen(0x00, 'b');
        time.writen(show_colon ? colon : blank, 'b');
        time.writen(0x00, 'b');
        time.writen(number[(mins/10).tointeger()], 'b');
        time.writen(0x00, 'b');
        time.writen(number[(mins%10)], 'b');
        time.writen(0x00, 'b');
        write(time);
        
        show_colon = !show_colon;
    }
    
    function update() {
        imp.wakeup(1, update.bindenv(this))
        if (when == null || time() > when) {
            displayClear();
        } else {
            local time = formatTimeDiff(when);
            displayTime(time.hour, time.min);
        }
    }
}
 


//------------------------------------------------------------------------------------------------
imp.configure("Meeting Minder", [], []);
server.log("Device booted.");

hardware.i2c12.configure(CLOCK_SPEED_100_KHZ);
imp.enableblinkup(true);
 
grn <- SevenSeg(hardware.i2c12, 0xE0, "Green");
red <- SevenSeg(hardware.i2c12, 0xE2, "Red");

//------------------------------------------------------------------------------------------------
agent.on("display", function (clocks) {
    grn.when = ("now" in clocks) ? clocks.now : null;
    red.when = ("next" in clocks) ? clocks.next : null; 
})


