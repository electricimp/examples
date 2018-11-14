const LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";
const MAPS_APIKEY  = "<YOUR GOOGLE MAPS API KEY HERE>";

device.on("netInfo", _onNetInfo.bindenv(this));

cellStatus <- {
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
}

currentLoc <- {
    "lat" : 0,
    "lng" : 0
}

currentCell <- {};


function _onNetInfo(netInfo) {
    server.log(http.jsonencode(netInfo));

    local info = netInfo.interface[netInfo.active];
    local type = info.type;

    switch(type) {
        case "wifi":
            server.log("Device connected via WiFi.");
            break;
        case "ethernet":
            server.log("Device connected via Ethernet.");
            break;
        case "cell":
            // Update Cell Status
            processDevNetInfo(info.cellinfo);
            break;
    }
}

function processDevNetInfo(cellinfo) {
    try {
        local s = split(cellinfo, ",");
        cellStatus.time = time();

        switch(s[0]) {
            case "4G":
                cellStatus.type    ="LTE";
                cellStatus.earfcn  = s[1];
                cellStatus.band    = s[2];
                cellStatus.dlbw    = s[3];
                cellStatus.ulbw    = s[4];
                cellStatus.mode    = s[5];
                cellStatus.mcc     = s[6];
                cellStatus.mnc     = s[7];
                cellStatus.tac     = s[8];
                cellStatus.cellid  = s[9];
                cellStatus.physid  = s[10];
                cellStatus.srxlev  = s[11];
                cellStatus.rsrp    = s[12];
                cellStatus.rsrq    = s[13];
                cellStatus.state   = s[14];
                break;

            case "3G":
                cellStatus.type    ="HSPA";
                cellStatus.earfcn  = s[1];
                cellStatus.band    = "na";
                cellStatus.dlbw    = "na";
                cellStatus.ulbw    = "na";
                cellStatus.mode    = "na";
                cellStatus.mcc     = s[5];
                cellStatus.mnc     = s[6];
                cellStatus.tac     = s[7];
                cellStatus.cellid  = s[8];
                cellStatus.physid  = "na";
                cellStatus.srxlev  = s[10];
                cellStatus.rsrp    = s[4];
                cellStatus.rsrq    = "na";
                cellStatus.state   = "na";
                break;
        }
    } catch(e) {
        server.log("Input: " + cellinfo);
        server.err("Parse error: " + e);
    }

    // Geo
    local cell = {
        "cellId": Utils.hexStrToDec(cellStatus.cellid),
        "locationAreaCode": _hexStrToDec(cellStatus.tac),
        "mobileCountryCode": cellStatus.mcc,
        "mobileNetworkCode": cellStatus.mnc
    };

    // Don't issue a request if it hasn't changed from last time
    if (_hasNewCellInfo(cell)) _getGeolocation(cell);
}

function _hexStrToDec(hexStr) {
    local result = 0;
    foreach(c in hexStr) {
        result = 16 * result;
        local hi = c - '0'
        if (hi > 9 )
            hi = ((hi & 0x1f) - 7)
        result = result | hi;
    }
    return result
}

function _getGeolocation(cell) {
    server.log("Looking up location via google");

    // Build request
    local url = format("%s%s", LOCATION_URL, MAPS_APIKEY);
    local headers = { "Content-Type" : "application/json" };
    local body = {
        "considerIp": "false",
        "radioType": "lte",
        "cellTowers": [cell]
    };

    local request = http.post(url, headers, http.jsonencode(body));
    request.sendasync(function(res) {
        local body;
        try {
            body = http.jsondecode(res.body);
        } catch(e) {
            server.err("Geolocation parsing error: " + e);
        }

        if (res.statuscode == 200) {
            // Update stored state variables
            currentLoc.lat = body.location.lat;
            currentLoc.lng = body.location.lng;
            currentCell    = _updateCurrentCellInfo(cell);
        } else {
            server.err("Geolocation unexpected reponse: " + res.statuscode);
        }
    }.bindenv(this));
}

function _hasNewCellInfo(updatedCell) {
    foreach(k, v in updatedCell) {
        if (!(k in currentCell) || v != currentCell[k]) return true;
    }
    return false;
}

function _updateCurrentCellInfo(newCellInfo) {
    currentCell = {};
    foreach (k, v in newCellInfo) {
        currentCell[k] <- v;
    }
}