led <- hardware.pin9;
button <- hardware.pin1;

ledState <- 0;

function toggleLED() {
    // flip ledState
    ledState = 1-ledState;
    if (ledState == 0) {
        server.log("LED Off");
    } else {
        server.log("LED On");
    }
    led.write(ledState);
}

function onButtonPress() {
    local state = button.read();
    
    imp.sleep(0.02);    // software debounce
    if (state == 0) {
        server.log("Button Pressed");
    } else {
        server.log("Button Released");
        toggleLED();
    }
}

led.configure(DIGITAL_OUT);
button.configure(DIGITAL_IN_PULLUP, onButtonPress);

