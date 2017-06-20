//device code
hardware.pin9.configure(DIGITAL_OUT);  // configure pin as digital output

function powerHandler(state) {
    server.log("Setting Pin9 to: " + state);
    hardware.pin9.write(state);  // set state of pin
}

// whenever we get a "power" message, run the powerHandler function 
agent.on("power", powerHandler);

