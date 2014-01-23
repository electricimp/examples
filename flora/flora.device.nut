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

// create and configure pin variables
level_sensor_en_high <- hardware.pin9;
level_sensor <- hardware.pin1;

level_sensor_en_high.configure(DIGITAL_OUT);
level_sensor.configure(PULSE_COUNTER, 0.01);

// disable level sensor
level_sensor_en_high.write(0);

function sample() {
    local count;
    local level;

    // turn on oscillator, sample, turn off
    level_sensor_en_high.write(1);
    count = level_sensor.read();
    level_sensor_en_high.write(0);
    
    // work out level
    if (count > 5000) return 0.0;
    
    // see http://www.xuru.org/rt/PowR.asp#CopyPaste
    level = math.pow(count / 3035.162425, -1.1815893306620) / 10.0;

    // bound level between 0.0 and 1.0    
    if (level < 0.0) return 0.0;
    if (level > 1.0) return 1.0;
    
    return level;
}

// poll and log data every 0.5 seconds
function poll() {
  imp.wakeup(0.5, poll);
  local moistureContent = sample() * 100.0;
  server.log(format("%0.2f", moistureContent) + "% moisture");
}

// start the poll function
poll();
