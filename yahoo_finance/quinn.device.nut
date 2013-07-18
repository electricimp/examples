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

// 6-channel 5A PWM Driver (RGB In)

// initialize some handy values
// PWM frequency in Hz
local pwm_f = 500.0;

// Configure hardware
// red pins (on most RGB tape)
hardware.pin1.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, 1.0);
// green pins (on most RGB tape)
hardware.pin8.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin9.configure(PWM_OUT, 1.0/pwm_f, 1.0);
// blue pins (on most RGB tape)
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, 1.0);


imp.configure("Quinn Financier", [], []);

agent.on("update", function(value) {
    if (value.len() != 3) {
        server.error("Device Received Invalid Color Update");
    } else {
        local red = value[0].tointeger();
        local green = value[1].tointeger();
        local blue = value[2].tointeger();
        
        hardware.pin1.write(red*(1.0/255.0));
        hardware.pin7.write(red*(1.0/255.0));
        hardware.pin8.write(green*(1.0/255.0));
        hardware.pin9.write(green*(1.0/255.0));
        hardware.pin2.write(blue*(1.0/255.0));
        hardware.pin5.write(blue*(1.0/255.0));
    }
});