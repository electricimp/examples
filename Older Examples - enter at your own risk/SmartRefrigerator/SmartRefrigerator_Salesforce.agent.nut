#require "Salesforce.class.nut:1.1.0"
#require "Rocky.class.nut:1.2.3"

#require "bullwinkle.class.nut:2.3.0"
#require "promise.class.nut:3.0.0"

// EXTEND SALESFORCE CLASS TO HANDLE OAUTH 2.0
// ----------------------------------------------------------
class SalesforceOAuth2 extends Salesforce {

    _login = null;

    constructor(consumerKey, consumerSecret, loginServiceBase = null, salesforceVersion = null) {
        _clientId = consumerKey;
        _clientSecret = consumerSecret;

        if ("Rocky" in getroottable()) {
            _login = Rocky();
        } else {
            throw "Unmet dependency: SalesforceOAuth2 requires Rocky";
        }

        if (loginServiceBase != null) _loginServiceBase = loginServiceBase;
        if (salesforceVersion != null) _version = salesforceVersion;

        getStoredCredentials();
        defineLoginEndpoint();
    }

    function getStoredCredentials() {
        local persist = server.load();
        local oAuth = {};
        if ("oAuth" in persist) oAuth = persist.oAuth;

        // Load credentials if we have them
        if ("instance_url" in oAuth && "access_token" in oAuth) {
            // Set the credentials in the Salesforce object
            setInstanceUrl(oAuth.instance_url);
            setToken(oAuth.access_token);

            // Log a message
            server.log("Loaded OAuth Credentials!");
        }
    }

    function defineLoginEndpoint() {
        // Define log in endpoint for a GET request to the agent URL
        _login.get("/", function(context) {

            // Check if an OAuth code was passed in
            if (!("code" in context.req.query)) {
                // If it wasn't, redirect to login service
                local location = format("%s/services/oauth2/authorize?response_type=code&client_id=%s&redirect_uri=%s", _loginServiceBase, _clientId, http.agenturl());
                context.setHeader("Location", location);
                context.send(302, "Found");

                return;
            }

            // Exchange the auth code for inan OAuth token
            getOAuthToken(context.req.query["code"], function(err, resp, respData) {
                if (err) {
                    context.send(400, "Error authenticating (" + err + ").");
                    return;
                }

                // If it was successful, save the data locally
                local persist = { "oAuth" : respData };
                server.save(persist);

                // Set/update the credentials in the Salesforce object
                setInstanceUrl(persist.oAuth.instance_url);
                setToken(persist.oAuth.access_token);

                // Finally - inform the user we're done!
                context.send(200, "Authentication complete - you may now close this window");
            }.bindenv(this));
        }.bindenv(this));
    }

    // OAuth 2.0 methods
    function getOAuthToken(code, cb) {
        // Send request with an authorization code
        _oauthTokenRequest("authorization_code", code, cb);
    }

    function refreshOAuthToken(refreshToken, cb) {
        // Send request with refresh token
        _oauthTokenRequest("refresh_token", refreshToken, cb);
    }

    function _oauthTokenRequest(type, tokenCode, cb = null) {
        // Build the request
        local url = format("%s/services/oauth2/token", _loginServiceBase);
        local headers = { "Content-Type": "application/x-www-form-urlencoded" };
        local data = {
            "grant_type": type,
            "client_id": _clientId,
            "client_secret": _clientSecret,
        };

        // Set the "code" or "refresh_token" parameters based on grant_type
        if (type == "authorization_code") {
            data.code <- tokenCode;
            data.redirect_uri <- http.agenturl();
        } else if (type == "refresh_token") {
            data.refresh_token <- tokenCode;
        } else {
            throw "Unknown grant_type";
        }

        local body = http.urlencode(data);

        http.post(url, headers, body).sendasync(function(resp) {
            local respData = http.jsondecode(resp.body);
            local err = null;

            // If there was an error, set the error code
            if (resp.statuscode != 200) err = data.message;

            // Invoke the callback
            if (cb) imp.wakeup(0, function() { cb(err, resp, respData); });
        });
    }
}


/***************************************************************************************
 * SmartFrigDataManager Class:
 *      Handle incoming device readings
 *      Set sensor threshold values
 *      Set callback handlers for events and streaming data
 *      Check for temperature, humidity, and door events
 *      Average temperature and humidity readings
 **************************************************************************************/
class SmartFrigDataManager {

    // Default settings
    static DEFAULT_LX_THRESHOLD = 50; // LX level indicating door open
    static DEFAULT_TEMP_THRESHOLD = 11;
    static DEFAULT_HUMID_THRESHOLD = 70;

    // NOTE: changing the device reading or reporting intervals will impact timing of event and alert conditions
    static DOOR_OPEN_ALERT = 10; // Number of reading cycles before activating a door alert (currently 30s: DOOR_OPEN_ALERT * device reading interval = seconds before sending door alert)
    static CLEAR_DOOR_OPEN_EVENT = 180; // Clear door open event after num seconds (prevents temperature or humidity alerts right after is opened)
    static TEMP_ALERT_CONDITION = 900; // Number of seconds the temperature must be over threshold before triggering event
    static HUMID_ALERT_CONDITION = 900; // Number of seconds the humidity must be over threshold before triggering event

    // Class variables
    _bull = null;

    // Threshold
    _tempThreshold = null;
    _humidThreshold = null;
    _lxThreshold = null;
    _thresholdsUpdated = null;

    // Alert flags and counters
    _doorOpenTS = null;
    _doorOpenCounter = null;
    _doorOpenAlertTriggered = null;
    _tempAlertTriggered = null;
    _humidAlertTriggered = null;
    _tempEventTime = null;
    _humidEventTime = null;

    // Event handlers
    _doorOpenHandler = null;
    _streamReadingsHandler = null;
    _tempAlertHandler = null;
    _humidAlertHandler = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      bullwinkle : instance - of Bullwinkle class
     **************************************************************************************/
    constructor(bullwinkle) {
        _bull = bullwinkle;
        setThresholds(DEFAULT_TEMP_THRESHOLD, DEFAULT_HUMID_THRESHOLD, DEFAULT_LX_THRESHOLD);

        _doorOpenCounter = 0;

        openListeners();
    }

     /***************************************************************************************
     * openListeners
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function openListeners() {
        _bull.on("readings", _readingsHandler.bindenv(this));
        _bull.on("lxThreshold", _lxThresholdHandler.bindenv(this));
        return this;
    }

    /***************************************************************************************
     * setThresholds
     * Returns: null
     * Parameters:
     *      temp : integer - new tempertature threshold value
     *      humid : integer - new humid threshold value
     *      lx : integer - new light level door  value
     **************************************************************************************/
    function setThresholds(temp, humid, lx) {
        _tempThreshold = temp;
        _humidThreshold = humid;
        _lxThreshold = lx;
        _thresholdsUpdated = true;
    }

    /***************************************************************************************
     * setDoorOpenHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when door open alert triggered
     **************************************************************************************/
    function setDoorOpenHandler(cb) {
        _doorOpenHandler = cb;
    }

    /***************************************************************************************
     * setStreamReadingsHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when new reading received
     **************************************************************************************/
    function setStreamReadingsHandler(cb) {
        _streamReadingsHandler = cb;
    }

    /***************************************************************************************
     * setTempAlertHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when temperature alert triggerd
     **************************************************************************************/
    function setTempAlertHandler(cb) {
        _tempAlertHandler = cb;
    }

    /***************************************************************************************
     * setHumidAlertHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when humidity alert triggerd
     **************************************************************************************/
    function setHumidAlertHandler(cb) {
        _humidAlertHandler = cb;
    }

    /***************************************************************************************
     * _lxThresholdHandler
     * Returns: null
     * Parameters:
     *      message : table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _lxThresholdHandler(message, reply) {
        if (_thresholdsUpdated) {
            reply(_lxThreshold);
            _thresholdsUpdated = false;
        } else {
            reply(null);
        }
    }

    /***************************************************************************************
     * _readingsHandler
     * Returns: null
     * Parameters:
     *      message : table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _readingsHandler(message, reply) {
        // grab readings array from message
        local readings = message.data;

        // set up variables for calculating reading average
        local tempAvg = 0;
        local humidAvg = 0
        local numReadings = 0;

        // set up variables for door event
        local doorOpen = null;
        local ts = null;

        // process readings
        // reading table keys : "brightness", "humidity", "temperature", "ts"
        foreach(reading in readings) {
            // calculate temperature and humidity totals
            if ("temperature" in reading && "humidity" in reading) {
                numReadings++;
                tempAvg += reading.temperature;
                humidAvg += reading.humidity;
            }

            // get time stamp of reading
            ts = reading.ts;

            // determine door status
            if ("brightness" in reading) doorOpen = _checkDoorEvent(ts, reading.brightness);
        }

        if (numReadings != 0) {
            // average the temperature and humidity readings
            tempAvg = tempAvg/numReadings;
            humidAvg = humidAvg/numReadings;

            // check for events
            _checkTempEvent(tempAvg, ts);
            _checkHumidEvent(humidAvg, ts);
        }

        // send reading to handler
        _streamReadingsHandler({"temperature" : tempAvg, "humidity" : humidAvg, "door" : doorOpen}, ts);
        // send ack to device (device erases this set of readings when ack received)
        reply("OK");
    }

    /***************************************************************************************
     * _checkTempEvent
     * Returns: null
     * Parameters:
     *      reading : float - a temperature reading
     **************************************************************************************/
    function _checkTempEvent(reading, ts) {
        // check for temp event
        if (reading > _tempThreshold) {
            // check that frig door hasn't been open recently & that alert hasn't been sent
            if (_doorOpenTS == null && !_tempAlertTriggered) {
                // create event timer
                if (_tempEventTime == null) {
                    _tempEventTime = ts + TEMP_ALERT_CONDITION;
                }
                // check that alert conditions have exceeded the time needed to trigger alert
                if (ts >= _tempEventTime) {
                    // Trigger Temp Alert
                    _tempAlertHandler(reading, ts, _tempThreshold);
                    // Set flag so we don't trigger the same alert again
                    _tempAlertTriggered = true;
                    // Reset Temp Event timer
                    _tempEventTime = null;
                }
            }
        } else {
            // Reset Temp Alert Conditions
            _tempAlertTriggered = false;
            _tempEventTime = null;
        }
    }

    /***************************************************************************************
     * _checkHumidEvent
     * Returns: null
     * Parameters:
     *      reading : float - a humidity reading
     **************************************************************************************/
    function _checkHumidEvent(reading, ts) {
        // check for humidity event
        if (reading > _humidThreshold) {
            // check that frig door hasn't been open recently & that alert hasn't been sent
            if (_doorOpenTS == null && !_humidAlertTriggered) {
                // create event timer
                if (_humidEventTime == null) {
                    _humidEventTime = ts + HUMID_ALERT_CONDITION;
                }
                // check that alert conditions have exceeded the time needed to trigger alert
                if ( ts >= _humidEventTime) {
                    // Trigger Humidity Alert
                    _humidAlertHandler(reading, ts, _humidThreshold);
                    // Set flag so we don't trigger the same alert again
                    _humidAlertTriggered = true;
                    // Reset Humidity timer
                    _humidEventTime = null;
                }
            }
        } else {
            // Reset Hmidity Alert Conditions
            _humidAlertTriggered = false;
            _humidEventTime = null;
        }
    }

    /***************************************************************************************
     * _checkDoorEvent
     * Returns: sting - door status
     * Parameters:
     *      lxLevel : float - a light reading
     *      readingTS : integer - the timestamp of the reading
     **************************************************************************************/
    function _checkDoorEvent(readingTS, lxLevel = null) {
        // Boolean if door open event occurred
        local doorOpen = (lxLevel == null || lxLevel > _lxThreshold);

        // check if door open
        if (doorOpen) {
            _doorOpenCounter++;
            // check if door timer started
            if (!_doorOpenTS) {
                // start door timer
                _doorOpenTS = readingTS;
            // check that door alert conditions have been met
            } else if (!_doorOpenAlertTriggered && _doorOpenCounter > DOOR_OPEN_ALERT) {
                // trigger door open alert
                _doorOpenAlertTriggered = readingTS;
                _doorOpenHandler(readingTS - _doorOpenTS);
            }
        } else {
            // since door is closed, reset door open alert conditions
            _doorOpenCounter = 0;
            _doorOpenAlertTriggered = null;

            // check that door timer can be reset
            if (_doorOpenTS && (readingTS - _doorOpenTS) >= CLEAR_DOOR_OPEN_EVENT ) {
                // since door closed for set ammount of time, reset door event timer
                _doorOpenTS = null;
            }
        }
        return (doorOpen) ? "Open" : "Closed";
    }

}


// APPLICATION CLASS TO SEND FRIG DATA/ALERTS TO SALESFORCE
// ----------------------------------------------------------
class Application {

    _dm = null;
    _force = null;
    _deviceID = null;
    _objName = null;

    constructor(key, secret, objName) {
        _deviceID = imp.configparams.deviceid.tostring();
        _objName = objName;
        initializeClasses(key, secret);
        setDataMngrHandlers();
    }

    function initializeClasses(key, secret) {
        local _bull = Bullwinkle();

        _dm = SmartFrigDataManager(_bull);
        _force = SalesforceOAuth2(key, secret);
    }

    function setDataMngrHandlers() {
        _dm.setDoorOpenHandler(doorOpenHandler.bindenv(this));
        _dm.setStreamReadingsHandler(streamReadingsHandler.bindenv(this));
        _dm.setTempAlertHandler(tempAlertHandler.bindenv(this));
        _dm.setHumidAlertHandler(humidAlertHandler.bindenv(this));
    }

    function updateRecord(data, cb = null) {
        local url = format("sobjects/%s/DeviceId__c/%s?_HttpMethod=PATCH", _objName, _deviceID);
        local body = {};

        // add salesforce custom object postfix to data keys
        foreach(k, v in data) {
            body[k + "__c"] <- v;
        }

        // don't send if we are not logged in
        if (!_force.isLoggedIn()) {
            server.error("Not logged into saleforce.")
            return;
        }
        _force.request("POST", url, http.jsonencode(body), cb);
    }


    function openCase(subject, description, cb = null) {
        local data = {
            "Subject": subject,
            "Description": description,
            "Related_Fridge__r" : {"DeviceId__c": _deviceID}
        };

        // don't send if we are not logged in
        if (!_force.isLoggedIn()) {
            server.error("Not logged into saleforce.")
            return;
        }
        _force.request("POST", "sobjects/Case", http.jsonencode(data), cb);
    }

    function streamReadingsHandler(reading, ts) {
        reading.ts <- ts;
        server.log(http.jsonencode(reading));
        updateRecord(reading, updateRecordResHandler);
    }

    function doorOpenHandler(doorOpenFor) {
        local alert = "Refrigerator Door Open";
        local description = format("Refrigerator with id %s door has been open for %s seconds.", _deviceID, doorOpenFor.tostring());
        server.log("Door Open Alert: door has been open for " + doorOpenFor + " seconds.");
        openCase(alert, description, caseResponseHandler);
    }

    function tempAlertHandler(latestReading, alertTiggeredTime, threshold) {
        local alert = "Temperature Over Threshold";
        local description = format("Refrigerator with id %s temperature above %s °C. Refrigerator temperature is %s °C", _deviceID, threshold.tostring(), latestReading.tostring());
        server.log(alert + ": " + description);
        openCase(alert, description, caseResponseHandler);
    }

    function humidAlertHandler(latestReading, alertTiggeredTime, threshold) {
        local alert = "Humidity Over Threshold";
        local description = format("Refrigerator with id %s humidity above %s%s. Refrigerator humidity is %s%s", _deviceID, threshold.tostring(), "%", latestReading.tostring(), "%");
        server.log(alert + ": " + description);
        openCase(alert, description, caseResponseHandler);
    }

    function caseResponseHandler(err, data) {
        if (err) {
            server.error(http.jsonencode(err));
            return;
        }

        server.log("Created case with id: " + data.id);
    }

    function updateRecordResHandler(err, respData) {
        if (err) {
            server.error(http.jsonencode(err));
            return;
        }

        // Log a message for creating/updating a record
        if ("success" in respData) {
            server.log("Record created: " + respData.success);
        }
    }
}


// RUNTIME
// ---------------------------------------------------------------------------------

// SALESFORCE CONSTANTS
// ----------------------------------------------------------
const CONSUMER_KEY = "<YOUR CONSUMER KEY HERE>";
const CONSUMER_SECRET = "<YOUR CONSUMER SECRET HERE>";
const OBJ_API_NAME = "SmartFridge__c";

Application(CONSUMER_KEY, CONSUMER_SECRET, OBJ_API_NAME);
