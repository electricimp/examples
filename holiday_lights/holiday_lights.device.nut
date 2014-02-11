
 
// -----------------------------------------------------------------------------
const BULBS = 25;
const FPS = 5;

// ----------------------------------------------------------------------------
class colorEffects {
    
    spi = null;
    drawBuffer = null;
    updateBufferTimer = FPS;
    aniFrame = 0;
    aniQueue = null;
    aniSequence = null;
    
    
    // ........................................................................
    constructor(_bulbs = BULBS) {
        
        // Initialise the hardware
        spi = hardware.spi257;
        spi.configure(CLOCK_IDLE_LOW, 15000);

        // Initialise the buffers
        drawBuffer = bulbBuffer(_bulbs);
        renderBuffer();
        aniQueue = queue();
        
        // Start the drawing
        imp.wakeup(0, updateBuffer.bindenv(this));
        
        // Let the agent know we are online and handle incoming requests
        agent.on("pushQueue", aniQueue.push.bindenv(aniQueue));
        agent.on("clearQueue", aniQueue.clear.bindenv(aniQueue));
        agent.send("status", "online");        
    }
    
    // ........................................................................
    function updateBuffer() {
        aniSequence = aniQueue.pop(aniSequence);
        // server.log(aniSequence == null ? "Null" : (aniSequence.animation + ":" + aniSequence.frames));
        
        if (aniSequence != null) {
            
            if (!("animation" in aniSequence)) aniSequence.animation <- "walk";
            if (!("color1" in aniSequence)) aniSequence.color1 <- "white";
            if (!("color2" in aniSequence)) aniSequence.color2 <- "blue";
            if (!("steps" in aniSequence)) aniSequence.steps <- 1;
            if (!("frames" in aniSequence)) aniSequence.frames <- null;
            if (!("speed" in aniSequence)) aniSequence.speed <- FPS;
            if (!("brightness" in aniSequence)) aniSequence.brightness <- 100;
            if (!("new" in aniSequence)) aniSequence.new <- false;
            
            aniSequence.steps = aniSequence.steps.tointeger();
            aniSequence.speed = aniSequence.speed.tointeger();
            aniSequence.brightness = aniSequence.brightness.tointeger();
            if ("frames" in aniSequence && aniSequence.frames != null) {
                aniSequence.frames = aniSequence.frames.tointeger();
            }
            
            if (aniSequence.new) aniFrame = 0;
            updateBufferTimer = aniSequence.speed;
            
            switch (aniSequence.animation)
            {
                case "fixed":
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        drawBuffer.setBulb(i, aniSequence.color1, aniSequence.brightness);
                    }
                    break;
                
                case "walk":
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        if ((i+aniFrame) % aniSequence.steps == 0) {
                            drawBuffer.setBulb(i, aniSequence.color1, aniSequence.brightness);
                        } else if ((i+aniFrame) % aniSequence.steps == 1) {
                            drawBuffer.setBulb(i, aniSequence.color2, aniSequence.brightness);
                        } else if ("color3" in aniSequence) {
                            drawBuffer.setBulb(i, aniSequence.color3, aniSequence.brightness);
                        } else {
                            drawBuffer.setBulb(i, aniSequence.color2, aniSequence.brightness);                            
                        }
                    }
                    break;
                    
                case "twinkle":
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        drawBuffer.setBulb(i, aniSequence.color1, aniSequence.brightness);
                    }
                    for (local i = 0; i < math.rand() % drawBuffer.bulbs; i++) {
                        drawBuffer.setBulb(math.rand() % drawBuffer.bulbs, aniSequence.color2, aniSequence.brightness);
                    }            
                    break;
                    
                case "pastel":
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        drawBuffer.setBulb(i, math.rand() % 0x7FFF, aniSequence.brightness);
                    }
                    break;
                    
                case "random":
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        local ci1 = math.rand() % drawBuffer.colors.len();
                        local ci2 = 0;
                        local color = "";
                        foreach (coli,colr in drawBuffer.colors) {
                            if (ci1 == ci2++) color = coli;
                        }
                        drawBuffer.setBulb(i, color, aniSequence.brightness);
                    }
                    break;
                    
                case "fadein":
                    aniSequence.steps = aniSequence.steps <= 0 ? 1 : aniSequence.steps;
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        drawBuffer.setBulb(i, aniSequence.color1, (aniFrame*aniSequence.steps) % 100);
                    }
                    break;
                    
                case "fadeout":
                    aniSequence.steps = aniSequence.steps <= 0 ? 1 : aniSequence.steps;
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        drawBuffer.setBulb(i, aniSequence.color1, 100 - ((aniFrame*aniSequence.steps) % 100));
                    }
                    break;

                case "smooth":
                    local color1 = drawBuffer.toColorRgb(aniSequence.color1);
                    local color2 = drawBuffer.toColorRgb(aniSequence.color2);
                    if (aniSequence.steps <= 0) aniSequence.steps = 1;
                    if (aniSequence.frames == null) {
                        local distance = 0;
                        for (local i = 0; i < 3; i++) {
                            local d = math.abs(color1[0] - color2[0]);
                            if (d > distance) distance = d;
                        }
                        aniSequence.frames = (1.0 * distance / aniSequence.steps).tointeger() + 1;
                    }
                    
                    local step = aniFrame * aniSequence.steps;
                    local r  = (color1[0] + (color2[0] - color1[0]) * (step % (0xFF + 1)) / 0xFF).tointeger();
                    local g  = (color1[1] + (color2[1] - color1[1]) * (step % (0xFF + 1)) / 0xFF).tointeger();
                    local b  = (color1[2] + (color2[2] - color1[2]) * (step % (0xFF + 1)) / 0xFF).tointeger();

                    // server.log(format(" %02d [ %02X,%02X,%02X ]  +  [ %02X,%02X,%02X ] = [ %02X,%02X,%02X ]", aniFrame, color1[0], color1[1], color1[2], color2[0], color2[1], color2[2], r, g, b));
                    
                    local color = [r, g, b];                    
                    for (local i = 0; i < drawBuffer.bulbs; i++) {
                        drawBuffer.setBulb(i, color);
                    }
                    break;

            }

            // Render the buffer to the serial port
            renderBuffer();
        }
        
        aniFrame++;
        
        imp.wakeup(1.0 / updateBufferTimer, updateBuffer.bindenv(this));
    }
    

    // ........................................................................
    function renderBuffer() {
        // server.log("Render");
        local out = drawBuffer.render();
        spi.write("\x00\x00\x00\x00"); // 32 bits of zero
        spi.write(out);
        spi.write("\x00\x00\x00\x00"); // 32 bits of zero
    }


}



// ----------------------------------------------------------------------------
class queue {
    
    items = null;
    
    // ........................................................................
    constructor() {
        items = [];
    }
    
    // ........................................................................
    function clear(dummy = null) {
        items.clear();
    }


    // ........................................................................
    function push(item) {
        items.push(item);
    }

    // ........................................................................
    function pop(sequence = null) {
        // Check if we have still got more time in the current animation
        if ("frames" in sequence && sequence.frames != null && --sequence.frames > 0) {
            // As you were
        } else {
            if ("frames" in sequence) sequence.frames = 0;
            
            if (items.len() > 0) {
                // Now remove that item
                local item = items[0];
                items.remove(0);
                item.new <- true;
                return item;
            }
        }
        
        if ("new" in sequence) sequence.new = false;
        
        return sequence;
    }    
}

// ----------------------------------------------------------------------------
class bulbBuffer {
    
    bulbs = 0;
    bulbDetails = null;

    colors = {
                "red":    [0xFF, 0x00, 0x00],
                "green":  [0x00, 0xFF, 0x00],
                "blue":   [0x00, 0x00, 0xFF],
                "aqua":   [0x00, 0xFF, 0xFF],
                "yellow": [0xFF, 0xFF, 0x00],
                "magenta":[0xFF, 0x00, 0xFF],
                "white":  [0xFF, 0xC0, 0x80],
                "black":  [0x00, 0x00, 0x00],
                "pink":   [0xC0, 0x10, 0x80],                
                "purple": [0x80, 0x00, 0x80],
                "teal":   [0x00, 0x80, 0x80],
                "skyblue":[0x00, 0xBF, 0xFF],
                "orange": [0xFF, 0x20, 0x00]
    };
    

    // ........................................................................
    constructor(_bulbs) {
        
        bulbs = _bulbs;

        // Initialise the bulb array
        bulbDetails = [];
        for (local i = 0; i < bulbs; i++) {
            local newbulb = { "color": 0x00, "brightness": 0x00, "changed": true };
            bulbDetails.push(newbulb);
        }
    }
    
    
    // ........................................................................
    // drawBuffer.setBulb(i, [red, green, blue]);
    // drawBuffer.setBulb(i, 0xFFF);
    // drawBuffer.setBulb(i, "pink");
    function setBulb(position, color = 0x00, brightness = 100) {
        
        if (position >= 0 && position < bulbs) {
            color = toColorHex(color);
            brightness = (1.0 * brightness / 100.00 * 0xFF).tointeger();
            if (brightness > 0xFF) brightness = 0xFF;
            if (brightness < 0) brightness = 0x00;
            
            if ((bulbDetails[position].color != color) || (bulbDetails[position].brightness != brightness)) {
                bulbDetails[position].color = color;
                bulbDetails[position].brightness = brightness;
                bulbDetails[position].changed = true;
            }
        }
    }
    
    
    // ........................................................................
    function render() {
        
        local out = blob(2 * bulbs);
        for(local i=0; i<bulbs; i++) {
            
            // Seek and write the buffer
            out.writen((bulbDetails[i].color >> 8) & 0xFF, 'b');
            out.writen(bulbDetails[i].color & 0xFF, 'b');
        }
        
        return out;        
    }
    

    // ........................................................................
    function toColorHex(color) {
        
        // Convert strings first
        if (typeof color == "string") {
            if (color in colors) {
                color = colors[color];
            } else {
                color = 0x0;
            }
        } 
        
        // Now convert arrays, tables and integers.
        local newcolor = null;
        if (typeof color == "array") {
            newcolor = ((color[0].tointeger() & 0xF8) << 7) | ((color[1].tointeger() & 0xF8) << 2) | ((color[2].tointeger() & 0xF8) >> 3);
        } 
        else if (typeof color == "table") {
            newcolor = ((color.r.tointeger() & 0xF8) << 7) | ((color.g.tointeger() & 0xF8) << 2) | ((color.b.tointeger() & 0xF8) >> 3);
        } 
        else if (typeof color == "integer") {
            newcolor = color;
        }
        
        return (0x8000 | newcolor);
    }
    
    
    // ........................................................................
    function toColorRgb(color) {
        local newcolor = null;
        if (typeof color == "string") {
            if (color in colors) {
                newcolor = colors[color];
            } else {
                newcolor = [0, 0, 0];
            }
        } 
        if (typeof color == "integer") {
            newcolor = [];
            newcolor.push((color >> 7) & 0xF8);
            newcolor.push((color >> 2) & 0xF8);
            newcolor.push((color << 3) & 0xF8);
        } 
        
        return newcolor;
    }
    
}


// ----------------------------------------------------------------------------
// Regularly update the server
function regular_update() {
    imp.wakeup(30, regular_update);
    agent.send("update", {});
}


// ----------------------------------------------------------------------------
imp.enableblinkup(true);
c <- colorEffects(48);
regular_update();

server.log("Device ready!");


