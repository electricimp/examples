
// the slave address for this device is set in hardware
const ALS_ADDR = 0x52;


// ========================================================================================
// Class: Emma
// Description: Controls the Emma board including the 8-character LED panel plus the Lux meter.
// Notes: The important public methods are pushQueue(), getLux() and
class emma
{
    // Emma Default Firmware - print 8-character string to small digit display
    // Pin 1 = load
    // Pin 2 = oe_l
    // Pin 5 = data
    // Pin 7 = srclk
    // Pin 8 = scl
    // Pin 9 = sda
    
    // Byte Ordering:
    // [digit 0 (left)][1][2][3][4][5][6][7 (right)][decimal point word]
    
    // Pin layout
    //   ---- ----           -0020-    -0004-
    //   | \  |  / |     |0080|    |0010|     |0002|
    //   |  \ | /  |          \0040\    /0008/
    //   | --- --- |     -8000-              -0001-
    //   |  / | \  |          /1000/    \0200\
    //   | /  |  \ |     |4000|    |0800|    |0100|
    //    ---- ----         -2000-    -0400-

    // ========================================================================================

    // holds the last lux reading
    lux = 0.0;

    // Holds the screen buffer
    drawBuffer = null;

    // number of bytes needed to write full display
    bufferSize = 18;

    // Current animation frame
    aniQueue = [];

    // variables containing the current state and associated data
    state_data = {  "animation": "draw",
                    "message": "        .",
                    "frame": 0,
                    "frames": -1,
                    "cycles": -1,
                    "nextPop": 0,
                    "fadeIn": false,
                    "fadeOut": false,
                    "power": null
                };

    // Timers
    updateDisplayTimer = 0.2;
    updateLuxTimer = 0.5;


    // ========================================================================================

    /*
     *
     */
    constructor(max_power = 100.0) {

        // Serial Interface to AS1110 Driver ICs
        hardware.configure(SPI_257);
        hardware.spi.configure(SIMPLEX_TX | LSB_FIRST | CLOCK_IDLE_LOW, CLOCK_SPEED_400_KHZ/1000);

        // Configure oe_l and load as GPIO
        // pin 2 is pulled up inside the AS1110 driver, nominally disable
        // we will use pin 2 (oe_l) for brightness control at 1kHz
        hardware.pin2.configure(PWM_OUT, 0.0001, 0.0);
        hardware.pin1.configure(DIGITAL_OUT);

        // pin 2 is pulled up inside the AS1110 driver, nominally disable
        hardware.pin1.write(0);

        // I2C Interface to TSL2561FN
        hardware.configure(I2C_89);
        hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

        // Initialise the draw buffer
        drawBuffer = emmaBuffer(bufferSize);
        drawBuffer.setMaxPower(max_power);
        drawBuffer.clear();

        // Start the timers
        imp.wakeup(0, updateLux.bindenv(this));
        imp.wakeup(0, updateDisplay.bindenv(this));

        // Handle incoming agent requests
        agent.on("pushQueue", pushQueue.bindenv(this));
        agent.on("clearQueue", clearQueue.bindenv(this));
        agent.on("setSpeed", setSpeed.bindenv(this));
        agent.on("setPower", drawBuffer.setMaxPower.bindenv(drawBuffer));
        agent.send("status", "boot");
    }


    /*
     *
     */
    function pushQueue(top) {
        // Set the beginning time
        if ("delay" in top) {
            top.when <- time() + top.delay;
            delete top.delay;
        } else {
            top.when <- time();
        }

        if (!("animation" in top)) top.animation <- "draw";
        if (!("message" in top)) top.message <- "";
        if (!("frames" in top)) top.frames <- -1;
        if (!("cycles" in top)) top.cycles <- -1;
        if (!("duration" in top)) top.duration <- -1;
        if (!("repeat" in top)) top.repeat <- 1;
        if (!("interrupt" in top)) top.interrupt <- false;
        if (!("fadeOut" in top)) top.fadeOut <- false;
        if (!("fadeIn" in top)) top.fadeIn <- false;
        if (!("power" in top)) top.power <- null;
        if (!("speed" in top)) top.speed <- null;
        if (top.duration == -1 && top.frames == -1) {
            top.frames = drawBuffer.cleanCount(top.message)+8;
        }

        // Push this onto the queue
        for (local i = 0; i < top.repeat; i++) {
            if (top.interrupt) aniQueue.insert(0, top);
            else aniQueue.push(top);
        }
    }


    /*
     *
     */
    function clearQueue(dummy) {
        aniQueue.clear();
    }


    /*
     *
     */
    function popQueue() {

        // server.log("Pop? queue (" + aniQueue.len() + ") > 0 && time (" + time() + ") >= nextPop (" + state_data.nextPop + ") && frames (" + state_data.frames + ") <= 0");
        if (aniQueue.len() > 0 && time() >= state_data.nextPop && state_data.frames <= 0) {

            // Peek at the first item in the queue
            local top = aniQueue[0];
            if (time() >= top.when) {
                if (top.fadeOut) {
                    // server.log("Fading out: [" + state_data.message + "] to [" + top.message + "] with power starting at [" + drawBuffer.power + "]");
                    // Mark the fadeOut as done and then start the fade but DO NOT move onto the next queue item
                    aniQueue[0].fadeOut = false;
                    state_data.fadeOut = true;
                } else {

                    // There is a change of power or speed
                    if (top.power != null) {
                        drawBuffer.setMaxPower(top.power);
                    }
                    if (top.speed != null) {
                        setSpeed(top.speed);
                    }

                    if (top.fadeIn) {
                        // server.log("Fading in: [" + state_data.message + "] to [" + top.message + "] with power starting at [" + drawBuffer.power + "]");
                        // Mark the fadeIn as done and then start the fade, but move on.
                        state_data.fadeIn = true;
                        drawBuffer.setPower(1.0);
                    }  else {
                        drawBuffer.setPower(0.0);
                    }

                    // Pop the queue
                    aniQueue.remove(0);

                    // Push this onto the state machine for rendering
                    state_data.animation = top.animation;
                    state_data.message = top.message;
                    state_data.nextPop = top.duration + time();
                    state_data.frames = top.frames;
                    state_data.cycles = top.cycles;
                    state_data.frame = 0;

                }

                return top;
            }
        }
        return false;
    }

    /*
     *
     */
    function updateDisplay() {

        // Process fadeIn or fadeOut requests
        if (state_data.fadeOut) {
            if (!drawBuffer.incPower(drawBuffer.getFadeIncrement())) {
                state_data.fadeOut = false;
            }
        } else if (state_data.fadeIn) {
            if (!drawBuffer.incPower(-drawBuffer.getFadeIncrement())) {
                state_data.fadeIn = false;
            }
        }

        // Populate the display
        drawBuffer.animate(state_data.animation, state_data.frame, state_data.message);

        // Finally, update the screen.
        if (drawBuffer.changed) {
            redrawBuffer();
        }

        // If we are done fading in or out then pop the next item off the queue
        if (!state_data.fadeIn && !state_data.fadeOut) {
            popQueue();
        }

        // Update some counters
        if (state_data.frames > 0) state_data.frames--;
        state_data.frame++;

        // Set the next update
        imp.wakeup(updateDisplayTimer, updateDisplay.bindenv(this));
    }


    /*
     *
     */
    function setSpeed(speedFPS) {
        if (speedFPS > 0) {
            updateDisplayTimer = 1 / speedFPS.tofloat();
        }
    }
    
    
    /*
     *
     */
    function redrawBuffer() {
        server.show(drawBuffer.toString());

        // Write the buffer
        hardware.spi257.write(drawBuffer.getBuffer());

        // Toggle the load button
        hardware.pin1.write(1);
        imp.sleep(0.001);
        hardware.pin1.write(0);

        // Set the power level
        hardware.pin2.write(drawBuffer.getPower());

    }


    /*
     *
     */
    function updateLux() {
        local reg0 = hardware.i2c89.read(ALS_ADDR, "\xAC", 2);
        local reg1 = hardware.i2c89.read(ALS_ADDR, "\xAE", 2);
        if (reg0 != null && reg1 != null) {
            local channel0 = ((reg0[1] & 0xFF) << 8) | (reg0[0] & 0xFF);
            local channel1 = ((reg1[1] & 0xFF) << 8) | (reg1[0] & 0xFF);
            local ratio = channel1/channel0.tofloat();

            if (ratio <= 0.52) {
                lux = (0.0315 * channel0 - 0.0593 * channel0 * math.pow(ratio,1.4));
            } else if (0.52 < ratio && ratio <= 0.65) {
                lux = (0.0229 * channel0 - 0.0291 * channel1);
            } else if (0.65 < ratio && ratio <= 0.8) {
                lux = (0.0157 * channel0 - 0.0180 * channel1);
            } else if (0.80 < ratio && ratio <= 1.30) {
                lux = (0.00338 * channel0 - 0.00260 * channel1);
            } else {
                lux = 0;
            }
        }

        // start the next ALS conversion
        hardware.i2c89.write(ALS_ADDR, "\x80\x03");
        imp.wakeup(updateLuxTimer, updateLux.bindenv(this));
    }


    /*
     *
     */
    function getLux() {
        return lux;
    }

}


// ========================================================================================
class emmaBuffer
{
    buffer = null;
    pos = 0;
    len = 0;
    power = 0.0;
    max_power = 0.0;
    changed = false;

    lastSentence = "";
    lastOffset = 0;
    lastPower = 0.0;

    fade_frames = 10;

    // hex translations (LSB) of characters (upper case / alphanum only)
    hexTable =
    {
        ['0']=0x75AE, ['1']=0x0102,  ['2']=0xE427, ['3']=0x252D, ['4']=0x8183, ['5']=0xA5A5,
        ['6']=0xE5A5, ['7']=0x082C,  ['8']=0xE5A7, ['9']=0xA5A7, ['A']=0xC1A7, ['B']=0x2D37,
        ['C']=0x64A4, ['D']=0x2D36,  ['E']=0xE4A5, ['F']=0xC0A5, ['G']=0x65A5, ['H']=0xC183,
        ['I']=0x2C34, ['J']=0x6506,  ['K']=0xC288, ['L']=0x6480, ['M']=0x41CA, ['N']=0x43C2,
        ['O']=0x65A6, ['P']=0xC0A7,  ['Q']=0x67A6, ['R']=0xC2A7, ['S']=0xA5A5, ['T']=0x0834,
        ['U']=0x6582, ['V']=0x5088,  ['W']=0x6D82, ['X']=0x1248, ['Y']=0x0848, ['Z']=0x342C,
        [' ']=0x0000, ['\'']=0x0008, ['$']=0xADB5, ['%']=0x9DB9, ['*']=0x9A59, ['-']=0x8001,
        ['+']=0x8811, ['<']=0x0208,  ['>']=0x1040, ['[']=0x60A0, [']']=0x0506, ['(']=0x60A0,
        [')']=0x0506, ['\\']=0x0240, ['/']=0x1008, ['^']=0x1200, ['_']=0x2400, [',']=0x1000,
        ['=']=0xA401, ['?']=0x022C,  ['!']=0x0240, ['#']=0xFFFF, ['@']=0x64B7
    }


    /*
     *
     */
    constructor(size) {
        len = size;
        buffer = blob(len);
        clear();
    }

    /*
     *
     */
    function getBuffer() {
        changed = false;
        buffer.seek(0, 'b');
        return buffer.readblob(len);
    }

    /*
     *
     */
    function toString() {
        local sentence = format("%d%% =>", 100.0 - 100.0 * power);
        buffer.seek(0, 'b');
        for (local i = 0; i < buffer.len(); i+=2) {
            local wrd = buffer.readn('w');
            sentence = sentence + " " + format("0x%04X", wrd);
        }
        buffer.seek(pos, 'b');
        return sentence;
    }

    /*
     *
     */
    function start() {
        pos = 2;
        buffer.seek(2, 'b');
    }

    /*
     *
     */
    function clear() {
        buffer.seek(0, 'b');
        for (local i = 0; i < len; i++) {
            buffer.writen(0x00, 'b');
        }
        start();
        changed = true;
    }

    /*
     *
     */
    function setMaxPower(newmax) {
        max_power = (1.0 - newmax/100.0);
        if (power < max_power) {
            power = max_power;
            changed = true;
        }
        return max_power;
    }

    /*
     *
     */
    function getPower() {
        return power;
    }

    /*
     *
     */
    function getFadeIncrement() {
        return (1.0-max_power)/fade_frames;
    }

    /*
     *
     */
    function setPower(newpower) {
        if (newpower <= max_power) newpower = max_power;
        if (newpower >= 1.0) newpower = 1.0;
        if (newpower != lastPower) changed = true;
        power = lastPower = newpower;
        return power;
    }

    /*
     *
     */
    function incPower(powerinc) {
        local newpower = power + powerinc;
        if (newpower <= max_power) newpower = max_power;
        if (newpower >= 1.0) newpower = 1.0;
        if (newpower != lastPower) changed = true;
        power = lastPower = newpower;
        return power > max_power && power < 1.0;
    }

    /*
     *
     */
    function write(sentence, offset = 0) {
        // Check if we have a new sentence
        if (sentence == lastSentence && offset == lastOffset) return;
        lastSentence = sentence;
        lastOffset = offset;

        // Start at the beginning of a clean buffer (also marks it as changed)
        clear();

        // Write the character to the buffer
        local i = 0;
        for (; i < sentence.len(); i++) {
            if (i < offset) continue;
            local ch = sentence[i];
            if (ch == '.') {
                // Take the dot out and store it in the first word as a bitfield
                offset++;
                buffer.seek(0, 'b');
                local periodWord = buffer.readn('w');
                periodWord = periodWord | (0x01 << 6+pos/2);
                buffer.seek(0, 'b');
                buffer.writen(periodWord, 'w');
                buffer.seek(pos, 'b');
            } else if (pos < len) {
                // Write the encoded character out
                local ech = encodeCharacter(ch);
                buffer.writen(ech, 'w');
                pos += 2;
            } else {
                // We have no more space in the buffer
                break;
            }
        }
    }


    /*
     *
     */
    function animate(style, frame, param=null) {
        // Select the animation
        local chars = [];
        local fullFrame = null;

        // server.log("Animate: style=" + style + ", frame=" + frame + ", param=" + param);
        switch (style) {
            case "draw":
                fullFrame = clean(param);
                break;
            case "walk-left":
                fullFrame = "        " + clean(strip(param)) + "        ";
                local fullFrameLen = cleanCount(fullFrame);
                fullFrame = cleanSlice(fullFrame, frame%(fullFrameLen-8));
                break;
            case "walk-right":
                fullFrame = "        " + strip(param);
                local fullFrameLen = cleanCount(fullFrame);
                fullFrame = cleanSlice(fullFrame, fullFrameLen-frame%fullFrameLen);
                break;
            case "cycle-in":
                chars = [0x8000, 0x0040, 0x0010, 0x0008, 0x0001, 0x0200, 0x0800, 0x1000];
                break;
            case "cycle-out":
                chars = [0x0004, 0x0002, 0x0100, 0x0400, 0x2000, 0x4000, 0x0080, 0x0020];
                break;
            case "dashes":
                if (frame % 2 == 0) fullFrame = "_.-_.-_.-_.-_.-_.-";
                else fullFrame = "-_.-_.-_.-_.-_.-_.";
                break;
            case "ribbon":
                if (frame % 2 == 0) fullFrame = "/[]<>[]\\";
                else fullFrame = "\\][><][/";
                break;
            case "time":
                local d = date(time() - 7*60*60);
                fullFrame = format(" %02d.%02d.%02d ", d.hour, d.min, d.sec);
                break;
            case "date":
                local d = date(time() - 7*60*60);
                switch (d.wday) {
                    case 0: d.sday <- "SUN"; break;
                    case 1: d.sday <- "MON"; break;
                    case 2: d.sday <- "TUE"; break;
                    case 3: d.sday <- "WED"; break;
                    case 4: d.sday <- "THU"; break;
                    case 5: d.sday <- "FRI"; break;
                    case 6: d.sday <- "SAT"; break;
                }
                switch (d.month) {
                    case 0: d.smonth <- "JAN"; break;
                    case 1: d.smonth <- "FEB"; break;
                    case 2: d.smonth <- "MAR"; break;
                    case 3: d.smonth <- "APR"; break;
                    case 4: d.smonth <- "MAY"; break;
                    case 5: d.smonth <- "JUN"; break;
                    case 6: d.smonth <- "JUL"; break;
                    case 7: d.smonth <- "AUG"; break;
                    case 8: d.smonth <- "SEP"; break;
                    case 9: d.smonth <- "OCT"; break;
                    case 10: d.smonth <- "NOV"; break;
                    case 11: d.smonth <- "DEC"; break;
                }
                fullFrame = "" + d.sday + " " + d.day + " " + d.smonth + " " + d.year;
                return animate("walk-left", frame, fullFrame);
        }

        // If we have a full frame, use it
        if (fullFrame != null) {
            write(fullFrame);

        // Otherwise animate the characters in sync
        } else if (chars.len() > 0) {
            changed = true;
            buffer.seek(0, 'b');
            buffer.writen(0x0000, 'w');
            for (local i = 2; i < len; i+=2) {
                buffer.writen(chars[frame % chars.len()], 'w');
            }
        }

    }

    /*
     *
     */
    function encodeCharacter(inputChar) {
        if (inputChar in hexTable) {
            return hexTable[inputChar];
        } else {
            return hexTable[' '];
        }
    }

    /*
     *
     */
    function clean(sentence) {

        sentence = sentence.toupper();

        do {
            // Replace all double-dots with dot-space-dot.
            local l = sentence.find("..");
            if (l == null) {
                break;
            } else {
                sentence = sentence.slice(0, l+1) + " " + sentence.slice(l+1);
            }
        } while (true);

        do {
            // Replace all colons with dot.
            local l = sentence.find(":");
            if (l == null) {
                break;
            } else {
                sentence = sentence.slice(0, l) + "." + sentence.slice(l+1);
            }
        } while (true);

        // Add a dot after every question mark and exclamation point
        for (local i = sentence.len()-1; i >= 0; i--) {
            if (sentence[i] == '?' || sentence[i] == '!') {
                sentence = sentence.slice(0, i+1) + "." + sentence.slice(i+1);
            }
        }

        // Special case of . at the start. Needs a space padding.
        if (sentence.len() > 0 && sentence[0] == '.') {
            sentence = " " + sentence;
        }

        return sentence;
    }

    /*
     *
     */
    function cleanCount(sentence) {
        local count = 0;
        for (local i = 0; i < sentence.len(); i++) {
            local ch = sentence[i];
            if (ch != '.') count++;
        }
        return count;
    }

    /*
     *
     */
    function cleanSlice(sentence, offset) {
        local sliceFrom = 0;
        for (; sliceFrom < offset && sliceFrom < sentence.len(); sliceFrom++) {
            if (sentence[sliceFrom] == '.') offset++;
        }
        if (sliceFrom >= sentence.len()) return "";
        if (sentence[sliceFrom] == '.') sliceFrom++;
        return sentence.slice(sliceFrom);
    }

}


// ========================================================================================
// TODO list:
// - Callbacks
//    - Trigger at the end of each animation state
//    - Trigger to request the next display buffer (5x a second)
// ========================================================================================

imp.configure("Emma 8-Char Display", [], []);
e <- emma();
