// Simple Remote Monitoring Application Agent Code
// ---------------------------------------------------

// WEBSERVICE LIBRARY
// ---------------------------------------------------
// Libraries must be required before all other code

// Initial State Library
#require "InitialState.class.nut:1.0.0"
#require "IBMWatson.class.nut:1.1.0"

// WEBSERVICE WRAPPER CLASSES
// ---------------------------------------------------
// Not all webservices behave in the same way. These classes will
// register this device with the webservice if needed. They also 
// configure the data before sending.

class IState {

    iState = null;
    agentID = null;

    constructor(_agentID, StreamingAccessKey) {
        iState = InitialState(StreamingAccessKey);
        agentID = _agentID;
    }

    function send(data) {
        // Initial State requires the data in a specific structre
        // Build an array with the data from our reading.
        local events = [];
        events.push({"key" : "temperature", "value" : data.temperature, "epoch" : data.time});
        events.push({"key" : "humidity", "value" : data.humidity, "epoch" : data.time});
        events.push({"key" : "pressure", "value" : data.pressure, "epoch" : data.time});
        events.push({"key" : "accel_x", "value" : data.accel_x, "epoch" : data.time});
        events.push({"key" : "accel_y", "value" : data.accel_y, "epoch" : data.time});
        events.push({"key" : "accel_z", "value" : data.accel_z, "epoch" : data.time});

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
    static DEVICE_TYPE             = "Electric_Imp";
    static DEVICE_TYPE_DESCRIPTION = "Electric Imp";
    static EVENT_ID                = "RemoteMonitoringData";

    // Time to wait before sending if device is not ready
    static SEND_DELAY_SEC = 5;

    watson   = null;
    agentID  = null;
    boot     = true;
    ready    = false;

    constructor(_agentID, apiKey, authToken, orgId) {
        agentID = _agentID;
        watson = IBMWatson(apiKey, authToken, orgId);
        configureWatson();

        // Turn off boot flag
        imp.wakeup(10, function() { boot = false }.bindenv(this));
    }

    function send(data) {
        local data = { "d": { "data": data },
                       "ts": watson.formatTimestamp() };
        if (ready) {
            watson.postData(DEVICE_TYPE, agentID, EVENT_ID, data, function(error, response) {
                if (error) {
                    server.error("Watson send error: " + error);
                } else {
                    server.log("Watson send successful");
                }
            })
        } else if (boot) {
            server.log("Watson device being configured. Will send data in " + SEND_DELAY_SEC + " seconds.");
            imp.wakeup(SEND_DELAY_SEC, function() {
                watson.postData(DEVICE_TYPE, agentID, EVENT_ID, data, function(error, response) {
                    if (error) {
                        server.error("Watson send error: " + error);
                    } else {
                        server.log("Watson send successful");
                    }
                })
            }.bindenv(this))
        } else {
            server.log("Watson not configured, cannot send data.");
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
        watson.getDevice(DEVICE_TYPE, agentID, function(err, res) {
            switch (err) {
                case watson.MISSING_RESOURCE_ERROR:
                    // Device doesn't exist yet create it
                    local info = {"deviceId": agentID,  "deviceInfo" : {}, "metadata" : {}};
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
                    watson.updateDevice(DEVICE_TYPE, agentID, info, function(error, response) {
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


// REMOTE MONITORING APPLICATION CODE
// ---------------------------------------------------
// Application code, listen for readings from device,
// when a reading is received send the data to Initial 
// State 

class Application {

    // Class variables
    iState  = null;
    watson  = null;
    agentID = null;

    constructor(iStateKey, watsonAPIKey, watsonAuthToken, watsonOrgID) {
        // The Initial State library will create a bucket  
        // using the agent ID 
        agentID = split(http.agenturl(), "/").top();
        // Let's log the agent ID here
        server.log("Agent ID: " + agentID);

        // Initialize Initial State Wrapper Class
        iState = IState(agentID, iStateKey);

        // Initialize Watson Wrapper Class
        watson = Watson(agentID, watsonAPIKey, watsonAuthToken, watsonOrgID);

        device.on("reading", readingHandler.bindenv(this));
    }

    function readingHandler(reading) {
        // Log the reading from the device. The reading is a 
        // table, so use JSON encodeing method convert to a string
        server.log(http.jsonencode(reading));

        // Send reading to the webservices 
        iState.send(reading);
        watson.send(reading);
    }

}


// RUNTIME
// ---------------------------------------------------
server.log("Agent running...");

// On Intial State website navigate to "my account" 
// page find/create a "Streaming Access Key"
// Paste it into the variable below
const IS_STREAMING_ACCESS_KEY = "<YOUR STREAMING ACCESS KEY>";

// Watson API Auth Keys
// See library examples for step by step Watson setup
const WATSON_API_KEY = "<YOUR API KEY HERE>";
const WATSON_AUTH_TOKEN = "<YOUR AUTHENTICATION TOKEN HERE>";
const WATSON_ORG_ID = "<YOUR ORG ID>";

// Run the Application
Application(IS_STREAMING_ACCESS_KEY, WATSON_API_KEY, WATSON_AUTH_TOKEN, WATSON_ORG_ID);
