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
 
/* 
 * Aron made this.
 */
 
 
fwd <- hardware.pin9;
bck <- hardware.pin8;
lft <- hardware.pin7;
rgt <- hardware.pin5;
chn <- hardware.pin2;

fwd.configure(DIGITAL_OUT);
bck.configure(DIGITAL_OUT);
lft.configure(DIGITAL_OUT);
rgt.configure(DIGITAL_OUT);
chn.configure(DIGITAL_OUT);

fwd.write(1);
bck.write(1);
lft.write(1);
rgt.write(1);
chn.write(1);


function forward(d=null) {
    bck.write(1);
    fwd.write(0);
}

function back(d=null) {
    fwd.write(1);
    bck.write(0);
}

function left(d=null) {
    rgt.write(1);
    lft.write(0);
}

function right(d=null) {
    lft.write(1);
    rgt.write(0);
}

function straight(d=null) {
    lft.write(1);
    rgt.write(1);
}

function neutral(d=null) {
    fwd.write(1);
    bck.write(1);
}

function stop(d=null) {
    lft.write(1);
    rgt.write(1);
    fwd.write(1);
    bck.write(1);
}

function heartbeat() {
    imp.wakeup(30, heartbeat);
    agent.send("heartbeat", 1);
}

agent.on("up", forward);
agent.on("forward", forward);
agent.on("down", back);
agent.on("back", back);
agent.on("left", left);
agent.on("right", right);
agent.on("straight", straight);
agent.on("stop", stop);
agent.on("neutral", neutral);

imp.configure("Hexbug Remote", [], [])
agent.send("ready", 0);
heartbeat();
