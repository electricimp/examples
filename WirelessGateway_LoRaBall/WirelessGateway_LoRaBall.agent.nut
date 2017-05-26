#require "IBMWatson.class.nut:1.1.0"
#require "Dweetio.class.nut:1.0.1"

/***************************************************************************************
 * Application Class:
 *      Initializes Watson
 *      Creates/Updates Device Type & Device on IBM Watson platform
 *      Listen for sensor readings & publishes them to IBM Watson
 **************************************************************************************/
class Application {
    // Watson Device Information
    static DEVICE_TYPE_ID = "LoRa_Accel_Ball";
    static DEVICE_TYPE_DESCRIPTION = "LoRa Accelerometer Ball Demo";
    static DEVICE_MANUFACTURER = "Electric Imp";

    static STREAMING_EVENT_ID = "AccelerometerData";
    static FREEFALL_EVENT_ID = "FreefallEvent";

    // Alert messages
    static FREEFALL_EVENT_MESSAGE = "Ball throw detected";
    static FREEFALL_EVENT_DONE = "Throw the ball";

    static EVENT_DURATION = 3;
    static LORA_DEVICE_ID = "Ball_01"; // RED BALL

    watson = null;
    dweetClient = null;
    _deviceConfigured = false;
    _deviceID = null;
    _deviceInfo = {};
    _meta = {};

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      apiKey: string - Watson API Key
     *      authToken: string - Watson Auth Token
     *      orgID: string - Watson organization ID
     **************************************************************************************/
    constructor(apiKey, authToken, orgID) {
        // Primary Dashboard
        watson = IBMWatson(apiKey, authToken, orgID);
        // Backup Dashboard
        dweetClient = DweetIO();

        openListeners();
        setDevInfo();

        // Create/update device type and device in Watson, then sets ready flag
        createDevType();
    }

    /***************************************************************************************
     * createDevType
     * Parameters: none
     **************************************************************************************/
    function createDevType() {
        watson.getDeviceType(DEVICE_TYPE_ID, function(err, res) {
            switch (err) {
                case watson.MISSING_RESOURCE_ERROR:
                    // dev type doesn't exist yet create it
                    local typeInfo = {"id" : DEVICE_TYPE_ID, "description" : DEVICE_TYPE_DESCRIPTION};
                    watson.addDeviceType(typeInfo, function(error, response) {
                        if (error != null) server.error(error);
                        createDev();
                        server.log("Dev type created");
                    }.bindenv(this));
                    break;
                case null:
                    // dev type exists, good to use for this device
                    createDev();
                    server.log("Dev type exists");
                    break;
                default:
                    server.error(err);
            }
        }.bindenv(this));
    }

    /***************************************************************************************
     * openListeners
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function openListeners() {
        device.on("reading", streamReadingsHandler.bindenv(this));
        device.on("event", eventHandler.bindenv(this));
        return this;
    }

    /***************************************************************************************
     * setBasicDevInfo
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function setDevInfo() {
        _deviceID = LORA_DEVICE_ID;
        _deviceInfo = {"manufacturer" : DEVICE_MANUFACTURER};
        _meta = {};
        return this;
    }

    /***************************************************************************************
     * createDev - creates or updates device on Watson platform
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function createDev() {
        watson.getDevice(DEVICE_TYPE_ID, _deviceID, function(err, res) {
            switch (err) {
                case watson.MISSING_RESOURCE_ERROR:
                    // dev doesn't exist yet create it
                    local info = {"deviceId": _deviceID,  "deviceInfo" : _deviceInfo, "metadata" : _meta};
                    watson.addDevice(DEVICE_TYPE_ID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        _deviceConfigured = true;
                        server.log("Dev created");
                    }.bindenv(this));
                    break;
                case null:
                    // dev exists, update
                    local info = {"deviceInfo" : _deviceInfo, "metadata" : _meta};
                    watson.updateDevice(DEVICE_TYPE_ID, _deviceID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                       _deviceConfigured = true;
                    }.bindenv(this));
                    break;
                default:
                    // we encountered an error
                    server.error(err);
            }
        }.bindenv(this));
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * streamReadingsHandler
     * Returns: null
     * Parameters:
     *      reading : table - temperature, humidity and door status
     **************************************************************************************/
    function streamReadingsHandler(reading) {
        // log the incoming reading
        server.log(http.jsonencode(reading));

        // set up data structure expected by Watson
        local data = { "d": reading,
                       "ts": watson.formatTimestamp(time()) };

        // Post data if Watson device configured
        if (_deviceConfigured) {
            watson.postData(DEVICE_TYPE_ID, _deviceID, STREAMING_EVENT_ID, data, watsonResponseHandler.bindenv(this));
        }

        // send data using the imp device's id so movement update rate limits don't step on alerts
        // Post data to dweet/freeboard
        dweetClient.dweet(imp.configparams.deviceid, data, dweetRespHandler.bindenv(this));
    }

    /***************************************************************************************
     * eventHandler
     * Returns: null
     * Parameters:
     *      event: table with event details
     **************************************************************************************/
    function eventHandler(event) {
        server.log(format("%s: %s", FREEFALL_EVENT_ID, FREEFALL_EVENT_MESSAGE));
        // set up Watson data structure
        local data = { "d" :  { "alert" : FREEFALL_EVENT_ID,
                                "deviceID": _deviceID,
                                "description" : FREEFALL_EVENT_MESSAGE,
                                "eventActive" : true,
                                "ts" : watson.formatTimestamp(time()) }};

        // Send alert if Watson device configured
        if (_deviceConfigured) {
            watson.postData(DEVICE_TYPE_ID, _deviceID, FREEFALL_EVENT_ID, data, watsonResponseHandler.bindenv(this));
        }
        // Post data to dweet/freebard
        server.log("sending dweet event begin")
        dweetClient.dweet(_deviceID, data, dweetRespHandler.bindenv(this));

        // Send Event Over Alert
        sendEventDone(_deviceConfigured);
    }

     /***************************************************************************************
     * sendEventDone
     * Returns: null
     * Parameters:
     *      toWatson: bool if should send to watson
     **************************************************************************************/
    function sendEventDone(toWatson) {
        local data = { "d" :  { "alert" : FREEFALL_EVENT_ID,
                                "deviceID": _deviceID,
                                "description" : FREEFALL_EVENT_DONE,
                                "eventActive" : false,
                                "ts" : watson.formatTimestamp(time()) }};

        // Reset Event state
        imp.wakeup(EVENT_DURATION, function() {
            if (toWatson) watson.postData(DEVICE_TYPE_ID, _deviceID, FREEFALL_EVENT_ID, data, watsonResponseHandler.bindenv(this));
            server.log("sending dweet event end")
            dweetClient.dweet(_deviceID, data, dweetRespHandler.bindenv(this));
        }.bindenv(this));
    }

    /***************************************************************************************
     * watsonResponseHandler
     * Returns: null
     * Parameters:
     *      err : string/null - error message
     *      res : table - response table
     **************************************************************************************/
    function watsonResponseHandler(err, res) {
        if(err) server.error(err);
        if(res.statuscode == 200) server.log("Watson request successful.");
    }

    /***************************************************************************************
     * dweetRespHandler
     * Returns: null
     * Parameters:
     *      res : table - response table
     **************************************************************************************/
    function dweetRespHandler(res) {
        if (res.statuscode == 200) {
            local body = http.jsondecode(res.body);
            server.log("Dweet " + body["this"]);
            if (body["this"] == "failed") {
                server.log("Dweet : " + res.body);
            }
        }
    }
}

// RUNTIME
// ----------------------------------------------

// Watson API Auth Keys
const API_KEY = "";
const AUTH_TOKEN = "";
const ORG_ID = "";

//  Start Up App
app <- Application(API_KEY, AUTH_TOKEN, ORG_ID);