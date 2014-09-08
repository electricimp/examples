// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// SPI Clock Rate in kHz
const SPICLK = 7500;
const IOEXP_ADDR = 0x40; // 8-bit address
const DISPWIDTH = 264;
const DISPHEIGHT = 176;

// class to drive Pervasive Displays epaper display
// see http://repaper.org
class Epaper {

    WIDTH           = null;
    HEIGHT          = null;
    PIXELS          = null;
    BYTESPERSCREEN  = null;
    FRAMEREPEATS    = 2;
    spi             = null;
    epd_cs_l        = null;
    busy            = null;
    rst_l           = null;
    pwr_en_l        = null;
    panel           = null;
    border          = null;
    discharge       = null;
    
    epd_cs_l_write  = null;
    spi_write       = null;

    constructor(_width, _height, _spi, _epd_cs_l, _busy, _rst_l, _pwr_en_l, _discharge, _border) {
        WIDTH = _width;
        HEIGHT = _height;
        PIXELS = WIDTH * HEIGHT;
        BYTESPERSCREEN = PIXELS / 4;
        spi = _spi;
        server.log("Display Running at: " + spiOff() + " kHz");
        epd_cs_l = _epd_cs_l;
        epd_cs_l.configure(DIGITAL_OUT, 0);
        busy = _busy;
        busy.configure(DIGITAL_IN);
        rst_l = _rst_l;
        rst_l.configure(DIGITAL_OUT, 0);
        discharge = _discharge;
        discharge.configure(DIGITAL_OUT, 0);
        border = _border;
        border.configure(DIGITAL_OUT, 0);
        pwr_en_l = _pwr_en_l;
        pwr_en_l.configure(DIGITAL_OUT, 1);

        // alias speed-critical calls
        epd_cs_l_write = epd_cs_l.write.bindenv(epd_cs_l);
        spi_write      = spi.write.bindenv(spi);
    }
    function spiOn() {
        local freq = spi.configure(CLOCK_IDLE_HIGH | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        spi.write("\x00");
        return freq;
    }
    function spiOff() {
        local freq = spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        spi.write("\x00");
        return freq;
    }
    // Write to EPD registers over SPI
    function writeEPD(index, ...) {
        epd_cs_l_write(1);                    
        epd_cs_l_write(0);          
        spi_write(format("%c%c", 0x70, index)); // Write header, then register index
        epd_cs_l_write(1);      
        epd_cs_l_write(0);        
        spi_write(format("%c", 0x72));          // Write data header
        
        foreach (word in vargv) {
            spi_write(format("%c", word)); 
        }
        epd_cs_l_write(1);        
    }
    function write_epd_pair(index, value) {
        epd_cs_l_write(1);                 
        epd_cs_l_write(0);                   
        spi_write(format(CHARCHAR, 0x70, index)); // Write header, then register index
        epd_cs_l_write(1);                 
        epd_cs_l_write(0);            
        spi_write(format(CHARCHAR, 0x72, value)); // Write data header, then register data
        epd_cs_l_write(1);                    
    }
    function writeEPD_raw(...) {
        epd_cs_l_write(0);                  
        foreach (word in vargv) {
            spi_write(format("%c", word));    
        }
        epd_cs_l_write(1);                  
    }
    function readEPD(...) {
        local result = "";
        epd_cs_l_write(0);              
        foreach (word in vargv) {
            result += spi.writeread(format("%c", word));
        }
        epd_cs_l_write(1);                
        return result;
    }
    function start() {
        server.log("Powering On EPD.");
 
        /* Power-On Sequence ------------------------------------------------*/
 
        // make sure SPI is low to avoid back-powering things through the SPI bus
        spiOn();
 
        // Make sure signals start unasserted (rest, panel-on, discharge, border, cs)
        pwr_en_l.write(1);
        rst_l.write(0);
        discharge.write(0);
        border.write(0);
        epd_cs_l_write(0);

        // Turn on panel power
        pwr_en_l.write(0);
        rst_l.write(1);
        epd_cs_l_write(1);
        border.write(1);
        
        // send reset pulse
        rst_l.write(0);
        imp.sleep(0.005);
        rst_l.write(1);
        imp.sleep(0.005);
        
        /* EPD Driver Initialization ----------------------------------------*/

        writeEPD(0x02, 0x40);         // Disable OE
        writeEPD(0x0b, 0x02);         //Power Saving Mode
        writeEPD(0x01,0x00,0x00,0x00,0x7F,0xFF,0xFE,0x00,0x00);        // Channel Select for 2.7" Display
        //writeEPD(0x07, 0x9D);         // High Power Mode Oscillator Setting
        writeEPD(0x07, 0xD1);         // High Power Mode Oscillator Setting 
        //writeEPD(0x08, 0x00);         // Disable ADC
        writeEPD(0x08, 0x02);         // "Power Setting"
        //writeEPD(0x09, 0xD0, 0x00);   // Set Vcom level
        writeEPD(0x09, 0xc2);         // Set Vcom level
        //writeEPD(0x04, 0x00);         // power setting
        writeEPD(0x04, 0x03);         // "Power Setting"
        writeEPD(0x03, 0x01);         // Driver latch on ("cancel register noise")
        writeEPD(0x03, 0x00);         // Driver latch off
        
        imp.sleep(0.05);
        
        // writeEPD(0x05, 0x01);         // Start charge pump positive V (VGH & VDH on)
        // imp.sleep(0.240);
        // writeEPD(0x05, 0x03);         // Start charge pump negative voltage
        // imp.sleep(0.04);
        // writeEPD(0x05, 0x0f);         // Set charge pump Vcom driver to ON
        // imp.sleep(0.04);
 
        local dc_ok = false;
        
        for (local i = 0; i < 4; i++) {
            // Start charge pump positive V (VGH & VDH on)
            this.writeEPD(0x05, 0x01);
            imp.sleep(0.240);
            // Start charge pump negative voltage
            this.writeEPD(0x05, 0x03);
            imp.sleep(0.040);
            // Set charge pump Vcom driver to ON
            this.writeEPD(0x05, 0x0f);
            imp.sleep(0.040);
            writeEPD_raw(0x70, 0x0f);
            local dc_state = readEPD(0x73, 0x00)[1];
            //server.log("dc state: " + dc_state);
            if (0x40 == (0x40 & dc_state)) {
                dc_ok = true;
                break;
            }
        }
        
        if (!dc_ok) {
            server.error("DC state failed");
            // Output enable to disable
            this.writeEPD(0x02, 0x40);
            this.stop();
            // TODO led error blink
            return;
        }
        
        server.log("COG Driver Initialized.");
    }
    // Power off COG Driver
    function stop() {
        server.log("Powering Down EPD");

        border.write(0);
        imp.sleep(0.2);
        border.write(1);
        
        // Check DC/DC
        writeEPD_raw(0x70, 0x0f);
        local dc_state = readEPD(0x73, 0x00)[1];
        //server.log("dc state: " + dc_state);
        if (0x40 != (0x40 & dc_state)) {
            // TODO fail properly
            server.log("dc failed");
        }
 
        writeEPD(0x03, 0x01);        // latch reset on
        writeEPD(0x02, 0x05);        // output enable off
        writeEPD(0x05, 0x03);        // VCOM power off
        writeEPD(0x05, 0x01);        // power off negative charge pump
        imp.sleep(0.240);
        writeEPD(0x05, 0x00);        // power off all charge pumps
        writeEPD(0x07, 0x01);        // turn off oscillator
        writeEPD(0x04, 0x83);        // discharge internal on

        imp.sleep(0.030);
 
        // turn off all power and set all inputs low
        rst_l.write(0);
        pwr_en_l.write(1);
        border.write(0);
 
        // ensure MOSI is low before CS Low
        spiOff();
        imp.sleep(0.001);
        epd_cs_l.write(0);
 
        // send discharge pulse
        discharge.write(1);
        imp.sleep(0.15);
        discharge.write(0);
        epd_cs_l.write(1);
        server.log("Display Powered Down.");
    }
    function drawScreen(screenData) {
        for (local repeat = 0; repeat < FRAMEREPEATS; repeat++) {   
            foreach (line in screenData) {    
                writeEPD(0x04, 0x00); // set charge pump voltage level
                writeEPD_raw(0x70, 0x0A)
                epd_cs_l_write(0);
                spi_write("\x72");      // line header byte
                spi_write("\x00");      // null border byte
                spi_write(line);
                spi_write("\x00");   
                epd_cs_l_write(1);
                writeEPD(0x02, 0x2F); // Output enable  
            }
        }
    }
}

class SX150x{
    //Private variables
    _i2c       = null;
    _addr      = null;
    _callbacks = null;

    //Pass in pre-configured I2C since it may be used by other devices
    constructor(i2c, address = 0x40) {
        _i2c  = i2c;
        _addr = address;  //8-bit address
        _callbacks = [];
    }

    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x", _addr, register));
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register, data) {
        _i2c.write(_addr, format("%c%c", register, data));
    }
    
    function writeBit(register, bitn, level) {
        local value = readReg(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        writeReg(register, value);
    }
    
    function writeMasked(register, data, mask) {
        //server.log("reading pre-masked value");
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }

    // set or clear a selected GPIO pin, 0-16
    function setPin(gpio, level) {
        writeBit(bank(gpio).REGDATA, gpio % 8, level ? 1 : 0);
    }

    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        writeBit(bank(gpio).REGDIR, gpio % 8, output ? 0 : 1);
    }

    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        writeBit(bank(gpio).REGPULLUP, gpio % 8, enable ? 1 : 0);
    }
    
    // enable or disable internal pull down resistor for specified GPIO
    function setPullDn(gpio, enable) {
        writeBit(bank(gpio).REGPULLDN, gpio % 8, enable ? 1 : 0);
    }

    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, enable ? 0 : 1);
    }

    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, 1);
    }

    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(bank(gpio).REGDATA) & (1<<(gpio%8))) ? 1 : 0);
    }

    //configure which callback should be called for each pin transition
    function setCallback(gpio, callback){
        _callbacks.insert(gpio,callback);
    }

    function callback(){
        local irq = getIrq();
        clearAllIrqs();
        for (local i = 0; i < 16; i++){
            if ( (irq & (1 << i)) && (typeof _callbacks[i] == "function")){
                _callbacks[i]();
            }
        }
    }
}
class SX1505 extends SX150x{
    // I/O Expander internal registers
    BANK_A = {  REGDATA    = 0x00
                REGDIR     = 0x01
                REGPULLUP  = 0x02
                REGPULLDN  = 0x03
                REGINTMASK = 0x05
                REGSNSHI   = 0x06
                REGSNSLO   = 0x07
                REGINTSRC  = 0x08
            }

    constructor(i2c, address=0x20){
        base.constructor(i2c, address);
        _callbacks.resize(8,null);
        this.reset();
        this.clearAllIrqs();
    }
    
    //Write registers to default values
    function reset() {
        writeReg(BANK_A.REGDIR, 0xFF);
        writeReg(BANK_A.REGDATA, 0xFF);
        writeReg(BANK_A.REGPULLUP, 0x00);
        writeReg(BANK_A.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_A.REGSNSHI, 0x00);
        writeReg(BANK_A.REGSNSLO, 0x00);
    }
    
    function bank(gpio){ return BANK_A; }

    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? BANK_A.REGSNSHI : BANK_A.REGSNSLO, data, mask);
    }

    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC, 0xFF);
    }
    
    function getIrq(){
        return (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
}
class expGPIO {
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    
    // Optional initial state (defaults to 0 just like the imp)
    function configure(mode, callback_initialstate = null) {
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if (callback_initialstate != null) {
                _expander.setPin(_gpio, callback_initialstate);    
            } else {
                _expander.setPin(_gpio, 0);
            }
            
            return this;
        }
            
        if (mode == DIGITAL_IN) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN_PULLUP) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (typeof callback_initialstate == "function") {
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio, callback_initialstate.bindenv(this));
        } else {
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }
        
        return this;
    }
    
    function write(state) { _expander.setPin(_gpio,state); }
    
    function read() { return _expander.getPin(_gpio); }
}
function chkBat() {
    vbat_sns_en.write(1);
    local vbat = (vbat_sns.read()/65535.0) * hardware.voltage() * (6.9/4.7);
    vbat_sns_en.write(0);
    return vbat;
}
function chkBtn1() {
    server.log("Button 1 State: "+btn1.read());
}
function chkBtn2() {
    server.log("Button 2 State: "+btn2.read());
}
function chgStatusChanged() {
    if (chg_status.read()) {
        server.log("Battery Charging Stopped.");
    } else {
        server.log("Battery Charging Started.");
    }
}

/* REGISTER AGENT CALLBACKS -------------------------------------------------*/

agent.on("newImg", function(data) {
    server.log("Drawing new image, memory free = "+imp.getmemoryfree());
    display.start();
    // agent sends the inverted version of the current image first
    display.drawScreen(data);
    agent.send("readyForWhite",0);
});

agent.on("white", function(data) {
    display.drawScreen(data);
    agent.send("readyForNewImgInv",0);
});

agent.on("newImgInv", function(data) {
    display.drawScreen(data);
    agent.send("readyForNewImgNorm",0);
});

agent.on("newImgNorm", function(data) {
    display.drawScreen(data);
    display.stop();
})

agent.on("clear", function(val) {
    server.log("Force-clearing screen.");
    display.start();
    display.white()
    display.stop();
});

/* RUNTIME BEGINS HERE ------------------------------------------------------*/

server.log(imp.getsoftwareversion());
imp.enableblinkup(true);

// Vanessa Reference Design Pin configuration
ioexp_int_l     <- hardware.pin1;   // I/O Expander Alert (Active Low)
spi             <- hardware.spi257;
// MISO         <- hardware.pin2;   // SPI interface
// SCLK         <- hardware.pin5;   // SPI interface
epd_busy        <- hardware.pin6;   // Busy input
// MOSI         <- hardware.pin7;   // SPI interface
i2c             <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
// SCL          <- hardware.pin8;   // I2C CLOCK
// SDA          <- hardware.pin9;   // I2C DATA
vbat_sns        <- hardware.pinA;   // Battery Voltage Sense (ADC)
vbat_sns.configure(ANALOG_IN);
temp_sns        <- hardware.pinB;   // Temperature Sense (ADC)
epd_cs_l        <- hardware.pinD;   // EPD Chip Select (Active Low)
flash_cs_l      <- hardware.pinE;
flash_cs_l.configure(DIGITAL_OUT);
flash_cs_l.write(1);

// Vanessa includes an 8-channel I2C I/O Expander (SX1505)
ioexp <- SX1505(i2c,IOEXP_ADDR);    // instantiate I/O Expander
// configure I/O Expander interrupt pin to check for callbacks on the I/O Expander
ioexp_int_l.configure(DIGITAL_IN, function(){ ioexp.callback(); });

epd_pwr_en_l    <- expGPIO(ioexp, 0);     // EPD Panel Power Enable Low (GPIO 0)
epd_rst_l       <- expGPIO(ioexp, 1);     // EPD Reset Low (GPIO 1)
epd_discharge   <- expGPIO(ioexp, 2);     // EPD Discharge Line (GPIO 2)
epd_border      <- expGPIO(ioexp, 3);     // EPD Border CTRL Line (GPIO 3)
// Two buttons also on GPIO Expander
btn1            <- expGPIO(ioexp, 4).configure(DIGITAL_IN, chkBtn1);     // User Button 1 (GPIO 4)
btn2            <- expGPIO(ioexp, 5).configure(DIGITAL_IN, chkBtn2);     // User Button 1 (GPIO 5)
// Battery Charge Status on GPIO Expander
chg_status      <- expGPIO(ioexp, 6).configure(DIGITAL_IN, chgStatusChanged);     // BQ25060 Battery Management IC sets this line low when charging
// VBAT_SNS_EN on GPIO Expander
vbat_sns_en     <- expGPIO(ioexp, 7).configure(DIGITAL_OUT, 0);    // VBAT_SNS_EN (GPIO Expander Pin7)
// Construct a SPI flash object
spi.configure(CLOCK_IDLE_LOW, SPICLK);
// log the battery voltage at startup
server.log(format("Battery Voltage: %.2f V",chkBat()));
display <- Epaper(DISPWIDTH, DISPHEIGHT, spi, epd_cs_l, epd_busy, 
    epd_rst_l, epd_pwr_en_l, epd_discharge, epd_border);
server.log("Config Done.");
server.log(imp.getmemoryfree()+" bytes free");