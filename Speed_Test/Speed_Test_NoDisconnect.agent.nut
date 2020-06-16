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

start <- null;
end <- null;
size <- 0;
sofar <- 0;

device.on("net", function(n) { server.log(http.jsonencode(n)); });

device.on("start", function(s) {
    server.log("Receiving "+s+" bytes");
    size = s;
    sofar = 0;
    start = date();
});

device.on("data", function(d) {
    
    // Ignore it
    sofar += d.len();
    
    if (sofar == size) {
        end = date();
    
        // Work out diff
        local seconds = end.time - start.time;
        seconds += (end.usec - start.usec) / 1000000.0;
        server.log("Took "+seconds+" Rate "+(size/1024)/seconds+"kB/s");
    }
});

last <- time();
count <- 0;