
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
// Receives a file in chunks from the device
incoming <- {};
last_wav_file <- null;
last_wav_filename <- null;
function flash_save(request) {

	local filename = request.filename;
	if (!(filename in incoming)) {
		server.log(format("Incoming new file: Expecting %d bytes of '%s.wav'", request.length, filename));
		incoming[filename] <- {};
        incoming[filename].device_id <- request.device_id;
		incoming[filename].expecting <- request.length;
		incoming[filename].received <- 0;
		incoming[filename].data <- blob(request.length);
	}

	incoming[filename].data.seek(request.start, 'b');
	incoming[filename].data.writeblob(request.data);
	incoming[filename].received += (request.finish-request.start);

	// Have we got everything?
	if (incoming[filename].received >= incoming[filename].expecting) {

		// We have everything ... POST it to the server and move on.
		local url = "https://api.emailyak.com/v1/API_KEY/json/send/email/"
		local headers = { "Content-Type": "application/json" };
        local length = incoming[filename].data.len();
        local data = {};
		local wavfile = waveHeader(length).tostring() + incoming[filename].data.tostring();

		data.SenderAddress <- "SENDER_EMAIL";
		data.FromAddress <- "FROM_EMAIL";
		data.FromName <- "FROM_NAME";
		data.ToAddress <- config.email;
		data.Subject <- "SUBJECT";
		data.TextBody <- "Please find attached your new voice recording.";
		data.Attachments <- [{ "Filename": filename+".wav", "Content": http.base64encode(wavfile) }];

		// Keep a backup of the last audio file
		last_wav_file <- wavfile;
		last_wav_filename <- filename+".wav";

		// Send it to the web service for emailing
		http.post(url, headers, http.jsonencode(data)).sendasync(function(req) {
			// Delete the file from memory
			if (filename in incoming) delete incoming[filename];

			// Check the response
            if (req.statuscode == 200) {
            	server.log("File '" + filename + ".wav' has been received, saved and acked");
        		device.send("flash.save.finish", filename);
            } else {
                server.error("File '" + filename + ".wav' failed to send to '" + config.email + "' with error code " + req.statuscode);
                device.send("flash.save.error", filename);
            }
		})
	}
}


// =============================================================================
// write chunk headers onto an outbound blob of audio data from the device
const DAC_SAMPLE_RATE = 16000;
function waveHeader(length) {
    // four essential headers: RIFF type header, format chunk header, fact header, and the data chunk header
    // data will come last, as the data chunk includes the data (concatenated outside this function)
    // RIFF type header goes first
    // RIFF header is 12 bytes, format header is 26 bytes, fact header is 12 bytes, data header is 8 bytes
    local msgBlob = blob(58);

    // Chunk ID is "RIFF"
    msgBlob.writen('R','b');
    msgBlob.writen('I','b');
    msgBlob.writen('F','b');
    msgBlob.writen('F','b');

    // four bytes for chunk data size (file size - 8)
    msgBlob.writen((msgBlob.len()+length-8), 'i');

    // RIFF type is "WAVE"
    msgBlob.writen('W','b');
    msgBlob.writen('A','b');
    msgBlob.writen('V','b');
    msgBlob.writen('E','b');
    // Done with wave file header
 
    // FORMAT CHUNK
    // first four bytes are "fmt "
    msgBlob.writen('f','b');
    msgBlob.writen('m','b');
    msgBlob.writen('t','b');
    msgBlob.writen(' ','b');

    // four-byte value here for chunk data size
    msgBlob.writen(18,'i');
    // two bytes for compression code (a-law = 0x06)
    msgBlob.writen(0x06, 'w');
    // two bytes for # of channels
    msgBlob.writen(1, 'w');
    // four bytes for sample rate
    msgBlob.writen(DAC_SAMPLE_RATE, 'i');
    // four bytes for average bytes per second
    msgBlob.writen(DAC_SAMPLE_RATE, 'i');
    // two bytes for block align - this is effectively what we use "width" for; nubmer of bytes per sample slide
    msgBlob.writen(1, 'w');
    // two bytes for significant bits per sample
    // again, this is effectively determined by our "width" parameter
    msgBlob.writen(8, 'w');
    // two bytes for "extra" data
    msgBlob.writen(0,'w');
    // END OF FORMAT CHUNK
 
    // FACT CHUNK
    // first four bytes are "fact"
    msgBlob.writen('f','b');
    msgBlob.writen('a','b');
    msgBlob.writen('c','b');
    msgBlob.writen('t','b');
    // fact chunk data size is 4
    msgBlob.writen(4,'i');
    // last four bytes are a vaguely-defined compression data field, currently just number of samples in data chunk
    msgBlob.writen(length, 'i');
    // END OF FACT CHUNK
 
    // DATA CHUNK
    // first four bytes are "data"
    msgBlob.writen('d','b');
    msgBlob.writen('a','b');
    msgBlob.writen('t','b');
    msgBlob.writen('a','b');
    // data chunk length - four bytes
    msgBlob.writen(length, 'i');
    // we return this blob, base-64 encode it, and concatenate with the actual data chunk - we're done 
 
    return msgBlob;
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

	default:
		local request = null;
		try {
			request = http.jsondecode(req.body);
			if (!("command" in request)) {
				return res.send(400, "Expecting 'command' in JSON request");
			}
		} catch (e) {
			return res.send(400, "Expecting JSON request");
		}

		switch (request.command) {
		case "config":
			config.updated <- time();
			config.email <- ("email" in request) ? request.email : config.email;
			break;
		default:
			return res.send(400, "Unknown command");
		}

		res.send(200, "OK");
	}
}


// =============================================================================
sync_config_callback <- null;
function sync_config(newconfig) {
	if (typeof newconfig == "table") {
		if (newconfig.updated > config.updated) {
			config = newconfig;
		}
		device.send("config.sync", config);
	}
}


// =============================================================================
server.log("Agent started. Using agent_url = " + http.agenturl());

config <- { updated = 0, email = null };
device.on("flash.load", flash_load);
device.on("flash.save", flash_save);
device.on("config.sync", sync_config);
http.onrequest(http_request);
