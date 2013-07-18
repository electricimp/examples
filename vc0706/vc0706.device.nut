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

/* Imp firmware for RadioShack Camera Shield
 Shield is Based on VC0706 Camera Module
 http://blog.radioshack.com/2013/01/radioshack-camera-shield-for-arduino-boards/

 NOTE: Adafruit's VC0706 camera shield is strapped to boot at 38400 baud,
       while Radioshack's shield defaults to 115200 baud. 

       Both modules are strapped to boot in SPI Master mode, and require
       pin 80 on the VC0706 to be pulled to 3.3V in order to enable
       SPI slave mode, which this class requires in order to read frame
       buffers via SPI.
 
 T. Buttner
 5/10/13
*/

// size of data chunks to send agent. Large multiple of 8.
const CHUNK_SIZE = 8192;

// register with imp service
imp.configure("Radioshack Camera",[],[]);

class camera {
    // Radioshack shield is strapped for 115200 default baud
    // Adafruit shield is strapped for 38400 default baud
    static SPI_CLKSPEED                        =  4000

    /* Because the imp can send multi-byte messages over UART,
     * and building blobs out of individual bytes during runtime
     * is unnecessary, this class stores most frequently-used
     * commands as static strings.
     *
     * commands from the original Arduino VC0706 library are 
     * provided for reference below.
     *

        static VC0706_PROTOCOL_SIGN                 =  0x56
        static VC0706_SERIAL_NUMBER                 =  0x00

        static VC0706_COMMAND_RESET                 =  0x26
        static VC0706_COMMAND_GEN_VERSION           =  0x11
        static VC0706_COMMAND_TV_OUT_CTRL           =  0x44
        static VC0706_COMMAND_OSD_ADD_CHAR          =  0x45
        static VC0706_COMMAND_DOWNSIZE_SIZE         =  0x53
        static VC0706_COMMAND_READ_FBUF             =  0x32
        static FBUF_CURRENT_FRAME                   =  0
        static FBUF_NEXT_FRAME                      =  0

        // 0x0A for UART Transfer ("MCU Mode")
        // 0x0F for SPI Transfer
        static FBUF_TRANSFER_MODE_UART              =  0x0A
        static FBUF_TRANSFER_MODE_SPI               =  0x0F

        static VC0706_COMMAND_FBUF_CTRL             =  0x36
        static VC0706_COMMAND_COMM_MOTION_CTRL      =  0x37
        static VC0706_COMMAND_COMM_MOTION_DETECTED  =  0x39
        static VC0706_COMMAND_POWER_SAVE_CTRL       =  0x3E
        static VC0706_COMMAND_COLOR_CTRL            =  0x3C
        static VC0706_COMMAND_MOTION_CTRL           =  0x42

        static VC0706_COMMAND_WRITE_DATA            =  0x31
        static VC0706_COMMAND_GET_FBUF_LEN          =  0x34
    */

    // Command strings sent over UART
    // Commands all start with the "Protocol sign" and "serial number"
    static CMD_RESET                            = "\x56\x00\x26\x00"
    static CMD_GETVERSION                       = "\x56\x00\x11\x00"
    static CMD_TVOUT                            = "\x56\x00\x44\x01"
    static CMD_DOWNSIZE                         = "\x56\x00\x53\x01"
    static CMD_SET_OSD_STR                      = "\x56\x00\x45"
    static CMD_READ_FBUF_SPI                    = "\x56\x00\x32\x0C\x00\x0F\x00\x00\x00\x00\x00\x00"
    static CMD_READ_FBUF_UART                   = "\x56\x00\x32\x0C\x00\x0A\x00\x00\x00\x00\x00\x00"
    static CMD_CTRL_FBUF                        = "\x56\x00\x36\x01"
    static CMD_SET_MOTION_DET                   = "\x56\x00\x37"
    static CMD_MOTION_DET_EN                    = "\x56\x00\x37\x03\x00\x01"
    static CMD_GET_FBUF_LEN                     = "\x56\x00\x34\x01"
    static CMD_SET_POWERSAVE                    = "\x56\x00\x3E\x03\x00\x01"
    static CMD_SET_COLOR                        = "\x56\x00\x3C\x02\x01"
    static CMD_SET_COMP_RATIO                   = "\x56\x00\x05\x01\x01\x12\x04"
    static CMD_160x120                          = "\x56\x00\x31\x05\x04\x01\x00\x19\x22"
    static CMD_640x480                          = "\x56\x00\x31\x05\x04\x01\x00\x19\x00"
    static CMD_SET_MOTION_WINDOWS               = "\x56\x00\x31\x08\x01\x04"

    static READ_BLOCKSIZE                       =  56
    
    // set by constructor
    UART_BAUD = null;
    uart = null;
    spi = null;
    cs_l = null;
    
    /**************************************************************************
     *
     * Constructor takes in a UART interface, initializes it, and resets the camera
     *
     *************************************************************************/
    constructor(uart,baud,spi,cs_l) {
        this.uart = uart;
        this.UART_BAUD = baud;
        // Configure the imp's UART interface for 8 data bits, no parity bits, 1 stop bit,
        // no flow control
        this.uart.configure(UART_BAUD, 8, PARITY_NONE, 1, NO_CTSRTS);

        this.spi = spi;
        // Configure the imp's SPI interface
        this.spi.configure(CLOCK_IDLE_HIGH, SPI_CLKSPEED);
        
        this.cs_l = cs_l;
        // the imp's SPI interface does not implicitly include a CS pin
        // configure a GPIO to use as the chip select (active low)
        this.cs_l.configure(DIGITAL_OUT);
        this.cs_l.write(1);
        
        reset();
    }

    /**************************************************************************
     *
     * Re-initialize Camera
     *
     *************************************************************************/
    function reset() {
        uart.write(CMD_RESET);
        uart.flush();
        imp.sleep(0.005);
        server.log("Camera Ready.");
    }

    /**************************************************************************
     *
     * Get firmware version from Camera
     *
     *************************************************************************/
    function get_version() {
        uart.write(CMD_GETVERSION);
        uart.flush();
    }

    /**************************************************************************
     *
     * Stop or Start Camera's TV Output (not pinned out in HW)
     *
     * Input:   val (boolean)
     *              0 to stop TV Output
     *              1 to start TV Output
     *
     *************************************************************************/
    function set_tv_out(val) {
        if (val) {
            uart.write(CMD_TVOUT+"\x01");
        } else {
            uart.write(CMD_TVOUT+"\x00");
        }
        uart.flush();
    }

    /**************************************************************************
     *
     * Adds OSD Characters to Channels (Channel 1)
     * 
     * Input:   column (integer)
     *          row (integer)
     *          osd_str (string)
     *              string to display, max 14 characters
     *
     *************************************************************************/
    function set_osd_str(col, row, osd_str) {
        local osd_str_len = osd_str.len();
        if (osd_str_len > 14) {
            osd_str_len = 14;
        }

        col = col & 0x0f;
        row = row & 0x0f;
        local col_row = ((col << 4) | row);

        uart.write(CMD_SET_OSD_STR+format("%c%c%c",(osd_str_len+2),osd_str_len,col_row)+osd_str);
        uart.flush();
    }
    /**************************************************************************
     *
     * Control Width and Height Downsize Parameters
     *
     * Input: scale_width (integer, 0 to 2)
     *             0 -> 1:1
     *             1 -> 1:2
     *             2 -> 1:4
     *        scale_height (integer, 0 to 2)
     *             0 -> 1:1
     *             1 -> 1:2
     *             2 -> 1:4 
     *
     *************************************************************************/
    function set_w_h_downsize(scale_width, scale_height) {
        if (scale_width > 2) {
            scale_width = 2;
        }
        if (scale_height > scale_width) {
            scale_height = scale_width;
        }

        local scale = ((scale_height << 2) | scale_width);

        uart.write(CMD_DOWNSIZE+format("%c",scale));
        uart.flush();
    }

    /**************************************************************************
     *
     * Write frame buffer control register
     *
     * Input: val (1 byte)
     *              0 -> stop current frame
     *              1 -> stop next frame
     *              2 -> step frame
     *              3 -> resume frame
     *
     *************************************************************************/
    function ctrl_frame_buffer(val) {
        uart.write(CMD_CTRL_FBUF+format("%c",val));
        // force the commands to go out on the wire
        uart.flush();
        // wait for the command to be processed
        imp.sleep(0.005);      
    }

    /**************************************************************************
     *
     * Enable/disable motion monitoring over UART interface
     *
     * Input: val (1 byte)
     *              0 -> stop motion monitoring over UART
     *              1 -> start motion monitoring over UART
     *
     *************************************************************************/
    function set_motion_detect(val) {
        if (val) {
            uart.write(CMD_SET_MOTION_DET+"\x01");
        } else {
            uart.write(CMD_SET_MOTION_DET+"\x00");
        }
        uart.flush();
    }

    /**************************************************************************
     *
     * Enable/disable motion monitoring
     *
     * Input: val (1 byte)
     *              0 -> disable motion monitoring
     *              1 -> enbale motion monitoring
     *
     *************************************************************************/
    function set_motion_detect_en(val) {

        if (val) {
            uart.write(CMD_MOTION_DET_EN+"\x01");
        } else {
            uart.write(CMD_MOTION_DET_EN+"\x00");
        }
        uart.flush();
    }

    /**************************************************************************
     *
     * Get byte lengths in frame buffer
     *
     * Input: type (1 byte)
     *              0 -> current frame buffer
     *              1 -> next frame buffer
     * 
     * Return: length of data in buffer (bytes)
     *
     *************************************************************************/
    function get_frame_buffer_len(type) {
        if (type) {
            uart.write(CMD_GET_FBUF_LEN+"\x01");
        } else {
            uart.write(CMD_GET_FBUF_LEN+"\x00");
        }
        uart.flush();

        imp.sleep(0.01);

        local sizeBuf = read_buffer_uart(9);
        local jpegSize = sizeBuf[7] * 256 + sizeBuf[8];

        return jpegSize;
    }

    /**************************************************************************
     *
     * Enable/disable uart power save
     * Used to stop current frame for read
     *
     * Input: val (boolean)
     *              0 -> disable powersave (resume)
     *              1 -> enable powersave (pause)
     *
     *************************************************************************/
    function set_powersave(val) {
        if (val) {
            uart.write(CMD_SET_POWERSAVE+"\x01");
        } else {
            uart.write(CMD_SET_POWERSAVE+"\x00");
        }
        uart.flush();
    }

    /**************************************************************************
     *
     * Select between black/white and color capture
     *
     * Input: mode (integer 0-2)
     *              0 -> auto mode 
     *              1 -> color mode
     *              2 -> black and white mode
     *
     *************************************************************************/
    function set_color_mode(mode) {
        if (show_mode > 2) {
            show_mode = 2;
        }
        uart.write(CMD_SET_COLOR+format("%c",show_mode));
        uart.flush();
    }

    /**************************************************************************
     *
     * set JPEG compression ratio
     *
     * Input: ratio (integer, 13 - 63)
     *
     *************************************************************************/
    function set_compression_ratio(ratio) {
        if (ratio > 63) {
            ratio = 63;
        }
        if (ratio < 13) {
            ratio = 13;
        }
        local vc_comp_ratio = ((ratio - 13) * 4) + 53; // math lol

        uart.write(CMD_SET_COMP_RATIO+format("%c",vc_comp_ratio));
        uart.flush();
        server.log("Camera Compression Ratio set to "+ratio);
    }

    function set_size_160x120() {
        uart.write(CMD_160x120);
        uart.flush();
        imp.sleep(0.01);
        server.log("Image Size set to 160x120");
    }

    function set_size_640x480() {
        uart.write(CMD_640x480);
        uart.flush();
        imp.sleep(0.01);
        server.log("Image Size set to 640x480");
    }
     
    /**************************************************************************
     *
     * Configure something interesting involving motion capture. 
     * Appears to actually just be a generic command to write to SOC register
     * Use with some caution
     *
     * Input: addr (2 bytes)
     *        data (4 bytes)
     *
     *************************************************************************/
    function set_motion_windows(addr, data) {
        uart.write(CMD_SET_MOTION_WINDOWS+format("%c%c%c%c%c%c",
            (addr >> 8), (addr & 0xFF), (data >> 24), (data >> 16),
            (data >> 8), (data & 0xFF)));
        uart.flush();
    }

    /**************************************************************************
     *
     * Read image data from frame buffer
     *
     * Input: size (integer)
     *          bytes to read via UART
     *
     *
     *************************************************************************/
    function read_frame_buffer_uart(size) {
        local num_chunks = math.ceil(size.tofloat()/CHUNK_SIZE).tointeger();
        agent.send("jpeg_start",size);

        uart.write(CMD_READ_FBUF_UART+format("%c%c%c%c",
            (size/256),(size%256),0x00,0x00));

        uart.flush();
        imp.sleep(0.01);

        for(local i = 0; i < num_chunks; i++) {
            local startingAddress = i*CHUNK_SIZE;
            local buf = read_buffer_uart(CHUNK_SIZE);
            agent.send("jpeg_chunk", [startingAddress, buf]);
        }
        
        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     * 
     * Read JPEG data from camera via SPI
     * 
     * Input: size (integer)
     *           bytes to read via SPI
     *
     **************************************************************************/
    function read_frame_buffer_spi(size) {
        local num_chunks = math.ceil(size.tofloat()/CHUNK_SIZE).tointeger();
        agent.send("jpeg_start",size);

        // request entire buffer from camera via SPI
        uart.write(CMD_READ_FBUF_SPI+format("%c%c%c%c",
            (size/256),(size%256),0x00,0x00));

        // Force the UART to flush
        uart.flush();
        // Give the camera's DSP chip 10 ms to figure out what to do with our command
        imp.sleep(0.01);

        // assert chip select for the spi interface
        cs_l.write(0);

        // camera sends 0x30 for no apparent reason, so get rid of it
        spi.writeread("\xff");

        for(local i = 0; i < num_chunks; i++) {
            local startingAddress = i*CHUNK_SIZE;
            local buf = spi.readblob(CHUNK_SIZE);
            agent.send("jpeg_chunk", [startingAddress, buf]);
        }

        cs_l.write(1);
        
        agent.send("jpeg_end", 1);
    }

    function pause_capture() {
        ctrl_frame_buffer(0);
        server.log("Camera Paused");
    }

    function resume_capture() {
        ctrl_frame_buffer(3);
        server.log("Camera Capture Resumed");
    }

    function capture_photo() {
        pause_capture();
        imp.sleep(0.01);

        clear_uart();

        local jpegSize = get_frame_buffer_len(0);

        server.log(format("Captured JPEG (%d bytes)",jpegSize));

        read_frame_buffer_spi(jpegSize);

        server.log("Device: done sending image");

        resume_capture();
    }

    /**************************************************************************
     *
     * Read a buffer from the camera module via UART
     *
     * Input:
     *
     *************************************************************************/
    function read_buffer_uart(nBytes) {
        local rx_buffer = blob(nBytes);

        local data = uart.read()
        //server.log(format("Got: 0x%02x",data));
        while ((data >= 0) && (rx_buffer.tell() < nBytes)) {
            rx_buffer.writen(data,'b');
            data = uart.read();
            //server.log(format("Got: 0x%02x",data));
        }
        /*
        if (rx_buffer[0] != 0x76) {
            server.error(format("Device got invalid return message: 0x%02x",rx_buffer[0]));
        }
        if (rx_buffer[1] != 0x00) {
            server.error(format("Message returned with invalid serial number: 0x%02x",rx_buffer[1]));
        }
        */
        return rx_buffer;
    }

    function clear_uart() {
        local data = uart.read();

        while(data >= 0) {
            //server.log(format("Got: 0x%02x",data));
            data = uart.read();
        }
        server.log("UART RX Buffer Cleared.");
    }

}

myCamera <- camera(hardware.uart1289,115200,hardware.spi257,hardware.pin1);

myCamera.set_size_160x120();

agent.on("take_picture", function(val) {
    myCamera.capture_photo();
});
