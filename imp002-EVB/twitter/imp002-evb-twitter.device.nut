// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// imp002 EVB Twitter Example Code

pwm <- hardware.pinC;

agent.on("tweet", function(dummy) {
    // play a 500 Hz tone, 50% duty cycle
    pwm.configure(PWM_OUT, 1.0/200.0, 0.5);
    // in 150 ms, switch the tone to 1 kHz
    imp.wakeup(0.15, function() {
        pwm.configure(PWM_OUT, 1.0/750.0, 0.5);
    });
    // in 300 ms, end the tone
    imp.wakeup(0.3, function() {
        // set duty cycle to 0% to stop driving beeper
        pwm.write(0.0);
    });
});