// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// WEBSERVICE LIBRARY
// ---------------------------------------------------
// Libraries must be required before all other code

// Initial State Library
#require "InitialState.class.nut:1.0.0"

// APPLICATION CODE
// ---------------------------------------------------
// Application code, listen for readings from device,
// when a reading is received send the data to Initial 
// State 
class Application {

    // On Intial State website navigate to "my account" 
    // page find/create a "Streaming Access Key"
    // Paste it into the variable below
    static STREAMING_ACCESS_KEY = "";

    static TEMP_ALERT = 30;

    static RED = 0x00;
    static YELLOW = 0x01;
    static GREEN = 0x02;

    // Class variables
    iState = null;
    agentID = null;

    constructor(connectionString, deviceConnectionString = null) {
        // Initialize Initial State
        iState = InitialState(STREAMING_ACCESS_KEY);

        // The Initial State library will create a bucket  
        // using the agent ID 
        agentID = split(http.agenturl(), "/").top();
        // Let's log the agent ID here
        server.log("Agent ID: " + agentID);

        device.on("event", eventHandler.bindenv(this));
    }

    function eventHandler(event) {
        // Log the reading from the device. The reading is a 
        // table, so use JSON encodeing method convert to a string
        server.log(http.jsonencode(event));

        // Initial State requires the data in a specific structre
        // Build an array with the data from our reading.
        if ("temperature" in event) {
            local now = time();
            local events = [];
            events.push({"key" : "temperature", "value" : event.temperature, "epoch" : now});
            events.push({"key" : "temperatureAlert", "value" : (event.temperature > TEMP_ALERT), "epoch" : now});

            // Send reading to Initial State
            iState.sendEvents(events, function(err, resp) {
                if (err != null) {
                    // We had trouble sending to Initial State, log the error
                    server.error("Error sending to Initial State: " + err);
                    device.send("blink", RED);
                } else {
                    // A successful send. The response is an empty string, so
                    // just log a generic send message
                    server.log("Reading sent to Initial State.");
                    device.send("blink", YELLOW);
                }
            })
        }
        
    }
}

// Start the Application
Application();