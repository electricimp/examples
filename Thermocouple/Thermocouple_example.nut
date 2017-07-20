spi <- hardware.spiBCAD;
cs <- hardware.pinD;
cs.configure(DIGITAL_OUT, 1);

// Max 5MHz spi clk freq
spi.configure(SIMPLEX_RX | CLOCK_IDLE_LOW | MSB_FIRST, 2000);

function readThermoCoupleTemp() {
    cs.write(0);
    local b = spi.readblob(2);
    cs.write(1);
    return ((((b[0] << 6) + (b[1]>>2)) << 18) >> 18)/4; // extract reading, sign extend, divide by 4 to map to celsius
}

server.log(readThermoCoupleTemp());