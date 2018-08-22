// Power Efficient Refrigerator Monitor Agent Code
// -------------------------------------------------------

// WEBSERVICE LIBRARY
// -------------------------------------------------------
// Libraries must be required before all other code

// Initial State Library
#require "InitialState.class.nut:1.0.0"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.2.0"

// POWER EFFICIENT REFRIGERATOR MONITOR APPLICATION CODE
// -------------------------------------------------------
// Application code, listen for readings from device,
// when a reading is received send the data to Initial
// State

class Application {

    // On Intial State website navigate to "my account"
    // page find/create a "Streaming Access Key"
    // Paste it into the variable below
    static STREAMING_ACCESS_KEY = "";

    // Class variables
    iState = null;
    agentID = null;
    mm = null;

    constructor() {
        // Initialize Initial State
        iState = InitialState(STREAMING_ACCESS_KEY);
        // Configure message manager for device/agent communication
        mm = MessageManager();

        // The Initial State library will create a bucket
        // using the agent ID
        agentID = split(http.agenturl(), "/").top();
        // Let's log the agent ID here
        server.log("Agent ID: " + agentID);

        mm.on("data", dataHandler.bindenv(this));
    }

    function dataHandler(msg, reply) {
        // Log the data from the device. The data is a
        // table, so use JSON encodeing method convert to a string
        // server.log(http.jsonencode(msg.data));

        // Initial State requires the data in a specific structre
        // Build an array with the data from our reading.
        local events = [];

        // Add door status
        server.log("Door is open: " + msg.data.doorOpen);
        events.push({"key" : "doorOpen", "value" : msg.data.doorOpen});

        // Add readings
        if ("readings" in msg.data) {
            server.log(http.jsonencode(msg.data.readings));
            foreach (reading in msg.data.readings) {
                events.push({"key" : "temperature", "value" : reading.temperature, "epoch" : reading.time});
                events.push({"key" : "humidity", "value" : reading.humidity, "epoch" : reading.time});
            }
        }

        // Add alerts
        if ("alerts" in msg.data) {
            server.log(http.jsonencode(msg.data.alerts));
            foreach (alertType, alertVal in msg.data.alerts) {
                events.push({"key" : alertType, "value" : alertVal, "epoch" : time()});
            }
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


// RUNTIME
// ---------------------------------------------------
server.log("Agent running...");

// Run the Application
Application();
