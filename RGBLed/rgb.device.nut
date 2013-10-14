/* Hardware
 * This example uses a common-anode RGB LED
 * A -> 3v3
 * R -> Pin1 (through a 82Ω resistor)
 * G -> Pin2 (through a 120Ω resistor)
 * B -> Pin5 (through a 120Ω resistor)
 */

imp.configure("RGB Led", [], []);
server.log("Device Started");

red <- hardware.pin1;
red.configure(PWM_OUT, 1.0/500.0, 1.0);

green <- hardware.pin2;
green.configure(PWM_OUT, 1.0/500.0, 1.0);

blue <- hardware.pin5;
blue.configure(PWM_OUT, 1.0/500.0, 1.0);

function setRGB(r,g,b) {
    red.write(r);
    green.write(g);
    blue.write(b);
}

function setLEDHandler(color) {
    server.log("Got a setLED message from the agent");
    setRGB(color.red, color.green, color.blue);
}

agent.on("setLED", setLEDHandler);
