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

// Streaming audio player - device side

const SAMPLERATE = 16000;

// DAC pin to use on imp
dac <- hardware.fixedfrequencydac;
dacpin <- null;
switch(imp.info().type) {
    case "imp001":
    case "imp002":
        dacpin = hardware.pin5;
        break;
        
    case "imp003":
        dacpin = hardware.pinC;
        break;
        
    case "imp004m":
        // See https://developer.electricimp.com/resources/imp004maudio
        dacpin = hardware.pwmpairKD;
        break;
    
    default:
        server.log("imp does not support ffdac");
        return;
}

// Audio queue; this holds buffers from the agent, of size DEVICE_CHUNK
// We have 4 of these queued initially
q <- [];
playing <- false;

// Handler to deal with the DAC having consumed a buffer
function bufferEmpty(buffer)
{
    // Refill buffer from queue
    if (q.len() > 0) {
        local newbuffer = q.remove(0);
        if (newbuffer != null) {
            // Queue the buffer
            dac.addbuffer(newbuffer);

            // Tell agent we need another one        
            agent.send("next", 1);
            return;
        }
    }

    // If we got here, we either underran or we hit the null buffer
    // that signifies EOF
    if (playing) {
        playing = false;
        server.log("Device stopped playing");
    }
}

// Handler to deal with new audio data from agent
agent.on("buffer", function(buffer) {
    // put it in the queue
    q.append(buffer);
    
    // If we're not playing, and we have enough buffered to be safe, start
    if (!playing && q.len() >= 4) {
        playing = true;
        server.log("Device started playing");
        dac.start();
    }
});

// Configure DAC
//
// Note we pass two blobs in here; these are empty but as each is consumed 
// we will get an empty callback, which will queue more real audio data, making
// us double buffered. We can add more here for more buffer depth and hence
// ability to block in user code without affecting playback
dac.configure(dacpin, SAMPLERATE, [blob(1024), blob(1024)], bufferEmpty, AUDIO | A_LAW_DECOMPRESS);

// Tell agent we're ready to play something!
// This is an old mp3.com free MP3 "Anezal" from "Strange Angel" transcoded to 16kHz A-Law
agent.send("fetch", "http://utter.chaos.org.uk/~altman/strange_angel_anezal.alaw");