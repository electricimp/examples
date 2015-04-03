
// Use weatherunderground to get the conditions, latitude and longitude given a location string.
// Location can be:
//   Country/City ("Australia/Sydney") 
//   US State/City ("CA/Los_Altos")
//   Lat,Lon ("37.776289,-122.395234") 
//   Zipcode ("94022") 
//   Airport code ("SFO")

// Add your own wunderground API Key here. 
// Register for free at http://api.wunderground.com/weather/api/
const WUNDERGROUND_KEY = "YOUR KEY HERE";
const WUNDERGROUND_URL = "http://api.wunderground.com/api/";
const LOCATIONSTR = "94022";
const UPDATEINTERVAL = 600;

last_weather <- server.load();
updatehandle <- null;

function getConditions(callback = null) {
    // schedule next update - prevent double-scheduled updates (in case both device and agent restart at some point)
    if (updatehandle) imp.cancelwakeup(updatehandle);
    updatehandle = imp.wakeup(UPDATEINTERVAL, getConditions);
    
    server.log(format("Agent getting current conditions for %s", LOCATIONSTR));
    // use http.urlencode to URL-safe the human-readable location string, 
    // the use string.split to remove "location=" from the result.
    local safelocationstr = split(http.urlencode({location = LOCATIONSTR}), "=")[1];
    local url = format("%s/%s/conditions/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, safelocationstr);
    local res = http.get(url, {}).sendsync();
    
    if (res.statuscode != 200) {
        server.log("Wunderground error: " + res.statuscode + " => " + res.body);
    } else {
        try {
            local response = http.jsondecode(res.body);
            local weather = response.current_observation;
            local forecastString = "";
            
            // Chunk together our forecast into a printable string
            forecastString += ("Forecast for "+weather.display_location.city+", "+weather.display_location.state+" ("+LOCATIONSTR+"): ");
            forecastString += (weather.weather+", ");
            forecastString += ("Temperature "+weather.temp_f+" °F, ");
            forecastString += (weather.temp_c+" °C, ");
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
            server.log(forecastString);
            
            // Store the weather for later
            last_weather = {conditions = weather.weather, temperature = weather.temp_c};
            server.save(last_weather);
            
            // Now let the caller know we have updated
            if (callback) callback();

        } catch (e) {
            server.error("Wunderground error: " + e)
        }
        
    }
}

// Respond to the device requesting the current weather
device.on("weather", function(d) {
    if ("conditions" in last_weather) {
        device.send("weather", last_weather);
    } else {
        getConditions(function() {
            device.send("weather", last_weather);
        });
    }
})

// Start up by grabbing the latest weather
server.log("Agent started");
getConditions();