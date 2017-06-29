// Power Efficient Refrigerator Monitor Device Code
// --------------------------------------------------------

// SENSOR LIBRARIES
// --------------------------------------------------------
// Libraries must be required before all other code

// Accelerometer Library
#require "LIS3DH.class.nut:1.3.0"
// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.0.0"

// Updated beta version of accelerometer - need for click interrupt
{ // LIS3DH Constants
    // Registers
    const LIS3DH_TEMP_CFG_REG  = 0x1F;
    const LIS3DH_CTRL_REG1     = 0x20;
    const LIS3DH_CTRL_REG2     = 0x21;
    const LIS3DH_CTRL_REG3     = 0x22;
    const LIS3DH_CTRL_REG4     = 0x23;
    const LIS3DH_CTRL_REG5     = 0x24;
    const LIS3DH_CTRL_REG6     = 0x25;
    const LIS3DH_OUT_X_L_INCR  = 0xA8;
    const LIS3DH_OUT_X_L       = 0x28;
    const LIS3DH_OUT_X_H       = 0x29;
    const LIS3DH_OUT_Y_L       = 0x2A;
    const LIS3DH_OUT_Y_H       = 0x2B;
    const LIS3DH_OUT_Z_L       = 0x2C;
    const LIS3DH_OUT_Z_H       = 0x2D;
    const LIS3DH_FIFO_CTRL_REG = 0x2E;
    const LIS3DH_FIFO_SRC_REG  = 0x2F;
    const LIS3DH_INT1_CFG      = 0x30;
    const LIS3DH_INT1_SRC      = 0x31;
    const LIS3DH_INT1_THS      = 0x32;
    const LIS3DH_INT1_DURATION = 0x33;
    const LIS3DH_CLICK_CFG     = 0x38;
    const LIS3DH_CLICK_SRC     = 0x39;
    const LIS3DH_CLICK_THS     = 0x3A;
    const LIS3DH_TIME_LIMIT    = 0x3B;
    const LIS3DH_TIME_LATENCY  = 0x3C;
    const LIS3DH_TIME_WINDOW   = 0x3D;
    const LIS3DH_WHO_AM_I      = 0x0F;
        

    // Bitfield values
    const LIS3DH_X_LOW         = 0x01;
    const LIS3DH_X_HIGH        = 0x02;
    const LIS3DH_Y_LOW         = 0x04;
    const LIS3DH_Y_HIGH        = 0x08;
    const LIS3DH_Z_LOW         = 0x10;
    const LIS3DH_Z_HIGH        = 0x20;
    const LIS3DH_SIX_D         = 0x40;
    const LIS3DH_AOI           = 0x80;

    // High Pass Filter values
    const LIS3DH_HPF_DISABLED               = 0x00;
    const LIS3DH_HPF_AOI_INT1               = 0x01;
    const LIS3DH_HPF_AOI_INT2               = 0x02;
    const LIS3DH_HPF_CLICK                  = 0x04;
    const LIS3DH_HPF_FDS                    = 0x08;

    const LIS3DH_HPF_CUTOFF1                = 0x00;
    const LIS3DH_HPF_CUTOFF2                = 0x10;
    const LIS3DH_HPF_CUTOFF3                = 0x20;
    const LIS3DH_HPF_CUTOFF4                = 0x30;

    const LIS3DH_HPF_DEFAULT_MODE           = 0x00;
    const LIS3DH_HPF_REFERENCE_SIGNAL       = 0x40;
    const LIS3DH_HPF_NORMAL_MODE            = 0x80;
    const LIS3DH_HPF_AUTORESET_ON_INTERRUPT = 0xC0;

    const LIS3DH_FIFO_BYPASS_MODE           = 0x00;
    const LIS3DH_FIFO_FIFO_MODE             = 0x40;
    const LIS3DH_FIFO_STREAM_MODE           = 0x80;
    const LIS3DH_FIFO_STREAM_TO_FIFO_MODE   = 0xC0;

    // Click Detection values
    const LIS3DH_SINGLE_CLICK  = 0x15;
    const LIS3DH_DOUBLE_CLICK  = 0x2A;
}

class LIS3DH {
    static VERSION = "2.0.0";

    // I2C information
    _i2c = null;
    _addr = null;

    // The full-scale range (+/- _range G)
    _range = null;

    constructor(i2c, addr = 0x30) {
        _i2c = i2c;
        _addr = addr;

        // Read the range + set _range property
        getRange();
    }


    // set default values for registers, read the current range and set _range
    // (resets to state when first powered on)
    function init() {
        // Set default values for registers
        _setReg(LIS3DH_CTRL_REG1, 0x07);
        _setReg(LIS3DH_CTRL_REG2, 0x00);
        _setReg(LIS3DH_CTRL_REG3, 0x00);
        _setReg(LIS3DH_CTRL_REG4, 0x00);
        _setReg(LIS3DH_CTRL_REG5, 0x00);
        _setReg(LIS3DH_CTRL_REG6, 0x00);
        _setReg(LIS3DH_INT1_CFG, 0x00);
        _setReg(LIS3DH_INT1_THS, 0x00);
        _setReg(LIS3DH_INT1_DURATION, 0x00);
        _setReg(LIS3DH_CLICK_CFG, 0x00);
        _setReg(LIS3DH_CLICK_SRC, 0x00);
        _setReg(LIS3DH_CLICK_THS, 0x00);
        _setReg(LIS3DH_TIME_LIMIT, 0x00);
        _setReg(LIS3DH_TIME_LATENCY, 0x00);
        _setReg(LIS3DH_TIME_WINDOW, 0x00);
        _setReg(LIS3DH_FIFO_CTRL_REG, 0x00);

        // Read the range + set _range property
        getRange();
    }

    // Read data from the Accelerometer
    // Returns a table {x: <data>, y: <data>, z: <data>}
    function getAccel(cb = null) {
        local result = {};
        
        try {
            // Read entire block with auto-increment
            local reading = _getMultiReg(LIS3DH_OUT_X_L_INCR, 6);
            // Read and sign extend
            result.x <- ((reading[0] | (reading[1] << 8)) << 16) >> 16;
            result.y <- ((reading[2] | (reading[3] << 8)) << 16) >> 16;
            result.z <- ((reading[4] | (reading[5] << 8)) << 16) >> 16;

            // multiply by full-scale range to return in G
            result.x = (result.x / 32000.0) * _range;
            result.y = (result.y / 32000.0) * _range;
            result.z = (result.z / 32000.0) * _range;
        } catch (e) {
            reslut.err <- e;
        }

        // Return table if no callback was passed
        if (cb == null) { return result; }

        // Invoke the callback if one was passed
        imp.wakeup(0, function() { cb(result); });
    }

    // Set Accelerometer Data Rate in Hz
    function setDataRate(rate) {
        local val = _getReg(LIS3DH_CTRL_REG1) & 0x0F;
        local normal_mode = (val < 8);
        if (rate == 0) {
            // 0b0000 -> power-down mode
            // we've already ANDed-out the top 4 bits; just write back
            rate = 0;
        } else if (rate <= 1) {
            val = val | 0x10;
            rate = 1;
        } else if (rate <= 10) {
            val = val | 0x20;
            rate = 10;
        } else if (rate <= 25) {
            val = val | 0x30;
            rate = 25;
        } else if (rate <= 50) {
            val = val | 0x40;
            rate = 50;
        } else if (rate <= 100) {
            val = val | 0x50;
            rate = 100;
        } else if (rate <= 200) {
            val = val | 0x60;
            rate = 200;
        } else if (rate <= 400) {
            val = val | 0x70;
            rate = 400;
        } else if (normal_mode) {
            val = val | 0x90;
            rate = 1250;
        } else if (rate <= 1600) {
            val = val | 0x80;
            rate = 1600;
        } else {
            val = val | 0x90;
            rate = 5000;
        }
        _setReg(LIS3DH_CTRL_REG1, val);
        return rate;
    }

    // set the full-scale range of the accelerometer (default +/- 2G)
    function setRange(range_a) {
        local val = _getReg(LIS3DH_CTRL_REG4) & 0xCF;
        local range_bits = 0;
        if (range_a <= 2) {
            range_bits = 0x00;
            _range = 2;
        } else if (range_a <= 4) {
            range_bits = 0x01;
            _range = 4;
        } else if (range_a <= 8) {
            range_bits = 0x02;
            _range = 8;
        } else {
            range_bits = 0x03;
            _range = 16;
        }
        _setReg(LIS3DH_CTRL_REG4, val | (range_bits << 4));
        return _range;
    }

    // get the currently-set full-scale range of the accelerometer
    function getRange() {
        local range_bits = (_getReg(LIS3DH_CTRL_REG4) & 0x30) >> 4;
        if (range_bits == 0x00) {
            _range = 2;
        } else if (range_bits == 0x01) {
            _range = 4;
        } else if (range_bits == 0x02) {
            _range = 8;
        } else {
            _range = 16;
        }
        return _range;
    }

    // Enable/disable the accelerometer (all 3-axes)
    function enable(state = true) {
        // LIS3DH_CTRL_REG1 enables/disables accelerometer axes
        // bit 0 = X axis
        // bit 1 = Y axis
        // bit 2 = Z axis
        local val = _getReg(LIS3DH_CTRL_REG1);
        if (state) { val = val | 0x07; }
        else { val = val & 0xF8; }
        _setReg(LIS3DH_CTRL_REG1, val);
    }

    // Enables /disables low power mude
    function setLowPower(state) {
        _setRegBit(LIS3DH_CTRL_REG1, 3, state ? 1 : 0);
    }

    // Returns the deviceID (should be 51)
    function getDeviceId() {
        return _getReg(LIS3DH_WHO_AM_I);
    }

    function configureHighPassFilter(filters, cutoff = null, mode = null) {
        // clear and set filters
        filters = LIS3DH_HPF_DISABLED | filters;

        // set default cutoff mode
        if (cutoff == null) { cutoff = LIS3DH_HPF_CUTOFF1; }

        // set default mode
        if (mode == null) { mode = LIS3DH_HPF_DEFAULT_MODE; }

        // set register
        _setReg(LIS3DH_CTRL_REG2, filters | cutoff | mode);
    }

    //-------------------- INTERRUPTS --------------------//

    // Enable/disable and configure FIFO buffer watermark interrupts
    function configureFifoInterrupt(state, fifomode = 0x80, watermark = 28) {
        
        // Enable/disable the FIFO buffer
        _setRegBit(LIS3DH_CTRL_REG5, 6, state ? 1 : 0);
        
        if (state) {
            // Stream-to-FIFO mode, watermark of [28].
            _setReg(LIS3DH_FIFO_CTRL_REG, (fifomode & 0xc0) | (watermark & 0x1F)); 
        } else {
            _setReg(LIS3DH_FIFO_CTRL_REG, 0x00); 
        }
        
        // Enable/disable watermark interrupt
        _setRegBit(LIS3DH_CTRL_REG3, 2, state ? 1 : 0);
        
    }

    // Enable/disable and configure inertial interrupts
    function configureInertialInterrupt(state, threshold = 2.0, duration = 5, options = null) {
        // Set default value for options (using statics, so can't set in ftcn declaration)
        if (options == null) { options = LIS3DH_X_HIGH | LIS3DH_Y_HIGH | LIS3DH_Z_HIGH; }

        // Set the enable flag
        _setRegBit(LIS3DH_CTRL_REG3, 6, state ? 1 : 0);

        // If we're disabling the interrupt, don't set anything else
        if (!state) return;

        // Clamp the threshold
        if (threshold < 0) { threshold = threshold * -1.0; }    // Make sure we have a positive value
        if (threshold > _range) { threshold = _range; }          // Make sure it doesn't exceed the _range

        // Set the threshold
        threshold = (((threshold * 1.0) / (_range * 1.0)) * 127).tointeger();
        _setReg(LIS3DH_INT1_THS, (threshold & 0x7f));

        // Set the duration
        _setReg(LIS3DH_INT1_DURATION, duration & 0x7f);

        // Set the options flags
        _setReg(LIS3DH_INT1_CFG, options);
    }

    // Enable/disable and configure an inertial interrupt to detect free fall
    function configureFreeFallInterrupt(state, threshold = 0.5, duration = 5) {
        configureInertialInterrupt(state, threshold, duration, LIS3DH_AOI | LIS3DH_X_LOW | LIS3DH_Y_LOW | LIS3DH_Z_LOW);
    }

    // Enable/disable and configure click interrupts
    function configureClickInterrupt(state, clickType = null, threshold = 1.1, timeLimit = 5, latency = 10, window = 50) {
        // Set default value for clickType (since we're using statics we can't set in function definition)
        if (clickType == null) clickType = LIS3DH_SINGLE_CLICK;

        // Set the enable / disable flag
        _setRegBit(LIS3DH_CTRL_REG3, 7, state ? 1 : 0);

        // If they disabled the click interrupt, set LIS3DH_CLICK_CFG register and return
        if (!state) {
            _setReg(LIS3DH_CLICK_CFG, 0x00);
            return;
        }

        // Set the LIS3DH_CLICK_CFG register
        _setReg(LIS3DH_CLICK_CFG, clickType);

        // Set the LIS3DH_CLICK_THS register
        if (threshold < 0) { threshold = threshold * -1.0; }    // Make sure we have a positive value
        if (threshold > _range) { threshold = _range; }          // Make sure it doesn't exceed the _range

        threshold = (((threshold * 1.0) / (_range * 1.0)) * 127).tointeger();
        _setReg(LIS3DH_CLICK_THS, threshold);

        // Set the LIS3DH_TIME_LIMIT register (max time for a click)
        _setReg(LIS3DH_TIME_LIMIT, timeLimit);
        // Set the LIS3DH_TIME_LATENCY register (min time between clicks for double click)
        _setReg(LIS3DH_TIME_LATENCY, latency);
        // Set the LIS3DH_TIME_WINDOW register (max time for double click)
        _setReg(LIS3DH_TIME_WINDOW, window);
    }

    // Enable/Disable Data Ready Interrupt 1 on Interrupt Pin
    function configureDataReadyInterrupt(state) {
        _setRegBit(LIS3DH_CTRL_REG3, 4, state ? 1 : 0);
    }

    // Enables/disables interrupt latching
    function configureInterruptLatching(state) {
        _setRegBit(LIS3DH_CTRL_REG5, 3, state ? 1 : 0);
        _setRegBit(LIS3DH_CLICK_THS, 7, state ? 1 : 0);
    }

    // Returns interrupt registers as a table, and clears the LIS3DH_INT1_SRC register
    function getInterruptTable() {
        local int1 = _getReg(LIS3DH_INT1_SRC);
        local click = _getReg(LIS3DH_CLICK_SRC);

        return {
            "int1":         (int1 & 0x40) != 0,
            "xLow":         (int1 & 0x01) != 0,
            "xHigh":        (int1 & 0x02) != 0,
            "yLow":         (int1 & 0x04) != 0,
            "yHigh":        (int1 & 0x08) != 0,
            "zLow":         (int1 & 0x10) != 0,
            "zHigh":        (int1 & 0x20) != 0,
            "click":        (click & 0x40) != 0,
            "singleClick":  (click & 0x10) != 0,
            "doubleClick":  (click & 0x20) != 0
        }
    }
    
    function getFifoStats() {
        local stats = _getReg(LIS3DH_FIFO_SRC_REG);
        return {
            "watermark": (stats & 0x80) != 0,
            "overrun": (stats & 0x40) != 0,
            "empty": (stats & 0x20) != 0,
            "unread": (stats & 0x1F) + ((stats & 0x40) ? 1 : 0) 
        }
    }


    //-------------------- PRIVATE METHODS --------------------//
    function _getReg(reg) {
        local result = _i2c.read(_addr, reg.tochar(), 1);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        return result[0];
    }

    function _getMultiReg(reg, numBits) {
        // Read entire block with auto-increment
        local result = _i2c.read(_addr, reg.tochar(), numBits);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        return result;
    }

    function _setReg(reg, val) {
        local result = _i2c.write(_addr, format("%c%c", reg, (val & 0xff)));
        if (result) {
            throw "I2C write error: " + result;
        }
        return result;
    }

    function _setRegBit(reg, bit, state) {
        local val = _getReg(reg);
        if (state == 0) {
            val = val & ~(0x01 << bit);
        } else {
            val = val | (0x01 << bit);
        }
        return _setReg(reg, val);
    }

    function dumpRegs() {
        server.log(format("LIS3DH_CTRL_REG1 0x%02X", _getReg(LIS3DH_CTRL_REG1)));
        server.log(format("LIS3DH_CTRL_REG2 0x%02X", _getReg(LIS3DH_CTRL_REG2)));
        server.log(format("LIS3DH_CTRL_REG3 0x%02X", _getReg(LIS3DH_CTRL_REG3)));
        server.log(format("LIS3DH_CTRL_REG4 0x%02X", _getReg(LIS3DH_CTRL_REG4)));
        server.log(format("LIS3DH_CTRL_REG5 0x%02X", _getReg(LIS3DH_CTRL_REG5)));
        server.log(format("LIS3DH_CTRL_REG6 0x%02X", _getReg(LIS3DH_CTRL_REG6)));
        server.log(format("LIS3DH_INT1_DURATION 0x%02X", _getReg(LIS3DH_INT1_DURATION)));
        server.log(format("LIS3DH_INT1_CFG 0x%02X", _getReg(LIS3DH_INT1_CFG)));
        server.log(format("LIS3DH_INT1_SRC 0x%02X", _getReg(LIS3DH_INT1_SRC)));
        server.log(format("LIS3DH_INT1_THS 0x%02X", _getReg(LIS3DH_INT1_THS)));
        server.log(format("LIS3DH_FIFO_CTRL_REG 0x%02X", _getReg(LIS3DH_FIFO_CTRL_REG)));
        server.log(format("LIS3DH_FIFO_SRC_REG 0x%02X", _getReg(LIS3DH_FIFO_SRC_REG)));
    }
}

// HARDWARE ABSTRACTION LAYER
// --------------------------------------------------------
// HAL's are tables that map human readable names to 
// the hardware objects used in the application. 

// Copy and Paste Your HAL here
// YOUR_HAL <- {...}


// POWER EFFICIENT REFRIGERATOR MONITOR APPLICATION CODE
// --------------------------------------------------------
// Application code, take readings from our sensors
// and send the data to the agent 

class Application {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC = 30;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC = 300;
    // Max number of stored readings
    static MAX_NUM_STORED_READINGS = 20;
    // Time to wait after boot before turning off WiFi
    static BOOT_TIMER_SEC = 60;
    // Time to wait between checks if door is open
    static DOOR_OPEN_INTERVAL_SEC = 1;

    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 100;
    // Set sensitivity for interrupt to wake on a door event
    static ACCEL_THRESHOLD = 0.1;
    static ACCEL_DURATION = 1;
    
    // The lx level at which we know the door is open
    static LX_THRESHOLD = 3000;
    // Alert thresholds
    static TEMP_THRESHOLD = 11;
    static HUMID_THRESHOLD = 70;

    // Time in seconds that door is open for before door alert triggered
    static DOOR_ALERT_TIMEOUT = 30;
    // Number of seconds the conditon must be over threshold before triggering env event
    static TEMP_ALERT_CONDITION = 900;
    static HUMID_ALERT_CONDITION = 900;
    // Time in seconds after door close event before env events will be checked 
    // Prevents temperature or humidity alerts right after is opened
    static DOOR_CONDITION_TIMEOUT = 180;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr
    accelAddr       = null; // Replace with your accel i2c addr
    wakePin         = null; // Replace with your wake pin

    // Sensor variables
    tempHumid = null;
    accel = null;

    // Message Manager variable
    mm = null;
    
    // Flag to track first disconnection
    _boot = false;

    // Variable to track next action timer
    _nextActTimer = null;

    constructor() {
        // Power save mode will reduce power consumption when the 
        // radio is idle. This adds latency when sending data. 
        imp.setpowersave(true);

        // Change default connection policy, so our application 
        // continues to run even if the WiFi connection fails
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message  
        // has been delivered. We will use this to know when it is ok
        // to disconnect from WiFi.
        mm.onAck(readingsAckHandler.bindenv(this));
        // Message Manager allows us to call a function if a message
        // is not ackknowledged.  We want to treat this the same as
        // if a message failed.
        mm.onTimeout(function(msg, wait, fail) { fail(); });
        // Message Manager allows us to call a function if a message  
        // fails to be delivered. We will use this to recover data.
        mm.onFail(sendFailHandler.bindenv(this));

        // Initialize sensors
        initializeSensors();

        // Configure different behavior based on the reason the 
        // hardware rebooted 
        checkWakeReason();
    }

    // Select which flow to run based on why we woke up
    function checkWakeReason() {
        // We can configure different behavior based on 
        // the reason the hardware rebooted. 
        switch (hardware.wakereason()) {
            case WAKEREASON_TIMER :
                // We woke up after sleep timer expired. 
                // Configure Sensors to take readings
                configureSensors();
                run();
                break;
            case WAKEREASON_PIN :
                // We woke up because an interrupt pin was triggerd.
                // Let's check our interrupt
                checkInterrupt(); 
                break;
            case WAKEREASON_SNOOZE : 
                // We woke up after connection timeout.
                // Configure Sensors to take readings
                configureSensors();
                run();
                break;
            default :
                // We pushed new code or just rebooted the device, etc. Lets
                // congigure everything. 
                server.log("Device running...");
            
                // NV can persist data when the device goes into sleep mode 
                // Set up the table with defaults - note this method will 
                // erase stored data, so we only want to call it when the
                // application is starting up.
                configureNV();

                // We want to make sure we can always blinkUp a device
                // when it is first powered on, so we do not want to
                // immediately disconnect from WiFi after boot
                // Set up first disconnect
                _boot = true;
                imp.wakeup(BOOT_TIMER_SEC, function() {
                    _boot = false;
                    powerDown();
                }.bindenv(this))

                // Configure Sensors to take readings
                configureSensors();
                run();
        }
    }

    // Basic run opperation, checks door then takes tempHumid reading
    function run() {
        checkDoor();
        takeTempHumidReading();
    }

    // Take an async temperature humdity reading then set up next action
    function takeTempHumidReading() {
        tempHumid.read(function(result) {
            // Create a table to store the results from the sensor readings
            local reading = {};
            // Add sensor readings
            if ("temperature" in results) reading.temperature <- results.temperature;
            if ("humidity" in results) reading.humidity <- results.humidity;
            // We have a good reading
            if (reading.len() > 0) {
                // Add a timestamp 
                reading.time <- time();
                nv.readings.push(reading);
                // Check for Temp/Humid alert conditions
                checkForTempHumidAlerts(reading);
            } else if (nv.readings.len() > 0 || nv.alerts.len() > 0) {
                // Even if this reading failed if we have stored readings
                // or events continue to run the connection flow
                checkConnetionTime();
            } else {
                // We don't have any data to send
                // Update the next reading time varaible
                setNextReadTime(time());
                // Then shut down
                powerDown();    
            }
        }.bindenv(this))
    }

    // Create temperature or humidity alerts if needed based on reading passed in
    function checkForTempHumidAlerts(reading) {
        // If door is open or has been open recently and there are no 
        // active temperature or humidity alerts skip alert checks
        if ((nv.doorOpen || reading.time <= nv.doorTimeout) && !(nv.tempAlert || nv.humidAlert)) return;

        local now = time();

        // Check temperature
        if ("temperature" in reading) {
            if (reading.temperature >= TEMP_THRESHOLD) {
                // Condition met
                if (!nv.tempAlert) {
                    // Build alert
                    nv.tempAlert <- {"timeStarted" : now, "reported" : false};
                } else {
                    // Update alert
                    local highFor = now - nv.tempAlert.timeStarted;
                    // We haven't reported alert, check time 
                    if (!nv.tempAlert.reported && highFor >= TEMP_ALERT_CONDITION) {
                        // Create alert if temp too high for too long
                        nv.alerts.tempHighFor <- highFor;
                        nv.tempAlert.reported <- true;
                        // Force a connection, we want to report this
                        nv.nextConectTime <- now;
                    } else if ("tempHighFor" in nv.alerts) {
                        // Update how long
                        nv.alerts.tempHighFor <- highFor;
                    }
                }
            } else if (nv.tempAlert) {
                // Clear alert
                nv.tempAlert <- false;
                nv.alerts.rawdelete("tempHighFor");
            }
        }

        // Check humidity
        if ("humidity" in reading) {
            if (reading.humidity >= HUMID_THRESHOLD) {
                // Condition met
                if (!nv.humidAlert) {
                    // Build alert
                    nv.humidAlert <- {"timeStarted" : now, "reported" : false};
                } else {
                    // Update alert
                    local highFor = now - nv.humidAlert.timeStarted;
                    // We haven't reported alert, check time 
                    if (!nv.humidAlert.reported && highFor >= HUMID_ALERT_CONDITION) {
                        // Create alert if temp too high for too long
                        nv.alerts.humidHighFor <- highFor;
                        nv.humidAlert.reported <- true;
                        // Force a connection, we want to report this
                        nv.nextConectTime <- now;
                    } else if ("humidHighFor" in nv.alerts) {
                        // Update how long
                        nv.alerts.humidHighFor <- highFor;
                    }
                }
            } else if (nv.humidAlert) {
                // Clear alert
                nv.humidAlert <- false;
                nv.alerts.rawdelete("humidHighFor");
            }
        }
    }

    // Use light sensor to determine if door is open, update 
    // variables and alerts based on findings
    // Return boolean if door state has changed
    function checkDoor() {
        // Take a light reading to check if door is open
        local doorOpen = hardware.lightlevel() > LX_THRESHOLD;
        local now = time();

        // If door is open check alert conditions 
        if (doorOpen) {
            if (!nv.doorAlert) {
                nv.doorAlert <- {"timeStarted" : now, "reported" : false};
            } else {
                local openedFor = now - nv.doorAlert.timeStarted;
                // We haven't reported a door alert check how long 
                if (!nv.doorAlert.reported && openedFor >= DOOR_ALERT_TIMEOUT) {
                    // Create alert if door has been open too long
                    nv.alerts.doorOpenFor <- openedFor;
                    nv.doorAlert.reported <- true;
                } else if ("doorOpenFor" in nv.alerts) {
                    // Update how long
                    nv.alerts.doorOpenFor <- openedFor;
                }
            }
        }
        
        // Check for a change in door status
        if (doorOpen != nv.doorOpen) {
            // Update stored door state
            nv.doorOpen = doorOpen;  
            // Force a connection, we want to report this
            nv.nextConectTime <- now;

            // The door just closed
            if (!doorOpen) {
                // Set door timeout timestamp
                nv.doorTimeout = now + DOOR_CONDITION_TIMEOUT;
                // Reset alert conditions
                nv.doorAlert <- false;
                nv.alerts.rawdelete("doorOpenFor");  
            }

            // Return bool - door changed state
            return true;
        }

        // Return bool - door did not changed state
        return false;
    }

    // Runs a check then either powers down or connects & sends store data 
    function checkConnetionTime(resetReadingTime = true) {
        // Grab a timestamp
        local now = time();

        // Update the next reading time varaible
        if (resetReadingTime) setNextReadTime(now);
        
        local connected = server.isconnected();
        // Only send if we are already connected 
        // to WiFi or if it is time to connect
        if (connected || timeToConnect()) {

            // Update the next connection time varaible
            setNextConnectTime(now);

            // We changed the default connection policy, so we need to 
            // use this method to connect
            if (connected) {
                sendData();
            } else {
                server.connect(function(reason) {
                    if (reason == SERVER_CONNECTED) {
                        // We connected let's send readings
                        sendData();
                    } else {
                        // We were not able to connect
                        // Let's make sure we don't run out 
                        // of meemory with our stored readings
                        failHandler();
                    }
                }.bindenv(this));
            }

        } else {
            // Not time to connect, let's power down
            powerDown();
        }
    }

    // Sends current door status and all stored readings and alerts
    function sendData() {
        local data = {"doorOpen" : nv.doorOpen};

        if (nv.readings.len() > 0) {
            data.readings <- nv.readings;
        }
        if (nv.alerts.len() > 0) {
            data.alerts <- nv.alerts;
        }

        // Send data to the agent   
        mm.send("data", data);

        // Clear readings we just sent, we can recover
        // the data if the message send fails
        nv.readings.clear();

        // If this message is acknowleged by the agent
        // the readingsAckHandler will be triggered
        
        // If the message fails to send we will handle 
        // in the sendFailHandler handler
    }

    // Data has been sent to the agent, lets power down
    function readingsAckHandler(msg) {
        // We connected successfully & sent data

        // Reset numFailedConnects
        nv.numFailedConnects <- 0;
        
        // Disconnect from server
        powerDown();
    }

    // Message manager handler - message failed during send
    // Let's recover the message data and pass to our connection
    // fail handler
    function sendFailHandler(msg, error, retry) {
        // Message did not send, pass them the 
        // the connection failed handler, so they
        // can be condensed and stored
        failHandler(msg.payload.data);
    }

    // Puts sensor into power down mode, then determines whether
    // to sleep or just disconnect from WiFi til next reading time
    // or door open check time
    function powerDown() {
        // Power Down sensors
        powerDownSensors();

        // Calculate how long before next reading time
        local timer = (nv.doorOpen) ? DOOR_OPEN_INTERVAL_SEC : nv.nextReadTime - time();

        // If we did not just boot up, the door is closed, the interrupt 
        // pin is not triggered, and we are not about to take a reading
        if (!_boot && wakePin.read() == 0 && !nv.doorOpen &&  timer > 2) {
            // Go to sleep
            if (server.isconnected()) {
                imp.onidle(function() {
                    // This method flushes server before sleep
                    server.sleepfor(timer);
                }.bindenv(this));
            } else {
                // This method just put's the device to sleep
                imp.deepsleepfor(timer);
            }
        } else {
            // Turn off WiFi if we didn't just boot
            if (!_boot && server.isconnected()) server.disconnect();

            // Schedule next action, but don't go to sleep
            _nextActTimer = imp.wakeup(timer, function() {
                if (nextActTimer != null) {
                    imp.cancelwakeup(_nextActTimer);
                    _nextActTimer = null;
                }
                local now = time();
                if (nv.nextReadTime >= now) {
                    // Time for a reading
                    powerUpSensors();
                    run();
                } else {
                    (checkDoor()) ? checkConnetionTime(false) : powerDown();
                }
            }.bindenv(this));
        }
    }

    // Put sensors into powerdown mode
    function powerDownSensors() {
        tempHumid.setMode(HTS221_MODE.POWER_DOWN);
    }
    
    // Put sensors into reading mode
    function powerUpSensors() {
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
    }

    // If connection has failed condense data so our
    // persistant storeage doesn't run out of space
    function failHandler(data = null) {
        // We are having connection issues
        // Let's condense and re-store the data

        // Find the number of times we have failed
        // to connect (use this to determine new readings 
        // previously condensed readings) 
        local failed = nv.numFailedConnects;
        local readings;
        
        // Connection failed before we could send
        if (data == null) {
            // Make a copy of the stored readings
            readings = nv.readings.slice(0);
            // Clear stored readings
            nv.readings.clear();
        } else {
            if ("readings" in data) readings = data.readings;
        }

        if (readings.len() > 0) {
            // Create an array to store condensed readings
            local condensed = [];

            // If we have already averaged readings move them
            // into the condensed readings array
            for (local i = 0; i < failed; i++) {
                condensed.push( readings.remove(i) );
            }

            // Condense and add the new readings 
            condensed.push(getAverage(readings));
        
            // Drop old readings if we are running out of space
            while (condensed.len() >= MAX_NUM_STORED_READINGS) {
                condensed.remove(0);
            }

            // If new readings have come in while we were processing
            // Add those to the condensed readings
            if (nv.readings.len() > 0) {
                foreach(item in nv.readings) {
                    condensed.push(item);
                }
            }

            // Replace the stored readings with the condensed readings
            nv.readings <- condensed;
        } 

        // Update the number of failed connections
        nv.numFailedConnects <- failed++;
    }

    // Calculate and return the average of stored readings 
    function getAverage(readings) {
        // Variables to help us track readings we want to average
        local tempTotal = 0;
        local humidTotal = 0;
        local pressTotal = 0;
        local tCount = 0;
        local hCount = 0;
        local pCount = 0;

        // Loop through the readings to get a total
        foreach(reading in readings) {
            if ("temperature" in reading) {
                tempTotal += reading.temperature;
                tCount ++;
            }
            if ("humidity" in reading) {
                humidTotal += reading.humidity;
                hCount++;
            }
            if ("pressure" in reading) {
                pressTotal += reading.pressure;
                pCount++;
            }
        }

        // Grab the last value from the readings array
        // This we allow us to keep the last accelerometer 
        // reading and time stamp
        local last = readings.top();

        // Update the other values with an average 
        last.temperature <- tempTotal / tCount;
        last.humidity <- humidTotal / hCount;
        last.pressure <- pressTotal / pCount;

        // return the condensed single value
        return last
    }

    // Configure NV (persistant storage) with default values
    function configureNV() {
        local root = getroottable();
        if (!("nv" in root)) root.nv <- {};

        // Store sleep and connection varaibles
        local now = time();
        setNextConnectTime(now); 
        setNextReadTime(now);

        // Readings to be sent to agent
        nv.readings <- [];
        // Alerts to be sent to agent
        nv.alerts <- {};

        // Status vars that we need to persist through sleep
        nv.numFailedConnects <- 0;
        // Previous state of the door (set a default of closed)
        nv.doorOpen <- false;
        // Time at which to start checking for temp/humid alerts
        nv.doorTimeout <- now; 
        // Store alert status info: defaults to false, 
        // when alert tracking needed will be a table with
        // keys "timeStarted" and "reported"
        nv.doorAlert <- false;
        nv.tempAlert <- false; 
        nv.humidAlert <- false;  
    }

    // Update stored connection time based on REPORTING_INTERVAL_SEC
    function setNextConnectTime(now) {
        nv.nextConectTime <- now + REPORTING_INTERVAL_SEC;
    }

    // Update stored connection time based on READING_INTERVAL_SEC
    function setNextReadTime(now) {
        nv.nextReadTime <- now + READING_INTERVAL_SEC;
    }

    // Return a boolean - if it is time to connect based on 
    // the current time
    function timeToConnect() {
        return (time() >= nv.nextConectTime);
    }

    // Configures a latching click interrupt, and interrupt wake pin
    function configureInterrupt() {
        accel.configureInterruptLatching(true);
        accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK, ACCEL_THRESHOLD, ACCEL_DURATION);
        
        // Configure wake pin
        wakePin.configure(DIGITAL_IN_WAKEUP);
        // wakePin.configure(DIGITAL_IN_WAKEUP, function() {
        //     if (wakePin.read()) checkInterrupt();
        // }.bindenv(this));
    }

    // Clear interrupt, then run check door flow
    function checkInterrupt() {
        local interrupt = accel.getInterruptTable();
        if (interrupt.singleClick) {
            // Check of door state has changed
            if (checkDoor()) {
                checkConnetionTime(false);
                return;
            }
        } 
        powerDown();
    }

    // Configure i2c and create instances of tempHumid and accel
    // sensors
    function initializeSensors() {
        // Configure i2c
        i2c.configure(CLOCK_SPEED_400_KHZ);

        // Initialize sensors
        tempHumid = HTS221(i2c, tempHumidAddr);
        accel = LIS3DH(i2c, accelAddr);
    }

    // Configure sensors to take readings and tigger an interrupt
    function configureSensors() {
        // Configure sensors to take readings
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        accel.init();
        accel.setLowPower(true);
        accel.setDataRate(ACCEL_DATARATE);
        accel.enable(true);
        // Configure accelerometer click interrupt 
        configureInterrupt();
    }
}


// RUNTIME 
// ---------------------------------------------------

// Initialize application to start readings loop
app <- Application();
