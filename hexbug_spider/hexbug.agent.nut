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
 
/* 
 * Aron made this.
 */
 
// -----------------------------------------------------------------------------
const FB_API_KEY = "";
function set_firebase(data = {}, callback = null) {

    // Also send the results to firebase
    local agentid = http.agenturl().slice(-12);
    local url = "https://devices.firebaseIO.com/agent/" + agentid + ".json?auth=" + FB_API_KEY;
    local headers = {"Content-Type": "application/json"};
    data.heartbeat <- time();
    http.request("PATCH", url, headers, http.jsonencode(data)).sendasync(function(res) {
        if (res.statuscode != 200) server.log(res.statuscode + " :=> " + res.body)
        if (callback) callback();
    });

}

device.on("heartbeat", function (state) { 
    set_firebase();
})
device.on("ready", function(d) {
});

http.onrequest(function(req, res) {
    // server.log(req.method + " " + req.path + " => " + req.body);
    res.header("Access-Control-Allow-Origin", "*")
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    
    try {
        if (req.path == "/") {
            show_index(req, res);
        } else if (req.path == "/devil") {
            serve_devil(req, res);
        } else {
            send(req, res);
        }
    } catch (e) {
        res.send(500, "Oops");
    }
})

function show_index(req, res) {
    local queryparams = {agent = http.agenturl().slice(-12)}
    res.header("Location", "https://devious-dorris.gopagoda.com/remote?" + http.urlencode(queryparams));
    res.send(307, "Moved");
}

function serve_devil(req, res) {
    res.send(200, "OK");
    
    local json = http.jsondecode(req.body);
    if ("left" in json) device.send("left", 0);
    if ("right" in json) device.send("right", 0);
    if ("key" in json) device.send(json.key, 0);
    if ("slider" in json) {
        if (json.slider.tofloat() < 0.3) {
            device.send("left", 0);
        } else if (json.slider.tofloat() > 0.7) {
            device.send("right", 0);
        } else {
            device.send("straight", 0);
        }
    }
}

function send(req, res) {
    res.send(200, "OK");
    
    local path = req.path.slice(1);
    local slash = path.find("/");
    if (slash == null) {
        server.log("Sending: " + path)
        device.send(path, 0);
    } else {
        device.send(path.slice(0,slash), 0);
        device.send(path.slice(slash+1), 0);
        server.log("Sending: " + path.slice(0,slash) + " and " + path.slice(slash+1))
    }
}


server.log("Serving HTTP from " + http.agenturl());

