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



// =============================================================================
// String to blob conversion
function string_to_blob(str) {
    local myBlob = blob(str.len());
    for(local i = 0; i < str.len(); i++) {
        myBlob.writen(str[i],'b');
    }
    myBlob.seek(0,'b');
    return myBlob;
}

// =============================================================================
// Loads up a file and sends it in chunks to the device
function flash_load(req)
{
    // server.log(format("Loading chunk (%d-%d) of URL: %s", req.start, req.finish, req.url));
    local query = http.urlencode({url = req.url});
    local url = "https://devious-dorris.gopagoda.com/tasha?" + query;
    local headers = {Range=format("bytes=%u-%u", req.start, req.finish) };
    local res = http.get(url, headers).sendasync(function (res) {

        if (res.statuscode == 200 || res.statuscode == 206) {
            if (res.body.len() == 0) {
                device.send("flash.load.finish", req);
                busy = false;
            } else {
                // server.log(format("... Loaded chunk: %d bytes", res.body.len()));
                req.chunk <- string_to_blob(res.body);
                device.send("flash.load.data", req);
            } 
        } else if (res.statuscode == 416) {
            device.send("flash.load.finish", req);
            busy = false;
        } else {
            req.err <- res.statuscode;
            device.send("flash.load.error", req);
            busy = false;
        }

    });
}



// =============================================================================
busy <- false;
function http_request(req, res) {
    try {
        // Go away, we are busy
        if (busy) {
            return res.send(429, "We are busy doing something at the moment.\n");
        }
        
        switch (req.path) {
        case "/list":
        case "/list/":
            device.on("list", function(list) {
                res.header("Content-Type", "application/json");
                res.send(200, http.jsonencode(list) + "\n");
                device.on("list", function(l) {})
            });
            device.send("list", 1);
            break;
    
        case "/display":
        case "/display/":
            local request = http.jsondecode(req.body);
            if (!("filename" in request)) {
                return res.send(400, "Expecting 'filename' in JSON request");
            }
            device.send("display", request.filename);
            res.send(200, "Displaying\n");
            break;
    
        case "/load":
        case "/load/":
            local request = http.jsondecode(req.body);
            if (!("filename" in request) || !("url" in request)) {
                return res.send(400, "Expecting 'filename' and 'url' in JSON request");
            }
            busy = true;
            device.send("load", {filename = request.filename, url = request.url})
            res.send(200, "Loading\n");
            break;
            
        case "/cat":
        case "/cat/":
            get_new_cat();
            res.send(200, "Loading cat, meow.\n");
            break;
    
        case "/wipe":
        case "/wipe/":
            busy = true;
            device.on("wipe", function(d) {
                device.on("wipe", function(l) {})
                busy = false;
            });
            device.send("wipe", true);
            res.send(200, "Wiping memory\n");
            break;
            
        default:
            return res.send(400, "Unknown command");
        }
    } catch (e) {
        return res.send(400, e);
    }
}


function get_new_cat(d = null) {
    // Go away, we are busy
    if (busy) return;
    busy = true;
    
    local url = "http://thecatapi.com/api/images/get?format=src&results_per_page=1&type=jpg&size=small";
    http.get(url, {}).sendasync(function (response) {
        // device.send("load", {filename = request.filename, url = request.url})
        if ("location" in response.headers) {
            local url = response.headers.location;
            local filename = format("%d", math.rand());
            device.send("load", {filename = filename, url = url})
        }
    });
}


// =============================================================================
server.log("Agent started. Using agent_url = " + http.agenturl());

device.on("flash.load", flash_load);
device.on("cat", get_new_cat);
http.onrequest(http_request);


