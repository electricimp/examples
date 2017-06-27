// Power Efficient Remote Monitoring Application Agent Code
// ---------------------------------------------------

// WEBSERVICE LIBRARY
// ---------------------------------------------------
// Libraries must be required before all other code

// Initial State Library
#require "InitialState.class.nut:1.0.0"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.0.0"

// REMOTE MONITORING APPLICATION CODE
// ---------------------------------------------------
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

        mm.on("readings", readingsHandler.bindenv(this));
    }

    function readingsHandler(msg, reply) {
        // Initial State requires the data in a specific structre
        // Build an array with the data from our reading.
        local events = [];

        foreach (reading in msg.data) {
            // Log the reading from the device. The reading is a 
            // table, so use JSON encodeing method convert to a string
            server.log(http.jsonencode(reading));

            events.push({"key" : "temperature", "value" : reading.temperature, "epoch" : reading.time});
            events.push({"key" : "humidity", "value" : reading.humidity, "epoch" : reading.time});
            events.push({"key" : "pressure", "value" : reading.pressure, "epoch" : reading.time});
            events.push({"key" : "accel_x", "value" : reading.accel_x, "epoch" : reading.time});
            events.push({"key" : "accel_y", "value" : reading.accel_y, "epoch" : reading.time});
            events.push({"key" : "accel_z", "value" : reading.accel_z, "epoch" : reading.time});
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
