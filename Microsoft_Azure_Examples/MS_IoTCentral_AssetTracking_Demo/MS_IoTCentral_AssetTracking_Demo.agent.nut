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
#require "utilities.lib.nut:2.0.0" 

// Azure IoT Hub 3.0.0 and above requires agent server with MQTT support
#require "AzureIoTHub.agent.lib.nut:4.0.0"
 
// Agent code for IoT Central Asset Tracking demo
//
// Note: This code is demo quality
class Application {

    // Same as in device
    static RED = 0x00;
    static YELLOW = 0x01;
    static GREEN = 0x02;
    static DEVICE_CONNECT_DELAY = 15;
    
    _client = null;
    // registry = null;
    // hostName = null;
    _agentID = null;
    _deviceID = null;
    _blinkColor = 0;
    _gmaps = null;
    _deviceConnected = null;
    _prevDeviceConnected = null;
    _cellUtils = null;
    
    
    constructor(gmapsKey, connectionString, deviceConnectionString = null) {
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

        _gmaps = GoogleMaps(gmapsKey);
        _cellUtils = CellUtils(gmapsKey);

        device.on("telemetry", telemetryHandler.bindenv(this));
        device.on("location", locationHandler.bindenv(this));
        device.on("pong", pongHandler.bindenv(this));
        device.on("connect", connectHandler.bindenv(this));

        _blinkColor = YELLOW;
        _deviceConnected = false;
        _prevDeviceConnected = false;
    }
    
    // Run the application
    function run() {

        // Give device time to connect
        if (imp.wakeup(DEVICE_CONNECT_DELAY, _statusLoop.bindenv(this)) == null) {
            server.error("_statusLoop timer fail");
        }
        
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
            _client.sendMessage(message, function(err, msg) {
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
            switch (locationData.type) {
                case "wifi":
                    server.log("using WiFi location");
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
                break;
                case "cell":
                    server.log("no GPS fix, using cellular location");
                    _cellUtils.setCellStatus(locationData.cellinfo);
                    // TODO: only need to compute this is the cell info has changed
                    _cellUtils.getGeolocation(function(location) {
                        locationProp.location.lon = location.lng;     
                        locationProp.location.lat = location.lat;    
                        server.log("Updating location as: " + http.jsonencode(locationProp));
                        _client.updateTwinProperties(locationProp, _onTwinUpdated.bindenv(this));
                    }.bindenv(this));
                break;
                case "gps":
                    server.log("using GPS location");
                    // TODO: only need to compute this is the gps location has changed
                    locationProp.location.lon = locationData.location.lng;     
                    locationProp.location.lat = locationData.location.lat;    
                    server.log("Updating location as: " + http.jsonencode(locationProp));
                    _client.updateTwinProperties(locationProp, _onTwinUpdated.bindenv(this));
                break;
            } // switch
            
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
        
        if (imp.wakeup(10, _statusHandler.bindenv(this)) == null) {
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
            _client.sendMessage(message, function(err, msg) {
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

    // On connecting, do the following
    function connectHandler(netInfo) {
        
        // Send network info to IoT Hub 
        local info = netInfo.interface[netInfo.active];
        local type = info.type;

        switch(type) {
            case "wifi":
                // The imp is on a wifi connection: Get ssid
                local networkString = "WiFi: " + info.ssid;
                _updateNetwork(networkString);
            break;
            case "ethernet":
                // Not really supporting Ethernet connections in this app 
                server.log("Device on Ethernet");
            break;
            case "cell":
                // The imp is on a cellular connection: Get mcc and mnc
                _cellUtils.setCellStatus(netInfo.cellinfo);
                _cellUtils.getCarrierInfo(function(networkString) {
                    _updateNetwork(networkString);
                }.bindenv(this));
            break;
        } // switch
        
        // Retrieve current properties on connect
        _retrieveTwinProperties();

    }

    // Update network info Device Twin property
    function _updateNetwork(networkInfo) {
        server.log("networkString: " + networkInfo);
        local networkProp = { "network" : networkInfo };

        if (_client.isConnected()) {
                server.log("Updating network info as: " + http.jsonencode(networkProp));
                _client.updateTwinProperties(networkProp, _onTwinUpdated.bindenv(this)); 
        } else {
            server.log("Not connected to Azure: Not sending network info")
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
        
        // server.log("Desired twin properties:");
        // _printTable(desProps);

        // Make sure device updates itself with desired properties
        _onTwinRequest(desProps);

    }
    
    // Triggered by Azure: Desired properties to device
    function _onTwinRequest(props) {

        local updated = false;
        local updatedProps = {};

        server.log("Desired twin properties:");
        _printTable(props);

        // update device accordingly 
        foreach (key, value in props) {
            
            if (key == "reportingInterval") {
                device.send("reporting", value.value);
                updated = true;
                // sync back to IoT Hub and IoT Central
                updatedProps.reportingInterval <- { 
                        "value" : value.value,
                        "statusCode" : "200",
                        "status" : "completed",
                        "desiredVersion" : props["$version"]
                    };
            }
            
            if (key == "ledColor") {
                switch (value.value) {
                    case "RED": _blinkColor = RED; break;
                    case "YELLOW": _blinkColor = YELLOW; break;
                    case "GREEN": _blinkColor = GREEN; break;
                }
                device.send("color", _blinkColor);
                updated = true;
                // sync back to IoT Hub and IoT Central
                updatedProps.ledColor <- { 
                        "value" : value.value,
                        "statusCode" : "200",
                        "status" : "completed",
                        "desiredVersion" : props["$version"]
                    };
            }
        }
        
        if (updated) {
            if (_client.isConnected()) {
                server.log("Reporting desired props as: " + http.jsonencode(updatedProps));
                _client.updateTwinProperties(updatedProps, _onTwinUpdated.bindenv(this));
            } else {
                server.log("Not connected to Azure: Not updating props")
            }
        }
        
    }
    
    // Triggered by Device: Updated properties to Azure
    function _onTwinUpdated(err, props) {
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

            //deleteProperty();  // If there is a property to delete, do it here

            // Don't retrieve current properties here, will be done when device connects
        }
    } 
    
    function deleteProperty() {
        // Used to delete properties
        local prop = {"example" : null };
        _client.updateTwinProperties(prop, _onTwinUpdated.bindenv(this));
    }
    
    // Called when direct method functionality has been enabled
    function _onMethodDone(err) {
        if (err != 0) {
            server.error("Enabling Direct Methods failed: " + err);
        } else {
            // server.log("Direct Methods enabled successfully");
        }
    }
    
    function _onMethod(name, params, reply) {
        server.log("Direct Method called. Name: " + name);
        _printTable(params);
        device.send("restart", true);
        local responseStatusCode = 200;  
        local responseBody = {"restart" : "done"}; 
        local data = AzureIoTHub.DirectMethodResponse(responseStatusCode, responseBody);
        reply(data);
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
        server.log("Connected to Azure");
        
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
            server.error("Disconnected from Azure unexpectedly with code: " + err);
            // Reconnect if disconnection is not initiated by application
            if (imp.wakeup(10, _delayedReconnect.bindenv(this)) == null) {
                server.error("_delayedReconnect timer fail");
            }
        } else {
            server.log("Disconnected from Azure by application");
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

// Set of utility functions around cellular
class CellUtils {
    
    _cellStatus = {
        "time"   : 0,
        "type"   : "na",
        "earfcn" : 0,
        "band"   : "-",
        "dlbw"   : 0,
        "ulbw"   : 0,
        "mode"   : "na",
        "mcc"    : "000",
        "mnc"    : "000",
        "tac"    : "na",
        "cellid" : "-",
        "physid" : "",
        "srxlev" : "-",
        "rsrp"   : "-",
        "rsrq"   : "-",
        "state"  : ""
    };
    
    // Set cellular status based on cellinfo string
    function setCellStatus(cellinfo) {
        
        try {
            local str = split(cellinfo, ",");
            _cellStatus.time = time();
    
            switch(str[0]) {
                case "4G":
                    _cellStatus.type    ="LTE";
                    _cellStatus.earfcn  = str[1];
                    _cellStatus.band    = str[2];
                    _cellStatus.dlbw    = str[3];
                    _cellStatus.ulbw    = str[4];
                    _cellStatus.mode    = str[5];
                    _cellStatus.mcc     = str[6];
                    _cellStatus.mnc     = str[7];
                    _cellStatus.tac     = str[8];
                    _cellStatus.cellid  = str[9];
                    _cellStatus.physid  = str[10];
                    _cellStatus.srxlev  = str[11];
                    _cellStatus.rsrp    = str[12];
                    _cellStatus.rsrq    = str[13];
                    _cellStatus.state   = str[14];
                    break;
    
                case "3G":
                    _cellStatus.type    ="HSPA";
                    _cellStatus.earfcn  = str[1];
                    _cellStatus.band    = "na";
                    _cellStatus.dlbw    = "na";
                    _cellStatus.ulbw    = "na";
                    _cellStatus.mode    = "na";
                    _cellStatus.mcc     = str[5];
                    _cellStatus.mnc     = str[6];
                    _cellStatus.tac     = str[7];
                    _cellStatus.cellid  = str[8];
                    _cellStatus.physid  = "na";
                    _cellStatus.srxlev  = str[10];
                    _cellStatus.rsrp    = str[4];
                    _cellStatus.rsrq    = "na";
                    _cellStatus.state   = "na";
                    break;
            }
        } catch(err) {
            server.log("Input: " + cellinfo);
            server.error("Parse error: " + err);
        }
        
    }
    
    // Get carrier name and country based on cellular info
    function getCarrierInfo(cb) {
        
        // Load csv file with mcc/mnc information to find network country and carrier name
        local request = http.get("https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.csv");
        request.sendasync(function(response) {
            
            local carrier = null;
            local country = null;
           
            if (response.statuscode == 200) {
                // Search the response for the place with the right mcc and mnc 
                local expr = regexp(_cellStatus.mcc + ",.+," + _cellStatus.mnc + ",.+\\n");
                local result = expr.search(response.body);
                if (result != null) {
                    // Get the entry and break it into substrings to get country and carrier
                    local entry = response.body.slice(result.begin, result.end)
                    local expr2 = regexp(@"(.+,)(.+,)(.+,)(.+,)(.+,)(.+,)(.+,)(.+)");
                    local results = expr2.capture(entry);
                    if (results) {
                        foreach (idx, value in results) {
                            local subString = entry.slice(value.begin, value.end-1)
                            if (idx == 6) { country = subString };
                            if (idx == 8) { carrier = subString };
                        }
                        local networkString = "Cellular: " + country + ", " + carrier;
                        // server.log("networkString: " + networkString);
                        cb(networkString);
                    }
                } else {
                    server.log("Carrier info not found");
                    return null;
                }
            } else {
                server.error("Carrier info http request: " + response.statuscode);
            }
        }.bindenv(this)); 
        
    } 

    // Get location based on cellular triangulation
    function getGeolocation(cb) {
        
        // Explicitly calling Google Maps for now as the current library only supports WiFi, not cellular
        local LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";

        local cell = {
            "cellId": utilities.hexStringToInteger(_cellStatus.cellid),
            "locationAreaCode": utilities.hexStringToInteger(_cellStatus.tac),
            "mobileCountryCode": _cellStatus.mcc,
            "mobileNetworkCode": _cellStatus.mnc
        };

        // Build request
        local url = format("%s%s", LOCATION_URL, GOOGLE_MAPS_KEY);
        local headers = { "Content-Type" : "application/json" };
        local body = {
            "considerIp": "false",
            "radioType": "lte",
            "cellTowers": [cell]
        };
    
        // send requst
        local request = http.post(url, headers, http.jsonencode(body));
        request.sendasync(function(res) {
            local body;
            try {
                body = http.jsondecode(res.body);
            } catch(e) {
                server.error("Geolocation parsing error: " + e);
            }
    
            if (res.statuscode == 200) {
                // Update stored state variables
                local lat = body.location.lat;
                local lng = body.location.lng;
                cb(body.location);
            } else {
                server.error("Geolocation unexpected reponse: " + res.statuscode);
            }
        }.bindenv(this));
    }

} // CellUtils

////////// Application Variables //////////

GOOGLE_MAPS_KEY <- "<add key>";
softwareVersion <- "4.1";

// IoT Central now uses SAS for device authentication
// To create a deviceConnectionString, use the dps_cstr command
// https://docs.microsoft.com/en-us/azure/iot-central/concepts-connectivity#getting-device-connection-string
deviceConnectionString <- null;

if (http.agenturl() == "<add url>") { 
    server.log("*** Agent starting for impC Breakout Tracker ..."); 
    deviceConnectionString = "<add connection string>";
} else if (http.agenturl() == "<add url>") {
    server.log("*** Agent starting for impExplorer Tracker ..."); 
    deviceConnectionString = "<add connection string>";
} else {
    server.error("unknown device");  
} 

// Start the Application
app <- Application(GOOGLE_MAPS_KEY, null, deviceConnectionString);
app.run()