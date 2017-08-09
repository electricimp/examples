#require "WS2812.class.nut:3.0.0"

hardware.pin1.configure(DIGITAL_OUT, 1);
spi <- hardware.spi257;
spi.configure(MSB_FIRST, 7500);
led <- WS2812(spi, 1);

function blink(a) {
    local count = 100;
    local state = 1;
    while(count) {
        local color = state ? [255, 255, 255] : [0, 0, 0];
        led.set(0, color).draw();
        state = !state;
        imp.sleep(0.1);
        --count;
    }
}

agent.on("event", blink);