// impMonitor AGENT CODE
// Copyright (c) 2018, Electric Imp, Inc.
// Writer: Tony Smith
// Licence: MIT
// Version: 1.1.0

// IMPORTS
#require "Rocky.class.nut:2.0.1"
// If you are not using Squinter or an equivalent tool to combine multiple Squirrel files,
// you need to paste the contents of the accompanying files over the following four lines
#import "online.png.nut"
#import "offline.png.nut"
#import "warn.png.nut"
#import "spacer.png.nut"

// CONSTANTS
const LOGIN_KEY = "YOUR_LOGIN_KEY";
const HTML_HEADER = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<head>
  <title>Device Status Monitor 1.1.0</title>
  <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
  <link href='https://fonts.googleapis.com/css?family=Comfortaa' rel='stylesheet'>
  <link rel='apple-touch-icon' href='https://smittytone.github.io/images/ati-imp.png'>
  <link rel='shortcut icon' href='https://smittytone.github.io/images/ico-imp.ico'>
  <meta http-equiv='Cache-Control' content='no-cache, no-store, must-revalidate'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <style>
    .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
    body {background-color: #21abd4;}
    p {color: white; font-family: Comfortaa}
    h3 {color: white; font-family: Comfortaa; font-weight:bold}
    h4 {color: white; font-family: Comfortaa}
    td {color: white; font-family: Comfortaa; vertical-align: center;}
    .tabborder {width: 20px; text-align: center}
    .tabcontent {width: 300px; text-align: left}
    .uicontent {border: 2px solid white; padding: 5px}
    .container {padding: 20px}
  </style>
</head>
<body>
  <div class='container'>
  <div class='uicontent' align='center'>
    <h3>Electric Imp</h3>
    <h3>Device Status Monitor</h3>
    <p>Updated at %s<br>&nbsp;</p>
        <table width='100%%'>
      ";
const HTML_FOOTER = @"  </table>
  </div>
  </div>

  <script>
    setTimeout(function() {
      location.reload(true);
    }, 30000);
  </script>
</body>
</html>";
const ENTRY_START = @"<tr>
        <td class='tabborder'><img src='%s' width='16' height='16'></td>
        ";
const ENTRY_END = @"<td class='tabborder'><img src='%s' width='16' height='16'></td>
        <td class='tabcontent'><h4>%s</h4></td>
      </tr>
      ";
const API_BASE_URL = "https://api.electricimp.com/v5/";
const USER_AGENT = "impAgent-impMonitor-1.1.0";
const LOOP_TIME = 60;
const PAGE_SIZE = 100;
const EXPIRY_DELTA = 5;

// GLOBALS
local api = null;
local token = null;
local isLoggedIn = false;
local htmlBody = "";
local devices = [];

// API ACCESS FUNCTIONS
#line 1000
function getDeviceData() {
    server.log("Updating device information");

    // Ask the impCentral API for a list of devices, calling up multiple pages
    // as needed and then combining them into a single list 'uDevices'
    local headers = { "User-Agent": "impAgent Monitor 1.1.0",
                      "Authorization": "Bearer " + token.accessToken };
    local url = API_BASE_URL + "devices" + "?page[size]=" + format("%i", PAGE_SIZE);
    local nextURL = "";
    local uDevices = [];
    do {
        // Check the access token is still valid - it may expire mid-run
        // If it is not valid, abandon the update
        if (!(isAccessTokenValid())) return;
        local request = http.get(url, headers);
        local data = request.sendsync();
        try {
            data = http.jsondecode(data.body);
            if ("links" in data) {
                nextURL = getNextPageLink(getNextURL(data.links));
                foreach (device in data.data) uDevices.append(device);
                url = nextURL;
            }
        } catch (err) {
            server.error(err + " (data: " + data.body + ")");
        }
    } while (nextURL.len() != 0);

    // Build the UI from the list of devices gathered above
    if (uDevices.len() > 0) {
        htmlBody = "";
        uDevices.sort(sorter);
        foreach (device in uDevices) {
            // 'device' is a table - use it to get the device's name (or ID if it has no name),
            // and its online status, then build the device's entry in the HTML table
            local isOnline = device.attributes.device_online;
            local deviceName = device.attributes.name;
            if (deviceName == null) deviceName = device.id;
            local statusImageURL = http.agenturl() + "/images/o" + (isOnline ? "n" : "ff") + ".png";
            local tableEntry = format(ENTRY_END, statusImageURL, deviceName);
            local warnImageCode = "/images/spacer.png";

            // Find the current device's record in the saved list to see
            // if its online status has changed since we last checked
            foreach (aDevice in devices) {
                if (aDevice.id == device.id) {
                    if (aDevice.attributes.device_online != device.attributes.device_online) {
                        // The device's status has changed, so add a warning triangle to the web UI
                        warnImageCode = "/images/warn.png";
                    }
                    break;
                }
            }

            // Assemble the table entry: add a space, or a warning triangle if the device's status has changed
            tableEntry = format(ENTRY_START, http.agenturl() + warnImageCode) + tableEntry;

            // Add the table entry to the HTML body
            htmlBody = htmlBody + tableEntry;
        }

        // Having processed the updated device list, store it for next time
        devices = uDevices;
    } else {
        // Create a simple HTML body indicating the user has no devices
        htmlBody = @"<tr><td class='tabcontent'><h4 align='center'>No Devices</h4></td></tr>";
    }
}

function sorter(first, second) {
    // Sort devices by name
    local a = first.attributes.name.tolower();
    local b = second.attributes.name.tolower();
    if (a == null || a > b) return 1;
    if (b == null || a < b) return -1;
    return 0;
}

function isFirstPage(links) {
    // Check the 'links' dictionary returned by the impCentral API.
    // Responds 'true' or 'false' if the received data is the first page of several
    local isFirst = false;
    foreach (link in links) {
        if (link == "first") {
            local currentPageLink = links.self;
            local firstPageLink = links.first;
            if (currentPageLink == firstPageLink) {
                // The current page is the first one
                isFirst = true;
                break;
            }
        }
    }
    return isFirst;
}

function getNextURL(links) {
    // Check the 'links' dictionary returned by the the impCentral API.
    // Returns the URL of the next page of data
    local nextURLString = "";
    foreach (link in links) {
        if (link == "next") {
            // We have at least one more page to recover before we have the full list
            nextURLString = links.next;
            break;
        }
    }
    return nextURLString;
}

function getNextPageLink(url = null) {
    // Strips the non-query content out of the supplied URL, or
    // returns an empty string if 'url' is nil or empty - what's
    // returned is added to a full URL by the calling method
    if (url = null || url.len() == 0) return "";
    return url.slice(31);
}

function login(key = null) {
    // Login is the process of sending the user's login key to the impCentral API
    // in order to retrieve a new access token
    if (key == null || key.len() == 0) {
        server.error("Could not log in to the Electric Imp impCloud — no login key");
        return;
    }

    // Retain the credential for future use
    token = { "loginkey": key };

    // Get a new token using the credentials provided
    getNewAccessToken();
}

function getNewAccessToken() {
    // Request a new access token using the stored credentials,
    // Set up a POST request to the /auth URL to get an access token
    local body = { "key": token.loginkey };
    local headers = { "User-Agent": USER_AGENT,
                      "Content-Type": "application/json" };
    local url = API_BASE_URL + "auth/token";
    local request = http.post(url, headers, http.jsonencode(body));
    server.log("Getting acccess token");
    request.sendasync(gotAccessToken);
}

function gotAccessToken(respData) {
    // We have retrieved a new access token, so add it and other
    // useful data to the 'token' structure
    if (respData.statuscode != 200) {
        isLoggedIn = false;
        server.error("Function: gotAccessToken()");
        server.error("Code: " + respData.statuscode);
        server.error("Data: " + respData.body);
        return;
    }

    try  {
        // Attempt to decode the response from impCentral
        local data = http.jsondecode(respData.body);

        if ("access_token" in data) {
            if ("accessToken" in token) {
                token.accessToken = data.access_token;
            } else {
                token.accessToken <- data.access_token;
            }

            server.log("Acquired Access Token: " + token.accessToken.slice(0, 40) + "...");
            isLoggedIn = true;
        } else {
            server.error("Could not get access token. JSON: " + respData.body);
            isLoggedIn = false;
            return;
        }

        if ("expires_in" in data) {
            if ("expiryTime" in token) {
                token.expiryTime = time() + data.expires_in.tointeger();
            } else {
                token.expiryTime <- time() + data.expires_in.tointeger();
            }

            server.log("Expires in " + data.expires_in + " seconds");
        } else {
            server.error("No access token expiry time");
        }
    } catch (err) {
        server.error("gotAccessToken() " + err);
    }
}

function isAccessTokenValid() {
    // Check if the currently held access token has expired.
    // Return 'true' if it is good, or 'false' if we need a new one
    // No token available? Return false
    local rv = true;
    if (token == null || !("expiryTime" in token)) {
        // We don't have a token (or it lacks an expiry time)
        // so just mark it as expired
        rv = false;
    } else {
        local now = time();
        // Expire the token even it it hasn't expired, but is nonetheless
        // within EXPIRY_DELTA of expiry. This is to prevent the token
        // expiring while the request is being made, ie. after the request
        // is sent but before the server has checked it
        if (now >= token.expiryTime - EXPIRY_DELTA) rv = false;
    }

    if (!rv) server.log("Access Token has expired");
    return rv;
}

function timestamp() {
    // Return the current date and time in a printable form
    local now = date();
    local timeString = format("%02i", now.hour) + ":" + format("%02i", now.min) + ":" + format("%02i", now.sec);
    local dateString = format("%04i", now.year) + "-" + format("%02i", now.month + 1) + "-" + format("%02i", now.day);
    return dateString + " " + timeString;
}

// DEVICE-CHECK LOOP FUNCTION
function updateDevices() {
    if (isLoggedIn) {
        // Check the current access token is valid
        if (!(isAccessTokenValid())) {
            // The access token has expired - refresh it
            getNewAccessToken();
        } else {
            // The access token is good - update the devices' status
            getDeviceData();
        }
    } else {
        // Initialize (or re-initialize after a disconnect)
        // our access to the impCentral API
        login(LOGIN_KEY);
    }

    // Schedule the next check in LOOP_TIME seconds
    updateTimer = imp.wakeup(LOOP_TIME, updateDevices);
}

// START OF PROGRAM

// Define the API to serve the web UI
api = Rocky();

// Any call to the endpoint / is sent the current web page
api.get("/", function(context) {
    context.send(200, format(HTML_HEADER, timestamp()) + htmlBody + HTML_FOOTER);
});

// Any call to the endpoint /images is sent the correct PNG data
api.get("/images/([^/]*)", function(context) {
    // Determine which image has been requested and send the appropriate
    // stored data back to the requesting web browser
    context.setHeader("Content-Type", "image/png");
    local path = context.matches[1];
    local imageData = ONLINE_PNG;
    if (path == "off.png") imageData = OFFLINE_PNG;
    if (path == "warn.png") imageData = WARN_PNG;
    if (path == "spacer.png") imageData = SPACER_PNG;
    context.send(200, imageData);
});

// Set default text to display in the web UI
htmlBody = @"<tr><td class='tabcontent'><h4 align='center'>Getting Device Info...</h4></td></tr>";

// Start the device check loop
updateDevices();
