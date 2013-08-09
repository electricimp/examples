/* Hardware
 * This example uses a common-anode RGB LED
 * A -> 3v3
 * R -> Pin1 (through a 82Ω resistor)
 * G -> Pin2 (through a 120Ω resistor)
 * B -> Pin5 (through a 120Ω resistor)
 */

imp.configure("RGB Led", [], []);

// configure LEDs
red <- hardware.pin1;
green <- hardware.pin2;
blue <- hardware.pin5;
red.configure(PWM_OUT, 1.0/500.0, 1.0);
green.configure(PWM_OUT, 1.0/500.0, 1.0);
blue.configure(PWM_OUT, 1.0/500.0, 1.0);

// Set LEDs
function set(r,g,b) {
    server.log(format("Setting color to (%i,%i,%i)", r,g,b));
    red.write(1 - r/255.0);
    green.write(1 - g/255.0);
    blue.write(1 - b/255.0);
}

// Turn LED off to start
set(0,0,0);

// When we get a "setRGB" message from the agent:
agent.on("setRGB", function(c) {
    // set the LEDs
    set(c.r, c.g, c.b);
});