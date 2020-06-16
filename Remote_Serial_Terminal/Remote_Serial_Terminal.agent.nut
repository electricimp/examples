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

// Updated 20191021 with fixed xtermjs version; the API changed with v4
//
// Simple serial terminal using xtermjs
// See https://connect.electricimp.com/blog/secure-web-based-serial-terminal
#require "rocky.class.nut:2.0.2"

debug <- false;

const HTML_STRING = @"<!doctype html>
 <html>
   <head>
     <link rel=""stylesheet"" href=""https://unpkg.com/xterm@3.14.5/dist/xterm.css"" />
     <script src=""https://unpkg.com/xterm@3.14.5/dist/xterm.js""></script>
   </head>
   <body>
     <div id=""terminal""></div>
     <script>
        var term = new Terminal();
        var agent = '%s';
        var lastbyte = 0;
        term.open(document.getElementById('terminal'));
        term.focus();
    
        function poll() {
            var xhttp = new XMLHttpRequest();
            xhttp.onreadystatechange = function() {
                if (this.readyState == 4) {
                    if (this.status == 200) {
                        // First line is the byte offset in ascii
                        var n = this.responseText.indexOf('\n');
                        lastbyte = this.responseText.slice(0, n);

                        // Write the data to the terminal
                        term.write(this.responseText.slice(n+1));
                    }
                    
                    // Fetch again (even if there was an error) - we long poll
                    // This prevents session death, though is obviously fairly
                    // obnoxious to ignore all errors.
                    setTimeout(poll, 100);
                }
            };
            xhttp.open('GET', agent+'/rxstream', true);
            xhttp.setRequestHeader('Range', 'bytes='+lastbyte+'-');
            xhttp.timeout = 70000; // 70s for request life; agent should close after 60s
            xhttp.send();
        }
        poll();       
        
        // Keypress handler: no attempt at being clever here
        term.on('key', (key, ev) => {
            var xhttp = new XMLHttpRequest();
            xhttp.open('POST', agent+'/txstream', true);
            xhttp.send(key);
        });        

        // Paste handler: hope it's not too big!
        term.on('paste', (paste, ev) => {
            var xhttp = new XMLHttpRequest();
            xhttp.open('POST', agent+'/txstream', true);
            xhttp.send(paste);
        });        

     </script>
   </body>
 </html>";

// Set up rocky with a long timeout: 60s
api <- Rocky({ accessControl = true, allowUnsecure = false, strictRouting = false, timeout = 60 });

// Timeouts only hit the long poll; when this happens, just return a timeout.
// If the client is still there, they will re-issue the request
api.onTimeout(function(context) {
    // Remove from the waiters queue if it's there (it should be)
    for(local i=0; i<waiters.len(); i++) {
        if (context == waiters[i].context) {
            waiters.remove(i);
            break;
        }
    }
    
    // Send a generic timeout message
    context.send(408, { "message": "Agent Timeout" });
});

// Buffer of data received from device waiting to be picked up by browser(s)
rxbuffer <- "";
rxsize <- 100*1024;
rxoldest <- 0;
rxnewest <- 0;

// HTTP requests waiting for new serial data; when we get data from the device
// we push it to all waiters immediately
waiters <- [];

// Handle RX data from device
device.on("data", function(v) {
    // Append to buffer
    rxbuffer += v;
    rxnewest += v.len();
    local rxlen = rxbuffer.len();
    
    // Trim buffer if it's oversize
    if (rxlen > rxsize) {
        rxbuffer = rxbuffer.slice(rxlen - rxsize);
        rxoldest += (rxlen - rxsize);
    }
    
    // We got new data; are there any sessions waiting for it?
    while(waiters.len()) {
        // Send the data to each session
        local session = waiters.pop();
        if (session.startat < rxoldest) session.startat = rxoldest;
        session.context.send(200, format("%d\n", rxnewest) + rxbuffer.slice(session.startat - rxoldest));
    }
})

// Set up the app's API
api.get("/", function(context) {
   // Root request: return the JS client
   local url = http.agenturl();
   context.send(200, format(HTML_STRING, url));
});

// Feed data to the terminal in the browser
api.get("/rxstream", function(context) {
    // Check range format and parse
    local range = context.req.headers.range;
    if (range.slice(0,6) == "bytes=") {
        local startat = range.slice(6).tointeger();
        
        // Work out what to send; startat bigger than rxnewest is generally only
        // when the agent has been restarted and a new request comes in
        if (startat < rxoldest) startat = rxoldest;
        if (startat > rxnewest) startat = rxnewest;

        if (debug) server.log(format("startat = %d, buffer = %d-%d", startat, rxoldest, rxnewest));

        // If there's no data, just hang for up to a minute until there is;
        // Rocky deals with this timeout, the client will just get sent a 408
        // after 60s and the client will re-issue the request
        if (rxnewest == startat) {
            if (debug) server.log("Pushing to waiters queue");
            waiters.push({ "context":context, "startat":startat });
            return;
        }
        
        // Otherwise, return now with the new data
        if (debug) server.log(format("sending %d bytes", rxbuffer.len() - (startat-rxoldest)));
        context.send(200, format("%d\n", rxnewest) + rxbuffer.slice(startat - rxoldest));
        return;
    }
    
    context.send(400, "Bad range probably");
});

api.post("/txstream", function(context) {
    device.send("data", context.req.body);
    context.send(200, "");
});

function print_sessions() {
    server.log("open sessions "+waiters.len());
    imp.wakeup(10, print_sessions);
}
if (debug) print_sessions();