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

server.log(imp.getsoftwareversion());
imp.enableblinkup(true);

agent.send("net", imp.net.info())
imp.setsendbuffersize(65535);

// Use nodisconnect
server.setsendtimeoutpolicy(RETURN_ON_ERROR_NO_DISCONNECT, WAIT_TIL_SENT, 1);

class filesender {
    _sending = null;
    _length = 0;
    _offset = 0;
    _chunksize = 4096;
    _callback = null;
    
    function constructor() {
    }
    
    function send(file, cb = null) {
        _sending = file;
        _length = _sending.len();
        _offset = 0;
        local r = agent.send("start", _length);
        if (r != 0) {
            // just try again, buffers may be full
            imp.wakeup(0, function() { send(file, cb); });
            return;
        }
        sendblock();
        _callback = cb;
    }
    
    function sendblock() {
        if (_offset == _length) {
            _sending = null;
            _length = _offset = 0;
            if (_callback != null) _callback();
            return;
        }
        
        local chunk = (_length - _offset);
        if (chunk > _chunksize) chunk = _chunksize;
        
        _sending.seek(_offset, 'b');
        local r = agent.send("data", _sending.readblob(chunk));
        if (r == 0) {
            // If we sent ok, increment _offset for next time
            _offset += chunk;
        } else if (r != SEND_ERROR_WOULDBLOCK) {
            // Some other error, log it
            server.setsendtimeoutpolicy(SUSPEND_ON_ERROR, WAIT_TIL_SENT, 10);
            server.connect();
            server.log("send returned "+r);
            return;
        }
        
        // If we got here, we need to be requeued
        imp.wakeup(0, sendblock.bindenv(this));
    }
}

// Send something repeatedly
local b = blob(64*1024);
f <- filesender();
loops <- 5;

function sendit() {
    f.send(b, function() { if (--loops) sendit(); });
}

sendit();