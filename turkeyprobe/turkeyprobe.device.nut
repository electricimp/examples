/*
Copyright (C) 2014 electric imp, inc.

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

/* Turkey Probe Device Firmware
 * Tom Byrne
 * 12/7/13
 */
 
/* CONSTS and GLOBAL VARS ====================================================*/
const LONGPRESS_TIME    = 3; // button press time to wake the imp (seconds)
const INTERVAL          = 30; // log temp data every n seconds
const TEMP_COEFF_2      = 0; // temperature 2nd-order curve fit coefficient
const TEMP_COEFF_1      = 0.0017       // temperature curve fit linear coefficient
const TEMP_OFFSET       = 7; // temperature curve fit offset
const MAXSLEEP          = 86396; // max amount of time to sleep (1 day)
 
/* GLOBAL CLASS AND FUNCTION DEFINITIONS =====================================*/

function getTemp() {
    imp.wakeup(INTERVAL, getTemp);

    vtherm_en_l.write(0);
    imp.sleep(0.01);
    local rawval = vtherm.read();
    //server.log(rawval);
    local temp = (TEMP_COEFF_2*(math.pow(rawval,2)))+(TEMP_COEFF_1*rawval)+TEMP_OFFSET; 
    temp = (temp * 1.8) + 32.0;
    vtherm_en_l.write(1);
    
    agent.send("temp",{"temp":temp,"vbat":hardware.voltage()});
}

function goToSleep() {
    wake.configure(DIGITAL_IN_WAKEUP);
    // go to sleepfor max sleep time (1 day minus 5 seconds)
    server.sleepfor(MAXSLEEP);
}

function btnPressed() {
    // wait to see if this is a long press, and go to sleep if it is
    local start = hardware.millis();
    while ((hardware.millis() - start) < LONGPRESS_TIME*1000) {
        if (!hardware.pin1.read()) {return;}
    }
    goToSleep();
}

/* AGENT EVENT HANDLERS ======================================================*/
agent.on("sleep", function(val) {
    imp.onidle(function() {
        goToSleep();
    }); 
});
 
agent.on("needDeviceId", function(val) {
    agent.send("deviceId",hardware.getdeviceid());
}); 
 
/* RUNTIME BEGINS HERE =======================================================*/

// configure hardware
wake            <- hardware.pin1;
vtherm_en_l     <- hardware.pin8;
vtherm_en_l.configure(DIGITAL_OUT);
vtherm_en_l.write(1);
vtherm          <- hardware.pin9;
vtherm.configure(ANALOG_IN);

// check wakereason and make this a shallow wake if necessary
if ((hardware.wakereason() == WAKEREASON_PIN1) || (hardware.wakereason() == WAKEREASON_TIMER)) {
    local start = hardware.millis();
    while ((hardware.millis() - start) < LONGPRESS_TIME*1000) {
        if (!hardware.pin1.read()) {goToSleep();}
    }
    
    // if we made it here, somebody's just long-pressed the power button to wake the imp
    // go ahead and boot right up.
}

// not a shallow wake; fire up the radio and let's cook a turkey
imp.configure("Turkey Probe",[],[]);
imp.setpowersave(true); // save juice, as this application is not latency-critical

wake.configure(DIGITAL_IN, btnPressed);
vtherm_en_l     <- hardware.pin8;
vtherm_en_l.configure(DIGITAL_OUT);
vtherm_en_l.write(1);
vtherm          <- hardware.pin9;
vtherm.configure(ANALOG_IN);

agent.send("justwokeup",hardware.getdeviceid());
getTemp();