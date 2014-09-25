
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
    if (btn1.read()) {
        led.write(0);
        imp.wakeup(1, function() {
            led.write(1);
        })
    }
}


// Handle the stage change for button 2
function btn2_change() {
    imp.sleep(0.01);
    led.write(1-btn2.read());
}

// -----------------------------------------------------------------------------
// Configure the LED pin
led.configure(DIGITAL_OUT, 1);

// Configure button 1 
btn1.configure(DIGITAL_IN_PULLDOWN, btn1_change);

// Configure button 2 
btn2.configure(DIGITAL_IN_PULLDOWN, btn2_change);

