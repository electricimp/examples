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
wavblob <- blob(50000);
new_message <- false;

/* GENERAL FUNCTIONS --------------------------------------------------------*/

// find a string in message buffer
function wavBlobFind(str) {
    //sserver.log("Searching for \""+str+"\" in blob");
    if (wavblob.len() < str.len()) {
        server.log("Blob too short! ("+wavblob.len()+" bytes)");
        server.log("Short object was of type "+typeof(wavblob));
        return -1;
    }
    local startPos = wavblob.tell();
    wavblob.seek(0,'b');
    local testString = "";
    for (local i = 0; i < str.len(); i++) {
        testString += format("%c",wavblob.readn('b'));
    }
    while ((testString != str) && (wavblob.tell() < (wavblob.len() - str.len()))) {
        //server.log(testString);
        testString = testString.slice(1);
        testString += format("%c",wavblob.readn('b'));
    }
    if (testString != str) {
        // failed to find it
        return -1;
    }
    // found it, return its position
    local pos = wavblob.tell() - str.len();
    // restore the blob handle before returning
    wavblob.seek(startPos, 'b');
    return pos;
}

// parse the format chunk header on an inbound wav file 
function getFormatData() {
    local startPos = wavblob.tell();
    wavblob.seek(inParams.fmt_chunk_offset + 4,'b');

    inParams.fmt_chunk_size = wavblob.readn('i');
    inParams.compression_code = wavblob.readn('w');
    if (inParams.compression_code == 0x01) {
        // 16-bit PCM
        inParams.width = 'w';
    } else if (inParams.compression_code == 0x06) {
        // A-law
        inParams.sample_width = 'b';
    } else {
        server.log(format("Audio uses unsupported compression code 0x%02x",
            inParams.compression_code));
        return 1;
    }
    inParams.channels = wavblob.readn('w');
    inParams.samplerate = wavblob.readn('i');
    inParams.avg_bytes_per_sec = wavblob.readn('i');
    inParams.block_align = wavblob.readn('w');
    inParams.sig_bits = wavblob.readn('w');

    server.log(format("Compression Code: %x", inParams.compression_code));
    server.log(format("Channels: %d",inParams.channels));
    server.log(format("Sample rate: %d", inParams.samplerate));

    // return the file pointer
    wavblob.seek(startPos, 'b');

    return 0;
}

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

// For big files, fetch in bite-size chunks from a url accessible by the agent
// Writes big files to the agents memory.
function fetch(url) {
    const LUMP = 4096;
    offset <- 0;

    server.log("Fetching content from " + url);
    do {
        server.log(format("Downloading (%d bytes)",offset)); 

        response <- http.get(url, 
            {Range=format("bytes=%u-%u", offset, offset+LUMP-1) }
        ).sendsync();

        if (offset == 0) {
            local totalLen = split(response.headers["content-range"], "/")[1].tointeger();
            wavblob = blob(totalLen);
        }

        wavblob.writestring(response.body);
        offset += LUMP;
    } while (response.statuscode == 206);
    
}

// Prepares and sends whatever is currently stored in the global blob to the 
// device in the proper format
function sendAudioToDevice() {
    inParams.fmt_chunk_offset = wavBlobFind("fmt ");
    
    if (inParams.fmt_chunk_offset < 0) {
        server.log("Agent: Failed to find format chunk in new message");
        return 1;
    }
    server.log("Located format chunk at offset "+inParams.fmt_chunk_offset);
    inParams.data_chunk_offset = wavBlobFind("data");
    if (inParams.data_chunk_offset < 0) {
        server.log("Agent: Failed to find data chunk in new message");
        return 1;
    }
    server.log("Located data chunk at offset "+inParams.data_chunk_offset);

    // blob to hold audio data exists at global scope
    wavblob.seek(0,'b');

    // read in the vital parameters from the file's chunk headers
    if (getFormatData()) {
        server.log("Agent: failed to get audio format data for file");
        return 1;
    }

    // seek to the beginning of the audio data chunk
    wavblob.seek(inParams.data_chunk_offset + 4,'b');
    inParams.data_chunk_size = wavblob.readn('i');
    server.log(format("Agent: at beginning of audio data chunk, length %d", inParams.data_chunk_size));

    // Notifty the device we have audio waiting, and wait for a pull request to serve up data
    device.send("new_audio", inParams);
}

/* AGENT EVENT HANDLERS -----------------------------------------------------*/
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
    server.log(format("Agent: device signaled new message ready, length %d, sample rate %d, compression code 0x%02x",
        outParams.data_chunk_size, outParams.samplerate, outParams.compression_code));
    new_message = true;
    // prep our buffer to begin writing in chunks from the device
    wavblob.seek(0,'b');
    // tell the device we're ready to receive data; device will respond with "push" and a blob
    device.send("pull", CHUNKSIZE);
});

// take in chunks of data from the device during upload
device.on("push", function(buffer) {
    local buffer_len = buffer.len();
    local num_buffers = (outParams.data_chunk_size / CHUNKSIZE) + 1;
    local buffer_index = (wavblob.tell() / CHUNKSIZE + 1);
    server.log(format("Agent: got chunk %d of %d, len %d", buffer_index, num_buffers, buffer_len));
    wavblob.writeblob(buffer);
    if (buffer_index < num_buffers) {
        // there's more file to fetch
        device.send("pull", buffer_len);
    } else {
        server.log("Agent: Done fetching recorded buffer from device");
    }
});

// Serve up a chunk of audio data from an inbound wav file when the device signals it is ready to download a chunk
device.on("pull", function(buffer_len) {
    local buffer = blob(buffer_len);
    // make a "sequence number" out of our position in audioData
    local buffer_index = ((wavblob.tell()-inParams.data_chunk_offset) / buffer_len) + 1;
    server.log("Agent: sending chunk "+buffer_index+" of "+(inParams.data_chunk_size / buffer_len));
    
    // wav data is interlaced
    // skip channels if there are more than one; we'll always take the first
    local max = buffer_len;
    local bytes_left = (inParams.data_chunk_size - (wavblob.tell() - inParams.data_chunk_offset + DATA_HEADER_LEN)) / inParams.channels;
    if (inParams.sample_width == 'w') {
        // if we're A-law encoded, it's 1 byte per sample; if we're 16-bit PCM, it's two
        bytes_left = bytes_left * 2;
    }
    if (buffer_len > bytes_left) {
        max = bytes_left;
    }
    // the data chunk of a wav file is interlaced; the first sample for each channel, then the second for each, etc...
    // grab only the first channel if this is a multi-channel file
    // sending single-channel files is recommended as the agent's memory is constrained
    for (local i = 0; i < max; i += inParams.channels) {
        buffer.writen(wavblob.readn(inParams.sample_width), inParams.sample_width);
    } 

    // pack up the sequence number and the buffer in a table
    local data = {
        index = buffer_index,
        chunk = buffer,
    }
    
    // send the data out to the device
    device.send("push", data);
});

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/getmsg" || request.path == "/getmsg/") {
        if (new_message) {
            server.log("Agent: Responding with new audio buffer, len "+outParams.data_chunk_size);
            wavblob.seek(0,'b');
            //res.send(200, http.base64encode(writeChunkHeaders())+http.base64encode(wavblob));
            local outblob = blob(wavblob.len() + 58);
            outblob.writeblob(writeChunkHeaders());
            outblob.writeblob(wavblob);
            res.send(200, outblob);
            new_message = false;
        } else {
            server.log("Agent: Responding with 204 (no new messages)");
            res.send(204, "No new messages");
        }
    } else if (request.path == "/newmsg" || request.path == "/newmsg/") {
        server.log("Agent: got a new message");
        server.log("Agent: WAV buffer length = "+request.body.len()+" bytes");
        try {
            wavblob = blob(request.body.len());
            wavblob.writestring(request.body);
            res.send(200, "OK");
        } catch (err) {
            res.send(400, err);
            return;
        }

        sendAudioToDevice();
    } else if (request.path == "/fetch" || request.path == "/fetch/") {
        local fetch_url = request.body;
        server.log("Agent: requested to fetch a new message from "+fetch_url);
        res.send(200, "OK");
        try {
            fetch(fetch_url);
        } catch (err) {
            server.log("Agent: failed to fetch new message " + err);
            return 1;
        }
        server.log("Agent: done fetching message");

        sendAudioToDevice();
    } else {
        // send a generic response to prevent browser hang
        res.send(200, "OK");
    }
});

/* EXECUTION BEGINS HERE ----------------------------------------------------*/

server.log("Agent running");
server.log("Free memory: "+imp.getmemoryfree());
