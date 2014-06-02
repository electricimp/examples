// Snack Dispenser
imp.setpowersave(true);

//Configure Pin
motor  <- hardware.pin9;
motor.configure(DIGITAL_OUT);
motor.write(0);

agent.on("dispense", function(seconds) {
    server.log("Imp Dispensing:" + seconds);
    motor.write(1);
    imp.wakeup(seconds, function(){ motor.write(0);});
});
