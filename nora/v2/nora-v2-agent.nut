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

*/

//----------------------------------------------------------------------
function remote(dev, method, params=[], callback=null, clear=true) {
  
    // Convert strings to tables
    if (typeof params == "string") {
        params = [params];
    }
    
    // Set a temporary event handler
    local event = dev + "." + method;
    device.on(event, function(res) {
        // Clear the old event handler and call the callback
        if (clear) device.on(event, function(d){});
        if (callback) callback(res);
    });
    
    // Send the request to the device
    device.send(dev, {method=method, params=params});
}

//----------------------------------------------------------------------
function read_remote_data(dummy = null) {
  
    /*
    // Read the individual sensors
    remote("thermistor", "read", [], function(res) {
        if (res) server.log("Temp: " + res.temperature + ", Humidity: " + res.humidity);
    })
    
    remote("thermistor", "read", [], function(res) {
        if (res) server.log("Temp: " + res.temperature + ", Humidity: " + res.humidity);
    })
    
    remote("pressure", "read", [], function (res) {
        if (res) server.log("Pressure: " + res.pressure);
    });
    
    remote("ambient", "read", [], function (res) {
        if (res) server.log("Lux: " + res.lux);
    });
    
    remote("battery", "read", [], function (res) {
        if (res) server.log(format("Battery: %0.02fV, %0.02f%%", res.volts, res.capacity));
    });
    
    // Read the temperature sensor and setup a waking thermostat
    remote("temperature", "read", [], function(res) {
        if (res) {
            server.log("Temperature: " + res.temperature);
            local min = (res.temperature-2.5).tointeger();
            local max = (res.temperature+2.5).tointeger();
            remote("temperature", "thermostat", [min, max], function(res) {
                server.log("Thermostat triggered at: " + (res.temperature));
            }, false);
            remote("temperature", "sleep", [600, 1]);
        }
    })

    // Reads the temperature when not in one-shot mode
    remote("temperature", "read_temp", [0x00], function(res) {
        if (res) {
            server.log("Temperature: " + res.temperature);
        }
    });

    // Read the accelerometer and setup a waking movement detector
    remote("accelerometer", "read", [], function (res) {
        if (res) {
            remote("accelerometer", "movement_detect", [], function (res) {
                remote("accelerometer", "stop", [], function(res) {
                    remote("accelerometer", "read", [], function (res) {
                        server.log("--------------------------");
                        server.log(format("Acceleration: [X: %0.02f, Y: %0.02f, Z: %0.02f]", res.x, res.y, res.z));
                        read_remote_data();
                    });
                });
            }, false);
            remote("accelerometer", "sleep", [600, 5]);
        }
    });

    // Send continuous stream of changes to the position of the Nora. Won't wake up Nora.
    local threshold = 0.3;
    local thresholds = { low = -threshold, high = threshold, axes = "XY"};
    remote("accelerometer", "threshold", [thresholds], function (res) {
        // server.log(format("Acceleration: [X: %0.02f, Y: %0.02f, Z: %0.02f]", res.x, res.y, res.z));
        if (res) {
            local pitch = "";
            if (res.x <= -threshold) pitch = "back";
            else if (res.x >= threshold) pitch = "forward";
            else pitch = "stop";
            
            local roll = "";
            if (res.y <= -threshold) roll = "right";
            else if (res.y >= threshold) roll = "left";
            else roll = "straight";
            
            server.log("Pitch: " + pitch + ", Roll: " + roll);

        }
        read_remote_data();
    })
    */

	// Request nora to read all sensors once a minute, sleeping offline in between, and after 5 readings, come online and present the data
    remote("nora", "read", [60, 5], function (resultset) {
        foreach (resultid,result in resultset) {
            server.log("------------[ Result set " + resultid + " ]------------")
            foreach (sensor in result) {
                foreach (k,v in sensor.value) {
                    server.log(format("... %s[%d].%s: %0.02f", sensor.name, resultid, k, v))
                }
            }
        }
    }, false);
    
}


//----------------------------------------------------------------------
device.on("ready", read_remote_data);
server.log("Agent started")

