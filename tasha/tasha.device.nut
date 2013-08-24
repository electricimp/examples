// Adafruit Color TFT
imp.setpowersave(true);
imp.configure("Adafruit TFT", [], []);

// Addresses
const SPLASH = 0x000000;
const IMAGE_ADDR = 0x00A000;

// Colors
const RED       = "\xF8\x00";
const GREEN     = "\x03\xE0";
const BLUE      = "\x00\x1F";

// Pin configuration
// Pin 1: Flash Chip Select (active low)
// Pin 2: SPI (MISO)
// Pin 5: SPI (SCLK)
// Pin 6: LCD Chip Select (active low)
// Pin 7: SPI (MOSI)
// Pin 8: Backlight PWM
// Pin 9: LCD Reset (active low)
// Pin A: Ambient Light Sensor
// Pin B: Button 3
// Pin C: Button 2
// Pin D: Button 1
// Pin E: LCD Mode - Data (high) / Command (low)

hardware.pin1.configure(DIGITAL_OUT);
hardware.pin1.write(1);
hardware.pin6.configure(DIGITAL_OUT);
hardware.pin6.write(1);
hardware.pin8.configure(PWM_OUT, 0.002, 1.0);
hardware.pin9.configure(DIGITAL_OUT);
hardware.pin9.write(0);
hardware.pinA.configure(ANALOG_IN);
hardware.pinB.configure(DIGITAL_IN_PULLUP);
hardware.pinC.configure(DIGITAL_IN_PULLUP);
hardware.pinD.configure(DIGITAL_IN_PULLUP);
hardware.pinE.configure(DIGITAL_OUT);
hardware.pinE.write(1);

// SPI Mode 0 (defaults, max rate)
hardware.spi257.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);

class ST7735_LCD {
    // ST7735-driven color LCD class
    // Will run with 15MHz SPI clock, but don't go above 6MHz if you want to read anything!
    // System commands
    static NOP       = "\x00"; // No operation
    static SWRESET   = "\x01"; // Software reset
    static RDDID     = "\x04"; // Read display ID
    static RDDST     = "\x09"; // Read display status
    static RDDPM     = "\x0A"; // Read display power
    static RDDMADCTL = "\x0B"; // Read display
    static RDDCOLMOD = "\x0C"; // Read display pixel
    static RDDIM     = "\x0D"; // Read display image
    static RDDSM     = "\x0E"; // Read display signal
    static SLPIN     = "\x10"; // Sleep in
    static SLPOUT    = "\x11"; // Sleep off
    static PTLON     = "\x12"; // Partial mode on
    static NORON     = "\x13"; // Partial mode off (normal)
    static INVOFF    = "\x20"; // Display inversion off
    static INVON     = "\x21"; // Display inversion on
    static GAMSET    = "\x26"; // Gamma curve select
    static DISPOFF   = "\x28"; // Display off
    static DISPON    = "\x29"; // Display on
    static CASET     = "\x2A"; // Column address set
    static RASET     = "\x2B"; // Row address set
    static RAMWR     = "\x2C"; // Memory write
    static RGBSET    = "\x2D"; // LUT (lookup table) for 4k, 65k, 262k color
    static RAMRD     = "\x2E"; // Memory read
    static PTLAR     = "\x30"; // Partial start/end address set
    static TEOFF     = "\x34"; // Tearing effect line off
    static TEON      = "\x35"; // Tearing effect mode set & on
    static MADCTL    = "\x36"; // Memory access data control
    static IDMOFF    = "\x38"; // Idle mode off
    static IDMON     = "\x39"; // Idle mode on
    static COLMOD    = "\x3A"; // Interface pixel format
    static RDID1     = "\xDA"; // Read ID1
    static RDID2     = "\xDB"; // Read ID2
    static RDID3     = "\xDC"; // Read ID3
    // Display commands
    static FRMCTR1   = "\xB1"; // In normal mode (Full colors)
    static FRMCTR2   = "\xB2"; // In idle mode (8-colors)
    static FRMCTR3   = "\xB3"; // In partial mode (full colors)
    static INVCTR    = "\xB4"; // Display inversion control
    static PWCTR1    = "\xC0"; // Power control setting
    static PWCTR2    = "\xC1"; // Power control setting
    static PWCTR3    = "\xC2"; // Power control setting
    static PWCTR4    = "\xC3"; // Power control setting
    static PWCTR5    = "\xC4"; // Power control setting
    static VMCTR1    = "\xC5"; // VCOM control 1
    static VMOFCTR   = "\xC7"; // Set VCOM offset control
    static WRID2     = "\xD1"; // Set LCM version code
    static WRID3     = "\xD2"; // Set customer project code
    static NVCTR1    = "\xD9"; // NVM control status
    static NVCTR2    = "\xDE"; // NVM read command
    static NVCTR3    = "\xDF"; // NVM write command
    static GAMCTRP1  = "\xE0"; // Gamma adjustment (+ polarity)
    static GAMCTRN1  = "\xE1"; // Gamma adjustment (- polarity)
    
    pixelCount = null;
    
    // I/O pins
    spi = null;
    lite = null;
    rst = null;
    cs_l = null;
    dc = null;
    
    // Constructor. Arguments: Width, Height, SPI, Backlight, Reset, Chip Select, Data/Command_L
    constructor(width, height, spiBus, litePin, rstPin, csPin, dcPin) {
        this.pixelCount = width * height;
        this.spi = spiBus;
        this.lite = litePin;
        this.rst = rstPin;
        this.cs_l = csPin;
        this.dc = dcPin;
    }
    
    // Send a command by pulling the D/C line low and writing to SPI
    // Takes a variable number of parameters which are sent after the command
    function command(c, ...) {
        cs_l.write(0);      // Select LCD
        dc.write(0);        // Command mode
        spi.write(c);       // Write command
        dc.write(1);        // Exit command mode to send parameters
        foreach (datum in vargv) {
            spi.write(datum);
        }
        cs_l.write(1);      // Deselect LCD
    }
    
    // Read bytes and return as a blob (this doesn't work - maybe because SCLK is too fast)
    function read(numberOfBytes) {
        cs_l.write(0);
        dc.write(1);    // All reads are data mode
        local output = spi.readblob(numberOfBytes);
        cs_l.write(1);
        return output;
    }
    
    // Write a blob to the screen
    function writeBlob(imageBlob) {
        cs_l.write(0);          // Select the LCD
        spi.write(imageBlob);   // Write the blob
        cs_l.write(1);          // Deselect the LCD
    }
    
    // Pulse the reset line for 50ms and send a software reset command
    function reset() {
        rst.write(0);
        imp.sleep(0.05);
        rst.write(1);
        command(SWRESET);
        imp.sleep(0.120); // Must wait 120ms before sending next command
    }
    
    // Clear the contents of the display RAM
    function clear() {
        scan("\x00\x00");           // Slow, looks neat
//        fillScreen("\x00\x00");   // Fast, takes more memory
    }
    
    // Initialize the display (Reset, exit sleep, turn on display)
    function initialize() {
        server.log("Initializing...");
        reset();                    // HW/SW reset
        clear();                    // Clear screen
        lite.write(1.0);            // Turn on backlight
        command(SLPOUT);            // Wake from sleep
        command(DISPON);            // Display on
        command(COLMOD, "\x05");    // 16-bit color mode
        command(FRMCTR1, "\x00", "\x06", "\x03");   // Refresh rate / "porch" settings
    }
    
    // Fill screen with a color by (slowly) scanning throw each pixel
    function scan(color) {
        command(RAMWR);
        cs_l.write(0);
        local w = spi.write.bindenv(spi);
        for (local i = 0; i < pixelCount; i++) {
            w(color + color);
        }
        cs_l.write(1);
    }
    
    // Fill screen with a solid color (two bytes, RGB 5-6-5) in two chunks
    // RED, GREEN, and BLUE are static and can be used for testing
    function fillScreen(color) {
        server.log("Filling screen.");
        cs_l.write(0);
        command(RAMWR);
        local colorBlob = blob(pixelCount);
        foreach (i, byte in colorBlob) {
            if (i % 2) {
                colorBlob[i] = color[1];
            }
            else
                colorBlob[i] = color[0];
        }
        spi.write(colorBlob);
        spi.write(colorBlob);
        cs_l.write(1);
    }

    
}
// End ST7735_LCD class

// SPI Flash class
class spiFlash {
    // MX25L3206E SPI Flash
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    static WREN     = "\x06"; // write enable
    static WRDI     = "\x04"; // write disable
    static RDID     = "\x9F"; // read identification
    static RDSR     = "\x05"; // read status register
    static READ     = "\x03"; // read data
    static FASTREAD = "\x0B"; // fast read data
    static RDSFDP   = "\x5A"; // read SFDP
    static RES      = "\xAB"; // read electronic ID
    static REMS     = "\x90"; // read electronic mfg & device ID
    static DREAD    = "\x3B"; // double output mode, which we don't use
    static SE       = "\x20"; // sector erase (Any 4kbyte sector set to 0xff)
    static BE       = "\x52"; // block erase (Any 64kbyte sector set to 0xff)
    static CE       = "\x60"; // chip erase (full device set to 0xff)
    static PP       = "\x02"; // page program 
    static RDSCUR   = "\x2B"; // read security register
    static WRSCUR   = "\x2F"; // write security register
    static ENSO     = "\xB1"; // enter secured OTP
    static EXSO     = "\xC1"; // exit secured OTP
    static DP       = "\xB9"; // deep power down
    static RDP      = "\xAB"; // release from deep power down

    // offsets for the record and playback sectors in memory
    // 64 blocks
    // first 48 blocks: playback memory
    // blocks 49 - 64: recording memory
    static totalBlocks = 64;
    static playbackBlocks = 48;
    static recordOffset = 0x2FFFD0;
    
    // manufacturer and device ID codes
    mfgID = null;
    devID = null;
    
    // spi interface
    spi = null;
    cs_l = null;

    // constructor takes in pre-configured spi interface object and chip select GPIO
    constructor(spiBus, csPin) {
        this.spi = spiBus;
        this.cs_l = csPin;

        // read the manufacturer and device ID
        cs_l.write(0);
        spi.write(RDID);
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        cs_l.write(1);
    }
    
    function wrenable() {
        cs_l.write(0);
        spi.write(WREN);
        cs_l.write(1);
    }
    
    function wrdisable() {
        cs_l.write(0);
        spi.write(WRDI);
        cs_l.write(1);
    }
    
    // pages should be pre-erased before writing
    function write(addr, data) {
        wrenable();
        
        // check the status register's write enabled bit
        if (!(getStatus() & 0x02)) {
            server.error("Device: Flash Write not Enabled");
            server.log(getStatus());
            return 1;
        }
        
        cs_l.write(0);
        // page program command goes first
        spi.write(PP);
        // followed by 24-bit address
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        spi.write(data);
        cs_l.write(1);
        
        // wait for the status register to show write complete
        // typical 1.4 ms, max 5 ms
        local timeout = 50000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                server.log(getStatus());
                return 1;
            }
        }
        
        return 0;
    }

    // allow data chunks greater than one flash page to be written in a single op
    function writeChunk(addr, data) {
        // separate the chunk into pages
        data.seek(0,'b');
        for (local i = 0; i < data.len(); i+=256) {
            local leftInBuffer = data.len() - data.tell();
            if (leftInBuffer < 256) {
                flash.write((addr+i),data.readblob(leftInBuffer));
            } else {
                flash.write((addr+i),data.readblob(256));
            }
        }
    }

    function read(addr, bytes) {
        cs_l.write(0);
        // to read, send the read command and a 24-bit address
        spi.write(READ);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        local readBlob = spi.readblob(bytes);        
        cs_l.write(1);
        return readBlob;
    }
    
    function getStatus() {
        cs_l.write(0);
        spi.write(RDSR);
        local status = spi.readblob(1);
        cs_l.write(1);
        return status[0];
    }
    
    function sleep() {
        cs_l.write(0);
        spi.write(DP);
        cs_l.write(1);     
   }
    
    function wake() {
        cs_l.write(0);
        spi.write(RDP);
        cs_l.write(1);
    }
    
    // erase any 4kbyte sector of flash
    // takes a starting address, 24-bit, MSB-first
    function sectorErase(addr) {
        this.wrenable();
        cs_l.write(0);
        spi.write(SE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 60ms, max = 300ms
        local timeout = 300000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for sector erase to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function blockErase(addr) {
        server.log(format("Device: erasing 64kbyte SPI Flash block beginning at 0x%06x",addr));
        this.wrenable();
        cs_l.write(0);
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for block erase to complete
        // typ = 700ms, max = 2s
        local timeout = 2000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for block erase to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // clear the full flash to 0xFF
    function chipErase() {
        server.log("Device: Erasing SPI Flash");
        this.wrenable();
        cs_l.write(0);
        spi.write(CE);
        cs_l.write(1);
        // chip erase takes a *while*
        // typ = 25s, max = 50s
        local timeout = 50000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for chip erase to finish");
                server.log(getStatus());
                return 1;
            }
        }
        server.log("Device: Done with chip erase");
        return 0;
    }
}
// End SPI Flash class

// Log how much free memory we have
function mem() {
    server.log("Memory free: " + imp.getmemoryfree());
}

// Ask the agent to send us the image data
function requestImageChunk(chunk) {
    if (chunk == 1) {
        screen.clear();                        // Clear screen
    }
    agent.send("getChunk", chunk);       // Get first chunk
    //imp.wakeup(10, requestImage);   // Check for new image every X seconds
}

// Read image from flash and write it to the screen
function displayImage(addr) {
    server.log("Displaying image @ " + addr);
    screen.clear();
    local imageHalf = flash.read(addr, 20480);
    screen.writeBlob(imageHalf);
    imageHalf.seek(0);
    imageHalf.resize(0);
    imageHalf = flash.read(addr + 0x005000, 20480);
    screen.writeBlob(imageHalf);
}

// screen constructor. arguments: Width, Height, SPI, Backlight, Reset, Chip Select, Data/Command
screen <- ST7735_LCD(128, 160, hardware.spi257, hardware.pin8, hardware.pin9, hardware.pin6, hardware.pinE);
// flash constructor. arguments: SPI, Chip Select
flash <- spiFlash(hardware.spi257, hardware.pin1);

// After receiving part of an image, write to the flash and check for more chunks
agent.on("imageChunk", function(data) {
    server.log("loading image chunk " + data.thisChunk);
    local blockSize = screen.pixelCount * 2 / data.totalChunks;
    local blockAddr = blockSize * data.thisChunk + IMAGE_ADDR;
    flash.wake();
    server.log("Writing chunk " + data.thisChunk + " to flash @ " + blockAddr);
    flash.writeChunk(blockAddr, data.chunkBlob);              // Write chunk to flash
    if (data.thisChunk  < data.totalChunks - 1) {
        agent.send("getChunk", data.thisChunk + 1);     // Get next (zero-indexed) chunk
    }
    else {
        displayImage(IMAGE_ADDR); // Display contents of image storage block
    }
});
screen.initialize();
screen.clear();
//displayImage(SPLASH);     // Display imp logo as startup splash
flash.blockErase(IMAGE_ADDR); // Erase image storage block
// flash.chipErase();
requestImageChunk(0);       // Get the first part of the image (zero-indexed)