// Simple Audio Playback Agent
// Play new audio by sending a POST containing the message to <agenturl>/play

// size of chunks to pull from device when fetching new recorded message
const BUFFERSIZE        = 8192;
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
    buffers             = []
}

// global buffer for audio data; we keep this at global scope so that it can be asynchronously
// accessed by device event handlers
agent_buffer <- blob(BUFFERSIZE);
// used during byte-ranged download of a new file from another server
fetch_url <- "";
fetch_offset <- 0;

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
    inParams.buffers             = [];
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
    // chunk up three buffers of data to pre-load the DAC on the device
    // device will ask for additional buffers as it neads them
    for (local i = 0; i < 3; i++) {
        local buffer = blob(BUFFERSIZE);
        buffer.writeblob(agent_buffer.readblob(BUFFERSIZE));
        inParams.buffers.push(buffer);
    }

    // agent_buffer stream is now in position to start download to device
}

/* DEVICE EVENT HANDLERS -----------------------------------------------------*/

// Serve up a chunk of audio data from an inbound wav file when the device signals it is ready to download a chunk
device.on("pull", function(buffer_len) {
    local buffer = blob(buffer_len);

    // make a "sequence number" out of our position in the audio data
    local buffer_index = 0;
    local num_buffers = inParams.data_chunk_size / buffer_len;
    buffer_index = ((agent_buffer.tell() - inParams.data_chunk_offset) / buffer_len) + 1;
    
    if (buffer_index > num_buffers) {
        // just let the device finish what we've already given it
        return;
    }
    
    server.log("Sending buffer "+buffer_index+" of "+num_buffers);
    
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
    for (local i = 0; i < bytes_to_dl; i += inParams.channels) {
        buffer.writen(agent_buffer.readn(inParams.sample_width), inParams.sample_width);
    } 
    
    // send the data out to the device
    device.send("push", buffer);
});

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (req.path == "/play") {
        server.log("New Message. WAV buffer length = "+req.body.len()+" bytes");
        try {
            getAudioParameters(req.body);
            device.send("start_playback", inParams);
            res.send(200, "OK");
            server.log("Sent buffers 1-3 to device.");
        } catch (err) {
            res.send(400, err);
            return;
        }
    } else {
        // send a response to prevent browser hang
        res.send(200, "OK");
    }
});

/* EXECUTION BEGINS HERE ----------------------------------------------------*/

server.log("Started. Free memory: "+imp.getmemoryfree());