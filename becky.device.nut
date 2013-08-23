// outlet controller and power sensor
// http://www.analog.com/en/analog-to-digital-converters/energy-measurement/ade7953/products/product.html
 
local function read(i2c, addr) {
    // registers 0-ff are 8 bit, 100-1ff are 16 bit, 200-2ff are 24 bit and
    // 300-3ff are 32 bit
    local res = i2c.read(0x70, format("%c%c", addr>>8, addr&0xff), 1+(addr>>8));
    local resv = 0;
 
    if (res != null) {
        foreach (b in res) resv = (resv<<8) + b;
        return resv;
    }
 
    return 0;
}
 
// Signed read
local function reads(i2c, addr) {
    local r = read(i2c, addr);
    local length = 1 + (addr>>8);
    local mask = 1<<(length<<3);
    if (r > (mask>>1)) return r-mask;
    return r;
}
 
local function write(i2c, addr, data) {
    // registers 0-ff are 8 bit, 100-1ff are 16 bit, 200-2ff are 24 bit and 
    // 300-3ff are 32 bit
    local length = 1 + (addr>>8);
    i2c.write(0x70, format("%c%c", addr>>8, addr&0xff) + data);
}
 
// Pin1 = relay off (drive high for 100ms)
// Pin5 = relay on (drive high for 100ms)
// Pin7 = 5v supply monitor (divided by two)
// Pin8/9 = I2C
 
relay0 <- hardware.pin1;
relay1 <- hardware.pin5;
i2c <- hardware.i2c89;
 
relay0.configure(DIGITAL_OUT);
relay1.configure(DIGITAL_OUT);
i2c.configure(CLOCK_SPEED_400_KHZ);
 
// configure current gain to 1 (500mV swing max)
write(i2c, 0x008, "\x01");
 
// configure voltage gain to 1 (500mV swing max)
write(i2c, 0x007, "\x01");
 
// configure active energy line accumulation mode on current channel A, clear on read
write(i2c, 0x004, "\x41");
 
local function pulse(r) {
    r.write(1);
    imp.sleep(0.1);
    r.write(0);
}
 
// We don't know if we were on or off
switchstate <- -1;
watts <- 0.0;
 
// Output: power being used
power <- OutputPort("Power Used");
 
// Input: relay control
class Control extends InputPort {
    name = "On/Off"
    function set(v) {
        if (v != switchstate) pulse(v==0?relay0:relay1);
        switchstate = v;
        sendstate();
    }
}
 
function sendstate() {
    local s=format("%6.1f W", watts);
    if (switchstate == 1) {
        power.set(watts);
    } else {
        s="off";
        power.set(0);
    }
 
    server.show(s)
}
 
function reporter() {
    imp.wakeup(2.0, reporter);
    local awatt = reads(i2c, 0x0212);
 
    // Debug if we want more detail
    //local cyclecount = read(i2c, 0x010e);
    //local vrms = read(i2c, 0x21c);
    //server.log(format("vrms = %d  cyclecount = %d  awatt=%d", vrms, cyclecount, awatt));
 
    // No negative readings
    if (awatt < 0.0) awatt = 0.0;
 
    // Scaling
    watts = (286.0 * awatt) / 236000.0;
    watts = math.floor(watts * 10 + 0.5) / 10.0;
 
    // If we just rebooted and don't know if we're on or off, work it out from power draw
    if (switchstate == -1) {
        switchstate = (watts > 0.5)?1:0;
    }
 
    sendstate();
}
 
// Appear on planner
imp.configure("Plugtop", [Control()], [power]);
 
// Start reporting
reporter();
