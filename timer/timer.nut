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
class timer {
    
    cancelled = false;
    callback = null;
    interval = 0;

    // -------------------------------------------------------------------------
    function set(_duration, _callback) {
        callback = _callback;
        imp.wakeup(_duration, alarm.bindenv(this))
        return this;
    }
    
    // -------------------------------------------------------------------------
    function repeat(_interval, _callback) {
        interval = _interval;
        callback = _callback;
        imp.wakeup(interval, alarm.bindenv(this))
        return this;
    }
    
    // -------------------------------------------------------------------------
    function cancel() {
        cancelled = true;
        return this;
    }
    
    // -------------------------------------------------------------------------
    function alarm() {
        if (interval > 0 && !cancelled) imp.wakeup(interval, alarm.bindenv(this))
        if (callback && !cancelled) callback();
    }
}

/*............./[ Samples ]\..................
t <- timer().set(10, function() {
     // Do something in 10 seconds
});
t <- timer().repeat(10, function() {
     // Do something every 10 seconds
});
t.cancel();
............./[ Samples ]\..................*/
