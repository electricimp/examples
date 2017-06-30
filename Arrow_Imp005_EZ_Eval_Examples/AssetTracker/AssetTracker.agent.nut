// Asset Tracker Application Agent Code
// ---------------------------------------------------

// WEBSERVICE LIBRARYS
// ---------------------------------------------------
// Libraries must be required before all other code

// IBM Watson Library
#require "IBMWatson.class.nut:1.1.0"


// WEBSERVICE WRAPPER CLASSES
// ---------------------------------------------------
// Not all webservices behave in the same way. These classes will
// register this device with the webservice if needed. They also 
// configure the data before sending.

class Watson {

    // Watson Settings
    static DEVICE_TYPE = "Arrow_Imp005_EZ";
    static DEVICE_TYPE_DESCRIPTION = "Arrow Imp 005 EZ Eval";
    static EVENT_ID = "AssetTracker";

    // Time to wait before send if device is not ready
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


// GOOGLE MAPS INTEGRATION
// ---------------------------------------------------
// Receives location from Google based on WiFi scan results

class GoogleMaps {

    static LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";

    static WIFI_SIGNALS_ERROR = "Insufficient wifi signals found";
    static GOOGLE_REQ_ERROR = "Unexpected response from Google";
    static GOOGLE_REQ_LIMIT_EXCEEDED_ERROR  = "You have exceeded your daily limit";
    static GOOGLE_REQ_INVALID_KEY_ERROR  = "Your Google Maps Geolocation API key is not valid or the request body is not valid JSON";
    static GOOGLE_REQ_LOCATION_NOT_FOUND_ERROR  = "Your API request was valid, but no results were returned";

    _apiKey = null;

    constuctor(apiKey) {
        _apiKey = apiKey;
    }

    function getLocation(wifis, cb) {
        if (wifis.len() < 2) {
            imp.wakeup(0, function() {
                cb(WIFI_SIGNALS_ERROR, null);
            }.bindenv(this))
            return;
        }

        // Build request
        local url = format("%s%s", LOCATION_URL, _apiKey);
        local headers = {"Content-Type" : "application/json"};
        local body = { "wifiAccessPoints": [] };

        foreach (network in wifis) {
            body.wifiAccessPoints.append({ "macAddress": _addColons(network.bssid),
                                           "signalStrength": network.rssi
                                           "channel" : network.channel });
        }

        local request = http.post(url, headers, http.jsonencode(body));
        request.sendasync(function(res) {
            _locationRespHandler(wifis, res, cb);
        }.bindenv(this));
    }

    // Process location HTTP response
    function _locationRespHandler(wifis, res, cb) {
        local body; 
        local err = null;

        try {
            body = http.jsondecode(res.body);
        } catch(e) {
            imp.wakeup(0, function() { cb(e, res); }.bindenv(this))
        }
        
        local statuscode = res.statuscode;
        switch(statuscode) {
            case 200:
                if ("location" in body) {
                    res = body;
                } else {
                    err = GOOGLE_REQ_LOCATION_NOT_FOUND_ERROR;
                }
                break;
            case 400:
                err = GOOGLE_REQ_INVALID_KEY_ERROR;
                break;
            case 403:
                err = GOOGLE_REQ_LIMIT_EXCEEDED_ERROR;
                break;
            case 404:
                err = GOOGLE_REQ_LOCATION_NOT_FOUND_ERROR;
                break;
            case 429:
                // Too many requests try again in a second
                imp.wakeup(1, function() {
                    getLocation(wifis);
                }.bindenv(this));
                return;
            default:
                if ("message" in body) {
                    // Return Google's error message
                    err = body.message;
                } else {
                    // Pass generic error and response so user can handle error
                    err = GOOGLE_REQ_ERROR;
                }
        }
        
        imp.wakeup(0, function() {
            cb(err, res);  
        }.bindenv(this));
    }

    // Format bssids for Google
    function _addColons(bssid) {
        // Format a WLAN basestation MAC for transmission to Google
        local result = bssid.slice(0, 2);
        for (local i = 2 ; i < 12 ; i += 2) {
            result = result + ":" + bssid.slice(i, i + 2)
        }
        return result.toupper();
    }
}


// ASSET TRACKER APPLICATION CODE
// ---------------------------------------------------
// Application code, listen for readings from device,
// when a reading is received send the data to Initial 
// State 

class AssetTracker {

    // Class variables
    gMaps = null;
    deviceID = null;

    constructor(watsonApiKey, watsonAuthToken, watsonOrgId, googleApiKey) {
        // Get the device ID
        deviceID = imp.configparams.deviceid;

        // Initialize Watson
        watson = Watson(deviceID, watsonApiKey, watsonAuthToken, watsonOrgId);
        gMaps = GoogleMaps(googleApiKey);

        device.on("wifi.networks", getLocation.bindenv(this));
    }

    function getLocation(wifis) {
        gMaps.getLocation(wifis, function(err, res) {
            if (err) {
                server.error(err);
            } else {
                server.log(http.jsonencode(res))
                watson.send(res.location);
            }
        }.bindenv(this));
    }

}


// RUNTIME
// ---------------------------------------------------
server.log("Agent running...");

// Google API key from the google developer console
const GOOGLE_API_KEY = "<YOUR API KEY HERE>";

// Watson API Auth Keys
// See library examples for step by step Watson setup
const WATSON_API_KEY = "<YOUR API KEY HERE>";
const WATSON_AUTH_TOKEN = "<YOUR AUTHENTICATION TOKEN HERE>";
const WATSON_ORG_ID = "<YOUR ORG ID>";

// Run the Application
AssetTracker(WATSON_API_KEY, WATSON_AUTH_TOKEN, WATSON_ORG_ID, GOOGLE_API_KEY);
