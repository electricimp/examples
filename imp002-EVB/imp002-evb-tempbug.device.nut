/*  

Notes on limitations of this design:
- If the wifi is running but the agent is offline then we will send the readings 
  and drop the data. The better way to do this is to send the data and wait for
  instructions from the agent to delete the data, and only deleting data that is
  confirmed to be received at the agent.
- Non-volatile (nv) RAM on the imp will not survive through power outages and is 
  limited to a total of 4kb of serialised data. A "real" implementation of the 
  Temp Bug would be better served by external non-volatile flash storage.


--------[ Pin mux ]--------
1 - Wake (button1)
2 - LED (Red)
5 - 
6 - 
7 - 
8 - I2C clock (temperature)
9 - I2C data
A - 
B - 
C - 
D - Button 1
E - 

*/

wake <- hardware.pin1;
ledR <- hardware.pin2;
hall <- hardware.pinA;
btn2 <- hardware.pinB;
beep <- hardware.pinC;
btn1 <- hardware.pinD;
spi  <- hardware.spi257;
uart <- hardware.uart6E;
i2c  <- hardware.i2c89;


// -----------------------------------------------------------------------------
class TMP1x2 {
    
    // Register addresses
    static TEMP_REG         = 0x00;
    static CONF_REG         = 0x01;

    // ADC resolution in degrees C
    static DEG_PER_COUNT    = 0.0625;

    // i2c bus 
    _i2c    = null;
    // i2c address
    _addr   = null;

    /*
     * Class Constructor. Takes two arguments:
     *      i2c:                    Pre-configured I2C Bus
     *      addr:                   I2C Slave Address for device. 8-bit address.
     */
    constructor(i2c, addr) {
        _addr   = addr;
        _i2c    = i2c;
    }
    
    // Configures the sensor and requests it start converting
    function startConversion() {
        local _conf = _i2c.read(_addr, format("%c",CONF_REG), 2);
        if (_conf == null) throw "TMP1x2 configuration failed.";
        
        local conf = blob(2);
        conf[0] = _conf[0] | 0x80 | 0x01; // Start conversion and turn on shutdown mode
        conf[1] = _conf[1] & 0xEF;        // Turn off extended mode
        _i2c.write(_addr, format("%c%c%c", CONF_REG, conf[0], conf[1]));
        
    }

    // Read the temperature from the TMP1x2 Sensor and returns it in celsius
    function readTempC() {
        // Start the conversion
        startConversion();
        
        // Check if the conversion is completed
        local timeout = 30; // ms
        local start = hardware.millis();
        while(true) {
            local _conf = _i2c.read(_addr,format("%c", CONF_REG), 2);
            if (_conf[1] & 0x80) {
                // The conversion is finished
                break;
            } else if ((hardware.millis() - start) > timeout) {
                throw "TMP1x2 timed out waiting for conversion";
            }
        } 
        
        // Now that the conversion is complete, check the reading
        local result = _i2c.read(_addr, format("%c", TEMP_REG), 2);
        if (result == null) throw "TMP1x2 failed to return a temperature reading";

        // And convert to a floating point number
        local mask = 0x0FFF;
        local sign_mask = 0x0800;
        local offset = 4;
        local temp = (result[0] << 8) + result[1];
        temp = (temp >> offset) & mask;
        if (temp & sign_mask) {
            // Take the two's compliment for negative numbers
            temp = ~(temp & mask) + 1;
            temp = -1.0 * (temp & mask);
        }

        return temp * DEG_PER_COUNT;
    }


    // Read the temperature from the TMP1x2 Sensor and converts to fareinheit
    function readTempF() {
        return (readTempC() * 9.0 / 5.0 + 32.0);
    }


}


// -----------------------------------------------------------------------------
class Connection {

    static CONNECTION_TIMEOUT = 30;
    static CHECK_TIMEOUT = 5;
    static MAX_LOGS = 100;
    
    connected = null;
    connecting = false;
    stayconnected = true;
    reason = null;
    callbacks = null;
    blinkup_timer = null;
    logs = null;
    
    // .........................................................................
    constructor(_do_connect = true) {
        callbacks = {};
        logs = [];
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, CONNECTION_TIMEOUT);
        connected = server.isconnected();
        imp.wakeup(CHECK_TIMEOUT, _check.bindenv(this));
        
        if (_do_connect && !connected) imp.wakeup(0, connect.bindenv(this));
        else if (connected) imp.wakeup(0, _reconnect.bindenv(this));
    }
    
    
    // .........................................................................
    function _check() {
        imp.wakeup(CHECK_TIMEOUT, _check.bindenv(this));
        if (!server.isconnected() && !connecting && stayconnected) {
            // We aren't connected or connecting, so we should try
            _disconnected(NOT_CONNECTED, true);
        }
    }
    

    // .........................................................................
    function _disconnected(_reason, _do_reconnect = false) {
        local fireevent = connected;
        connected = false;
        connecting = false;
        reason = _reason;
        if (fireevent && "disconnected" in callbacks) callbacks.disconnected();
        if (_do_reconnect) connect();
    }
    
    // .........................................................................
    function _reconnect(_state = null) {
        if (_state == SERVER_CONNECTED || _state == null) {
            connected = true;
            connecting = false;
            
            // Dump the logs
            while (logs.len() > 0) {
                local logo = logs[0];
                logs.remove(0);
                local d = date(logo.ts);
                local msg = format("%04d-%02d-%02d %02d:%02d:%02d UTC %s", d.year, d.month+1, d.day, d.hour, d.min, d.sec, logo.msg);
                if (logo.err) server.error(msg);
                else          server.log(msg);
            }
            
            if ("connected" in callbacks) callbacks.connected(SERVER_CONNECTED);
        } else {
            connected = false;
            connecting = false;
            if ("disconnected" in callbacks) callbacks.disconnected();
            connect();
        }
    }
    
    
    // .........................................................................
    function connect(withblinkup = true) {
        stayconnected = true;
        if (!connected && !connecting) {
            server.connect(_reconnect.bindenv(this), CONNECTION_TIMEOUT);
            connecting = true;
        }
        
        if (withblinkup) {
            // Enable BlinkUp for 60 seconds
            imp.enableblinkup(true);
            if (blinkup_timer) imp.cancelwakeup(blinkup_timer);
            blinkup_timer = imp.wakeup(60, function() {
                blinkup_timer = null;
                imp.enableblinkup(false);
            }.bindenv(this))
            
        }
    }
    
    // .........................................................................
    function disconnect() {
        stayconnected = false;
        server.disconnect();
        _disconnected(NOT_CONNECTED, false);
    }

    // .........................................................................
    function isconnected() {
        return connected == true;
    }

    // .........................................................................
    function ondisconnect(_disconnected = null) {
        if (_disconnected == null) delete callbacks["disconnected"];
        else callbacks["disconnected"] <- _disconnected;
    }

    // .........................................................................
    function onconnect(_connected = null) {
        if (_connected == null) delete callbacks["connected"];
        else callbacks["connected"] <- _connected;
    }

    // .........................................................................
    function log(msg, err=false) {
        if (server.isconnected()) server.log(msg);
        else logs.push({msg=msg, err=err, ts=time()})
        if (logs.len() > MAX_LOGS) logs.remove(0);
    }

    // .........................................................................
    function error(msg) {
        log(msg, true);
    }

}


// -----------------------------------------------------------------------------
function send_readings() {
    
    // Send the data to the agent
    if (agent.send("readings", nv.readings) == 0) {
        nv.readings = [];
    }
}


// -----------------------------------------------------------------------------
function sleep() {

    // Cap the number of readins by deleting the oldest
    while (nv.readings.len() > MAX_SAMPLES) nv.readings.remove(0);

    // Shut down everything and go back to sleep
    ledR.configure(DIGITAL_OUT, 0);
    if (server.isconnected()) {
        imp.onidle(function() {
            server.sleepfor(READING_INTERVAL);
        })
    } else {
        imp.deepsleepfor(READING_INTERVAL);
    }
}

// -----------------------------------------------------------------------------
// Configure the imp and all the devices
imp.setpowersave(true);
imp.enableblinkup(false);
ledR.configure(PWM_OUT, 0.20, 0.01); // Turn on to indicate activity
wake.configure(DIGITAL_IN_WAKEUP);
i2c.configure(CLOCK_SPEED_400_KHZ);

READING_INTERVAL <- 60; // Read a new sample every [READING_INTERVAL] seconds.
READING_SAMPLES  <- 60; // When there are [READING_SAMPLES] come online and dump the results.
MAX_SAMPLES     <- 140; // This is roughly how many readings we can store in 4k of nvram.

// -----------------------------------------------------------------------------
// Setup the basic memory and temperature sensor
if (!("nv" in getroottable())) nv <- { "readings": [], next_connect = time() };
temp <- TMP1x2(i2c, 0x90);

// Take a reading as we always want to do this
nv.readings.push({"t": temp.readTempC(), "s": time()});

// -----------------------------------------------------------------------------
if (hardware.wakereason() == WAKEREASON_TIMER && (time() < nv.next_connect || nv.readings.len() < READING_SAMPLES)) {
    
    // After a timer, go immediately back to sleep
    sleep();

} else {

    // Make sure we don't come online again for another cycle
    nv.next_connect = time() + (READING_INTERVAL * READING_SAMPLES);

    // Now forward the results to the server
    local cm = Connection();
    
    // On connect, send readings and shutdown
    cm.onconnect(function(reason=null) {
        imp.enableblinkup(true);
        send_readings();
        if (hardware.wakereason() == WAKEREASON_PIN || 
            hardware.wakereason() == WAKEREASON_POWER_ON || 
            hardware.wakereason() == WAKEREASON_NEW_SQUIRREL) {
                
            // The button was pressed to wake up the imp. Stay online for a while.
            imp.wakeup(30, sleep);
            
            // Capture the button while we are awake and send the imp to sleep if pressed
            btn1.configure(DIGITAL_IN, function() {
                imp.sleep(0.02);
                if (btn1.read() == 0) sleep();
            })
        } else {
            // Go back to sleep
            sleep();
        }
    });
    
    // If connection fails, just go to sleep
    cm.ondisconnect(function(reason=null) {
        sleep();
    });
}


