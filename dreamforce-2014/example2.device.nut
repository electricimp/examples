// -----------------------------------------------------------------------------
// PIN mux
irtrx <- hardware.uart1289;
irpwm <- hardware.pin7;
btn1 <- hardware.pin1;
btn2 <- hardware.pin2;
led <- hardware.pin5;

// -----------------------------------------------------------------------------
// Notify the agent when button 1 changes state
function btn1_change() {
    imp.sleep(0.01); // Debounce
    agent.send("button1", btn1.read());
}


// Notify the agent when button 2 changes state
function btn2_change() {
    imp.sleep(0.01); // Debounce
    agent.send("button2", btn2.read());
}

// Notify the agent when the LED changes state
function led_change() {
    agent.send("led", led.read());
}

// Handle the agent requesting the LED changes
function set_led(state) {
    local oldstate = (led.read() == 0);
    if (oldstate != state) {
        led.write(state ? 0 : 1);
        led_change();
    }
}

// -----------------------------------------------------------------------------
imp.enableblinkup(true);

// Configure button 1 as an input with an event handler
btn1.configure(DIGITAL_IN_PULLDOWN, btn1_change);

// Configure button 2 as an input with an event handler
btn2.configure(DIGITAL_IN_PULLDOWN, btn2_change);

// Configure the LED pin for output
led.configure(DIGITAL_OUT, 0);

// Handle incoming agent requests to change the LED state
agent.on("led", set_led);

// Initialise the data on the agent
btn1_change();
btn2_change();
led_change();

