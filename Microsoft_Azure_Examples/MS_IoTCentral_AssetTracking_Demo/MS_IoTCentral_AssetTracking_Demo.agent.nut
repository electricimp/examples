// MIT License
//
// Copyright 2015-2018 Electric Imp
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

#require "GoogleMaps.agent.lib.nut:1.0.0"

// Azure IoT Hub 3.0.0 and above requires agent server with MQTT support
#require "AzureIoTHub.agent.lib.nut:3.0.0"

// Agent code for IoT Central Asset Tracking demo
//
// Note: This code is demo quality
class Application {

    // Same as in device
    static RED = 0x00;
    static YELLOW = 0x01;
    static GREEN = 0x02;
    
    static GOOGLE_API_KEY = "AIzaSyDk1e0Yu9bgGEsE5MwIiZ0vEKS9SbxvW7Y";
    
    _client = null;
    // registry = null;
    // hostName = null;
    _agentID = null;
    _deviceID = null;
    _blinkColor = 0;
    _gmaps = null;
    _deviceConnected = null;
    _prevDeviceConnected = null;
    
    constructor(connectionString, deviceConnectionString = null) {
        _agentID = split(http.agenturl(), "/").pop();
        _deviceID = imp.configparams.deviceid;

        if (deviceConnectionString) {
            // We have registered device previously
            _createClient(deviceConnectionString);
        } else {
            server.error("Should not be registering device");
            // connectionString = connectionString;
            // hostName = AzureIoTHub.ConnectionString.Parse(connectionString).HostName;
            // registry = AzureIoTHub.Registry(connectionString);
            // registerDevice();
        }

        _gmaps = GoogleMaps(GOOGLE_API_KEY);

        device.on("telemetry", telemetryHandler.bindenv(this));
        device.on("location", locationHandler.bindenv(this));
        device.on("pong", pongHandler.bindenv(this));
        
        if (imp.wakeup(10, _statusLoop.bindenv(this)) == null) {
            server.error("_statusLoop timer fail");
        }
        
        _blinkColor = YELLOW;
        _deviceConnected = false;
        _prevDeviceConnected = false;
    }

    // function registerDevice() {
    //     // Find this device in the registry
    //     registry.get(_deviceID, function(err, iotHubDev) {
    //         if (err) {
    //             if (err.response.statuscode == 404) {
    //                 // No such device, let's create it, connect & open receiver
    //                 registry.create({"deviceId" : _deviceID}, function(error, iotHubDevice) {
    //                     if (error) {
    //                         server.error(error.message);
    //                     } else {
    //                         server.log("Dev created " + iotHubDevice.getBody().deviceId);
    //                         createClient(iotHubDevice.connectionString(hostName));
    //                     }
    //                 }.bindenv(this)); 
    //             } else {
    //                 server.error(err.message);
    //             }
    //         } else {
    //             // Found device, let's connect & open receiver
    //             server.log("Device registered as " + iotHubDev.getBody().deviceId);
    //             createClient(iotHubDev.connectionString(hostName));
    //         }
    //     }.bindenv(this));
    // }

    // Send telemetry data to IoT Hub
    function telemetryHandler(telemetryData) {
        
        telemetryData.agentid <- _agentID;
        telemetryData.time <- _formatDate();
        
        local message = AzureIoTHub.Message(http.jsonencode(telemetryData));

        if (_client.isConnected()) {
            _client.sendMessage(message, function(msg, err) {
                if (err) { 
                     server.error("Failed to send message to Azure IoT Hub: " + err);
                } else {
                    server.log("Telemetry sent to Azure IoT Hub: " + message.getBody());
                }
            }.bindenv(this));
        } else {
            server.log("Not connected to Azure: Not sending telemetry data")
        }
    } 
    
    // Send location data to IoT Hub
    // Supports either GPS location or WiFi location (via Google Places)
    function locationHandler(locationData) { 
        
        local locationProp = { "location" : { "lon" : 0, "lat" : 0 } };

        if (_client.isConnected()) {
            if (locationData.type == "wifi") {
                _gmaps.getGeolocation(locationData.networks, function(error, resp) {
                    if (error != null) {
                        server.error(error);
                    } else {
                        locationProp.location.lon = resp.location.lng;
                        locationProp.location.lat = resp.location.lat;
                        server.log("Updating location as: " + http.jsonencode(locationProp));
                        _client.updateTwinProperties(locationProp, _onTwinUpdated.bindenv(this));
                    }
                }.bindenv(this));
            } else {
                locationProp.location.lon = locationData.coord.lng;     
                locationProp.location.lat = locationData.coord.lat;    
                server.log("Updating location as: " + http.jsonencode(locationProp));
                _client.updateTwinProperties(locationProp, _onTwinUpdated.bindenv(this));
            }
        } else {
            server.log("Not connected to Azure: Not sending location data")
        }
    }
    
    // For connection status check
    function pongHandler(startTime) {
        _deviceConnected = true;
    }
    
    
    // Check connection status
    function _statusCheck() {

        _deviceConnected = false;
        device.send("ping", time());
        
        if (imp.wakeup(5, _statusHandler.bindenv(this)) == null) {
            server.error("_statusHandler timer fail");
        }
        
    }
    
    // Send connection status to IoT Hub
    function _statusHandler() {

        // _deviceConnected has been set by pongHandler
        if (_deviceConnected == _prevDeviceConnected) {
            // nothing to do, return
            return;
        }
        _prevDeviceConnected = _deviceConnected;
        
        // Need to send online status both as telemetry and as property 
        // because IoT Central display limitations
        
        // send as telemetry
        local telemetryData = {};
        telemetryData.online <- _deviceConnected.tostring();
        telemetryData.agentid <- _agentID;
        telemetryData.time <- _formatDate();
        
        local message = AzureIoTHub.Message(http.jsonencode(telemetryData));

        if (_client.isConnected()) {
            _client.sendMessage(message, function(msg, err) {
                if (err) { 
                     server.error("Failed to send message to Azure IoT Hub: " + err);
                } else {
                    server.log("Status sent to Azure IoT Hub: " + message.getBody());
                }
            }.bindenv(this));
        } else {
            server.log("Not connected to Azure: Not sending telemetry data")
        }

        // send as property
        local onlineProp = { "online" : _deviceConnected.tostring() };

        if (_client.isConnected()) {
            server.log("Updating status as: " + http.jsonencode(onlineProp));
            _client.updateTwinProperties(onlineProp, _onTwinUpdated.bindenv(this));
        } else {
            server.log("Not connected to Azure: Not sending location data")
        }
        
    }
    
    // Periodically check the online status of the device
    function _statusLoop() {
        
        _statusCheck();
        if (imp.wakeup(10, _statusLoop.bindenv(this)) == null) {
            server.error("_statusLoop timer fail");
        }
    }

    // Triggered by Device: Azure view of properties to device
    function _onTwinRetrieved(err, repProps, desProps) {
        if (err != 0) {
            server.error("Retrieving Twin properties failed: " + err);
            return;
        }
        server.log("Reported twin properties:");
        _printTable(repProps);
        
        server.log("Desired twin properties");
        _printTable(desProps);
    }
    
    // Triggered by Azure: Desired properties to device
    function _onTwinRequest(props) {
        
        server.log("Desired twin properties:");
        _printTable(props);

        // update device accordingly
        foreach (key, value in props) {
            
            if (key == "reportingInterval") {
                device.send("reporting", value.value);
            }
            
            if (key == "ledColor") {
                switch (value.value) {
                    case "RED": _blinkColor = RED; break;
                    case "YELLOW": _blinkColor = YELLOW; break;
                    case "GREEN": _blinkColor = GREEN; break;
                }
                device.send("color", _blinkColor);
            }
        }

    }
    
    // Triggered by Device: Updated properties to Azure
    function _onTwinUpdated(props, err) {
        if (err != 0) {
            server.error("Twin properties update failed: " + err);
        } else {
            // server.log("Twin properties updated successfully");
        }
    }

    // Retrieve device twin properties
    function _retrieveTwinProperties() {
        _client.retrieveTwinProperties(_onTwinRetrieved.bindenv(this));
    }
     
    // Called when device twin functionality has been enabled
    function _onTwinDone(err) {
        if (err != 0) {
            server.error("Enabling Twins functionality failed: " + err);
        } else {
            // server.log("Twins functionality enabled successfully");
            
            // Only push the software version on start-up
            local prop = {"softwareVersion" : softwareVersion };
            _client.updateTwinProperties(prop, _onTwinUpdated.bindenv(this));

            //deleteProperty();  // Delete a property

            // Retrieve all properties on start-up
            if (imp.wakeup(3, _retrieveTwinProperties.bindenv(this)) == null) {
                server.error("_retrieveTwinProperties timer fail");
            }
        }
    } 
    
    // function deleteProperty() {
    //     // Used to delete properties
    //     prop = {"prop" : null };
    //     _client.updateTwinProperties(prop, _onTwinUpdated.bindenv(this));
    // }
    
    // Called when direct method functionality has been enabled
    function _onMethodDone(err) {
        if (err != 0) {
            server.error("Enabling Direct Methods failed: " + err);
        } else {
            // server.log("Direct Methods enabled successfully");
        }
    }
    
    // Called when direct method is triggered
    function _onMethod(name, params) {
        server.log("Direct Method called. Name: " + name);
        _printTable(params);
        device.send("restart", true);
        local responseStatusCode = 200; 
        local responseBody = {"restart" : "done"};
        return AzureIoTHub.DirectMethodResponse(responseStatusCode, responseBody);
    }
    
    // Called when IoT Hub connection is established
    function _onConnected(err) {
        
        //server.log("onConnected"); 
        
        if (err != 0) {
            server.error("Connect to Azure failed: " + err);
            // Reconnect later
            if (imp.wakeup(10, _delayedReconnect.bindenv(this)) == null) {
                server.error("_delayedReconnect timer fail");
            }
        }
        server.log("Device connected to Azure");
        
        // Enable required features
        _client.enableIncomingMessages(_receiveHandler.bindenv(this));
        _client.enableTwin(_onTwinRequest.bindenv(this), _onTwinDone.bindenv(this)); 
        _client.enableDirectMethods(_onMethod.bindenv(this), _onMethodDone.bindenv(this));        
    }

    // Retry to connect after a delay
    function _delayedReconnect() {
        server.log("Reconnect to Azure ...");
        _client.connect();
    }

    // Called when IoT Hub connection is lost
    function _onDisconnected(err) {
        
        //server.log("onDisconnected");  
        if (err != 0) {
            server.error("Device disconnected from Azure unexpectedly with code: " + err);
            // Reconnect if disconnection is not initiated by application
            if (imp.wakeup(10, _delayedReconnect.bindenv(this)) == null) {
                server.error("_delayedReconnect timer fail");
            }
        } else {
            server.log("Device disconnected from Azure by application");
        }
    }
    
    // Create a client, open a connection and receive listener
    function _createClient(devConnectionString) {
        
        _client = AzureIoTHub.Client(devConnectionString, 
            _onConnected.bindenv(this), _onDisconnected.bindenv(this));
        server.log("Connecting to Azure ..."); 
        _client.connect();
   
    }

    // Called when message from IoT Hub is received
    function _receiveHandler(err, delivery) {
        
        if (err) {
            server.error(err);
            return;
        }
 
        local message = delivery.getMessage();

        // send feedback
        if (typeof message.getBody() == "blob") {
            server.log("Received message: " + message.getBody().tostring());
            // do something
            server.log(http.jsonencode(message.getProperties()));
            delivery.complete();
        } else {
            delivery.reject();
        }
    }

    // Utility to print a table
    function _printTable(table) {
        foreach (key, value in table) {
            server.log(key + ": " + value);
            if ((typeof value) == "table") {
                foreach (k, v in value) {
                    server.log("{ " + k + ": " + v + " }");
                } 
            }
        }
    }
    
    // Utility to format the date object as a UTC string
    function _formatDate() {
        local d = date();
        return format("%04d-%02d-%02d %02d:%02d:%02d", d.year, (d.month+1), d.day, d.hour, d.min, d.sec);
    }
    
} // Application

////////// Application Variables //////////

softwareVersion <- "3.2.3";

// IoT Central now uses SAS for device authentication
// To create a deviceConnectionString, use the dps_cstr command
// https://docs.microsoft.com/en-us/azure/iot-central/concepts-connectivity#getting-device-connection-string
deviceConnectionString <- null;

if (http.agenturl() == "<impC breakout tracker agenturl>") { 
    server.log("*** Agent starting for impC Breakout Tracker ..."); 
    deviceConnectionString = "<impC breakout tracker connectionString>";
} else if (http.agenturl() == "impExplorer Tracker agenturl") {
    server.log("*** Agent starting for impExplorer Tracker ..."); 
    deviceConnectionString = "<impExplorer tracker connectionString";
} else {
    server.error("unknown device");  
} 

// Start the Application
Application(null, deviceConnectionString);