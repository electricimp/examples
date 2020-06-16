// MIT License
//
// Copyright 2020 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// Streaming audio player - agent side

// ToDo: lots. Like, parsing the WAV header, transcoding in the agent, etc

// Summary:
// - device asks agent to play a URL
// - agent fetches AGENT_CHUNK sized blocks from the URL using range fetches
// - agent chops these up into DEVICE_CHUNK sized pieces and puts them in
//   send_queue. It then refills send_queue every time it gets down to half
//   empty.
// - device consumes these pieces, requesting a new one each time it has
//   queued one for the DAC
// - initially, we send 4 DEVICE_CHUNKs to the device; when it has got all
//   4 of these locally it starts playing (consuming data and hence requesting
//   more buffers)
// - in this way, the device always has ~3x DEVICE_CHUNK samples on hand
//   (~1.5s buffering with 8192 byte chunks and 16kHz sample rate)
// - the data from the device to the agent is essentially also operating in a
//   "sliding window" mode, with up to 4 buffers in flight at any time

// Buffer we will keep locally to minimize number of fetches. We will refill this
// when it gets half-empty, so we will use 1.5x this amount of memory at peak
const AGENT_CHUNK = 262144;
agent_buffer <- null;

// Chunk size we are going to send to the device
const DEVICE_CHUNK = 8192;

// URL we're fetching from & offset through the fetch
// fetching indicates if an async http request is in progress (we only do one
// at a time). done indicates that the fetching is complete, though the buffer
// may not be all sent to the device yet
url <- null;
fetch_offset <- 0;
fetching <- false;
done <- false;

// Queue of buffers to device
send_queue <- [];

// Fetch a chunk from the server and queue it for device
function fetch_chunk(ready_cb = null) {
    if (fetching) return;
    
    // Note range is inclusive
    local req = http.get(url, { "Content-Type": "application/octet-stream",
                                "Range": format("Bytes=%d-%d", fetch_offset, fetch_offset + AGENT_CHUNK - 1)});
    fetching = true;
    
    // Issue this request; when it returns, send the fetched data to the device
    req.sendasync(function(response) {
        fetching = false;
        if (response.statuscode == 200 || response.statuscode == 206) {
            local length = response.body.len();

            server.log("Fetched "+fetch_offset+"-"+(fetch_offset + length));
            fetch_offset += length;
            if (length > 0) {
                // Split it into bite size chunks & queue them ready for sending
                for(local o = 0; o < length; o += DEVICE_CHUNK) {
                    // Last chunk will be small
                    local chunklen = (length - o) > DEVICE_CHUNK ? DEVICE_CHUNK : (length - o);
                    send_queue.append(response.body.slice(o, o + chunklen));
                }
            }
            
            if (length < AGENT_CHUNK || length == 0) {
                // End of file; append a zero length sentinel
                server.log("Agent reached EOF");
                done = true;
            }
            
            // If we had a callback passed, trigger it now buffer is filled
            if (ready_cb != null) ready_cb();
        } else {
            // We'll generally get error 416 when we are beyond the end
            done = true;
            server.log(format("Got error %d: %s", response.statuscode, response.body));
        }
    });
}

// Handler for when device requests another buffer
device.on("next", function(v) {
    // Anything left?
    if (send_queue.len() == 0) {
        // Send null to finish playback
        // Generally this won't get hit - this only happens if the HTTP fetch
        // is slower than the device's audio consumption
        device.send("buffer", null);
        done = true;
    } else {
        // Send next chunk
        device.send("buffer", send_queue[0]);
        send_queue.remove(0);
        
        // Refill the agent-side buffer when we are halfway down (and not done!)
        if (!done && send_queue.len() < (AGENT_CHUNK / DEVICE_CHUNK / 2)) {
            fetch_chunk();
        }
    }
});

// When device tells us a URL to stream, start!
device.on("fetch", function(file) {
    server.log("Streaming "+file+" to device");

    // Reset offset
    fetch_offset = 0;
    done = false;
    url = file;

    fetch_chunk(function() {
        // Send first four buffers to get started
        device.send("buffer", send_queue.remove(0));
        device.send("buffer", send_queue.remove(0));
        device.send("buffer", send_queue.remove(0));
        device.send("buffer", send_queue.remove(0));
    });    
});