// impMonitor AGENT CODE
// Copyright (c) 2018, Electric Imp, Inc.
// Writer: Tony Smith
// Licence: MIT
// Version: 1.0.1

// IMPORTS
#require "Rocky.class.nut:2.0.1"
// If you are not using Squinter or an equivalent tool to combine multiple Squirrel files,
// you need to paste the contents of the accompanying files over the following four lines
#import "online.png.nut"
#import "offline.png.nut"
#import "warn.png.nut"
#import "spacer.png.nut"

// CONSTANTS
// If you are not using Squinter or an equivalent tool to combine multiple Squirrel files,
// you need to uncomment the following two lines and enter your Electric Imp account credentials
// const USERNAME = "<YOUR__ELECTRIC_IMP_ACCOUNT_USERNAME>";
// const PASSWORD = "<YOUR_ELECTRIC_IMP_ACCOUNT_PASSWORD>";
#import "~/dropbox/programming/imp/codes/monitor.nut"

const HTML_HEADER = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<head>
  <title>Device Status Monitor 0.0.1</title>
  <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
  <link href='https://fonts.googleapis.com/css?family=Comfortaa' rel='stylesheet'>
  <link rel='apple-touch-icon' href='https://smittytone.github.io/images/ati-imp.png'>
  <link rel='shortcut icon' href='https://smittytone.github.io/images/ico-imp.ico'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <meta http-equiv='Cache-Control' content='no-cache, no-store, must-revalidate'>
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
    <h3>Device Status Monitor<br>&nbsp;</h3>
    <table width='100%%'>
      ";
const HTML_FOOTER = @"  </table>
  </div>
  </div>
  <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js'></script>
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
const USER_AGENT = "impAgent-impMonitor-0.0.1";
const LOOP_TIME = 60;
const PAGE_SIZE = 100;

// GLOBALS
local api = null;
local token = null;
local isLoggedIn = false;
local htmlBody = "";
local devices = [];

// API ACCESS FUNCTIONS
#line 1000
function getDeviceData() {
    // Ask the impCentral API for a list of devices, calling up multiple pages
    // as needed and then combining them into a single list 'uDevices'
    local headers = { "User-Agent": "impAgent Monitor 0.0.1",
                      "Authorization": "Bearer " + token.accessToken };
    local url = API_BASE_URL + "devices" + "?page[size]=" + format("%i", PAGE_SIZE);
    local nextURL = "";
    local uDevices = [];
    do {
        local request = http.get(url, headers);
        local data = request.sendsync();
        data = http.jsondecode(data.body);
        if ("links" in data) {
            nextURL = getNextPageLink(getNextURL(data.links));
            foreach (device in data.data) uDevices.append(device);
            url = nextURL;
        }
    } while (nextURL.len() != 0);

    // Build the UI from the list of devices gathered above
    if (uDevices.len() > 0) {
        htmlBody = "";

        // Sort the incoming device list aphabetically
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

        // Having processed the updated device list,
        // store it for next time
        devices = uDevices;
    } else {
        // Create a simple HTML body indicating the user has no devices
        htmlBody = @"<tr><td class='tabcontent'><h4 align='center'>No Devices</h4></td></tr>";
    }
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

function login(username = null, password = null) {
    // Login is the process of sending the user's username/email address and password to the impCentral API
    // in return for a new access token and the refresh token used to get new access tokens later
    if (username == null || username.len() == 0 || password == null || password.len() == 0) {
        server.error("Could not log in to the Electric Imp impCloud — no username/email address or password.");
        return;
    }

    // Retain the data for future use
    token = {};
    token.username <- username;
    token.password <- password;

    // Get a new token using the credentials provided
    getNewAccessToken();
}

function getNewAccessToken() {
    // Request a new access token using the stored credentials,
    // Set up a POST request to the /auth URL to get an access token
    local body = { "id": token.username,
                   "password": token.password };
    local headers = { "User-Agent": USER_AGENT,
                      "Content-Type": "application/json" };
    local url = API_BASE_URL + "auth";
    local request = http.post(url, headers, http.jsonencode(body));
    request.sendasync(gotAccessToken);
}

function refreshAccessToken() {
    // Getting a new session token using the refresh_token does not
    // require the account username and password
    if (!("refreshToken" in token) || token == null) {
        // We don't have a token, so just get a new one
        getNewAccessToken();
        return;
    }

    local body = { "token" : token.refreshToken };
    local headers = { "User-Agent": USER_AGENT,
                      "Content-Type": "application/json" };
    local url = API_BASE_URL + "auth/token";
    local request = http.post(url, headers, http.jsonencode(body));
    request.sendasync(refreshedAccessToken);
}

function gotAccessToken(data) {
    // We have retrieved an initial access token,
    // so add it and other useful data to the 'token' structure
    data = http.jsondecode(data.body);
    if ("accessToken" in token) {
        token.accessToken = data.access_token;
    } else {
        token.accessToken <- data.access_token;
    }

    if ("expiryTime" in token) {
        token.expiryTime = time() + data.expires_in.tointeger();
    } else {
        token.expiryTime <- time() + data.expires_in.tointeger();
    }

    if ("refreshToken" in token) {
        token.refreshToken = data.refresh_token;
    } else {
        token.refreshToken <- data.refresh_token;
    }

    // Flag that we are now logged in
    isLoggedIn = true;
}

function refreshedAccessToken(data) {
    // We have retrieved a subsequent access token,
    // so add it to the 'token' structure
    data = http.jsondecode(data.body);
    if ("accessToken" in token) {
        token.accessToken = data.access_token;
    } else {
        token.accessToken <- data.access_token;
    }

    if ("expiryTime" in token) {
        token.expiryTime = time() + data.expires_in.tointeger();
    } else {
        token.expiryTime <- time() + data.expires_in.tointeger();
    }

    // Since we bypassed a device update request to come here,
    // we need to make that request now
    getDeviceData();
}

function isAccessTokenValid() {
    // Check if the currently held access token has expired.
    // Return 'true' if it is good, or 'false' if we need a new one
    // No token available? Return false
    if (token == null || !("expiryTime" in token)) return false;
    local expiry = token.expiryTime;
    local now = time();
    if (now >= expiry) return false;
    return true;
}

// DEVICE-CHECK LOOP FUNCTION
function updateDevices() {
    if (isLoggedIn) {
        // We're logged in, ie. we have an access token, but
        // is it valid? If not, we will need to get a fresh one
        if (!(isAccessTokenValid())) {
            // The access token has expired - refresh it
            refreshAccessToken();
        } else {
            // The access token is good - update the devices' status
            getDeviceData();
        }
    }

    // Schedule the next check in LOOP_TIME seconds
    imp.wakeup(LOOP_TIME, updateDevices);
}

// UTILITY FUNCTIONS
function sorter(first, second) {
  // Helper function for array.sort()
  // Sort devices by name. Devices without a name
  // Should appear at the end of the list
	local a = first.attributes.name.tolower();
	local b = second.attributes.name.tolower();
	if (a == null || a > b) return 1;
	if (b == null || a < b) return -1;
	return 0;
}

// START OF PROGRAM

// Define the API
api = Rocky();

// A call to the endpoint / calls up the current web page
api.get("/", function(context) {
    context.send(200, HTML_HEADER + htmlBody + HTML_FOOTER);
});

// GET call to /images
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

// Log into the API
login(USERNAME, PASSWORD);

// Set default text to display
htmlBody = @"<tr><td class='tabcontent'><h4 align='center'>Getting Device Info...</h4></td></tr>";

// Start the device check loop
updateDevices();
