/*
The MIT License (MIT)

Copyright (c) 2013 Electric Imp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/


//------------------------------------------------------------------------------------------
// Sign up with an account on http://loggly.com and replace the TOKEN with the provided one.
//
const LOGGLY_URL = "https://logs-01.loggly.com/inputs/TOKEN/tag/imp/";
function log(message, callback = null) {
    if (typeof message != "object") {
        message = {message = message};
    }
    message.agenturl <- http.agenturl();
    
    http.post(LOGGLY_URL, {}, http.jsonencode(message)).sendasync(function (res) {
        if (res.statuscode != 200) server.log("Error posting to Logly: " + res.statuscode);
        if (callback) callback(res);
    })
}

//------------------------------------------------------------------------------------------
// This is a sample application for the log function above. It simply sends any "log" event 
// from the device to loggly.
//
device.on("log", function(logmsg) {
    log(logmsg);
});

