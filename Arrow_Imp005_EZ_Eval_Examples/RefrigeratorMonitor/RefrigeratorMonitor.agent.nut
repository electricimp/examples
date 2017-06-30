// Refrigerator Monitor Application Agent Code
// ---------------------------------------------------

// WEBSERVICE LIBRARYS
// ---------------------------------------------------
// Libraries must be required before all other code


// IBM Watson Library
#require "IBMWatson.class.nut:1.1.0"
// Initial State Library
#require "InitialState.class.nut:1.0.0"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.0.0"


// WEBSERVICE WRAPPER CLASSES
// ---------------------------------------------------
// Not all webservices behave in the same way. These classes will
// register this device with the webservice if needed. They also 
// configure the data before sending.

class IState {

    iState = null;
    devID = null;

    constructor(_devID, StreamingAccessKey) {
        iState = InitialState(StreamingAccessKey);
        devID = _devID;
    }

    function send(data) {
        // Initial State requires the data in a specific structure
        // Build an array with the data from our reading.
        local events = [];

        foreach (reading in data) {
            events.push({"key" : "temperature", "value" : reading.temperature, "epoch" : reading.time});
            events.push({"key" : "humidity", "value" : reading.humidity, "epoch" : reading.time});
            events.push({"key" : "door_open", "value" : reading.doorOpen, "epoch" : reading.time});
        }

        // Send reading to Initial State
        iState.sendEvents(events, function(err, resp) {
            if (err != null) {
                // We had trouble sending to Initial State, log the error
                server.error("Error sending to Initial State: " + err);
            } else {
                // A successful send. The response is an empty string, so
                // just log a generic send message
                server.log("Reading sent to Initial State.");
            }
        })
    }

}

class Watson {

    // Watson Settings
    static DEVICE_TYPE = "Arrow_Imp005_EZ";
    static DEVICE_TYPE_DESCRIPTION = "Arrow Imp 005 EZ Eval";
    static EVENT_ID = "RefrigeratorMonitor";

    // Time to wait before sending if device is not ready
    static SEND_DELAY_SEC = 5;

    watson = null;
    devID = null;

    ready = false;

    constructor(_devID, apiKey, authToken, orgId) {
        watson = IBMWatson(apiKey, authToken, orgId);
        devID = _devID;
    }

    function send(data) {
        local data = { "d": { "data": data },
                       "ts": watson.formatTimestamp() };
        if (ready) {
            watson.postData(DEVICE_TYPE, devID, EVENT_ID, data, function(error, response) {
                if (error) {
                    server.error("Watson send error: " + error);
                } else {
                    server.log("Watson send successful");
                }
            })
        } else {
            server.log("Watson device being configured. Will send data in " + SEND_DELAY_SEC + " seconds.");
            imp.wakeup(SEND_DELAY_SEC, function() {
                watson.postData(DEVICE_TYPE, devID, EVENT_ID, data, function(error, response) {
                    if (error) {
                        server.error("Watson send error: " + error);
                    } else {
                        server.log("Watson send successful");
                    }
                })
            }.bindenv(this))
        }

    }

    function configureWatson() {
        watson.getDeviceType(DEVICE_TYPE, function(err, res) {
            switch (err) {
                case watson.MISSING_RESOURCE_ERROR:
                    // Device type doesn't exist yet create it
                    local typeInfo = {"id" : DEVICE_TYPE, "description" : DEVICE_TYPE_DESCRIPTION};
                    watson.addDeviceType(typeInfo, function(error, response) {
                        if (error != null) {
                            server.error(error);
                        } else {
                            server.log("Dev type created");
                            createDev();
                        }
                    }.bindenv(this));
                    break;
                case null:
                    // Device type exists, good to use for this device
                    server.log("Dev type exists");
                    createDev();
                    break;
                default:
                    // We encountered an error
                    server.error(err);
            }
        }.bindenv(this));
    }

    function createDev() {
        watson.getDevice(DEVICE_TYPE, devID, function(err, res) {
            switch (err) {
                case watson.MISSING_RESOURCE_ERROR:
                    // Device doesn't exist yet create it
                    local info = {"deviceId": devID,  "deviceInfo" : {}, "metadata" : {}};
                    watson.addDevice(DEVICE_TYPE, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        server.log("Dev created");
                        // Watson is now ready to receive data from this device
                        ready = true;
                    }.bindenv(this));
                    break;
                case null:
                    // Device exists, update
                    local info = {"deviceInfo" : {}, "metadata" : {}};
                    watson.updateDevice(DEVICE_TYPE, devID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        // Watson is now ready to receive data from this device
                        ready = true;
                    }.bindenv(this));
                    break;
                default:
                    // We encountered an error
                    server.error(err);
            }
        }.bindenv(this));
    }

}


// REFRIGERATOR MONTOR APPLICATION CODE
// ---------------------------------------------------
// Application code, listen for readings from device,
// when a reading is received send the data to Initial 
// State 

class SmartFridge {

    // Class variables
    iState = null;
    deviceID = null;
    mm = null;

    constructor(watsonApiKey, watsonAuthToken, watsonOrgId, iStateAccessKey = null) {
        // Get the device ID
        deviceID = imp.configparams.deviceid;

        // Initialize Watson
        watson = Watson(deviceID, watsonApiKey, watsonAuthToken, watsonOrgId);

        // Initialize Initial State if we have a key
        if (iStateAccessKey != null) {
            iState = IState(deviceID, iStateAccessKey);
        }

        // Configure message manager for device/agent communication
        mm = MessageManager();

        mm.on("readings", readingsHandler.bindenv(this));
    }

    function readingsHandler(msg, reply) {
        watson.send(msg.data);
        if (iState) iState.send(msg.data);
    }

}


// RUNTIME
// ---------------------------------------------------
server.log("Agent running...");

// Initial state is optional if you wish to push data 
// add your "Streaming Access Key" to the variable below
// On Intial State website navigate to "my account" 
// page find/create a "Streaming Access Key"
// Paste it into the variable below
const IS_STREAMING_ACCESS_KEY = null;

// Watson API Auth Keys
// See library examples for step by step Watson setup
const WATSON_API_KEY = "<YOUR API KEY HERE>";
const WATSON_AUTH_TOKEN = "<YOUR AUTHENTICATION TOKEN HERE>";
const WATSON_ORG_ID = "<YOUR ORG ID>";

// Run the Application
SmartFridge(WATSON_API_KEY, WATSON_AUTH_TOKEN, WATSON_ORG_ID, IS_STREAMING_ACCESS_KEY);
