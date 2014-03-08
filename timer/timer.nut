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


// -----------------------------------------------------------------------------
// Timer class: Implements a simple timer class with one-off and interval timers
//              all of which can be cancelled.
//
// Author: Aron
// Created: October, 2013
//
// =============================================================================
class Timer {

    self = null;
    cancelled = false;
    paused = false;
    running = false;
    callback = null;
    interval = 0;
    params = null;
    send_self = false;
    alarm_timer = null;

    // -------------------------------------------------------------------------
    constructor(_params = null, _send_self = false) {
        params = _params;
        send_self = _send_self;
        self = this;
    }

    // -------------------------------------------------------------------------
    function update(_params) {
        params = _params;
        return self;
    }

    // -------------------------------------------------------------------------
    function set(_duration, _callback) {
        callback = _callback;
        running = true;
        cancelled = false;
        paused = false;
        if (alarm_timer) imp.cancelwakeup(alarm_timer);
        if (_duration == 0) {
            alarm();
        } else {
            alarm_timer = imp.wakeup(_duration, alarm.bindenv(self))
        }
        return self;
    }

    // -------------------------------------------------------------------------
    function repeat(_interval, _callback) {
        interval = _interval;
        return set(_interval, _callback);
    }

    // -------------------------------------------------------------------------
    function cancel() {
        if (alarm_timer) imp.cancelwakeup(alarm_timer);
        alarm_timer = null;
        cancelled = true;
        running = false;
        callback = null;
        return self;
    }

    // -------------------------------------------------------------------------
    function pause() {
        paused = true;
        return self;
    }

    // -------------------------------------------------------------------------
    function unpause() {
        paused = false;
        return self;
    }

    // -------------------------------------------------------------------------
    function alarm() {
        if (interval > 0 && !cancelled) {
            alarm_timer = imp.wakeup(interval, alarm.bindenv(self))
        } else {
            running = false;
            alarm_timer = null;
        }

        if (callback && !cancelled && !paused) {
            if (!send_self && params == null) {
                callback();
            } else if (send_self && params == null) {
                callback(self);
            } else if (!send_self && params != null) {
                callback(params);
            } else  if (send_self && params != null) {
                callback(self, params);
            }
        }
    }
}





/*............./[ Samples ]\..................
t <- Timer().set(10, function() {
     // Do something in 10 seconds
});
t <- Timer().repeat(10, function() {
     // Do something every 10 seconds
});
t.cancel();
............./[ Samples ]\..................*/
