// Web Integration Libraries
#require "AutodeskFusionConnect.agent.lib.nut:2.0.0"

// -------------------------------------------------------

// Message and route names
const TANK_LEVEL_EVENT = "tank_level";
const PUMP_EVENT = "pump";
const TANK_THRESHOLD = "tank_threshold";
const LOCATION = "location";

// AutoDesk Fusion Connect Configuration
class FusionConnect {

  static HOSTNAME = "";
  static HTTPS_PORT = ;
  static HTTP_PORT = ;
  static MESSAGE_CODE = "in_message";
  static POLLING_TIMER = 15;
  static MSG_FILTER = 0.7;

  fusion = null;
  deviceID = null;
  _location = null;
  _sending = false;

  constructor(_deviceID) {
    deviceID = _deviceID;
    fusion = AutodeskFusionConnect(HOSTNAME, HTTPS_PORT, true);
  }

  function setHandler(handler) {
    fusion.openDirectiveListener(deviceID, POLLING_TIMER, function(resp) {
      if ("values" in resp && "tank_threshold" in resp.values) {
        handler(resp.values.tank_threshold);
      } else {
        server.log(http.jsonencode(resp));
      }
    }.bindenv(this))
  }

  function send(msg) {
    // Filter Tank Level Msgs
    if (_sending && msg.type == TANK_LEVEL_EVENT && !overThreshold(msg)) return;

    if (HOSTNAME && HTTPS_PORT) {
      _sending = true;
      local data = {};
      data[msg.type] <- msg.data;
      server.log(http.jsonencode(data));
      fusion.sendMessage(deviceID, MESSAGE_CODE, data, function(err, res) {
        if (err) {
          server.error("Autodesk send error: " + err);
          // foreach (k, v in res) {
          //   server.log(k + ": " + v)
          // }
        } else {
          // foreach (k, v in res) {
          //   server.log(k + ": " + v)
          // }
          server.log("Autodesk send successful");
        }
      });
      imp.wakeup(MSG_FILTER, function() { _sending = false; }.bindenv(this));
    }
  }

  function overThreshold(msg) {
    return ("thresh" in msg && msg.data >= msg.data);
  }
}

// Application Code
class App {

  // Check for threshold updates from Fusion Connect
  static THRESHOLD_TIMER = 60;
  static GOOGLE_LOCATION_API_KEY = "";

  fc = null;
  api = null;

  devID = null;
  tankThreshold = null;
  thresholdLoop = null;

  constructor() {
    devID = imp.configparams.deviceid;

    fc = FusionConnect(devID);

    openListeners();
    fc.setHandler(fusionThresholdHandler.bindenv(this));
  }

  function openListeners() {
    device.on(TANK_LEVEL_EVENT, tankLevelHandler.bindenv(this));
    device.on(PUMP_EVENT, pumpEvent.bindenv(this));
    device.on(TANK_THRESHOLD, updateThreshold.bindenv(this));
    device.on(LOCATION, getLocation.bindenv(this));
  }

  function fusionThresholdHandler(threshold) {
    device.send(TANK_THRESHOLD, threshold);
    updateThreshold(threshold, false);
  }

  function updateThreshold(threshold = null, toFusion = true) {
    // Check parameters
    if (typeof threshold == "boolean") {
      toFusion = threshold;
      threshold = null;
    }

    // Update threshold
    if (threshold) tankThreshold = threshold;

    // Send to webservices
    send({"data" : tankThreshold, "type" : TANK_THRESHOLD}, toFusion);
  }

  function pumpEvent(state) {
    // Send to Webservices
    send({"data" : state, "type" : PUMP_EVENT});
  }

  function tankLevelHandler(level) {
    // Send to Webservices
    send({"data" : level, "type" : TANK_LEVEL_EVENT, "thresh" : tankThreshold});
  }

  function send(data, toFusion = true) {
    // Log data
    server.log(http.jsonencode(data));

    // Send to each webservices
    if (toFusion) fc.send(data);
  }

  function getLocation(wifis) {
    if (wifis.len() < 2) return callback("Insufficient wifi signals");

    local url = "https://www.googleapis.com/geolocation/v1/geolocate?key=" + GOOGLE_LOCATION_API_KEY;
    local headers = {
      "Content-Type": "application/json"
    }
    local request = {
      "considerIp": false,
      "wifiAccessPoints": []
    }

    // Convert the wifis into a format that google likes
    foreach (wifi in wifis) {
      local bssid = format("%s:%s:%s:%s:%s:%s", wifi.bssid.slice(0,2),
                            wifi.bssid.slice(2,4),
                            wifi.bssid.slice(4,6),
                            wifi.bssid.slice(6,8),
                            wifi.bssid.slice(8,10),
                            wifi.bssid.slice(10,12));
      local newwifi = {};
      newwifi.macAddress <- bssid.toupper();
      newwifi.signalStrength <- wifi.rssi;
      newwifi.channel <- wifi.channel;
      request.wifiAccessPoints.push(newwifi);
    }

    // Post the request
    http.post(url, headers, http.jsonencode(request)).sendasync(function(res) {
      // Parse the response
      local body = null;
      try {
        body = http.jsondecode(res.body);
      } catch (e) {
        server.error(e);
        return;
      }

      if (res.statuscode == 200 && "location" in body) {
        // All looking good
        local location = {};
        location.latitude <- body.location.lat;
        location.longitude <- body.location.lng;
        server.log(http.jsonencode(location));
        // Send location data here
      } else if (res.statuscode == 429) {
        // We have been throttled. try again in a second
        imp.wakeup(1, function() {
          getLocation(wifis);
        }.bindenv(this));
      } else if ("message" in body) {
        // Return Google's error message
        server.error(body.message);
      } else {
        server.error("Error " + res.statuscode);
      }
    }.bindenv(this));
  }
}


// RUNTIME
// -------------------------------------------------------

// Initialize & Run the Application
App();
