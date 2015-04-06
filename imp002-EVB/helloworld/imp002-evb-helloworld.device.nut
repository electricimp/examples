
server.log("Device booted");

function blink() {
    imp.wakeup(1, blink);
    led.write(1-led.read());
}

led <- hardware.pin2;
led.configure(DIGITAL_OUT, 0);
blink();
