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



const CALENDAR_URL = "http://devious-dorris.gopagoda.com/meeting_minder/get";
const REFRESH_TIME = 900; // 15 minutes, maximum

function check_calendar() {
	// Request the calendar from Google (via Pagodabox)
    http.get(CALENDAR_URL, {}).sendasync(function (res) {
        local now = null;
        local next = null;
        try {
            local json = http.jsondecode(res.body);
            if (typeof json == "array") {
                device.send("display", null)
            } else if (typeof json == "table") {
				// We have a response for storage
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
        imp.wakeup(next_wakeup, check_calendar);
        
    })
}
check_calendar();

