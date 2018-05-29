// // Cellular Breakout Example - Reading a Sensor Agent Code
// ----------------------------------------------------------

// WEBSERVICE LIBRARY
// ----------------------------------------------------------
// Libraries must be included before all other code

// Initial State Library
#require "InitialState.class.nut:1.0.0"


// SETUP
// ----------------------------------------------------------
// Set up an account with Initial State. Log in and
// navigate to "my account" page.

// On "my account" page find/create a "Streaming Access Key"
// Paste it into the constant below
const STREAMING_ACCESS_KEY = "";

// Initialize Initial State
local iState = InitialState(STREAMING_ACCESS_KEY);

// The library will create a bucket using the agent ID
// Let's log the agent ID here
local agentID = split(http.agenturl(), "/").top();
server.log("Agent ID: " + agentID);


// RUNTIME
// ----------------------------------------------------------
server.log("Agent running...");

// Open listener for "reading" messages from the device
device.on("reading", function(reading) {
    // Log the reading from the device. The reading is a
    // table, so use JSON encodeing method convert to a string
    server.log(http.jsonencode(reading));
    // Initial State requires the data in a specific structre
    // Build an array with the data from our reading.
    local events = [];
    events.push({"key" : "x", "value" : reading.x, "epoch" : time()});
    events.push({"key" : "y", "value" : reading.y, "epoch" : time()});
    events.push({"key" : "z", "value" : reading.z, "epoch" : time()});

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
})