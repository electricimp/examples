// Imp Vending Machine

// Constants
const DEBOUNCE_DELAY = 250; // Debounce delay (milliseconds)
const TIMEOUT = 60;         // Transaction timeout (seconds)

// Globals
// Human-readable product names
itemName <- ["Coca-Cola", "Diet Coke"];

// LED blinking status table - 1 means an LED should be blinking, 0 otherwise
blink <- [0, 0, 0, 0];

// State
enum STATE {
    productSelect = 1
    barcodeScan = 2
    dispense = 3	
}
state <- STATE.productSelect;   // Default to product select state
productSelection <- -1;         // with no product selected

// Pin aliases
uart    <- hardware.uart12; // TX pin connected to LCD screen, RX connected to barcode scanner
btn0    <- hardware.pin6;   // Left button
btn1    <- hardware.pinE;   // Right button

relay   <- [hardware.pinC, hardware.pinD];  // Left and right dispense relays
stock <- [4, 4];                            // Initial stock of each product

led <- [hardware.pin5,      // Left blue LED
        hardware.pin7,      // Left yellow LED
        hardware.pin8,      // Right blue LED
        hardware.pin9]      // Right yellow LED

lastProductSelect <- time();// Time of last product select
debounce <- 0;              // Debounce timer

// Test function - turns on display and all LEDs, plays mario theme
function bootTest() {
    writeLCD("\x16");   // Turn display on, no cursor, no blink
    writeLCD("Electric Imp\rVending Fridge");   // Write splash screen
    backlight(1);       // Turn backlight on
    setLED(0, "on");    // Turn on all LEDs
    setLED(1, "on");
    setLED(2, "on");
    setLED(3, "on");
    marioTheme();       // Play Super Mario theme
    imp.sleep(2);       // Wait until mario is done before returning
}

// Set LED 'num' to 'state', which is off, on, or blink
function setLED(num, state) {
    if (num < 0) return;
    if (state == "off") {
        blink[num] = 0;         // Disable blink
        led[num].write(0);      // Turn off LED
    }
    else if (state == "on") {
        blink[num] = 0;         // Disable blink
        led[num].write(1);      // Turn on LED
    }
    else if (state == "blink") {
        blink[num] = 1;         // Enable blink
    }
    else {
        server.error("Invalid LED state requested!");
    }
}

// Dispense an item to the user
function vend(item) {
    // Simulate button press to activate vending circuit
    if (stock[item] > 0) {
        stock[item]--;
        relay[item].write(1);
    }
    writeLCD("Vending\r" + itemName[item]);
    imp.sleep(0.1);
    relay[item].write(0);
    imp.wakeup(8, setState);
}

function button0Pressed() {
    if (btn0.read() == 0 && hardware.millis() - debounce > DEBOUNCE_DELAY) {
        server.log("Button 0 pressed");
        debounce = hardware.millis();
        setLED(2, "off");
        if (stock[0]) {
            productSelection = 0;
            writeLCD(itemName[0] + "\rScan to buy");
            setLED(0, "blink");
    	    agent.send("buttonPress", 0);
            lastProductSelect = time();
        }
        else {
            setLED(1, "blink");
            writeLCD(itemName[0] + "\rSOLD OUT");
            imp.wakeup(2, setState);
        }
    }
}

function button1Pressed() {
    if (btn1.read() == 0 && hardware.millis() - debounce > DEBOUNCE_DELAY) {
        server.log("Button 1 pressed");
        debounce = hardware.millis();
        setLED(0, "off");
        if (stock[1]) {
            productSelection = 1;
            writeLCD(itemName[1] + "\rScan to buy");
            blink[0] = 0;
            setLED(2, "blink");
    	    agent.send("buttonPress", 1);
            lastProductSelect = time();
        }
        else {
            setLED(3, "blink");
            writeLCD(itemName[1] + "\rSOLD OUT");
            imp.wakeup(2, setState);
        }
    }
}

function blinkLED(state = 1) {
    foreach (i, lite in led) {
        if (blink[i]) {
            lite.write(state);
        }
    }
    if (productSelection >= 0 && time() - lastProductSelect > TIMEOUT) {
        writeLCD("Transaction\rCanceled");
        imp.sleep(2);
        setState(STATE.productSelect);
    }
    imp.wakeup(0.25, function() { blinkLED(state?0:1) });
}

function setState(_state = STATE.productSelect) {
    state = _state;
    if (state == STATE.productSelect) {
        server.log("Entering state: productSelect");
        productSelection = -1;
        agent.send("buttonPress", -1);
        writeLCD("Select a\rProduct");
        if (stock[0]) {
            setLED(0, "on");
            setLED(1, "off");
        }
        else {
            setLED(0, "off");
            setLED(1, "on");
        }
        if (stock[1]) {
            setLED(2, "on");
            setLED(3, "off");
        }
        else {
            setLED(2, "off");
            setLED(3, "on");
        }
        if (!(stock[0] || stock[1])) {
            writeLCD("All Selections\rSOLD OUT");
        }
    }
    if (state == STATE.barcodeScan) {
        server.log("Entering state: barcodeScan");
        writeLCD("Authorizing\r(Check phone)");
        setLED(productSelection * 2, "on");
    }
}

function readScanner() {
    local byte = uart.read();
    local str = "";
    while(byte >= 0) {
        str += byte.tochar();
        imp.sleep(0.01);
        byte = uart.read();
    }
    if (str != "") {
        server.log(str);
        setState(STATE.barcodeScan);
        agent.send("verifyBarcode", str);
    }
}

function clearLCD() {
    uart.write("\x0C");
    imp.sleep(0.005);
}

function writeLCD(str){
    clearLCD();
    uart.write(str);
}

function backlight(state) {
    if (state) {
        uart.write("\x11");
    }
    else {
        uart.write("\x12");
    }
}

function marioTheme() {
    uart.write("\xD8\xD2");          // Set scale 4 (A=440), duration 1/16
    uart.write("\xE3\xE3\xE8\xE3\xE8\xDF\xE3\xE8\xE6\xE8\xE8\xE8\xD8\xE6");
}

// Barcode scanner: 1200 baud, 8 data bits, no parity bit, 1 stop bit, no CTS/RTS
uart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS, readScanner);
writeLCD("\x15");   // Turn display off

// Pin configuration
// uart.configure();
led[0].configure(DIGITAL_OUT);   led[0].write(0);
led[1].configure(DIGITAL_OUT);   led[1].write(0);
led[2].configure(DIGITAL_OUT);   led[2].write(0);
led[3].configure(DIGITAL_OUT);   led[3].write(0);
btn0.configure(DIGITAL_IN_PULLUP, button0Pressed);
btn1.configure(DIGITAL_IN_PULLUP, button1Pressed);
relay[0].configure(DIGITAL_OUT);  relay[0].write(0);
relay[1].configure(DIGITAL_OUT);  relay[1].write(0);

imp.configure("Vending Machine", [], []);
imp.setpowersave(true);

// Enable blinking routine
blinkLED();

bootTest();
setState(STATE.productSelect);

agent.on("dispense", function(arg) {
    if (arg == 0 || arg == 1) {
        vend(arg);
    }
    else {
        server.error("Agent sent dispense command for an unrecognized product.");
    }
});

agent.on("cancel", function(arg) {
    setState(STATE.productSelect);
});