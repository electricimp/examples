// MIT License
// Copyright 2017 Electric Imp
// SPDX-License-Identifier: MIT
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


// Imp firmware for Arducam Mini 2MP
// Shield is Based on OV2640 Camera Module
// http://www.arducam.com/tag/arducam-mini/

class Camera {
    // These sensor register sets are taken from the ArduCAM source, and reorganized a bit to expose commonalities
    static OV2640_JPEG_INIT =
        "\xff\x00\x2c\xff\x2e\xdf\xff\x01\x3c\x32\x11\x04\x09\x02\x04\x28\x13\xe5\x14\x48\x2c\x0c\x33\x78\x3a\x33\x3b\xfB\x3e\x00\x43\x11\x16\x10\x39\x92"+
        "\x35\xda\x22\x1a\x37\xc3\x23\x00\x34\xc0\x36\x1a\x06\x88\x07\xc0\x0d\x87\x0e\x41\x4c\x00\x48\x00\x5B\x00\x42\x03\x4a\x81\x21\x99\x24\x40\x25\x38"+
        "\x26\x82\x5c\x00\x63\x00\x61\x70\x62\x80\x7c\x05\x20\x80\x28\x30\x6c\x00\x6d\x80\x6e\x00\x70\x02\x71\x94\x73\xc1\x12\x40\x17\x11\x18\x43\x19\x00"+
        "\x1a\x4b\x32\x09\x37\xc0\x4f\x60\x50\xa8\x6d\x00\x3d\x38\x46\x3f\x4f\x60\x0c\x3c\xff\x00\xe5\x7f\xf9\xc0\x41\x24\xe0\x14\x76\xff\x33\xa0\x42\x20"+
        "\x43\x18\x4c\x00\x87\xd5\x88\x3f\xd7\x03\xd9\x10\xd3\x82\xc8\x08\xc9\x80\x7c\x00\x7d\x00\x7c\x03\x7d\x48\x7d\x48\x7c\x08\x7d\x20\x7d\x10\x7d\x0e"+
        "\x90\x00\x91\x0e\x91\x1a\x91\x31\x91\x5a\x91\x69\x91\x75\x91\x7e\x91\x88\x91\x8f\x91\x96\x91\xa3\x91\xaf\x91\xc4\x91\xd7\x91\xe8\x91\x20\x92\x00"+
        "\x93\x06\x93\xe3\x93\x05\x93\x05\x93\x00\x93\x04\x93\x00\x93\x00\x93\x00\x93\x00\x93\x00\x93\x00\x93\x00\x96\x00\x97\x08\x97\x19\x97\x02\x97\x0c"+
        "\x97\x24\x97\x30\x97\x28\x97\x26\x97\x02\x97\x98\x97\x80\x97\x00\x97\x00\xc3\xed\xa4\x00\xa8\x00\xc5\x11\xc6\x51\xbf\x80\xc7\x10\xb6\x66\xb8\xa5"+
        "\xb7\x64\xb9\x7c\xb3\xaf\xb4\x97\xb5\xff\xb0\xc5\xb1\x94\xb2\x0f\xc4\x5c\xc0\x64\xc1\x4b\x8c\x00\x86\x3d\x50\x00\x51\xc8\x52\x96\x53\x00\x54\x00"+
        "\x55\x00\x5a\xc8\x5b\x96\x5c\x00\xd3\x00\xc3\xed\x7f\x00\xda\x00\xe5\x1f\xe1\x67\xe0\x00\xdd\x7f\x05\x00\x12\x40\xd3\x04\xc0\x16\xc1\x12\x8c\x00"+
        "\x86\x3d\x50\x00\x51\x2c\x52\x24\x53\x00\x54\x00\x55\x00\x5a\x2c\x5b\x24\x5c\x00";             
    
    static OV2640_YUV422 =
        "\xff\x00\x05\x00\xda\x10\xd7\x03\xdf\x00\x33\x80\x3c\x40\xe1\x77\x00\x00";
    
    static OV2640_JPEG = 
        "\xe0\x14\xe1\x77\xe5\x1f\xd7\x03\xda\x10\xe0\x00\xFF\x01\x04\x08"; 
    
    static OV2640_160x120_JPEG = 
        "\xff\x01\x12\x40\x17\x11\x18\x43\x19\x00\x1a\x4b\x32\x09\x4f\xca\x50\xa8\x5a\x23\x6d\x00\x39\x12\x35\xda\x22\x1a\x37\xc3\x23\x00\x34\xc0\x36\x1a"+
        "\x06\x88\x07\xc0\x0d\x87\x0e\x41\x4c\x00\xff\x00\xe0\x04\xc0\x64\xc1\x4b\x86\x35"+
        "\x50\x92"+
        "\x51\xc8\x52\x96\x53\x00\x54\x00\x55\x00\x57\x00"+
        "\x5a\x28\x5b\x1e\x5c\x00\xe0\x00";
    
    static OV2640_176x144_JPEG =  
        "\xff\x01\x12\x40\x17\x11\x18\x43\x19\x00\x1a\x4b\x32\x09\x4f\xca\x50\xa8\x5a\x23\x6d\x00\x39\x12\x35\xda\x22\x1a\x37\xc3\x23\x00\x34\xc0\x36\x1a"+
        "\x06\x88\x07\xc0\x0d\x87\x0e\x41\x4c\x00\xff\x00\xe0\x04\xc0\x64\xc1\x4b"+
        "\x86\x35\x50\x92"+
        "\x51\xc8\x52\x96\x53\x00\x54\x00\x55\x00\x57\x00"+
        "\x5a\x2c\x5b\x24\x5c\x00"+
        "\xe0\x00";
    
    static OV2640_320x240_JPEG =  
        "\xff\x01\x12\x40\x17\x11\x18\x43\x19\x00\x1a\x4b\x32\x09\x4f\xca\x50\xa8\x5a\x23\x6d\x00\x39\x12\x35\xda\x22\x1a\x37\xc3\x23\x00\x34\xc0\x36\x1a"+
        "\x06\x88\x07\xc0\x0d\x87\x0e\x41\x4c\x00\xff\x00\xe0\x04\xc0\x64\xc1\x4b"+
        "\x86\x35\x50\x89"+
        "\x51\xc8\x52\x96\x53\x00\x54\x00\x55\x00\x57\x00"+
        "\x5a\x50\x5b\x3c\x5c\x00"+
        "\xe0\x00";
    
    static OV2640_352x288_JPEG =  
        "\xff\x01\x12\x40\x17\x11\x18\x43\x19\x00\x1a\x4b\x32\x09\x4f\xca\x50\xa8\x5a\x23\x6d\x00\x39\x12\x35\xda\x22\x1a\x37\xc3\x23\x00\x34\xc0\x36\x1a"+
        "\x06\x88\x07\xc0\x0d\x87\x0e\x41\x4c\x00\xff\x00\xe0\x04\xc0\x64\xc1\x4b"+
        "\x86\x35\x50\x89"+
        "\x51\xc8\x52\x96\x53\x00\x54\x00\x55\x00\x57\x00"+
        "\x5a\x58\x5b\x48\x5c\x00"+
        "\xe0\x00";
    
    static OV2640_640x480_JPEG =  
        "\xff\x01\x11\x01\x12\x00\x17\x11\x18\x75\x32\x36\x19\x01\x1a\x97\x03\x0f\x37\x40\x4f\xbb\x50\x9c\x5a\x57\x6d\x80\x3d\x34\x39\x02\x35\x88\x22\x0a"+
        "\x37\x40\x34\xa0\x06\x02\x0d\xb7\x0e\x01\xff\x00\xe0\x04\xc0\xc8\xc1\x96\x51\x90\x52\x2c\x53\x00\x54\x00\x55\x88\x57\x00"+
        "\x86\x3d\x50\x89"+
        "\x5a\xa0\x5b\x78\x5c\x00"+ // OUTW=640, OUTH=480
        "\xd3\x04\xe0\x00";     

    static OV2640_800x600_JPEG =  
        "\xff\x01\x11\x01\x12\x00\x17\x11\x18\x75\x32\x36\x19\x01\x1a\x97\x03\x0f\x37\x40\x4f\xbb\x50\x9c\x5a\x57\x6d\x80\x3d\x34\x39\x02\x35\x88\x22\x0a"+
        "\x37\x40\x34\xa0\x06\x02\x0d\xb7\x0e\x01\xff\x00\xe0\x04\xc0\xc8\xc1\x96\x51\x90\x52\x2c\x53\x00\x54\x00\x55\x88\x57\x00"+
        "\x86\x35\x50\x89"+
        "\x5a\xc8\x5b\x96\x5c\x00"+ // OUTW=800, OUTH=600
        "\xd3\x02\xe0\x00";     
           
    static OV2640_1024x768_JPEG =  
        "\xff\x01\x11\x01\x12\x00\x17\x11\x18\x75\x32\x36\x19\x01\x1a\x97\x03\x0f\x37\x40\x4f\xbb\x50\x9c\x5a\x57\x6d\x80\x3d\x34\x39\x02\x35\x88\x22\x0a"+
        "\x37\x40\x34\xa0\x06\x02\x0d\xb7\x0e\x01\xff\x00\xe0\x04\xc0\xc8\xc1\x96\x51\x90\x52\x2c\x53\x00\x54\x00\x55\x88\x57\x00"+
        "\x86\x3d\x50\x00"+
        "\x5a\x00\x5b\xc0\x5c\x01"+ // OUTW=1024, OUTH=768
        "\xd3\x02\xe0\x00";
    
    static OV2640_1280x960_JPEG =  
        "\xff\x01\x11\x01\x12\x00\x17\x11\x18\x75\x32\x36\x19\x01\x1a\x97\x03\x0f\x37\x40\x4f\xbb\x50\x9c\x5a\x57\x6d\x80\x3d\x34\x39\x02\x35\x88\x22\x0a"+
        "\x37\x40\x34\xa0\x06\x02\x0d\xb7\x0e\x01\xff\x00\xe0\x04\xc0\xc8\xc1\x96\x51\x90\x52\x2c\x53\x00\x54\x00\x55\x88\x57\x00"+
        "\x86\x3d\x50\x00"+
        "\x5a\x40\x5b\xf0\x5c\x01"+ // OUTW=1280, OUTH=960
        "\xd3\x02\xe0\x00";         

    static OV2640_1600x1200_JPEG =  
        "\xff\x01\x11\x01\x12\x00\x17\x11\x18\x75\x32\x36\x19\x01\x1a\x97\x03\x0f\x37\x40\x4f\xbb\x50\x9c\x5a\x57\x6d\x80\x3d\x34\x39\x02\x35\x88\x22\x0a"+
        "\x37\x40\x34\xa0\x06\x02\x0d\xb7\x0e\x01\xff\x00\xe0\x04\xc0\xc8\xc1\x96\x51\x90\x52\x2c\x53\x00\x54\x00\x55\x88\x57\x00"+
        "\x86\x3d\x50\x00"+
        "\x5a\x90\x5b\x2c\x5c\x05"+ // OUTW=1600, OUTH=1200
        "\xd3\x02\xe0\x00";
        
    static OV2640_QVGA = 
        "\xff\x00\x2c\xff\x2e\xdf\xff\x01\x3c\x32\x11\x00\x09\x02\x04\xa8\x13\xe5\x14\x48\x2c\x0c\x33\x78\x3a\x33\x3b\xfb\x3e\x00\x43\x11\x16\x10\x39\x02\x35\x88\x22\x0a\x37\x40\x23\x00\x34\xa0\x06\x02\x06\x88\x07\xc0\x0d\xb7\x0e\x01\x4c\x00\x4a\x81\x21\x99\x24\x40\x25\x38\x26\x82\x5c\x00\x63\x00\x46\x22\x0c\x3a\x5d\x55\x5e\x7d\x5f\x7d\x60\x55\x61\x70\x62\x80\x7c\x05\x20\x80\x28\x30\x6c\x00\x6d\x80\x6e\x00\x70\x02\x71\x94\x73\xc1\x3d\x34\x12\x04\x5a\x57\x4f\xbb\x50\x9c\xff\x00\xe5\x7f\xf9\xc0\x41\x24\xe0\x14\x76\xff\x33\xa0\x42\x20\x43\x18\x4c\x00\x87\xd0\x88\x3f\xd7\x03\xd9\x10\xd3\x82\xc8\x08\xc9\x80\x7c\x00\x7d\x00\x7c\x03\x7d\x48\x7d\x48\x7c\x08\x7d\x20\x7d\x10\x7d\x0e\x90\x00\x91\x0e\x91\x1a\x91\x31\x91\x5a\x91\x69\x91\x75\x91\x7e\x91\x88\x91\x8f\x91\x96\x91\xa3\x91\xaf\x91\xc4\x91\xd7\x91\xe8\x91\x20\x92\x00\x93\x06\x93\xe3\x93\x03\x93\x03\x93\x00\x93\x02\x93\x00\x93\x00\x93\x00\x93\x00\x93\x00\x93\x00\x93\x00\x96\x00\x97\x08\x97\x19\x97\x02\x97\x0c\x97\x24\x97\x30\x97\x28\x97\x26\x97\x02\x97\x98\x97\x80\x97\x00\x97\x00\xa4\x00\xa8\x00\xc5\x11\xc6\x51\xbf\x80\xc7\x10\xb6\x66\xb8\xa5\xb7\x64\xb9\x7c\xb3\xaf\xb4\x97\xb5\xff\xb0\xc5\xb1\x94\xb2\x0f\xc4\x5c\xa6\x00\xa7\x20\xa7\xd8\xa7\x1b\xa7\x31\xa7\x00\xa7\x18\xa7\x20\xa7\xd8\xa7\x19\xa7\x31\xa7\x00\xa7\x18\xa7\x20\xa7\xd8\xa7\x19\xa7\x31\xa7\x00\xa7\x18\x7f\x00\xe5\x1f\xe1\x77\xdd\x7f\xc2\x0e\xff\x00\xe0\x04\xc0\xc8\xc1\x96\x86\x3d\x51\x90\x52\x2c\x53\x00\x54\x00\x55\x88\x57\x00\x50\x92\x5a\x50\x5b\x3c\x5c\x00\xd3\x04\xe0\x00\xff\x00\x05\x00\xda\x08\xd7\x03\xe0\x00\x05\x00\xff\xff"

    static RGB565 = 
        "\xFF\x00\x05\x00\xDA\x08\x98\x00\x99\x00\x00\x00"   
   

    static ARDUCHIP_FIFO        = 0x04  //FIFO and I2C control
    static FIFO_CLEAR_MASK      = 0x01
    static FIFO_START_MASK      = 0x02
    static FIFO_RDPTR_RST_MASK  = 0x10
    static FIFO_WRPTR_RST_MASK  = 0x20
    
    static ARDUCHIP_GPIO        = 0x06  //GPIO Write Register
    
    static BURST_FIFO_READ      = 0x3c  //Burst FIFO read operation
    static SINGLE_FIFO_READ     = 0x3d  //Single FIFO read operation
    
    static ARDUCHIP_REV         = 0x40  //ArduCHIP revision
    static VER_LOW_MASK         = 0x3f
    static VER_HIGH_MASK        = 0xc0
    
    static ARDUCHIP_TRIG        = 0x41  //Trigger source
    static VSYNC_MASK           = 0x01
    static SHUTTER_MASK         = 0x02
    static CAP_DONE_MASK        = 0x08
    
    static FIFO_SIZE1           = 0x42  //Camera write FIFO size[7:0] for burst to read
    static FIFO_SIZE2           = 0x43  //Camera write FIFO size[15:8]
    static FIFO_SIZE3           = 0x44  //Camera write FIFO size[18:16]
    
    static ARDUCHIP_TEST1       = 0x00  //Test Register
    
    static AEC                  = 0x10;
    static REG04                = 0x04;
    static REG45                = 0x45;
    
    static RA_DLMT              = 0xff; // For selecting register bank
    static DSP_ADDRESS          = 0x00
    static SENSOR_ADDRESS       = 0x01;
    
    static CTRL0                = 0xC2; // Control Register 0

    static PHOTO_TIMEOUT        = 1000; // 1000 milliseconds timeout
    
    // set by constructor
    _i2c = null;
    _spi = null;
    _cs_l = null;

    
    /**************************************************************************
     *
     * Constructor takes in a pre-configured I2C interface and SPI interface, and resets the camera
     *
     *************************************************************************/
    constructor(spi, cs_l, i2c) {
        _spi = spi;
        _cs_l = cs_l;
        _i2c = i2c;
        // the imp's SPI interface does not implicitly include a CS pin
        // configure a GPIO to use as the chip select (active low)
        _cs_l.configure(DIGITAL_OUT);
        _cs_l.write(1);
        reset();
    };
    
    function _spi_write(address, value) {
        //server.log(format("Writing: 0x%02x to 0x%02x",value,address));
        _cs_l.write(0);
        _spi.write(address.tochar() + value.tochar());
        _cs_l.write(1);
    };
    
    function _spi_read(address) {
        _cs_l.write(0);
        local rblob = _spi.writeread(address.tochar()+"\x00");
        _cs_l.write(1);
        //server.log(format("read %02x from %02x",rblob[1], address));
        return rblob[1];
    };
    
    function _write_arduchip_reg(address, value) {
        _spi_write((address | 0x80), value);
    }
    
    function _read_arduchip_reg(address) {
        local value = _spi_read(address & 0x7F);
        return value; 
    }
    
    function flush_fifo()      { _write_arduchip_reg(ARDUCHIP_FIFO, FIFO_RDPTR_RST_MASK)}
    
    function start_capture()   { _write_arduchip_reg(ARDUCHIP_FIFO, FIFO_START_MASK)}
    
    function clear_fifo_flag() { _write_arduchip_reg(ARDUCHIP_FIFO, FIFO_CLEAR_MASK)}
    
    function read_fifo()       { _spi_read(SINGLE_FIFO_READ) }
    
    function read_fifo_length() {
        local len1 = _read_arduchip_reg(FIFO_SIZE1);
        local len2 = _read_arduchip_reg(FIFO_SIZE2);
        local len3 = _read_arduchip_reg(FIFO_SIZE3);
        local length = ((len3 << 16) | (len2 << 8) | len1) & 0x07fffff;
        return length;
    }

    function set_fifo_burst() {
        _spi.write(BURST_FIFO_READ.tochar());
    }
    
    function get_bit(address, bit) {
        local tmp = _read_arduchip_reg(address);
        return (tmp & bit);
    }

    function _write_sensor_reg(address, value) {
        local i2c_err = _i2c.write(0x60, address.tochar() + value.tochar());
        if (i2c_err) {
            throw("i2c error:" + _i2c_err);
        }
    }
    
    function _write_sensor_regs(regs) {
        for(local i = 0; i < regs.len(); i+=2) {
            _write_sensor_reg(regs[i], regs[i+1]);
        }
    }

    function _read_sensor_reg(reg) {
        local data = _i2c.read(0x61,reg.tochar(),1)[0];
        return data;
    }

    function reset() {
        // First, test SPI is working
        _write_arduchip_reg(0x00, 0xaa);
        if (_read_arduchip_reg(0x00) != 0xaa) {
            throw("Error: could not talk SPI to arduchip");
        }

        // Log arduchip version
        local arduchip = _read_arduchip_reg(0x40);
        if (arduchip != 0x40 && arduchip != 0x55) {
            throw(format("Error: did not find expected Arduchip version (0x40/0x55). Version found=0x%02x", arduchip))
        }

        // Read camera ID & check it's valid
        _write_sensor_reg(0xff, 0x01);
        local pid = (_read_sensor_reg(0x0a) << 8) | _read_sensor_reg(0x0b);
        if (pid != 0x2642) {
            throw(format("Error: did not find expected OV2640 camera (0x2642). PID found=0x%04x", pid));
        }

        // Set system reset bit
        _write_sensor_reg(0xff, 0x01);
        _write_sensor_reg(0x12, 0x80);
        imp.sleep(0.01);
        
        // Load default parameter sets
        _write_sensor_regs(OV2640_JPEG_INIT);
        _write_sensor_regs(OV2640_YUV422);
        _write_sensor_regs(OV2640_JPEG);

        // Set up a default picture size
        set_jpeg_size(320);
    }
    
    function capture() {
        flush_fifo();
        clear_fifo_flag();
        start_capture();
        local startTime = hardware.millis();
        while (!get_bit(ARDUCHIP_TRIG, CAP_DONE_MASK)) {
            if (hardware.millis() - startTime > PHOTO_TIMEOUT) {
                return false;
            }
        }
        return true; // success!
    }
    
    function set_jpeg_size(size) {
        switch(size) {
            case 160:   _write_sensor_regs(OV2640_160x120_JPEG); break;
            case 176:   _write_sensor_regs(OV2640_176x144_JPEG); break;
            case 320:   _write_sensor_regs(OV2640_320x240_JPEG); break;
            case 352:   _write_sensor_regs(OV2640_352x288_JPEG); break;
            case 640:   _write_sensor_regs(OV2640_640x480_JPEG); break;
            case 800:   _write_sensor_regs(OV2640_800x600_JPEG); break;
            case 1024:  _write_sensor_regs(OV2640_1024x768_JPEG); break;
            case 1280:  _write_sensor_regs(OV2640_1280x960_JPEG); break;
            case 1600:  _write_sensor_regs(OV2640_1600x1200_JPEG); break;
            default:
                _write_sensor_regs(OV2640_320x240_JPEG);
                server.log("Size not recognized, default 320x240 set");
                break;
        }
    }
    
    // Set into RGB mode
    function setRGB() {
        //_write_sensor_regs(OV2640_QVGA);
        _write_sensor_regs(RGB565);
    }
    
    // Set into YUV422 mode
    function setYUV422() {
        _write_sensor_regs(OV2640_YUV422);
    }
    
    // Returns the image stored in fifo
    function saveLocal() {
        local len = read_fifo_length();
        _cs_l.write(0);
        set_fifo_burst();
        _spi.readblob(1); //dummy read
        local b = _spi.readblob(len)
        _cs_l.write(1);
        return b;
    }
    
    // Brighten the picture you're taking
    function brighten() {
        _write_sensor_reg(RA_DLMT, DSP_ADDRESS);
        _write_sensor_reg(0x7c, 0x00);
        _write_sensor_reg(0x7d, 0x04);
        _write_sensor_reg(0x7c, 0x09);
        _write_sensor_reg(0x7d, 0x40);
        _write_sensor_reg(0x7d, 0x00);
    }
    
    // Pass in a 16-bit value that corresponds to how long the exposure lasts
    function setExposure(exp) {
        _write_sensor_reg(RA_DLMT, DSP_ADDRESS); // enable AEC
        _write_sensor_reg(CTRL0, (_read_sensor_reg(CTRL0) & 0x7f) | 0x80);
        _write_sensor_reg(RA_DLMT, SENSOR_ADDRESS);
        local msb = _read_sensor_reg(REG45);
        local msb_changed = (msb & 0xc0) | ((exp >> 10) & 0x3f) ;
        _write_sensor_reg(REG45, msb_changed);
        
        local lsb = _read_sensor_reg(REG04);
        local lsb_changed = (lsb & 0xfc) | (exp & 0x03);
        _write_sensor_reg(REG04, lsb_changed);
        
        _write_sensor_reg(AEC, (exp >> 2) & 0xff);
    }
}