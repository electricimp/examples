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

// Thermal Printer Impee
// Uses CSN-A2-T thermal receipt printer from Adafruit
// Imp sends serial commands to the printer on UART57

// Lots of ASCII to be used, so we'll define the relevant non-printables here 
const LF    = 0x0A;
const HT    = 0x09; // Horizontal TAB
const ESC   = 0x1B;
const GS    = 0x1D; // group seperator
const SP    = 0x20; // space
const FF    = 0x0C; // NP form feed; new page
// chunk size for downloading image data buffers from the agent
// equal to one paper width
const CHUNK_SIZE = 384;

// register with the imp service
imp.configure("Thermal Printer", [], []);

// printer needs a moment of warmup time on power-on
imp.sleep(0.5);

class printer {
    /* Print Commands
    LF          -> Print and line feed
    HT (TAB)    -> Jump to next TAB position
    ESC FF      -> Print the data in the buffer
    ESC J       -> Print and feed n dots paper
    ESC d       -> Print and feed n lines
    */
    // some basic printer parameters
    static printDensity        = 14         // yields 120% density, experimentally determined to be good
    static printBreakTime      = 4          // 500 us; slower but darker
    static dotPrintTime        = 30000      // time to print a single-dot line in us
    static dotFeedTime         = 2100       // time to feed a single-dot line in us

    static uartChunkSize       = 60         // max # of bytes to send in one go via UART (images)

    // current mode of the printer, in case we need to check and see
    lineSpacing         = 32
    bold                = false
    underline           = false
    justify             = "left"
    reverse             = false
    updown              = false
    emphasized          = false
    doubleHeight        = false
    doubleWidth         = false
    deleteLine          = false

    // the actual byte sent to the printer to select modes.
    // masked in methods below to set mode
    modeByte            = 0x00

    // pointers for image download from the agent
    imageDataLength     = null
    loadedDataLength    = null

    // image parameters need to be written out on each row as we stream in an image
    imageWidth          = null
    imageHeight         = null 

    // a UART object will be passed into the constructor
    uart = null
    
    constructor(myUart, myBaud) {
        // the imp can be reset without resetting the printer
        // clear the mode and the buffer every time we construct a new printer
        this.uart = myUart;
        this.uart.configure(myBaud, 8, PARITY_NONE, 1, NO_CTSRTS);
        this.reset();
    }
    
    // reset printer to default mode and print settings
    function reset() {
        // reset the class parameters
        this.modeByte = 0x00;
        this.reverse = false;
        this.updown = false;
        this.emphasized = false;
        this.doubleHeight = false;
        this.doubleWidth = false;
        this.deleteLine = false;
        this.justify = "left";
        this.bold = false;
        this.underline = false;
        this.lineSpacing = 32;
        
        // reset the image download pointer
        this.imageDataLength = 0;
        this.loadedDataLength = 0; 
        // and the image parameters
        this.imageWidth = 0;
        this.imageHeight = 0;
        
        // send the printer reset command
        uart.write(ESC);
        uart.write('@');

        // set the basic printer settings
        uart.write(ESC);
        uart.write('7');
        // ESC 7 n1 n2 n3 
        // n1 = 0-255: max printing dots, unit = 8 dots, default = 7 (64 dots)
        // n2 = 3-255: heating time, unit = 10 us, default = 80 (800 us)
        // n3 = 0-255: heating interval, unit = 10 us, default = 2 (20 us)
        // first, set the "printing dots"
        // more max dots -> faster printing. Max heating dots is 8*(n1+1)
        // more heating -> slower printing
        // not enough heating -> blank page
        uart.write(20); // Adafruit's library uses this default setting as well
        // now set the heating time
        uart.write(255); // max heating time
        // last, the heat interval
        uart.write(250); // 500 us -> slower but darker

        // set the print density as well
        uart.write(18);
        uart.write(35); 
        // 18 35 N
        // N[4:0] sets printing density (50% + 5% * N[4:0])
        // N[7:5] sets printing break time (250us * N[5:7])
        uart.write((this.printBreakTime << 5) | this.printDensity);
        
        imp.sleep(1);
        server.log("Printer Ready.");
    }
    
    // Load a buffer and print it immediately
    function print(printStr) {
        // load the string into the buffer
        uart.write(printStr);
        uart.write("\n");
        // print the buffer
        uart.write(FF);
    }

    // Load a buffer and print it immediately
    function printnolf(printStr) {
        // load the string into the buffer
        uart.write(printStr);
        // print the buffer
        uart.write(FF);
    }

    // load buffer into the printer's buffer without printing
    function load(buffer) {
        uart.write(buffer);
    }
    
    // this function pulls data from the agent down to the imp, which can then push it to the printer
    // part of the printer class because it eventually calls the "print downloaded image command" itself
    function pull() {
        server.log("pull called " + this.loadedDataLength + "/" + this.imageDataLength);
        if(this.loadedDataLength < this.imageDataLength) {
            agent.send("pull", CHUNK_SIZE);
        } else {        
            // reset image download pointers
            this.imageDataLength = 0;
            this.loadedDataLength = 0;
            // tell the agent we're done and it should reset download pointers too
            agent.send("imageDone", 0);
            imp.sleep(0.5);
            this.feed(1);
            this.reset();
            server.log("Device: done loading image");
        }
    }
    
    // this function writes a row of bitmap image data to the printer
    function printImgBuffer(data) {

        server.log("printImgBuffer");
        // round width up to next byte boundary
        local rowBytes = (this.imageWidth + 7) / 8;
        server.log("rowbytes "+rowBytes);
        // enforce max width (384 pixels / 8 = 48 bytes)
        local rowBytesClipped = (rowBytes >= 48) ? 48 : rowBytes;

        // print up to 255 rows at a time
        //for (local rowStart = 0; rowStart < this.imageHeight; rowStart += 255) 
        {
            local chunkHeight = CHUNK_SIZE / rowBytes;//this.imageHeight - rowStart;
            //if (chunkHeight > 255) chunkHeight = 255;
            // put printer in print-bitmap mode with some nasty magic numbers
            uart.write(18);
            uart.write(42);
            uart.write(chunkHeight);
            uart.write(rowBytesClipped);

            for (local row = 0; row < chunkHeight; row++) 
            {
                uart.write(data.readblob(rowBytes));
                uart.flush();
                server.log("Printing row "+row);
            }
        }
        server.log("Done Printing block");
        //this.feed(2);
    }
    
    // print the buffer and feed n lines
    function feed(lines) {
        while(lines--) {
            this.print("\n");
        }
    }
    
    // set line spacing to 'n' dots (default is 32)
    function setLineSpacing(dots = 32) {
        hardware.uart57.write(ESC);
        if (dots == 32) {
            // just set default line spacing if called with no or an invalid argument
            uart.write('2');
            this.lineSpacing = 32;
        } else if (dots > 0 && dots < 256) {
            uart.write('3');
            uart.write(dots);
            this.lineSpacing = dots;
        } else {
            server.error("Setting line spacing to invalid value (0-255 dots per line)");
        }
    }
    
    // select justification
    function setJustify(justifyValue) {
        local justifyByte = 0;
        if (justifyValue == "left") {
            justifyByte = 0;
            this.justify = "left";
        } else if (justifyValue == "center") {
            justifyByte = 1;
            this.justify = "center";
        } else if (justifyValue == "right") {
            justifyByte = 2;
            this.justify = "right";
        } else {
            server.error("Invalid Justify (left, center, right)");
            return;
        }
        uart.write(ESC);
        uart.write('a');
        uart.write(justifyByte);
    }
    
    // write mode byte to device
    // functions below are used to mask modes on and off in the mode byte
    function writeMode() {
        uart.write(ESC);
        uart.write('!');
        uart.write(this.modeByte);
    }
    
    // toggle bold print
    // takes one boolean argument
    // defaults to true
    function setBold(value = true) {
        uart.write(ESC);
        uart.write(SP);
        if (value) {
            uart.write(1);
            this.bold = true;
        } else {
            uart.write(0);
            this.bold = false;
        }
    }
    
    // set underline weight
    function setUnderline(value = true) {
        // send the command to set underline weight
        uart.write(ESC);
        uart.write(0x2D);
        // we'll just support two weights: none and "2" (max)
        if (value) {
            uart.write(2);
            this.underline = true;
        } else {
            uart.write(0);
            this.underline = false;
        }
    }
    
    // toggle reverse mode
    function setReverse(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x02;
            this.reverse = true;
        } else {
            this.modeByte = this.modeByte & 0xFD;
            this.reverse = false;
        }
        this.writeMode();
    }
    
    // toggle updown mode
    function setUpdown(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x04;
            this.updown = true;
        } else {
            this.modeByte = this.modeByte & 0xFB;
            this.updown = false;
        }
        this.writeMode();
    }
    
    // toggle emphasized mode
    function setEmphasized(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x08;
            this.emphasized = true;
        } else {
            this.modeByte = this.modeByte & 0xF7;
            this.emphasized = false;
        }
        this.writeMode();
    }
    
    // toggle double height mode
    function setDoubleHeight(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x10;
            this.doubleHeight = true;
        } else {
            this.modeByte = this.modeByte & 0xEF;
            this.doubleHeight = false;
        }
        this.writeMode();
    }    
    
    // toggle double width mode
    function setDoubleWidth(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x20;
            this.doubleWidth = true;
        } else {
            this.modeByte = this.modeByte & 0xDF;
            this.doubleWidth = false;
        }
        this.writeMode();
    }
    
    // toggle deleteLine mode
    function setDeleteLine(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x40;
            this.deleteLine = true;
        } else {
            this.modeByte = this.modeByte & 0xBF;
            this.deleteLine = false;
        }
        this.writeMode();
    }

}

// Actual execution picks up here
// instatiate the printer object at global scope
myPrinter <- printer(hardware.uart57, 19200);

// Register some hooks for the agent to call, allowing the agent to push actions to the device
// the most obvious: print a buffer of data
agent.on("print", function(buffer) {
    server.log("Device: printing new buffer from agent: "+buffer);
    myPrinter.print(buffer);
});

agent.on("printnolf", function(buffer) {
    server.log("Device: printing new buffer from agent (no lf): "+buffer);
    myPrinter.printnolf(buffer);
});

// provides info on a bitmap to download and print
agent.on("downloadImage", function(imageParams) 
{
    server.log("downloadImage called "+imageParams[1]+","+imageParams[2]);
    myPrinter.imageWidth = imageParams[1];
    myPrinter.imageHeight = imageParams[2];
    myPrinter.imageDataLength = imageParams[0];
    myPrinter.pull();
});

// load chunks of an image as pulled from agent
agent.on("imgData", function(buffer) {
    myPrinter.printImgBuffer(buffer);
    myPrinter.loadedDataLength += buffer.len();
    server.log("Loaded "+myPrinter.loadedDataLength+" bytes");
    // wait a moment - can't use imp.wakeup here due to a bug that causes variables to be freed prematurely
    imp.sleep(0.01);
    myPrinter.pull();
});

// allow the agent to load a buffer without printing
agent.on("load", function(buffer) {
    myPrinter.load(buffer);
});

agent.on("feed", function(lines) {
    myPrinter.feed(lines);
});

agent.on("bold", function(value) {
    myPrinter.setBold(value);
});

agent.on("underline", function(value) {
    myPrinter.setUnderline(value);
});

// allow the agent to clear the printer's mode and reset default settings
agent.on("reset", function(value) {
    myPrinter.reset();
});

agent.on("lineSpacing", function(dots) {
    myPrinter.setLineSpacing(dots);
});

agent.on("justify", function(value) {
    myPrinter.setJustify(value);
});

agent.on("reverse", function(value) {
    myPrinter.setReverse(value);
});

agent.on("updown", function(value) {
    myPrinter.setUpdown(value);
});

agent.on("emphasized", function(value) {
    myPrinter.setEmphasized(value);
});

agent.on("doubleHeight", function(value) {
    myPrinter.setDoubleHeight(value);
});

agent.on("doubleWidth", function(value) {
    myPrinter.setDoubleWidth(value);
});

agent.on("deleteLine", function(value) {
    myPrinter.setDeleteLine(value);
});