/*
The MIT License (MIT)

Copyright (c) 2013 Electric Imp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/



// ========================================================================================
// Quirky Xmas Lights
// Animates the Quirky christmas lights.
//
// Valid commands: pushQueue, clearQueue
// Valid params for pushQueue: animation (string), color1/2 (string|integer|[r,g,b]), frames (int)
// Valid animations: walk, pastel, random, twinkle, fade, smooth, fixed

// Samples
// Halloween: device.send("pushQueue", { "animation": "walk", "color1": "black", "color2": "orange", "steps": 2, "frames": 40, "speed": 4 });
// Xmas: device.send("pushQueue", { "animation": "walk", "color1": "red", "color2": "green", "steps": 6, "frames": 40, "speed": 2 });
// Independence day: device.send("pushQueue", { "animation": "walk", "color1": "blue", "color2": "white", "color3": "red", "steps": 3, "frames": 40, "speed": 2 });
// Hanukka: device.send("pushQueue", { "animation": "twinkle", "color1": "blue", "color2": "white", "frames": 40 });
// Random: device.send("pushQueue", { "animation": "random", "frames": 40, "speed": 4 });
// White: device.send("pushQueue", { "animation": "fixed", "color1": "white", "frames": 40 });


// -----------------------------------------------------------------------------
// Firebase class: Implements the Firebase REST API.
// https://www.firebase.com/docs/rest-api.html
//
// Author: Aron
// Created: September, 2013
//
class Firebase {

    database = null;
    authkey = null;
    agentid = null;
    url = null;
    headers = null;

    // ........................................................................
    constructor(_database, _authkey, _path = null) {
        database = _database;
        authkey = _authkey;
        agentid = http.agenturl().slice(-12);
        headers = {"Content-Type": "application/json"};
        set_path(_path);
    }


    // ........................................................................
	function set_path(_path) {
		if (!_path) {
			_path = "agents/" + agentid;
		}
        url = "https://" + database + ".firebaseIO.com/" + _path + ".json?auth=" + authkey;
	}


    // ........................................................................
    function write(data = {}, callback = null) {

        if (typeof data == "table") data.heartbeat <- time();
        http.request("PUT", url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Write: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null);
            }
        }.bindenv(this));

    }

    // ........................................................................
    function update(data = {}, callback = null) {

        if (typeof data == "table") data.heartbeat <- time();
        http.request("PATCH", url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Update: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null);
            }
        }.bindenv(this));

    }

    // ........................................................................
    function push(data, callback = null) {

        if (typeof data == "table") data.heartbeat <- time();
        http.post(url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res, null);
                else server.log("Push: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local body = null;
                try {
                    body = http.jsondecode(res.body);
                } catch (err) {
                    if (callback) return callback(err, null);
                }
                if (callback) callback(null, body);
            }
        }.bindenv(this));

    }

    // ........................................................................
    function read(callback = null) {
        http.get(url, headers).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res, null);
                else server.log("Read: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local body = null;
                try {
                    body = http.jsondecode(res.body);
                } catch (err) {
                    if (callback) return callback(err, null);
                }
                if (callback) callback(null, body);
            }
        }.bindenv(this));
    }

    // ........................................................................
    function remove(callback = null) {
        http.httpdelete(url, headers).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Delete: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null, res.body);
            }
        }.bindenv(this));
    }

}



// -----------------------------------------------------------------------------
function get_nv(key, def = null) {
    if (key in server.load()) {
        // Reader - found
        return server.load()[key];
    } else {
        // Reader - not found
        return def;
    }
}

function set_nv(key, value) {
    local nv = server.load();
    nv[key] <- value;
    server.save(nv);
}


turnon <- get_nv("turnon", "skip");
turnoff <- get_nv("turnoff", "skip");
turnonoff_timer <- null;
function set_settings(settings = null) {

    if (settings != null) {
        turnon = settings.turnon;
        turnoff = settings.turnoff;
        set_nv("turnon", turnon);
        set_nv("turnoff", turnoff);
        set_nv("msisdn", msisdn);
    }

    local turnon_time = next_time(turnon);
    local turnoff_time = next_time(turnoff, turnon_time);

    if (turnon_time != null && turnoff_time != null)
        server.log(format("Turn on in %d seconds and off in %d seconds", turnon_time, turnoff_time));
    else if (turnon_time != null)
        server.log(format("Turn on in %d seconds and don't turn off", turnon_time));
    else if (turnoff_time != null)
        server.log(format("Don't turn on but turn off in %d seconds", turnoff_time));

    if (turnonoff_timer) imp.cancelwakeup(turnonoff_timer);

    if (turnon_time != null && (turnoff_time == null || turnon_time < turnoff_time)) {
        turnonoff_timer = imp.wakeup(turnon_time, function() {
            // TODO: Need to remember the last requested animation
            device.send("pushQueue", { "animation": "fixed", "color1": "green"});
            set_settings();
        });
    } else if (turnoff_time != null && (turnon_time == null || turnoff_time <= turnon_time)) {
        turnonoff_timer = imp.wakeup(turnoff_time, function() {
            device.send("pushQueue", { "animation": "fixed", "color1": "black"});
            set_settings();
        });
    }
}


sunrise <- get_nv("sunrise", null);
sunset <- get_nv("sunset", null);
tzoffset <- get_nv("tzoffset", null);
function next_time(value, prev_time = null) {

    local d = date();
    local now = (d.hour * 3600) + (d.min * 60) + d.sec; // This is already in UTC

    local next = null;
    local prev = now;
    if (prev_time != null) prev = prev_time + now;
    if (24*3600-prev < 10) prev = math.abs(24*3600-prev);

    switch (value) {
        //.............................
        case "sunrise-1hr":
            next = sunrise - 3600;
            break;
        case "sunrise-30mn":
            next = sunrise - 1800;
            break;
        case "sunrise":
            next = sunrise;
            break;
        case "sunrise+30mn":
            next = sunrise + 1800;
            break;
        case "sunrise+1hr":
            next = sunrise + 3600;
            break;
        //.............................
        case "sunset-1hr":
            next = sunset - 3600;
            break;
        case "sunset-30mn":
            next = sunset - 1800;
            break;
        case "sunset":
            next = sunset;
            break;
        case "sunset+30mn":
            next = sunset + 1800;
            break;
        case "sunset+1hr":
            next = sunset + 3600;
            break;
        //.............................
        case "+1hr":
            next = prev + 3600;
            break;
        case "+2hr":
            next = prev + 7200;
            break;
        case "+3hr":
            next = prev + 10800;
            break;
        //.............................
        case "skip":
            return null;
        //.............................
        default:
            next = ((value.tofloat() - ::tzoffset) * 3600).tointeger();
    }

    if (next > 24*3600) next -= (24*3600);
    else if (next < 0) next += (24*3600);
    if (next - now <= 0) next += (24*3600);

    return next - now;

}            


// -----------------------------------------------------------------------------
const WUNDERGROUND_KEY = "bd86961f91f3a5e5";
const WUNDERGROUND_URL = "http://api.wunderground.com/api";
function get_sunrise_sunset(location, callback = null) {
    local url = format("%s/%s/astronomy/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, location);
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Wunderground error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null, null, null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local sunrise = json.sun_phase.sunrise;
                local sunset = json.sun_phase.sunset;
                local now = json.moon_phase.current_time;

                if (callback) callback(sunrise, sunset, now);
            } catch (e) {
                server.error("Wunderground error: " + e)
                if (callback) callback(null, null, null);
            }

        }
    })
}


function get_lat_lon(location, callback = null) {
    local url = format("%s/%s/geolookup/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, location);
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Wunderground error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null, null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local lat = json.location.lat.tofloat();
                local lon = json.location.lon.tofloat();

                if (callback) callback(lat, lon);
            } catch (e) {
                server.error("Wunderground error: " + e)
                if (callback) callback(null, null);
            }

        }
    })
}

// -----------------------------------------------------------------------------
const GOOGLE_MAPS_URL = "https://maps.googleapis.com/maps/api";
function get_tzoffset(lat, lon, callback = null) {
    local url = format("%s/timezone/json?sensor=false&location=%f,%f&timestamp=%d", GOOGLE_MAPS_URL, lat, lon, time());
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Google maps error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local dst = json.dstOffset.tofloat();
                local raw = json.rawOffset.tofloat();
                local tzoffset = ((raw+dst)/60.0/60.0);

                if (callback) callback(tzoffset);
            } catch (e) {
                server.error("Google maps error: " + e)
                if (callback) callback(null);
            }

        }
    })
}


// -----------------------------------------------------------------------------
location <- "CA/Los_Altos";
gdv_timer <- null;
function get_default_values() {

    server.log("Getting default values from Wunderground and Google maps");

    // Get the sunset times
    get_sunrise_sunset(location, function(sunrise, sunset, now) {
        if (sunrise == null) return imp.wakeup(60, get_default_values);

        local rise_h = sunrise.hour.tointeger();
        local rise_m = sunrise.minute.tointeger();
        local set_h = sunset.hour.tointeger();
        local set_m = sunset.minute.tointeger();
        local now_h = now.hour.tointeger();
        local now_m = now.minute.tointeger();

        // Set the lat lon, which we need for the timezone
        get_lat_lon(location, function(lat, lon) {

            if (location == null) return imp.wakeup(60, get_default_values);

            // Get the time zone offset
            get_tzoffset(lat, lon, function(tz) {

                if (lat == null) return imp.wakeup(60, get_default_values);

                ::tzoffset = tz;

                ::sunrise = ((rise_h-tz) * 3600) + (rise_m * 60);
                if (::sunrise < 0) ::sunrise += (24*3600);
                else if (::sunrise > 24*3600) ::sunrise -= (24*3600);

                ::sunset = ((set_h-tz) * 3600) + (set_m * 60);
                if (::sunset < 0) ::sunset += (24*3600);
                else if (::sunset > 24*3600) ::sunset -= (24*3600);

                // Update the data stores
                set_nv("tzoffset", ::tzoffset);
                set_nv("sunrise", ::sunrise);
                set_nv("sunset", ::sunset);
                fb.update({tzoffset = ::tzoffset, sunrise = ::sunrise, sunset = ::sunset});

                // Log the results
                local now = ((now_h-tz) * 3600) + (now_m * 60);
                server.log(format("Sunrise: %02d:%02d (%d), Sunset: %02d:%02d (%d), Now: %02d:%02d (%d), TZ: %0.0f",
                                  rise_h, rise_m, ::sunrise, set_h, set_m, ::sunset, now_h, now_m, now, ::tzoffset));

                // Update the default values once a day
                gdv_timer = imp.wakeup(24*60*60, get_default_values)

            });
        });
    });
}
imp.wakeup(1, get_default_values)


// -----------------------------------------------------------------------------
fb <- Firebase("devices", "LLfj2iAIHqwwy4mrsci8JprdU6U31HgXDbVEiz7A");

// When the device sends an update, send it on to Firebase
device.on("update", function(data) {
    fb.update(data);
})

// When the device disconnects, remove the entry from Firebase
device.ondisconnect(function() {
    fb.remove();
})

// When the device connects or reconnects, reestablish the entry in Firebase
device.onconnect(function() {
    fb.update();
})

// The imp has just come online
device.on("status", function (status) {
    device.send("pushQueue", { "animation": "fixed", "color1": "black"});
});

// Handle incoming HTTP requests
http.onrequest(function(req, res) {
    res.header("Access-Control-Allow-Origin", "*")
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    res.send(200, "OK");
    
    try {
        switch (req.path) {
            case "/push":
                if ("color1[]" in req.query) req.query.color1 <- req.query["color1[]"];
                if ("color2[]" in req.query) req.query.color2 <- req.query["color2[]"];
                if ("color3[]" in req.query) req.query.color3 <- req.query["color3[]"];
                device.send("pushQueue", req.query);
                break;
                
            case "/settings":
                local data = http.urldecode(req.body);
                set_settings(data);
                break;
        }
    } catch (e) {
        server.log("Exception: " + e)
    }
})


server.log("Agent ready! URL = " + http.agenturl())

