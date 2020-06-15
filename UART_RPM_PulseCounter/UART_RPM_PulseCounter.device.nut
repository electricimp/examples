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

// Non-blocking RPM and Pulse Counter using UART 
//
// This uses the falling edge of the input signal to trigger a UART receive.
// There will be a framing error generated, but we ignore this (and the data) and just
// use the timing information.
//
// The baudrate must be fast enough that the input signal is LOW for at least 1 bit time
// and the high time is at least 9 bit times - ie max RPM that can be detected is
// 60 * (baudrate/10).
//
// 115,200bps gives a max RPM detection rate of 691,200rpm, but you want to keep well
// below that in general.

// Pin J and pin B are connected with a wire; pinJ is the simulated RPM signal
uart <- hardware.uartABCD;
pwm <- hardware.pinJ;

// RPM; we update this every second
rpm <- 0;
lastrpm <- time();

// Intervals
interval_total <- 0;
interval_count <- 0;

function rx() {
    // Read out with timing; we don't care about the byte
    local b = uart.read() >> 8;
    
    interval_total += b;
    interval_count ++;
    
    // Print average RPM every second
    if (time() != lastrpm) {
        lastrpm = time();
        
        // Avoid a divide by zero!
        if (interval_count > 0) {
            // RPM = 60x number of pulses per second
            rpm = 60.0 * (1000000.0 / (interval_total / interval_count));

            // Reset for next time
            interval_total = interval_count = 0;
        } else {
            // No intervals? That's zero RPM
            rpm = 0;
        }
        
        server.log(format("rpm = %.3f", rpm));
    }
}

// RX only UART, timing mode
uart.configure(115200, 8, PARITY_NONE, 1, NO_TX | NO_CTSRTS | TIMING_ENABLED, rx);

// Set up PWM to simulate a particular rpm
const simulated_rpm = 4250;
pwm.configure(PWM_OUT, 1.0/(simulated_rpm/60.0), 0.9);