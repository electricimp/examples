// Solenoid is on pin 9; configure it
bell <- hardware.pin9;
bell.configure(DIGITAL_OUT);
bell.write(0);

// When we get a message, call the tonk function
agent.on("tonk", function (v) {
    // Turn solenoid on for 20ms
    bell.write(1);
    imp.wakeup(0.02, function() {
        bell.write(0);
    });
});

server.log("device up");

