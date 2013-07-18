/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Weather Agent
// Uses Wunderground API to obtain forecast for a provided zip every 10 minutes
// Relays parsed forecast to device (such as Emma 8-char display)

server.log("Weather Agent Running");

// Add your own wunderground API Key here. 
// Register for free at http://api.wunderground.com/weather/api/
local myAPIKey = "YOUR KEY GOES HERE";
local wunderBaseURL = "http://api.wunderground.com/api/"+myAPIKey+"/";

// Add the zip code you want to get the forecast for here.
local zip = "94022";

// The wunderground API has a lot of different features (tides, sailing, etc)
// We use "conditions" to indicate we just want a general weather report
local reportType = "conditions";

function getConditions() {
    server.log(format("Agent getting current conditions for %s", zip));
    // register the next run of this function, so we'll check again in five minutes
    
    // cat some strings together to build our request URL
    local reqURL = wunderBaseURL+reportType+"/q/"+zip+".json";

    // call http.get on our new URL to get an HttpRequest object. Note: we're not using any headers
    server.log(format("Sending request to %s", reqURL));
    local req = http.get(reqURL);

    // send the request synchronously (blocking). Returns an HttpMessage object.
    local res = req.sendsync();

    // check the status code on the response to verify that it's what we actually wanted.
    server.log(format("Response returned with status %d", res.statuscode));
    if (res.statuscode != 200) {
        server.log("Request for weather data failed.");
        imp.wakeup(600, getConditions);
        return;
    }

    // log the body of the message and find out what we got.
    //server.log(res.body);

    // hand off data to be parsed
    local response = http.jsondecode(res.body);
    local weather = response.current_observation;
    
    local forecastString = "";
        
    // Chunk together our forecast into a printable string
    server.log(format("Obtained forecast for ", weather.display_location.city));
    forecastString += ("Forecast for "+weather.display_location.city+", "+weather.display_location.state+" ");
    forecastString += (weather.weather+", ");
    forecastString += ("Temperature "+weather.temp_f+"F, ");
    forecastString += (weather.temp_c+"C, ");
    forecastString += ("Humidity "+weather.relative_humidity+", ");
    forecastString += ("Pressure "+weather.pressure_in+" in. ");
    if (weather.pressure_trend == "+") {
        forecastString += "and rising, ";
    } else if (weather.pressure_trend == "-") {
        forecastString += "and falling, ";
    } else {
        forecastString += "and steady, ";
    }
    forecastString += ("Wind "+weather.wind_mph+". ");
    forecastString += weather.observation_time;

    // relay the formatting string to the device
    // it will then be handled with function registered with "agent.on":
    // agent.on("newData", function(data) {...});
    server.log(format("Sending forecast to imp: %s",forecastString));
    device.send("newData", forecastString);
        
    imp.wakeup(600, getConditions);
}

imp.sleep(2);
getConditions();
