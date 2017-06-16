hardware.pin1.configure(DIGITAL_IN, function() {
    if (hardware.pin1.read() == 1) {
        agent.send("buttonPress", null);
    }
});

