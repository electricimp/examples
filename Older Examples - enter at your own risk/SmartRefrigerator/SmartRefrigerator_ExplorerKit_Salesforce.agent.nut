//line 1 "agent.nut"
// Utility Libraries
#require "Rocky.class.nut:1.2.3"
#require "bullwinkle.class.nut:2.3.2"
// Web Integration Library
#require "Salesforce.class.nut:1.1.0"

// Extends Salesforce Library to handle authorization
//line 1 "SalesforceOAuth2.class.nut"
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
}//line 9 "agent.nut"
// Class that receives and handles data sent from device SmartFridgeApp
//line 1 "SmartFrigDataManager.class.nut"
/***************************************************************************************
 * SmartFrigDataManager Class:
 *      Handle incoming device readings and events
 *      Set callback handlers for events and streaming data
 *      Average temperature and humidity readings
 *
 * Dependencies
 *      Bullwinle (passed into the constructor)
 **************************************************************************************/
class SmartFrigDataManager {

    static DEBUG_LOGGING = true;

    // Event types (these should match device side event types in SmartFrigDataManager)
    static EVENT_TYPE_TEMP_ALERT = "temperaure alert";
    static EVENT_TYPE_HUMID_ALERT = "humidity alert";
    static EVENT_TYPE_DOOR_ALERT = "door alert";
    static EVENT_TYPE_DOOR_STATUS = "door status";

    _streamReadingsHandler = null;
    _doorOpenAlertHandler = null;
    _tempAlertHandler = null;
    _humidAlertHandler = null;

    // Class instances
    _bull = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      bullwinkle : instance - of Bullwinkle class
     **************************************************************************************/
    constructor(bullwinkle) {
        _bull = bullwinkle;
        openListeners();
    }

     /***************************************************************************************
     * openListeners
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function openListeners() {
        _bull.on("update", _readingsHandler.bindenv(this));
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
     * setDoorOpenAlertHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when door open alert triggered
     **************************************************************************************/
    function setDoorOpenAlertHandler(cb) {
        _doorOpenAlertHandler = cb;
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

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _getAverage
     * Returns: null
     * Parameters:
     *      readings : table of readings
     *      type : key from the readings table for the readings to average
     *      numReadings: number of readings in the table
     **************************************************************************************/
    function _getAverage(readings, type, numReadings) {
        if (numReadings == 1) {
            return readings[0][type];
        } else {
            local total = readings.reduce(function(prev, current) {
                    return (!(type in prev)) ? prev + current[type] : prev[type] + current[type];
                })
            return total / numReadings;
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
        local data = message.data;
        local streamingData = { "ts" : time() };
        local numReadings = data.readings.len();

        // send ack to device (device erases this set of readings/events when ack received)
        reply("OK");

        if (DEBUG_LOGGING) {
            server.log("in readings handler")
            server.log(http.jsonencode(data.readings));
            server.log(http.jsonencode(data.doorStatus));
            server.log(http.jsonencode(data.events));
            server.log("Current time: " + time())
        }

        if ("readings" in data && numReadings > 0) {

            // Update streaming data table with temperature and humidity averages
            streamingData.temperature <- _getAverage(data.readings, "temperature", numReadings);
            streamingData.humidity <- _getAverage(data.readings, "humidity", numReadings);
        }

        if ("doorStatus" in data) {
            // Update streaming data table
            streamingData.door <- data.doorStatus.currentStatus;
        }

        // send streaming data to handler
        _streamReadingsHandler(streamingData);

        if ("events" in data && data.events.len() > 0) {
            // handle events
            foreach (event in data.events) {
                switch (event.type) {
                    case EVENT_TYPE_TEMP_ALERT :
                        _tempAlertHandler(event);
                        break;
                    case EVENT_TYPE_HUMID_ALERT :
                        _humidAlertHandler(event);
                        break;
                    case EVENT_TYPE_DOOR_ALERT :
                        _doorOpenAlertHandler(event);
                        break;
                    case EVENT_TYPE_DOOR_STATUS :
                        break;
                }
            }
        }
    }

}
//line 11 "agent.nut"


/***************************************************************************************
 * Application Class:
 *      Sends data and alerts to Salesforce
 *
 * Dependencies
 *      Bullwinkle Library
 *      Rocky Library
 *      Salesforce Library, SalesforceOAuth2 Class
 *      SmartFrigDataManager Class
 **************************************************************************************/
class Application {

    static DOOR_ALERT = "Refrigerator Door Open";
    static TEMP_ALERT = "Temperature Over Threshold";
    static HUMID_ALERT = "Humidity Over Threshold";

    _dm = null;
    _force = null;
    _deviceID = null;
    _objName = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      key : string - Yor Consumer Key (created in Salesforce App settings)
     *      secret : string - Yor Consumer Secret (created in Salesforce App settings)
     *      objName : string - Your Object API Name (created in Salesforce)
     **************************************************************************************/
    constructor(key, secret, objName) {
        _deviceID = imp.configparams.deviceid.tostring();
        _objName = objName;
        initializeClasses(key, secret);
        setDataMngrHandlers();
    }

    /***************************************************************************************
     * initializeClasses
     * Returns: null
     * Parameters:
     *      key : string - Yor Consumer Key (created in Salesforce App settings)
     *      secret : string - Yor Consumer Secret (created in Salesforce App settings)
     **************************************************************************************/
    function initializeClasses(key, secret) {
        local _bull = Bullwinkle();

        _dm = SmartFrigDataManager(_bull);
        _force = SalesforceOAuth2(key, secret);
    }

    /***************************************************************************************
     * setDataMngrHandlers
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function setDataMngrHandlers() {
        _dm.setDoorOpenAlertHandler(doorOpenHandler.bindenv(this));
        _dm.setStreamReadingsHandler(streamReadingsHandler.bindenv(this));
        _dm.setTempAlertHandler(tempAlertHandler.bindenv(this));
        _dm.setHumidAlertHandler(humidAlertHandler.bindenv(this));
    }

    /***************************************************************************************
     * updateRecord
     * Returns: null
     * Parameters:
     *      data : table - temperature, humidity, door status and ts
     *      cb(optional) : function - callback executed when http request completes
     **************************************************************************************/
    function updateRecord(data, cb = null) {
        local url = format("sobjects/%s/DeviceId__c/%s?_HttpMethod=PATCH", _objName, _deviceID);
        local body = {};

        // add salesforce custom object postfix to data keys
        foreach(k, v in data) {
            if (k == "ts") { v = formatTimestamp(v); }
            body[k + "__c"] <- v;
        }

        // don't send if we are not logged in
        if (!_force.isLoggedIn()) {
            server.error("Not logged into saleforce.")
            return;
        }
        _force.request("POST", url, http.jsonencode(body), cb);
    }

    /***************************************************************************************
     * openCase
     * Returns: null
     * Parameters:
     *      subject : string - type of alert, will be the subject of the case
     *      description : string - description of event
     *      cb(optional) : function - callback executed when http request completes
     **************************************************************************************/
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

    /***************************************************************************************
     * streamReadingsHandler
     * Returns: null
     * Parameters:
     *      reading : table - temperature, humidity and door status
     **************************************************************************************/
    function streamReadingsHandler(reading) {
        server.log(http.jsonencode(reading));
        updateRecord(reading, updateRecordResHandler);
    }

    /***************************************************************************************
     * doorOpenHandler
     * Returns: null
     * Parameters:
     *      event: table with event details
     **************************************************************************************/
    function doorOpenHandler(event) {
        // { "description": "door has been open for 33 seconds", "type": "door alert", "ts": 1478110044 }
        local description = format("Refrigerator with id %s %s.", _deviceID, event.description);
        server.log(DOOR_ALERT + ": " + description);
        openCase(DOOR_ALERT, description, caseResponseHandler);
    }

    /***************************************************************************************
     * tempAlertHandler
     * Returns: null
     * Parameters:
     *      event: table with event details
     **************************************************************************************/
    function tempAlertHandler(event) {
        local description = format("Refrigerator with id %s %s. Current temperature is %s°C.", _deviceID, event.description, event.latestReading.tostring());
        server.log(TEMP_ALERT + ": " + description);
        openCase(TEMP_ALERT, description, caseResponseHandler);
    }

    /***************************************************************************************
     * humidAlertHandler
     * Returns: null
     * Parameters:
     *      event: table with event details
     **************************************************************************************/
    function humidAlertHandler(event) {
        local description = format("Refrigerator with id %s %s. Current humidity is %s%s.", _deviceID, event.description, event.latestReading.tostring(), "%");
        server.log(HUMID_ALERT + ": " + description);
        openCase(HUMID_ALERT, description, caseResponseHandler);
    }

    /***************************************************************************************
     * caseResponseHandler
     * Returns: null
     * Parameters:
     *      err : string/null - error message
     *      data : table - response table
     **************************************************************************************/
    function caseResponseHandler(err, data) {
        if (err) {
            server.error(http.jsonencode(err));
            return;
        }

        server.log("Created case with id: " + data.id);
    }

    /***************************************************************************************
     * updateRecordResHandler
     * Returns: null
     * Parameters:
     *      err : string/null - error message
     *      respData : table - response table
     **************************************************************************************/
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

    /***************************************************************************************
     * formatTimestamp
     * Returns: time formatted as "2015-12-03T00:54:51Z"
     * Parameters:
     *      ts (optional) : integer - epoch timestamp
     **************************************************************************************/
    function formatTimestamp(ts = null) {
        local d = ts ? date(ts) : date();
        return format("%04d-%02d-%02dT%02d:%02d:%02dZ", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
    }
}


// RUNTIME
// ---------------------------------------------------------------------------------

// SALESFORCE CONSTANTS
// ----------------------------------------------------------
const CONSUMER_KEY = "<YOUR_CONSUMER_KEY_HERE>";
const CONSUMER_SECRET = "<YOUR_CONSUMER_SECRET_HERE>";
const OBJ_API_NAME = "SmartFridge__c";

// Start Application
Application(CONSUMER_KEY, CONSUMER_SECRET, OBJ_API_NAME);