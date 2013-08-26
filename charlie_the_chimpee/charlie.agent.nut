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
    // log(format("Loading chunk (%d-%d) of URL: %s", req.start, req.finish, req.url));
    local headers = {Range=format("bytes=%u-%u", req.start, req.finish) };
    local res = http.get(req.url, headers).sendasync(function (res) {
        
        if (res.statuscode == 200 || res.statuscode == 206) {
            if (res.body.len() == 0) {
                device.send("flash.load.finish", req);
            } else {
                req.chunk <- string_to_blob(res.body);
                device.send("flash.load.data", req);
            } 
        } else if (res.statuscode == 416) {
            device.send("flash.load.finish", req);
        } else {
            req.err <- res.statuscode;
            device.send("flash.load.error", req);
        }
        
    });
}



// =============================================================================
function http_request(req, res) {
	switch (req.path) {
	case "/download":
	case "/download/":
		if (last_wav_file == null || last_wav_filename == null) {
			res.send(404, "No audio files are ready yet.")
		} else {
			res.header("Content-Type", "audio/wav");
			res.header("Content-Length", last_wav_file.len())
			res.header("Content-Disposition", "attachment; filename=\"" + last_wav_filename + "\"");
			res.header("Content-Transfer-Encoding", "binary");
			res.header("Cache-Control", "private");
			res.header("Pragma", "private");
			res.header("Expires", "Mon, 26 Jul 1997 00:00:00 GMT");

			res.send(200, last_wav_file);
		}
		break;

    case "/clap":
    case "/clap/":
        device.send("clap", 1);
        res.send(200, "Clapping for you\n");
        break;
        
    case "/list":
    case "/list/":
        device.on("list", function(list) {
            res.header("Content-Type", "application/json");
            res.send(200, http.jsonencode(list) + "\n");        
            device.on("list", function(l) {})
        });
        device.send("list", 1);
        break;
        
    case "/play":
    case "/play/":
    	try {
			local request = http.jsondecode(req.body);
			if (!("filename" in request)) {
				return res.send(400, "Expecting 'filename' in JSON request");
			}
            local clap = ("clap" in request && request.clap == true);
            if (clap) device.send("clap", 1);
            device.send("play", request.filename);
            res.send(200, "Playing\n");
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
            local clap = ("clap" in request && request.clap == true);
            if (clap) device.send("clap", 1);
            device.send("load", {filename = request.filename, url = request.url, clap = clap})
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

config <- { updated = 0, email = null };
device.on("flash.load", flash_load);
device.on("flash.save", flash_save);
http.onrequest(http_request);

