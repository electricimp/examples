
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
    // Debounce (give the button a chance to settle)
    imp.sleep(0.01);    
    // Read the button state and if down (value of 1) then
    if (btn1.read()) {  
        // Turn the LED on
        led.write(1);
        // Wait a half second
        imp.wakeup(0.5, function() { 
            // Turn the LED off again
            led.write(0); 
        })
    }
}


// Handle the stage change for button 2
function btn2_change() {
    // Debounce (give the button a chance to settle)
    imp.sleep(0.01);
    // Set the LED state to match the button state
    led.write(btn2.read());
}

// -----------------------------------------------------------------------------
// Configure the LED pin as digital output and initialise its value to 0
led.configure(DIGITAL_OUT, 0);

// Configure button 1 as an input and set an event handler
btn1.configure(DIGITAL_IN_PULLDOWN, btn1_change);

// Configure button 2 as an input and set an event handler
btn2.configure(DIGITAL_IN_PULLDOWN, btn2_change);

