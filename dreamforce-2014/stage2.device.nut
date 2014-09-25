
// -----------------------------------------------------------------------------
// PIN mux
irtrx <- hardware.uart1289;
irpwm <- hardware.pin7;
btn1 <- hardware.pin1;
btn2 <- hardware.pin2;
led <- hardware.pin5;

// -----------------------------------------------------------------------------
// Handle the stage change for button 1
function btn1_change() {
    imp.sleep(0.01);
    agent.send("button1", btn1.read());
    if (btn1.read()) set_led(true);
}


// Handle the stage change for button 2
function btn2_change() {
    imp.sleep(0.01);
    agent.send("button2", btn2.read());
    if (btn2.read()) set_led(false);
}

// Notify the agent that the LED has changed
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
// Configure button 1 
btn1.configure(DIGITAL_IN_PULLDOWN, btn1_change);

// Configure button 2 
btn2.configure(DIGITAL_IN_PULLDOWN, btn2_change);

// Configure the LED pin
led.configure(DIGITAL_OUT, 1);

// Configure the LED to respond to agent requests
agent.on("led", set_led);

// Initialise the data
btn1_change();
btn2_change();
led_change();

