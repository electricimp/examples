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
current_image <- null;
function flash_load(req)
{
    // server.log(format("Loading chunk (%d-%d) of URL: %s", req.start, req.finish+1, req.url));
    if (current_image == null) {
        
        local headers = {};
        local query = http.urlencode({url = req.url});
        local url = "https://devious-dorris.gopagoda.com/tasha?" + query;
        local res = http.get(url, headers).sendasync(function (res) {
    
            if (res.statuscode == 200 || res.statuscode == 206) {
                if (res.body.len() == 0) {
                    device.send("flash.load.error", req);
                } else {
                    // server.log("Holding onto " + res.body.len() + " of image data");
                    current_image = res.body;
                    flash_load(req);
                }
            } else if (res.statuscode == 416) {
                device.send("flash.load.finish", req);
            } else {
                req.err <- res.statuscode;
                device.send("flash.load.error", req);
            }
    
        });
    } else {
        // Now send the data back in chunks
        if (req.start < current_image.len()) {
            req.chunk <- string_to_blob(current_image.slice(req.start, req.finish+1));
            // server.log("Serving up a chunk from " + req.start + " to " + (req.finish+1) + ", length " + req.chunk.len());
            device.send("flash.load.data", req);        
        } else {
            device.send("flash.load.finish", req);
            current_image = null;
        }
    }
}



// =============================================================================
function http_request(req, res) {
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
        try {
            local request = http.jsondecode(req.body);
            if (!("filename" in request)) {
                    return res.send(400, "Expecting 'filename' in JSON request");
            }
            device.send("display", request.filename);
            res.send(200, "Displaying\n");
        } catch (e) {
            return res.send(400, "Expecting JSON request");
        }
        break;

    case "/load":
    case "/load/":
        try {
            local request = http.jsondecode(req.body);
            if (!("filename" in request) || !("url" in request)) {
                return res.send(400, "Expecting 'filename' and 'url' in JSON request");
            }
            device.send("load", {filename = request.filename, url = request.url})
            res.send(200, "Loading\n");
        } catch (e) {
            return res.send(400, "Expecting JSON request");
        }
        break;

    default:
        return res.send(400, "Unknown command");
    }
}


// =============================================================================
server.log("Agent started. Using agent_url = " + http.agenturl());

device.on("flash.load", flash_load);
http.onrequest(http_request);


