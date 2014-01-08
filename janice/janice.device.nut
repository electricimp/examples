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

/* Janice Sprinkler Controller Device Firmware
 * Tom Byrne
 * 1/7/14
 */
 
/* CONSTS and GLOBAL VARS ====================================================*/

const WIFI_TIMEOUT = 30; // time in seconds to allow a connection attempt to wait
const RECONNECT_PERIOD = 1; // time between reconnect attempts (minutes)

/* GLOBAL CLASS AND FUNCTION DEFINITIONS =====================================*/

/* Squirrel Object serializer/deserializer class.
 * From Electric Imp Github Examples Repo:
 * https://github.com/electricimp/reference/blob/master/hardware/serializer/
 */
class serializer {
 
    // Serialize a variable of any type into a blob
    function serialize (obj) {
        // Take a guess at the initial size
        local b = blob(2000);
        // Write dummy data for len and crc late
        b.writen(0, 'b');
        b.writen(0, 'b');
        b.writen(0, 'b');
        // Serialise the object
        _serialize(b, obj);
        // Shrink it down to size
        b.resize(b.tell());
        // Go back and add the len and CRC
                local len = b.len()-3;
        b[0] = len >> 8 & 0xFF;
        b[1] = len & 0xFF;
        b[2] = CRC(b, 3);
        return b;
        }
 
        function _serialize (b, obj) {
 
                switch (typeof obj) {
                        case "integer":
                return _write(b, 'i', format("%d", obj));
                        case "float":
                local f = format("%0.7f", obj).slice(0,9);
                while (f[f.len()-1] == '0') f = f.slice(0, -1);
                return _write(b, 'f', f);
                        case "null":
            case "function": // Silently setting this to null
                return _write(b, 'n');
                        case "bool":
                return _write(b, 'b', obj ? "\x01" : "\x00");
                        case "blob":
                return _write(b, 'B', obj);
                        case "string":
                return _write(b, 's', obj);
                        case "table":
                        case "array":
                                local t = (typeof obj == "table") ? 't' : 'a';
                                _write(b, t, obj.len());
                                foreach ( k,v in obj ) {
                    _serialize(b, k);
                    _serialize(b, v);
                                }
                                return;
                        default:
                                throw ("Can't serialize " + typeof obj);
                                // server.log("Can't serialize " + typeof obj);
                }
        }
 
 
    function _write(b, type, payload = null) {
 
        // Calculate the lengths
        local payloadlen = 0;
        switch (type) {
            case 'n':
            case 'b':
                payloadlen = 0;
                break;
            case 'a':
            case 't':
                payloadlen = payload;
                break;
            default:
                payloadlen = payload.len();
        }
        
        // Update the blob
        b.writen(type, 'b');
        if (payloadlen > 0) {
            b.writen(payloadlen >> 8 & 0xFF, 'b');
            b.writen(payloadlen & 0xFF, 'b');
        }
        if (typeof payload == "string" || typeof payload == "blob") {
            foreach (ch in payload) {
                b.writen(ch, 'b');
            }
        }
    }
 
 
        // Deserialize a string into a variable 
        function deserialize (s) {
                // Read and check the header
        s.seek(0);
        local len = s.readn('b') << 8 | s.readn('b');
        local crc = s.readn('b');
        if (s.len() != len+3) throw "Expected exactly " + len + " bytes in this blob";
        // Check the CRC
        local _crc = CRC(s, 3);
        if (crc != _crc) throw format("CRC mismatch: 0x%02x != 0x%02x", crc, _crc);
        // Deserialise the rest
                return _deserialize(s, 3).val;
        }
    
        function _deserialize (s, p = 0) {
                for (local i = p; i < s.len(); i++) {
                        local t = s[i];
                        switch (t) {
                                case 'n': // Null
                                        return { val = null, len = 1 };
                                case 'i': // Integer
                                        local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                                        local val = s.readblob(len).tostring().tointeger();
                                        return { val = val, len = 3+len };
                                case 'f': // Float
                                        local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                                    local val = s.readblob(len).tostring().tofloat();
                                        return { val = val, len = 3+len };
                                case 'b': // Bool
                                        local val = s[i+1];
                                        return { val = (val == 1), len = 2 };
                                case 'B': // Blob 
                                        local len = s[i+1] << 8 | s[i+2];
                                        local val = blob(len);
                                        for (local j = 0; j < len; j++) {
                                                val[j] = s[i+3+j];
                                        }
                                        return { val = val, len = 3+len };
                                case 's': // String
                                        local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                                    local val = s.readblob(len).tostring();
                                        return { val = val, len = 3+len };
                                case 't': // Table
                                case 'a': // Array
                                        local len = 0;
                                        local nodes = s[i+1] << 8 | s[i+2];
                                        i += 3;
                                        local tab = null;
 
                                        if (t == 'a') {
                                                // server.log("Array with " + nodes + " nodes");
                                                tab = [];
                                        }
                                        if (t == 't') {
                                                // server.log("Table with " + nodes + " nodes");
                                                tab = {};
                                        }
 
                                        for (; nodes > 0; nodes--) {
 
                                                local k = _deserialize(s, i);
                                                // server.log("Key = '" + k.val + "' (" + k.len + ")");
                                                i += k.len;
                                                len += k.len;
 
                                                local v = _deserialize(s, i);
                                                // server.log("Val = '" + v.val + "' [" + (typeof v.val) + "] (" + v.len + ")");
                                                i += v.len;
                                                len += v.len;
 
                                                if (t == 'a') tab.push(v.val);
                                                else          tab[k.val] <- v.val;
                                        }
                                        return { val = tab, len = len+3 };
                                default:
                                        throw format("Unknown type: 0x%02x at %d", t, i);
                        }
                }
        }
 
 
        function CRC (data, offset = 0) {
                local LRC = 0x00;
                for (local i = offset; i < data.len(); i++) {
                        LRC = (LRC + data[i]) & 0xFF;
                }
                return ((LRC ^ 0xFF) + 1) & 0xFF;
        }
 
}

/* General Base Class for SX150X I/O Expander Family
 * http://www.semtech.com/images/datasheet/sx150x_789.pdf
 */
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
            server.error("I2C Read Failure. Device: "+_addr+" Register: "+register);
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

/* Class for the SX1505 8-channel GPIO Expander. */
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
    function reset(){
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
        writeReg(BANK_A.REGINTSRC,0xff);
    }
    
    function getIrq(){
        return (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
}

/* GPIO class for using GPIO pins on an I/O expander as if they were imp pins */
class ExpGPIO{
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    
    //Optional initial state (defaults to 0 just like the imp)
    function configure(mode, callback_initialstate = null) {
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if(callback_initialstate != null){
                _expander.setPin(_gpio, callback_initialstate);    
            }else{
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

/* I2C Display Module */
class st7036{
    _i2c  = null;
    _addr = null;
    
    constructor(i2c, addr = 0x78){
        _i2c  = i2c;
        _addr = addr;
        //This magical line came straight from the datasheet code example
        // 0x38 = 2-lines, Single Height, Instruction 00 = ??
        // 0x39 = 2-lines, Single Height, Instruction 01 = Bias Set
        // 0x14 = Bias Set = 1/4 Bias
        // 0x78 = 
        _i2c.write(_addr, format("%c%c%c%c%c%c%c%c%c%c", 0x00, 0x38, 0x39, 0x14, 0x78, 0x5E, 0x6D, 0x0C, 0x01, 0x06));
    }
    
    function write(str){
        _i2c.write(0x78, format("%c%s", 0x40,str));
    }
    
}

/* PCF8563 Real-Time Clock/Calendar
 * http://www.nxp.com/documents/data_sheet/PCF8563.pdf
 */
const CTRL_REG_1        = 0x00;
const CTRL_REG_2        = 0x01;
const VL_SEC_REG        = 0x02;
const MINS_REG          = 0x03;
const HOURS_REG         = 0x04;
const DAYS_REG          = 0x05;
const WKDAY_REG         = 0x06;
const CNTRY_MONTHS_REG  = 0x07;
const YEARS_REG         = 0x08;
const MINS_ALARM_REG    = 0x09;
const HOURS_ALARM_REG   = 0x0A;
const DAY_ALARM_REG     = 0x0B;
const WKDAY_ALARM_REG   = 0x0C;
const CLKOUT_CTRL_REG   = 0x0D;
const TIMER_CTRL_REG    = 0x0E;
const TIMER_REG         = 0x0F;
class pcf8563 {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr = 0xA2) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",_addr,register));
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register,data) {
        _i2c.write(_addr, format("%c%c",register,data));
    }
    
    /* The first bit of the VL_SEC_REG is a Voltage Low flag (VL)
     * If this flag is set, the internal voltage detector has detected a 
     * low-voltage event and the clock integrity is not guaranteed. 
     * The flag remains set until it is manually cleared.
     * This is provided because the RTC is often run on a secondary cell 
     * or supercap as a backup.
     */
    function clkGood() {
        if (0x80 & readReg(VL_SEC_REG)) {
            return 0;
        }
        return 1;
    }
    
    /* Clear the Voltage Low flag. */
    function clearVL() {
        local data = 0x7F & readReg(VL_SEC_REG);
        this.writeReg(VL_SEC_REG, data);
    }
    
    function sec() {
        local data = readReg(VL_SEC_REG)
        return (((data & 0x70) >> 4) * 10 + (data & 0x0F));
    }
    
    function min() {
        local data = readReg(MINS_REG);
        return (((data & 0x70) >> 4) * 10 + (data & 0x0F));
    }
    
    function hour() {
        local data = readReg(HOURS_REG);
        return (((data & 0x30) >> 4) * 10 + (data & 0x0F));
    }
    
    function day() {
        local data = readReg(DAYS_REG);
        return (((data & 0x30) >> 4) * 10 + (data & 0x0F));
    }
    
    function weekday() {
        return (readReg(WKDAY_REG) & 0x07);
    }
    
    function month() {
        local data = readReg(CNTRY_MONTHS_REG);
        return (((data & 0x10) >> 4) * 10 + (data & 0x0F));
    }
    
    function year() {
        local data = readReg(YEARS_REG);
        return (((data & 0xF0) >> 4) * 10 + (data & 0x0F));
    }
    
    /* Return a date object based on the RTC's current time */
    function rtcdate() {
        local now = {};
        now.year    <- this.year();
        now.month   <- this.month();
        now.wday    <- this.weekday();
        now.day     <- this.day();
        now.hour    <- this.hour();
        now.min     <- this.min()
        now.sec     <- this.sec();
        return now;
    }
    
    /* 
     * Set the RTC to match the imp's RTC. 
     * Note that if the imp's RTC is off, this will not correct the imp. You 
     * will simply be left to two clocks that don't tell the correct time.
     * The imp's RTC is re-synced on server connect, so syncing right after a 
     * server connect is recommended.
     */
    function sync() {
        local now = date(time(),'u');
        local secStr = format("%02d",now.sec);
        local minStr = format("%02d",now.min);
        local hourStr = format("%02d",now.hour);
        local dayStr = format("%02d",now.day);
        local monStr = format("%02d",now.month+1);
        local yearStr = format("%02d",now.year).slice(2,4);
        local wkdayStr = format("%d",now.wday);
        
        this.writeReg(VL_SEC_REG,       (((secStr[0] & 0x07) << 4) + (secStr[1] & 0x0F)));
        this.writeReg(MINS_REG,         (((minStr[0] & 0x07) << 4) + (minStr[1] & 0x0F)));
        this.writeReg(HOURS_REG,        (((hourStr[0] & 0x03) << 4) + (hourStr[1] & 0x0F)));
        this.writeReg(DAYS_REG,         (((dayStr[0] & 0x03) << 4) + (dayStr[1] & 0x0F)));
        this.writeReg(CNTRY_MONTHS_REG, (((monStr[0] & 0x01) << 4) + (monStr[1] & 0x0F)));
        this.writeReg(YEARS_REG,        (((yearStr[0] & 0x0F) << 4) + (yearStr[1] & 0x0F)));
        this.writeReg(WKDAY_REG,        (secStr[0] & 0x07));
    }
}

/* I2C EEPROM
 * CAT24C Family
 * http://www.onsemi.com/pub_link/Collateral/CAT24C02-D.PDF
 */
const PAGE_LEN = 16;        // page length in bytes
const WRITE_TIME = 0.005;   // max write cycle time in seconds
class cat24c {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr=0xA0) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function read(len, offset) {
        // "Selective Read" by preceding the read with a "dummy write" of just the offset (no data)
        _i2c.write(_addr, format("%c",offset));
        
        local data = _i2c.read(_addr, "", len);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",_addr,offset));
            return -1;
        }
        return data;
    }
    
    function write(data, offset) {
        local dataIndex = 0;
        if (typeof data == "integer") {data = format("%c",data);}
        while(dataIndex < data.len()) {
            // chunk of data we will send per I2C write. Can be up to 1 page long.
            local chunk = format("%c",offset);
            // check if this is the first page, and if we'll hit the boundary
            local leftOnPage = PAGE_LEN - (offset % PAGE_LEN);
            // set the chunk length equal to the space left on the page
            local chunkLen = leftOnPage;
            // check if this is the last page we need to write, and adjust the chunk size if it is
            if ((data.len() - dataIndex) < leftOnPage) { chunkLen = (data.len() - dataIndex); }
            // now fill the chunk with a slice of data and write it
            for (local chunkIndex = 0; chunkIndex < chunkLen; chunkIndex++) {
                chunk += format("%c",data[dataIndex++]);  
            }
            _i2c.write(_addr, chunk);
            offset += chunkLen;
            // write takes a finite (and rather long) amount of time. Subsequent writes
            // before the write cycle is completed fail silently. You must wait.
            imp.sleep(WRITE_TIME);
        }
    }
}

/* Log wrapper to redirect log messages if we're disconnected.
 * If this wrapper detects that we do not have a display object,
 * it will return silently.
 */
function log(msg) {
    // test if we're connected to wifi
    if (server.isconnected()) {
        server.log(msg);
    // if we're not on wifi, test if we have a display object instantiated
    } else if ("disp" in this) {
        disp.write(msg);
    // if we have no way to log, give up
    } else {
        return;
    }
}

/* Class for a status LED. Different patterns can be set for different states.
 * Constructor takes an pre-configured LED pin.
 *
 * As shown, statusLed.set takes a single argument: any of the elements of the
 * STATUS enum below.
 *
 * STATUS.CONNECTED         -> solid light
 * STATUS.DISCONNECTED      -> blinking light
 * STATUS.ERROR             -> light off
 */
const BLINK_INTERVAL = 0.5; // blink interval for status LED in seconds
enum STATUS {
    CONNECTED,
    DISCONNECTED,
    ERROR
};
class statusLed {
    led = null;
    blinkTimerHandle = null; // handle for blinking status wakeup timer

    constructor(_led) {
        this.led = _led;
    }

    function toggle() {
        blinkTimerHandle = imp.wakeup(BLINK_INTERVAL, toggle.bindenv(this));
        if (this.led.read() > 0) {
            this.led.write(0.0);
        } else {
            this.led.write(1.0)
        }
    }

    function set(status) {
        // cancel any blink timer currently running
        if (blinkTimerHandle) {imp.cancelwakeup(blinkTimerHandle);}
            
        if (status == STATUS.CONNECTED)         {this.led.write(1.0);}
        else if (status == STATUS.DISCONNECTED) {
            blinkTimerHandle = imp.wakeup(BLINK_INTERVAL, toggle.bindenv(this));}
        else if (status == STATUS.ERROR)      {led.write(0.0);}
    }
}

/* Class for a sprinkler schedule. 
 * Constructor takes pre-instantiated:
 *      - spi interface, sr_load pin, and sr_output_en_l pin for shift register
 *      - rtc: a real-time clock object; the pcf8563
 *      - eeprom: an eeprom object; the cat24c
 *      - the serializer class must be included to use this class 
 */ 
class waterSchedule {    
    spi             = null;     // SPI interface for shift register
    sr_load         = null;     // load Pin for shift register
    sr_output_en_l  = null;     // output enable for shift register
    rtc             = null;
    eeprom          = null;
    led             = null;     // status LED object
    channelStates   = null;     // Byte to store current state of sprinkler channels
    gmtoffset       = null;     // GMT offset in hours (positive or negative)
    schedule        = {};
    scheduledEvents = [];       // array of timer IDs for scheduled watering events.
    refreshtime     = "00:00"   // time of day to re-schedule watering events

    constructor(_spi, _sr_load, _sr_output_en_l, _eeprom, _rtc, _led) {
        this.spi            = _spi;
        this.sr_load        = _sr_load;
        this.sr_output_en_l = _sr_output_en_l;
        this.rtc            = _rtc;
        this.eeprom         = _eeprom;
        this.led            = _led;
    }

    /* Set Sprinkler Channel States */
    function setChannel(channel, state) {
        if ((channel < 0) || channel > 8) return;
        if (state) {
            this.channelStates = this.channelStates | (0x01 << channel);
        } else {
            this.channelStates = this.channelStates & ~(0x01 << channel);
        }
        
        // dispable the output and write the data out to the shift register
        this.sr_output_en_l.write(1);
        this.spi.write(format("%c",this.channelStates));
        
        // pulse the SRCLK line to load the data into the output stage
        this.sr_load.write(0);
        this.sr_load.write(1);
        this.sr_load.write(0);
        
        // enable the output
        this.sr_output_en_l.write(0);
    }

    function stopAllChannels() {
        this.channelStates = 0x00;
        
        // dispable the output and write the data out to the shift register
        this.sr_output_en_l.write(1);
        this.spi.write(format("%c",channelStates));
        
        // pulse the SRCLK line to load the data into the output stage
        this.sr_load.write(0);
        this.sr_load.write(1);
        this.sr_load.write(0);
        
        // enable the output
        this.sr_output_en_l.write(0);   
    }

    function halt() {
        this.stopAllChannels();
        this.cancel();
    }

    /* Calculate seconds from now until a given time.
     * Input: 
     *      targetStr - a 24-hour hours/minutes string, e.g. "12:34"
     * Return:
     *      seconds as an integer until the target time will next occur
     */
    function secondsTil(targetStr) {
        local data = split(targetStr,":");
        local target = { hour = data[0].tointeger(), min = data[1].tointeger() };
        target.hour -= this.gmtoffset;
        if (target.hour > 23) {
            target.hour -= 24;
        }

        local now = null;
        if (server.isconnected()) {
            now = date(time(),'u');
        } else {
            now = this.rtc.rtcdate();
        }
        
        if ((target.hour < now.hour) || (target.hour == now.hour && target.min < now.min)) {
            target.hour += 24;
        }
        
        local result = 0;
        result += (target.hour - now.hour) * 3600;
        result += (target.min - now.min) * 60;
        return result;
    }

    /* Load the schedule table from the EEPROM */
    function load() {
        // the length of the serialized object is stored in the first 2 bytes of the eeprom
        local lenstr = this.eeprom.read(2,0);
        local len = (lenstr[1] << 8) + lenstr[0];
        // the CRC for the stored table is in the third byte
        log("Loaded "+len+" bytes, deserializing...");
        local crc = this.eeprom.read(1,2)[0];
        local serSchedule = this.eeprom.read(len,3);
        local serBlob = blob(serSchedule.len());
        serBlob.writestring(serSchedule);
        if (serializer.CRC(serBlob) != crc) { 
            log("Error: CRC Error while loading schedule from EEPROM");
            return; 
        } else {
            local result = serializer.deserialize(serBlob);
            this.gmtoffset = result.gmtoffset;
            this.schedule = result.schedule;
        }
    }

    /* Serialize, CRC, and Save the schedule table to the EEPROM 
     * The TZ offset is also saved as a side effect.
     */
    function save() {
        local data = {"gmtoffset": this.gmtoffset, "schedule": this.schedule};
        local serSchedule = serializer.serialize(data);
        // write length of serialized object to first 2 bytes
        this.eeprom.write(serSchedule.len() & 0xFF,0);
        this.eeprom.write(serSchedule.len() & 0xFF00,1);
        // write the CRC of the serialized object to the third byte
        this.eeprom.write(serializer.CRC(serSchedule),2);
        this.eeprom.write(serSchedule,3);
    }

    function set(newSchedule) {
        this.schedule = newSchedule;
        this.save();
        this.run();
    }

    /* Walk the list of scheduled events and cancel them all */
    function cancel() {
        while (this.scheduledEvents.len() > 0) {
            imp.cancelwakeup(this.scheduledEvents.pop());
        }
    }

    /* Schedule On and Off events for each watering in the schedule table*/
    function run() {
        // if load() returned null, we're offline with no schedule.
        // return and wait for connection to come up
        if (this.schedule == null) {
            log("Error: No Schedule.");
            led.set(STATUS.ERROR);
            return;
        }
        
        // stop watering andcancel any existing scheduled events before scheduling
        this.halt();
         
        foreach(waterevent in this.schedule) {
            
            /* the list of channels must be local so that bindenv will hold it */
            local mychannels = waterevent.channels;
            
            /* SCHEDULE WATERING STARTS -----------------------------------------*/
            /* scheduled callback handles are added to the scheduledEvents array so
             * they can be later cancelled. */
            local handle = imp.wakeup(secondsTil(waterevent.onat), function() {
                local channelList = "";
                foreach(channel in mychannels) {
                    channelList += format("%d ",channel);
                    setChannel(channel, 1);
                }
                log(format("Starting Scheduled Watering, Channels: %s", channelList));
            /* Bindenv "binds" this callback to the current environment, 
             * so the channel array will be remembered */
            }.bindenv(this));
            this.scheduledEvents.push(handle);

            /* SCHEDULE WATERING STOPS ------------------------------------------*/
            handle = imp.wakeup(secondsTil(waterevent.offat), function() {
                local channelList = "";
                foreach(channel in mychannels) {
                    channelList += format("%d ",channel);
                    setChannel(channel, 0);
                }
                log(format("Ending Scheduled Watering, Channels: %s", channelList));
            }.bindenv(this));
            this.scheduledEvents.push(handle);
            
            /* if we're in the middle of a watering event when the schedule is received,
             * start immediately. */
            if (secondsTil(waterevent.offat) < secondsTil(waterevent.onat)) {
                foreach(channel in waterevent.channels) {
                    setChannel(channel, 1);
                }
            }
        }
        
        /* Schedule this function (this.run) to re-run at midnight nightly to refresh the schedule */
        local refreshHandle = imp.wakeup(secondsTil(this.refreshtime)+60, function() { this.run(); }.bindenv(this));
        this.scheduledEvents.push(refreshHandle);
        
        foreach(waterevent in this.schedule) {
           local channelList = "";
           foreach(channel in waterevent.channels) {
               channelList += format("%d ",channel);
           }
           log(format("On: %s, Off: %s, Channels: %s",waterevent.onat,
                waterevent.offat, channelList));
        }
    }

    /* Grab the schedule from the agent or the on-board EEPROM, depending on 
     * Connection status. If the schedule is received from the agent, it will be
     * saved to the EEPROM for future use.
     *
     * If we're connected to the agent, we first request the GMT offset so that 
     * we have it before we attempt to set the schedule. A schedule request will
     * be sent to the agent when the GMT offset is received.
     * 
     * If we're offline, the GMT offset will be stored in the EEPROM with the schedule.
     */
    function fetch() {
        if (server.isconnected()) {
            // we'll call for the schedule in a moment, as soon as we have this offset
            agent.send("getGMToffset",0);
        } else {
            // load the schedule from the eeprom
            // this will load the GMT offset as a side effect
            this.load();
            this.run();
        }
    }
}

/* AGENT EVENT HANDLERS ======================================================*/
 
agent.on("setGMToffset", function(offset) {
    mySchedule.gmtoffset = offset;
    // now that we have the TZ offset, we can handle a new schedule, so ask for it.
    agent.send("getSchedule",0);
}); 
 
agent.on("newSchedule", function(schedule) {
    log("New Schedule Received.");
    // set the new schedule, save it to the EEPROM, and start running it
    mySchedule.set(schedule)
});

agent.on("halt", function(val) {
    waterSchedule.halt();
});

/* RUNTIME BEGINS HERE =======================================================*/ 

//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);

//Initialize IO expanders`
ioexp_int_l <- hardware.pinB; 
disp_ioexp  <- SX1505(i2c,0x42);  //Display Board 8-Channel IO expander

//Imp Pin configuration
beeper_pin          <- hardware.pin1;
disp_reset_l_pin    <- hardware.pin2;
sr_output_en_l_pin  <- hardware.pin6;
sr_load_pin         <- hardware.pinA;
led_pin             <- hardware.pinC;
rain_sns_l_pin      <- hardware.pinD;
spi_ifc             <- hardware.spi257;

beeper_pin.configure(PWM_OUT, 1.0/1000, 0.0);
led_pin.configure(PWM_OUT, 1.0/1000, 0.0);

led <- statusLed(led_pin);

/* Rain Sensor Handler */
function rainStateChanged() {
    server.log("Rain Sensor: "+rain_sns_l.read());
}
rain_sns_l_pin.configure(DIGITAL_IN_PULLUP, rainStateChanged);

spi_ifc.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_HIGH, 4000);
sr_output_en_l_pin.configure(DIGITAL_OUT);
sr_output_en_l_pin.write(1);
sr_load_pin.configure(DIGITAL_OUT);
sr_load_pin.write(0);

// Initialize I2C Devices
// Configure the RTC
rtc <-  pcf8563(i2c);

// Configure the EEPROM
eeprom <- cat24c(i2c);

// instantiate a water scheduler with our shift register, RTC, and EEPROM
mySchedule <- waterSchedule(spi_ifc, sr_load_pin, sr_output_en_l_pin, eeprom, rtc, led);

/*
//Configure the Display
disp <- st7036(i2c);

//Configure IOs on the Display Expander
btn_up     <- ExpGPIO(disp_ioexp, 0).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Up:"+this.read())});
btn_left   <- ExpGPIO(disp_ioexp, 1).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Left:"+this.read())});
btn_enter  <- ExpGPIO(disp_ioexp, 2).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Enter:"+this.read())});
btn_right  <- ExpGPIO(disp_ioexp, 3).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Right:"+this.read())});
btn_down   <- ExpGPIO(disp_ioexp, 4).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Down:"+this.read())});
disp_rst_l <- ExpGPIO(disp_ioexp, 5).configure(DIGITAL_OUT, 1);
*/

//Initialize the interrupt Pin
ioexp_int_l.configure(DIGITAL_IN_PULLUP, function(){ disp_ioexp.callback(); });

/* SCHEDULE INITILIZATION LOGIC STARTS HERE ==================================*/
log("Software Version: "+imp.getsoftwareversion());
log("Free Memory:"+imp.getmemoryfree());
imp.enableblinkup(true);

// Clear the sprinkler channels
mySchedule.halt();

// Check the RTC
local now = date();
log(format("RTC Clock Integrity: %x",rtc.clkGood()));
log(format("Current UTC Time %02d:%02d:%02d, %02d/%02d/%02d",now.hour,
        now.min,now.sec,now.month+1,now.day,now.year));
log(format("RTC Set to %02d:%02d:%02d, %02d/%02d/%02d",rtc.hour(),
    rtc.min(),rtc.sec(),rtc.month(),rtc.day(),rtc.year()));
    
// Check our connection status and start trying to set up the watering schedule.

// If this is a cold boot or a new-squirrel boot, we'll already have WiFi up,
// as that's how the squirrel got here. This also means our send timeout policy 
// is set to SUSPEND_ON_ERROR (which means we'll automatically attempt connection 
// on WiFi-required actions like server.log().) If the connection drops, we need 
// to set the the send timeout policy to RETURN_ON_ERROR (manual connect) 
// immediately so we can keep doing our plant-watering job. 
server.onunexpecteddisconnect(function(err) {
    led.set(STATUS.DISCONNECTED);
    server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, WIFI_TIMEOUT);
    // this is also a good time to set up some reconnection attempts
    imp.wakeup((60*RECONNECT_PERIOD), function() {
        imp.wakeup((60*RECONNECT_PERIOD), this);
        server.connect(function() {
            led.set(STATUS.CONNECTED);
            rtc.sync();
            mySchedule.fetch();
        }, WIFI_TIMEOUT);
    });
});

// if we're connected now, sync up with the agent
if (server.isconnected()) {
    led.set(STATUS.CONNECTED);
    // we update the imp's internal RTC when we connect
    rtc.sync();
} else {
    led.set(STATUS.DISCONNECTED);
    server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, WIFI_TIMEOUT);
}

// get the watering schedule and start working.
mySchedule.fetch();
