// Power Efficient Refrigerator Monitor Device Code
// --------------------------------------------------------
// NOTE: imp004m, and imp006 devices do not have nv storage. 
// This code will work around this on limitation by using shallow sleep
// See developer docs - https://developer.electricimp.com/api/nv and 
// https://developer.electricimp.com/resources/sleepstatesexplained

// SENSOR LIBRARIES
// --------------------------------------------------------
// Libraries must be required before all other code

// Accelerometer Library
#require "LIS3DH.device.lib.nut:2.0.2"
// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.2.0"

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
    // Time to wait after boot before first disconection
    // This allows time for blinkup recovery on cold boots
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

    // Flag to track if imp is trying to connect
    _connecting = false;

    constructor() {
        // Power save mode will reduce power consumption when the radio
        // is idle, a good first step for saving power for battery
        // powered devices.
        // NOTE: Power save mode will add latency when sending data.
        // Power save mode is not supported on impC001 and is not
        // recommended for imp004m, so don't set for those types of imps.
        local type = imp.info().type;
        if (!(type == "imp004m" || type == "impC001")) {
            imp.setpowersave(true);
        }

        // Change default connection policy, so our application
        // continues to run even if the connection fails
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message
        // has been delivered. We will use this to know when it is ok
        // to disconnect.
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
                restoreNV(); 
                // Configure Sensors to take readings
                configureSensors();
                run();
                break;
            case WAKEREASON_PIN :
                // We woke up because an interrupt pin was triggered.
                restoreNV(); 

                // Let's check our interrupt
                checkInterrupt();
                break;
            case WAKEREASON_SNOOZE :
                // We woke up after connection timeout.
                // Configure Sensors to take readings
                restoreNV(); 
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
                // immediately disconnect after boot
                // Set up first disconnect
                _boot = true;
                imp.wakeup(BOOT_TIMER_SEC, function() {
                    _boot = false;
                    powerDown();
                }.bindenv(this));

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
            if ("temperature" in result) reading.temperature <- result.temperature;
            if ("humidity" in result) reading.humidity <- result.humidity;
            // We have a good reading
            if (reading.len() > 0) {
                // Add a timestamp
                reading.time <- time();
                status.readings.push(reading);
                // Check for Temp/Humid alert conditions
                checkForTempHumidAlerts(reading);
                checkConnectionTime();
            } else if (status.readings.len() > 0 || status.alerts.len() > 0) {
                // Even if this reading failed if we have stored readings
                // or events continue to run the connection flow
                checkConnectionTime();
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
        if ((status.doorOpen || reading.time <= status.doorTimeout) && !(status.tempAlert || status.humidAlert)) return;

        local now = time();

        // Check temperature
        if ("temperature" in reading) {
            if (reading.temperature >= TEMP_THRESHOLD) {
                // Condition met
                if (!status.tempAlert) {
                    // Build alert
                    status.tempAlert <- {"timeStarted" : now, "reported" : false};
                } else {
                    // Update alert
                    local highFor = now - status.tempAlert.timeStarted;
                    // We haven't reported alert, check time
                    if (!status.tempAlert.reported && highFor >= TEMP_ALERT_CONDITION) {
                        // Create alert if temp too high for too long
                        status.alerts.tempHighFor <- highFor;
                        status.tempAlert.reported <- true;
                        // Force a connection, we want to report this
                        status.nextConnectTime <- now;
                    } else if ("tempHighFor" in status.alerts) {
                        // Update how long
                        status.alerts.tempHighFor <- highFor;
                    }
                }
            } else if (status.tempAlert) {
                // Clear alert
                status.tempAlert <- false;
                status.alerts.rawdelete("tempHighFor");
            }
        }

        // Check humidity
        if ("humidity" in reading) {
            if (reading.humidity >= HUMID_THRESHOLD) {
                // Condition met
                if (!status.humidAlert) {
                    // Build alert
                    status.humidAlert <- {"timeStarted" : now, "reported" : false};
                } else {
                    // Update alert
                    local highFor = now - status.humidAlert.timeStarted;
                    // We haven't reported alert, check time
                    if (!status.humidAlert.reported && highFor >= HUMID_ALERT_CONDITION) {
                        // Create alert if temp too high for too long
                        status.alerts.humidHighFor <- highFor;
                        status.humidAlert.reported <- true;
                        // Force a connection, we want to report this
                        status.nextConnectTime <- now;
                    } else if ("humidHighFor" in status.alerts) {
                        // Update how long
                        status.alerts.humidHighFor <- highFor;
                    }
                }
            } else if (status.humidAlert) {
                // Clear alert
                status.humidAlert <- false;
                status.alerts.rawdelete("humidHighFor");
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
            if (!status.doorAlert) {
                status.doorAlert <- {"timeStarted" : now, "reported" : false};
            } else {
                local openedFor = now - status.doorAlert.timeStarted;
                // We haven't reported a door alert check how long
                if (!status.doorAlert.reported && openedFor >= DOOR_ALERT_TIMEOUT) {
                    // Create alert if door has been open too long
                    status.alerts.doorOpenFor <- openedFor;
                    status.doorAlert.reported <- true;
                } else if ("doorOpenFor" in status.alerts) {
                    // Update how long
                    status.alerts.doorOpenFor <- openedFor;
                }
            }
        }

        // Check for a change in door status
        if (doorOpen != status.doorOpen) {
            // Update stored door state
            status.doorOpen = doorOpen;
            // Force a connection, we want to report this
            status.nextConnectTime <- now;

            // The door just closed
            if (!doorOpen) {
                // Set door timeout timestamp
                status.doorTimeout = now + DOOR_CONDITION_TIMEOUT;
                // Reset alert conditions
                status.doorAlert <- false;
                status.alerts.rawdelete("doorOpenFor");
            }

            // Return bool - door changed state
            return true;
        }

        // Return bool - door did not change state
        return false;
    }

    // Runs a check then either powers down or connects & sends store data
    function checkConnectionTime(resetReadingTime = true) {
        // Grab a timestamp
        local now = time();

        // Update the next reading time varaible
        if (resetReadingTime) setNextReadTime(now);

        // If we are not currently tring to connect, check if we
        // should connect, send data, or power down
        if (!_connecting) {

            local connected = server.isconnected();
            // Only send if we are already connected
            // or if it is time to connect
            if (connected || timeToConnect()) {

                // Update the next connection time varaible
                setNextConnectTime(now);

                // We changed the default connection policy, so we need to
                // use this method to connect
                if (connected) {
                    sendData();
                } else {
                    // Toggle connecting flag
                    _connecting = true;

                    server.connect(function(reason) {
                        // Connect handler called, we are no longer tring to
                        // connect, so set connecting flag to false
                        _connecting = false;
                        if (reason == SERVER_CONNECTED) {
                            // We connected let's send readings
                            sendData();
                        } else {
                            // We were not able to connect
                            // Let's make sure we don't run out
                            // of memory with our stored readings
                            failHandler();
                        }
                    }.bindenv(this));
                }

            } else {
                // Not time to connect, let's power down
                powerDown();
            }
        } else {
            local timer = status.nextReadTime - time();
            // Schedule next reading, but don't go to sleep
            _nextActTimer = imp.wakeup(timer, function() {
                if (_nextActTimer != null) {
                    imp.cancelwakeup(_nextActTimer);
                    _nextActTimer = null;
                }
                run();
            }.bindenv(this));
        }
    }

    // Sends current door status and all stored readings and alerts
    function sendData() {
        local data = {"doorOpen" : status.doorOpen};

        if (status.readings.len() > 0) {
            data.readings <- status.readings;
        }
        if (status.alerts.len() > 0) {
            data.alerts <- status.alerts;
        }

        // Send data to the agent
        mm.send("data", data);

        // If this message is acknowleged by the agent
        // the readingsAckHandler will be triggered

        // If the message fails to send we will handle
        // in the sendFailHandler handler
    }

    // Data has been sent to the agent, lets power down
    function readingsAckHandler(msg) {
        // We connected successfully & sent data
        // Clear readings we just sent
        status.readings.clear();

        // Reset numFailedConnects
        status.numFailedConnects <- 0;

        // Disconnect from server
        powerDown();
    }

    // Message manager handler - message failed during send
    // Let's recover the message data and pass to our connection
    // fail handler
    function sendFailHandler(msg, error, retry) {
        // Readings did not send, call the
        // connection failed handler, so readings
        // can be condensed and re-stored
        failHandler();
    }

    // Puts sensor into power down mode, then determines whether
    // to sleep or just disconnect til next reading time
    // or door open check time
    function powerDown() {
        // Power Down sensors
        powerDownSensors();

        // Calculate how long before next reading time
        local timer = (status.doorOpen) ? DOOR_OPEN_INTERVAL_SEC : status.nextReadTime - time();
        local type = imp.info().type;

        // If we did not just boot up, the door is closed, the interrupt
        // pin is not triggered, and we are not about to take a reading
        if (!_boot && wakePin.read() == 0 && !status.doorOpen &&  timer > 2 && (!(type == "imp004m" || type == "imp006"))) {
            // Go to sleep
            imp.onidle(function() {
                server.sleepfor(timer);
            }.bindenv(this));
        } else {
            // Disconnect if we didn't just boot
            if (!_boot && server.isconnected()) server.disconnect();

            // Schedule next action, but don't go to sleep
            _nextActTimer = imp.wakeup(timer, function() {
                if (_nextActTimer != null) {
                    imp.cancelwakeup(_nextActTimer);
                    _nextActTimer = null;
                }
                local now = time();
                if (status.nextReadTime <= now) {
                    // Time for a reading
                    powerUpSensors();
                    run();
                } else {
                    (checkDoor()) ? checkConnectionTime(false) : powerDown();
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
    // persistant storage doesn't run out of space
    function failHandler() {
        // We are having connection issues
        // Let's condense and re-store the data

        // Find the number of times we have failed
        // to connect (use this to determine new readings
        // vs. previously condensed readings)
        local failed = status.numFailedConnects;
        local readings;

        // Make a copy of the stored readings
        readings = status.readings.slice(0);
        // Clear stored readings
        status.readings.clear();

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
            if (status.readings.len() > 0) {
                foreach(item in status.readings) {
                    condensed.push(item);
                }
            }

            // Replace the stored readings with the condensed readings
            status.readings <- condensed;
        }

        // Update the number of failed connections
        status.numFailedConnects <- failed++;

        powerDown();
    }

    // Calculate and return the average of stored readings
    function getAverage(readings) {
        // Variables to help us track readings we want to average
        local tempTotal = 0;
        local humidTotal = 0;
        local tCount = 0;
        local hCount = 0;

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
        }

        // Grab the last value from the readings array
        // This we allow us to keep the last accelerometer
        // reading and time stamp
        local last = readings.top();

        // Update the other values with an average
        last.temperature <- tempTotal / tCount;
        last.humidity <- humidTotal / hCount;

        // return the condensed single value
        return last
    }

    // Configure NV (persistant storage) with default values
    function configureNV() {
        local type = imp.info().type;
        local root = getroottable();
        // Create a table for storing status and recent readings
        if (!("status" in root)) root.status <- {};

        if (!(type == "imp004m" || type == "imp006")) {
            // There is an nv table, so make the status table a
            // reference to nv so it will be persisted
            if (!("nv" in root)) root.nv <- {};
            status = nv;
        }       

        // Store sleep and connection varaibles
        local now = time();
        setNextConnectTime(now);
        setNextReadTime(now);

        // Readings to be sent to agent
        status.readings <- [];
        // Alerts to be sent to agent
        status.alerts <- {};

        // Status vars that we need to persist through sleep
        status.numFailedConnects <- 0;
        // Previous state of the door (set a default of closed)
        status.doorOpen <- false;
        // Time at which to start checking for temp/humid alerts
        status.doorTimeout <- now;
        // Store alert status info: defaults to false,
        // when alert tracking needed will be a table with
        // keys "timeStarted" and "reported"
        status.doorAlert <- false;
        status.tempAlert <- false;
        status.humidAlert <- false;
    }

    function restoreNV() {
        local root = getroottable();
        local type = imp.info().type;
        if (!("status" in root)) root.status <- {};
        if (!(type == "imp004m" || type == "imp006")) status = nv ;
    }


    // Update stored connection time based on REPORTING_INTERVAL_SEC
    function setNextConnectTime(now) {
        status.nextConnectTime <- now + REPORTING_INTERVAL_SEC;
    }

    // Update stored connection time based on READING_INTERVAL_SEC
    function setNextReadTime(now) {
        status.nextReadTime <- now + READING_INTERVAL_SEC;
    }

    // Return a boolean - if it is time to connect based on
    // the current time
    function timeToConnect() {
        return (time() >= status.nextConnectTime);
    }

    // Configures a latching click interrupt, and interrupt wake pin
    function configureInterrupt() {
        accel.configureInterruptLatching(true);
        accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK, ACCEL_THRESHOLD, ACCEL_DURATION);

        // Configure wake pin
        wakePin.configure(DIGITAL_IN_WAKEUP, function() {
            if (wakePin.read()) checkInterrupt();
        }.bindenv(this));
    }

    // Clear interrupt, then run check door flow
    function checkInterrupt() {
        local interrupt = accel.getInterruptTable();
        if (interrupt.singleClick) {
            // Check of door state has changed
            if (checkDoor()) {
                checkConnectionTime(false);
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
        accel.reset();
        accel.setMode(LIS3DH_MODE_LOW_POWER);
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