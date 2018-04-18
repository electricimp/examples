// MIT License
//
// Copyright 2018 Electric Imp
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

// MICROSOFT AZURE IOT HUB LIBRARY
#require "AzureIoTHub.agent.lib.nut:2.0.0"

/* APPLICATION CLASS
 *     - Opens a connection to Azure IoT Hub using the connection string 
 *       generated from Azure IoT Central  
 *     - Sends temperature readings, threshold and alert data to Azure */
class IoTHubTempMonitor {

    // Unique identifier created by imp
    agentID = null;

    // Unique identifier created by IoTCentral
    iotHubDevID = null;

    // Instance of IoTHub Library client
    client = null;

    // Connection state of device's connection to IoTHub
    connected = false;

    // Sets unique IDs for the device, opens a listener to receive 
    // temperature readings/alerts from device, creates and opens a 
    // connection to Azure IoT Hub.
    //      
    // Parameters: 
    //      deviceConnectionString  (required)      String from IoT Central used to open a 
    //                                              connection to IoT Hub                                             
    // Returns:                                     Instance of IoTHubTempMonitor class
    constructor(deviceConnectionString = null) {
        agentID = split(http.agenturl(), "/").pop();
        iotHubDevID = getIoTHubDevId(deviceConnectionString);

        // Create an IoT Hub client and open a connection to IoT hub 
        createClient(deviceConnectionString);

        // Open listener to receive temperature messages from device
        device.on("temp", tempEventHandler.bindenv(this));
    }

    // Parses device connection string to retrieve device Id assigned to the device
    // from IoT Central.
    //      
    // Parameters: 
    //      deviceConnectionString  (required)      Connection string from IoT Central                                    
    // Returns:                                     String device Id
    function getIoTHubDevId(deviceConnectionString) {
        local id = split(deviceConnectionString, ";")[1];
        local start = id.find("=") + 1;
        return id.slice(start);
    }

    // Processes temperature messages sent from the device. And sends to IoT Central via IoT Hub
    //      
    // Parameters: 
    //      event  (required)      Data table from device :  
    //                                  { "temperature"      : latest temp reading (float),
    //                                    "temperatureLimit" : current temperature threshold (integer),
    //                                    "temperatureAlert" : 0 if temp equal to or above threshold, 1 if temp below (integer) };
    // Returns:                    Null
    function tempEventHandler(event) {

        // Create properties for IoT Hub message
        local properties = null;

        // Add device id's and time stamp to event data
        event.agentId  <- agentID;
        event.deviceId <- iotHubDevID;
        event.time     <- formatDate();
        
        // Create an IoT Hub message 
        local message = AzureIoTHub.Message(event, properties);

        // If device is connected, send event to IoT Hub
        if (connected) {
            server.log("Sending message: " + http.jsonencode(message.getBody()));
            client.sendEvent(message, function(err) {
                if (err) {
                     server.error("Failed to send message to Azure IoT Hub: " + err);
                } else {
                    server.log("Message sent to Azure IoT Hub");
                }
            }.bindenv(this));
        } else {
            server.log("Device not connected. Cannot send message:");
            server.log(http.jsonencode(message.getBody()));
        }
    }

    // Create a IoT hub client and open a connection
    //      
    // Parameters: 
    //      deviceConnectionString  (required)      String from IoT Central used to open a 
    //                                              connection to IoT Hub  
    // Returns:                                     Null
    function createClient(devConnectionString) {
        client = AzureIoTHub.Client(devConnectionString);
        client.connect(function(err) {
            if (err) {
                server.error(err);
            } else {
                connected = true;
                server.log("Device connected to IoT hub.");
            }
        }.bindenv(this));
    }

    // Formats the date object as a UTC string
    // 
    // Parameters:  None
    // Returns:     UTC formatted time string  
    function formatDate() {
        local d = date();
        return format("%04d-%02d-%02d %02d:%02d:%02d", d.year, (d.month+1), d.day, d.hour, d.min, d.sec);
    }
}

// RUNTIME
// ---------------------------------------------------------------
server.log("AGENT RUNNING...");

// Connection string from IoT Central
const DEVICE_CONNECTION_STRING = "<YOUR_DEVICE_CONNECTION_STRING_HERE>";

// Start the Application
IoTHubTempMonitor(DEVICE_CONNECTION_STRING);
