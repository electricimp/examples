/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/


//------------------------------------------------------------------------------------------------
const CALENDAR_URL = "https://server/meeting_minder";
const REFRESH_TIME = 60; // Once a minute
function check_calendar(reschedule = true) {
    http.get(CALENDAR_URL + "/get", {}).sendasync(function (res) {
        handle_response(res.body, reschedule);
    })
}
imp.wakeup(REFRESH_TIME - (time() % 60), check_calendar);

function handle_response(body, reschedule) {
        
    local now = null;
    local next = null;
    try {
        local json = http.jsondecode(body);
        if (typeof json == "array") {
            device.send("display", null)
        } else if (typeof json == "table") {
            now = ("now" in json) ? json.now : null;
            next = ("next" in json) ? json.next : null;
            device.send("display", {now=now, next=next});
        } 
    } catch (e) {
        server.log("Exception: " + e)
    }
    
    // Set the next wakeup, either after a fixed amount of time or on the next event, whichever is sooner
    local next_wakeup = REFRESH_TIME - (time() % 60);
    if (now != null && time() + next_wakeup > now) {
        next_wakeup = now - time();
    }
    if (reschedule) {
        imp.wakeup(next_wakeup, check_calendar);
    }
    
}



//------------------------------------------------------------------------------------------------
device.on("command", function(command) {
    server.log("Command '" + command + "' requested")
    
    switch (command) {
        case "ready":
            check_calendar(false);
            break;
            
        case "end":
        case "extend":
            http.get(CALENDAR_URL + "/" + command, {}).sendasync(function (res) {
                if (res.statuscode == 200) {
                    handle_response(res.body, false);
                } else {
                    device.send("error", command)
                }
            });
            break;
    }
    
})

//------------------------------------------------------------------------------------------------
server.log("Agent booted")


