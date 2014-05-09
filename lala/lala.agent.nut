// Lala Audio Impee Agent
// New audio is sent to the device by sending the URL of the message to <agenturl>/fetch
// or by sending a POST containing the message to <agenturl>/newmsg
// New messages from device can be downloaded with GET request to <agenturl>/getmsg

/* CONSTs and GLOBALS -------------------------------------------------------*/

// size of chunks to pull from device when fetching new recorded message
const CHUNKSIZE         = 8192;
const FMT_CHUNK_LEN     = 25; // length of format chunk in WAV file
const DATA_HEADER_LEN   = 8;

// parameters read from WAV headers on inbound files
inParams <- {
    fmt_chunk_offset    = null,
    fmt_chunk_size      = null,
    data_chunk_offset   = null,
    data_chunk_size     = null,
    /* two supported compression codes:
        0x01 = 16-bit PCM
        0x06 = 8-bit ITU G.711 A-Law
    */
    compression_code    = null,
    /* character to use in blob operations; depends on sample width:
        'b' = 1 byte per sample (A-law)
        'w' = 2 bytes per sample (16-bit PCM)
    */
    sample_width        = null,
    // if the inbound file is multi-channel, we send only the first channel to the imp
    channels            = null,
    samplerate          = null,
    avg_bytes_per_sec   = null,
    block_align         = null,
    sig_bits            = null,
}

// parameters to write to the WAV headers in outbound files
// these are provided by the device when it records and uploads a message
outParams <- {
    data_chunk_size     = null,
    sample_width        = null,
    compression_code    = null, 
    samplerate          = null,
}
// global buffer for audio data; we keep this at global scope so that it can be asynchronously
// accessed by device event handlers
agent_buffer <- blob(CHUNKSIZE);
new_message <- false;
// used during byte-ranged download of a new file from another server
fetch_url <- "";
fetch_offset <- 0;

// write chunk headers onto an outbound blob of audio data from the device
function writeChunkHeaders() {
    // four essential headers: RIFF type header, format chunk header, fact header, and the data chunk header
    // data will come last, as the data chunk includes the data (concatenated outside this function)
    // RIFF type header goes first
    // RIFF header is 12 bytes, format header is 26 bytes, fact header is 12 bytes, data header is 8 bytes
    local msgblob = blob(58);
    // Chunk ID is "RIFF"
    msgblob.writen('R','b');
    msgblob.writen('I','b');
    msgblob.writen('F','b');
    msgblob.writen('F','b');
    // four bytes for chunk data size (file size - 8)
    msgblob.writen((msgblob.len()+outParams.data_chunk_size - 8), 'i');
    // RIFF type is "WAVE"
    msgblob.writen('W','b');
    msgblob.writen('A','b');
    msgblob.writen('V','b');
    msgblob.writen('E','b');
    // Done with wave file header

    // FORMAT CHUNK
    // first four bytes are "fmt "
    msgblob.writen('f','b');
    msgblob.writen('m','b');
    msgblob.writen('t','b');
    msgblob.writen(' ','b');
    // four-byte value here for chunk data size
    msgblob.writen(18,'i');
    // two bytes for compression code
    msgblob.writen(outParams.compression_code, 'w');
    // two bytes for # of channels
    msgblob.writen(1, 'w');
    // four bytes for sample rate
    msgblob.writen(outParams.samplerate, 'i');
    // four bytes for average bytes per second
    if (outParams == 'b') {
        msgblob.writen(outParams.samplerate, 'i');
    } else {
        msgblob.writen((outParams.samplerate * 2), 'i');
    }
    // two bytes for block align - this is effectively what we use "width" for; nubmer of bytes per sample slide
    if (outParams.sample_width == 'b') {
        msgblob.writen(1, 'w');
    } else {
        msgblob.writen(2, 'w');
    }
    // two bytes for significant bits per sample
    // again, this is effectively determined by our "width" parameter
    if (outParams.sample_width == 'b') {
        msgblob.writen(8, 'w');
    } else {
        msgblob.writen(16, 'w');
    }
    // two bytes for "extra" data
    msgblob.writen(0,'w');
    // END OF FORMAT CHUNK

    // FACT CHUNK
    // first four bytes are "fact"
    msgblob.writen('f','b');
    msgblob.writen('a','b');
    msgblob.writen('c','b');
    msgblob.writen('t','b');
    // fact chunk data size is 4
    msgblob.writen(4,'i');
    // last four bytes are a vaguely-defined compression data field, currently just number of samples in data chunk
    msgblob.writen(outParams.data_chunk_size, 'i');
    // END OF FACT CHUNK

    // DATA CHUNK
    // first four bytes are "data"
    msgblob.writen('d','b');
    msgblob.writen('a','b');
    msgblob.writen('t','b');
    msgblob.writen('a','b');
    // data chunk length - four bytes
    msgblob.writen(outParams.data_chunk_size, 'i');
    // we return this blob, base-64 encode it, and concatenate with the actual data chunk - we're done 

    return msgblob;
}

// set all the inbound audio parameters back to null
function resetInParams() {
    inParams.fmt_chunk_offset    = null;
    inParams.fmt_chunk_size      = null;
    inParams.data_chunk_offset   = null;
    inParams.data_chunk_size     = null;
    inParams.compression_code    = null;
    inParams.sample_width        = null;
    inParams.channels            = null;
    inParams.samplerate          = null;
    inParams.avg_bytes_per_sec   = null;
    inParams.block_align         = null;
    inParams.sig_bits            = null;
}

// parse the format chunk header on an inbound wav file 
// Input: format chunk as a blob. This blob needs to start at "fmt ", the header for the chunk
//      vital parameters are parsed into inParams
// Return: None
function parseFmtChunk(buffer) {
    inParams.fmt_chunk_size = buffer.readn('i');
    inParams.compression_code = buffer.readn('w');
    if (inParams.compression_code == 0x01) {
        // 16-bit PCM
        inParams.width = 'w';
    } else if (inParams.compression_code == 0x06) {
        // A-law
        inParams.sample_width = 'b';
    } else {
        throw(format("Audio uses unsupported compression code 0x%02x",inParams.compression_code));
    }
    inParams.channels = buffer.readn('w');
    inParams.samplerate = buffer.readn('i');
    inParams.avg_bytes_per_sec = buffer.readn('i');
    inParams.block_align = buffer.readn('w');
    inParams.sig_bits = buffer.readn('w');

    server.log(format("Compression Code: %x", inParams.compression_code));
    server.log(format("Channels: %d",inParams.channels));
    server.log(format("Sample rate: %d", inParams.samplerate));
}

// parse the format chunk header on an inbound wav file 
function getAudioParameters(buffer = null) {
    resetInParams();
    fetch_offset = 0;
    local fmt_offset = null;
    local data_offset = null;
    
    if (buffer) {        
        server.log("Searching for headers in local buffer, len "+buffer.len());
        
        inParams.fmt_chunk_offset = buffer.find("fmt ");
        inParams.data_chunk_offset = buffer.find("data");
        
        if (inParams.fmt_chunk_offset == null || inParams.data_chunk_offset == null) {
            throw "Unable to locate headers in new message buffer."
        } 
        server.log("Located format chunk at offset "+inParams.fmt_chunk_offset);
        server.log("Located data chunk at offset "+inParams.data_chunk_offset);
        
        // move the inbound message into the agent buffer as a blob so we can parse the headers
        agent_buffer.seek(0,'b');
        agent_buffer.writestring(buffer);
        agent_buffer.seek(inParams.fmt_chunk_offset + 4,'b');
        try {
            parseFmtChunk(agent_buffer);
        } catch (err) {
            throw "Error parsing format chunk: "+err;
        }
        agent_buffer.seek(inParams.data_chunk_offset + 4,'b');
        inParams.data_chunk_size = agent_buffer.readn('i');
        // agent_buffer stream is now in position to start download to device
    } else {
        server.log("Searching for headers at" + fetch_url);
        do {
            server.log(format("Searching (%d bytes)",fetch_offset + CHUNKSIZE)); 
    
            response <- http.get(fetch_url, {Range=format("bytes=%u-%u", fetch_offset, fetch_offset + CHUNKSIZE - 1) }).sendsync();
            fmt_offset = response.body.find("fmt ");
            if (fmt_offset) {
                inParams.fmt_chunk_offset = fmt_offset + fetch_offset;
                server.log("Located format chunk at offset "+inParams.fmt_chunk_offset);
            }
    
            data_offset = response.body.find("data");
            if (data_offset) {
                inParams.data_chunk_offset = data_offset + fetch_offset;
                server.log("Located data chunk at offset "+inParams.data_chunk_offset);
            }
    
            fetch_offset += CHUNKSIZE;
            if ((fmt_offset != null) && (data_offset != null)) { 
                // done getting the vitals on this file; quit looking through it
                break; 
            }
        } while (response.statuscode == 206);
    
        if (fmt_offset == null || data_offset == null) {
            // we walked the whole file and didn't find the headers
            local err = "Unable to locate WAV headers on target file at "+fetch_url;
            fetch_url = "";
            throw err;
        }
    
        // download and read what we need from the format chunk
        local fmt_chunk = blob(FMT_CHUNK_LEN);
        fmt_chunk.writestring(http.get(fetch_url, { Range=format("bytes=%u-%u", inParams.fmt_chunk_offset + 4, inParams.fmt_chunk_offset + FMT_CHUNK_LEN) }).sendsync().body);
        fmt_chunk.seek(0,'b');
        try {
            parseFmtChunk(fmt_chunk);
        } catch (err) {
            throw "Error parsing format chunk: "+err;
        }
    
        // download the size of the data chunk
        local data_chunk_size = blob(4);
        data_chunk_size.writestring(http.get(fetch_url, {Range=format("bytes=%u-%u", inParams.data_chunk_offset + 4, inParams.data_chunk_offset + 8) }).sendsync().body);
        data_chunk_size.seek(0,'b');
        inParams.data_chunk_size = data_chunk_size.readn('i');
    
        // move the remote pointer to start of the data chunk
        fetch_offset = inParams.data_chunk_offset + 8;
    
        // Next: we send "new_audio" event. Device responds with "pull" event, and we pull from the fetch_url because it is non-null
    }
}

/* DEVICE EVENT HANDLERS -----------------------------------------------------*/
// hook for the device to start uploading a new message 
device.on("new_audio", function(params) {
    outParams.data_chunk_size = params.len;
    // the imp sends its sample width; if it's 'w', the imp is not using compression
    // if the width is 'b', the imp is using A-law compression
    outParams.sample_width = params.sample_width;
    if (outParams.sample_width == 'b') {
        outParams.compression_code = 0x06;
    } else {
        outParams.compression_code = 0x01;
    }
    outParams.samplerate = params.samplerate;
    server.log(format("Device signaled new message ready, length %d, sample rate %d, compression code 0x%02x",
        outParams.data_chunk_size, outParams.samplerate, outParams.compression_code));
    new_message = true;
    // prep our buffer to begin writing in chunks from the device
    agent_buffer.seek(0,'b');
    // tell the device we're ready to receive data; device will respond with "push" and a blob
    device.send("pull", CHUNKSIZE);
});

// take in chunks of data from the device during upload
device.on("push", function(buffer) {
    local buffer_len = buffer.len();
    local num_buffers = (outParams.data_chunk_size / CHUNKSIZE) + 1;
    local buffer_index = (agent_buffer.tell() / CHUNKSIZE + 1);
    server.log(format("Got chunk %d of %d, len %d", buffer_index, num_buffers, buffer_len));
    agent_buffer.writeblob(buffer);
    if (buffer_index < num_buffers) {
        // there's more file to fetch
        device.send("pull", buffer_len);
    } else {
        server.log("Done fetching recorded buffer from device");
    }
});

// Serve up a chunk of audio data from an inbound wav file when the device signals it is ready to download a chunk
device.on("pull", function(buffer_len) {
    local buffer = blob(buffer_len);

    // make a "sequence number" out of our position in the audio data
    local buffer_index = 0;
    if (fetch_url != "") {
        buffer_index = ((fetch_offset - inParams.data_chunk_offset) / buffer_len) + 1;
    } else {
        buffer_index = ((agent_buffer.tell() - inParams.data_chunk_offset) / buffer_len) + 1;
    }
    server.log("Sending chunk "+buffer_index+" of "+(inParams.data_chunk_size / buffer_len));
    
    // wav data is interlaced
    // skip channels if there are more than one; we'll always take the first
    local bytes_to_dl = buffer_len;
    local bytes_left = (inParams.data_chunk_size - (fetch_offset - inParams.data_chunk_offset + DATA_HEADER_LEN)) / inParams.channels;
    if (inParams.sample_width == 'w') {
        // if we're A-law encoded, it's 1 byte per sample; if we're 16-bit PCM, it's two
        bytes_left = bytes_left * 2;
    }
    if (buffer_len > bytes_left) {
        bytes_to_dl = bytes_left;
    }

    // the data chunk of a wav file is interlaced; the first sample for each channel, then the second for each, etc...
    // grab only the first channel if this is a multi-channel file
    // sending single-channel files is recommended as the agent's memory is constrained
    if (fetch_url != "") {
        local multichannel_buffer = blob(bytes_to_dl * inParams.channels);
        multichannel_buffer.writestring(http.get(fetch_url, { Range=format("bytes=%u-%u", fetch_offset, fetch_offset + (bytes_to_dl * inParams.channels)) }).sendsync().body);
        multichannel_buffer.seek(0,'b');
        for (local i = 0; i < bytes_to_dl; i += inParams.channels) {
            buffer.writen(multichannel_buffer.readn(inParams.sample_width), inParams.sample_width);
        } 
    } else {
        for (local i = 0; i < bytes_to_dl; i += inParams.channels) {
            buffer.writen(agent_buffer.readn(inParams.sample_width), inParams.sample_width);
        } 
    }

    // pack up the sequence number and the buffer in a table
    local data = {
        index = buffer_index,
        chunk = buffer,
    }
    
    // send the data out to the device
    device.send("push", data);
    
    // increment the remote pointer
    if (fetch_url != "") {
        fetch_offset += (bytes_to_dl * inParams.channels);
    }
});

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (req.path == "/getmsg" || req.path == "/getmsg/") {
        server.log("Request received for latest recorded message.");
        if (new_message) {
            server.log("Responding with new audio buffer, len "+outParams.data_chunk_size);
            agent_buffer.seek(0,'b');
            //res.send(200, http.base64encode(writeChunkHeaders())+http.base64encode(wavblob));
            local outblob = blob(agent_buffer.len() + 58);
            outblob.writeblob(writeChunkHeaders());
            outblob.writeblob(agent_buffer);
            res.send(200, outblob);
            // free the memory back up
            agent_buffer = blob(CHUNKSIZE);
            // outblob will simply fall out of scope
            new_message = false;
        } else {
            server.log("Responding with 204 (no new messages)");
            res.send(204, "No new messages");
        }
    } else if (req.path == "/newmsg" || req.path == "/newmsg/") {
        server.log("New Message. WAV buffer length = "+req.body.len()+" bytes");
        try {
            getAudioParameters(req.body);
            device.send("new_audio", inParams);
            res.send(200, "OK");
        } catch (err) {
            res.send(400, err);
            return;
        }
    } else if (req.path == "/fetch" || req.path == "/fetch/") {
        fetch_url = req.body;
        server.log("Requested to fetch a new message from "+fetch_url);
        res.send(200, "OK");
        try {
            getAudioParameters();
            device.send("new_audio", inParams); 
            // device then begins download by sending a "pull" event   
        } catch (err) {
            server.log("Error Fetching New Audio: " + err);
            return;
        }
    } else {
        // send a response to prevent browser hang
        res.send(200, "OK");
    }
});

/* EXECUTION BEGINS HERE ----------------------------------------------------*/

server.log("Started. Free memory: "+imp.getmemoryfree());