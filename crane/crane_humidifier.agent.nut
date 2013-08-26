/*
Copyright (C) 2013 Electric Imp, Inc

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



HTTP interface:

GET /
- Redirects the browser to the web server

GET /relay
- Returns the current state of the relay: { state = [status] },
  where [state] can be 0 (off), 1 (on) or null (unknown)

GET /settings
- Returns the settings store with the agent: { turnon = [when], turnoff = [when] }

POST /relay
- Change the state of the relay: { state = [status] },
  where [state] can be 0 (off) or 1 (on) or "toggle". Returns the new state.

POST /settings
- Change the settings stored with the agent: { turnon = [when], turnoff = [when] }
  where when can be one of a fixed set of values

*/


// -----------------------------------------------------------------------------
const GET_TIMEOUT = 1;
const POLL_TIMEOUT = 20;
http.onrequest(function (req, res) {
    server.log(req.method + " " + req.path + " => " + req.body);
    res.header("Access-Control-Allow-Origin", "*")
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");

    try {

        switch (req.method) {
        case "POST":
            switch (req.path) {
                case "/relay":
                    // Send the request
                    local request = http.jsondecode(req.body);
                    if ("state" in request) {
                        if (request.state == "toggle") {
                            device.send("toggle", 1)
                        } else {
                            local state = (request.state == "on" || request.state == 1 || request.state == "1") ? 1 : 0
                            device.send("set", state)
                        }
                    }

                    // Read the result of the request
                    poll("get", GET_TIMEOUT, function (state) {
                        local json = { state = state };
                        res.header("Content-Type", "application/json");
                        res.send(200, http.jsonencode(json));
                    });
                    device.send("get", 1);
                    break;

                case "/settings":
                    local data = http.urldecode(req.body);
                    set_settings(data);
                    res.send(200, "OK");
                    break;

                default:
                    res.send(404, "Whatcha looking for man?")
            }
            break;

        case "GET":
            switch (req.path) {
                case "":
                case "/":
                case "/index":
                case "/index.html":
                    local queryparams = {agent = http.agenturl().slice(-12)}
                    res.header("Location", "http://devious-dorris.gopagoda.com/crane?" + http.urlencode(queryparams));
                    res.send(307, "Moved");
                    break;

                case "/relay":
                    poll("get", GET_TIMEOUT, function (state) {
                        local json = { state = state };
                        res.header("Content-Type", "application/json");
                        res.send(200, http.jsonencode(json));
                    });
                    device.send("get", 1);
                    break;

                case "/settings":
                    local json = { turnon = turnon, turnoff = turnoff };
                    res.header("Content-Type", "application/json");
                    res.send(200, http.jsonencode(json));

                default:
                    res.send(404, "Whatcha looking for man?")
            }
            break;

        case "OPTIONS":
            res.send(200, "OK");
            break;

        default:
            res.send(400, "Whats that man?");
        }
    } catch (e) {
        server.error(e)
        res.send(500, "Exception");
    }

})


// -----------------------------------------------------------------------------
pollers <- {};
function poll_update(keyword, state) {
    // Update all pollers with the new state
    foreach (id,obj in pollers) {
        if (obj.keyword == keyword) {
            delete pollers[id];
            if (obj.timer) imp.cancelwakeup(obj.timer);
            if (obj.callback) obj.callback(state);
        }
    }

    set_firebase({state = state});
}

function poll(keyword="poll", timeout=POLL_TIMEOUT, callback=null) {
    // Setup a timeout timer
    local id = math.rand();
    local timer = null;
    timer = imp.wakeup(timeout, function () {
        if (id in pollers) {
            local obj = pollers[id];
            delete pollers[id];
            if (obj.callback) obj.callback(null);
        }
    })

    // Push the poller onto the stack
    pollers[id] <- { timer=timer, keyword=keyword, callback=callback };
}


function temp_update(temp) {
    set_firebase({temp = temp});
}


// -----------------------------------------------------------------------------
function set_firebase(data = {}, callback = null) {

    // Also send the results to firebase
    local agentid = http.agenturl().slice(-12);
    local url = "https://devices.firebaseIO.com/agent/" + agentid + ".json?auth=LLfj2iAIHqwwy4mrsci8JprdU6U31HgXDbVEiz7A";
    local headers = {"Content-Type": "application/json"};
    data.heartbeat <- time();
    http.request("PATCH", url, headers, http.jsonencode(data)).sendasync(function(res) {
        if (res.statuscode != 200) server.log(res.statuscode + " :=> " + res.body)
        if (callback) callback();
    });

}

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


// -----------------------------------------------------------------------------
turnon <- get_nv("turnon", "skip");
turnoff <- get_nv("turnoff", "skip");
turnonoff_timer <- null;
function set_settings(settings = null) {

    if (settings != null) {
        turnon = settings.turnon;
        turnoff = settings.turnoff;
        msisdn = settings.msisdn;
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
            device.send("set", 1);
            set_settings();
        });
    } else if (turnoff_time != null && (turnon_time == null || turnoff_time <= turnon_time)) {
        turnonoff_timer = imp.wakeup(turnoff_time, function() {
            device.send("set", 0);
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
const PROWL_KEY = "fe6d81e7609aedd65a6c15fee84ba7b574537a4a";
const PROWL_URL = "https://api.prowlapp.com/publicapi";
const PROWL_APP = "Crane Humidifier";
function send_to_prowl(short="Switch event", long="") {
    local data = {apikey=PROWL_KEY, url=http.agenturl(), application=PROWL_APP, event=short, description=long};
    http.post(PROWL_URL+"/add?" + http.urlencode(data), {}, "").sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Prowl error: " + res.statuscode + " => " + res.body);
        }
    })
}


// -----------------------------------------------------------------------------
const TWILIO_URL = "https://api.twilio.com/2010-04-01/Accounts/";
const TWILIO_SID = "ACcfd9b8b135c737c1afdc1d99d113c176";
const TWILIO_PWD = "19a0374e5a718854db53a88082589c91";
const TWILIO_SRC = "+14153736149";
msisdn <- get_nv("msisdn", "4157286707");
function send_to_twilio(message, number) {
    local data = { From = TWILIO_SRC, To = number, Body = message };
    local auth = http.base64encode(TWILIO_SID + ":" + TWILIO_PWD);
    local headers = {"Authorization": "Basic " + auth};
    http.post(TWILIO_URL + TWILIO_SID + "/SMS/Messages.json", headers, http.urlencode(data)).sendasync(function(res) {
        if (res.statuscode == 200 || res.statuscode == 201) {
            server.log("Twilio SMS sent to: " + number);
        } else {
            server.log("Twilio error: " + res.statuscode + " => " + res.body);
        }
    })
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
                set_firebase({tzoffset = ::tzoffset, sunrise = ::sunrise, sunset = ::sunset});

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


// -----------------------------------------------------------------------------
server.log("Agent started. Agent URL is " + http.agenturl());

device.on("heartbeat", function (state) { poll_update("get", state) })
device.on("poll", function (state) { poll_update("poll", state) });
device.on("get", function (state) { poll_update("get", state) });
device.on("temp", function (temp) { temp_update(temp) });
device.on("event", function (reason) {
    send_to_twilio("Crane humidifier switch alert: " + reason, msisdn);
});
imp.wakeup(1, get_default_values)


