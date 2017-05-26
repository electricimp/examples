#require "CRC16.class.nut:1.0.0"
#require "ModbusRTU.class.nut:1.0.0"
#require "ModbusMaster.class.nut:1.0.0"
#require "Modbus485Master.class.nut:1.0.0"
#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONEncoder.class.nut:1.0.0"

pp <- PrettyPrinter(null, false);
print <- pp.print.bindenv(pp);

FieldbusGateway_005 <- {
    "LED_RED" : hardware.pinP,
    "LED_GREEN" : hardware.pinT,
    "LED_YELLOW" : hardware.pinQ,

    "MIKROBUS_AN" : hardware.pinM,
    "MIKROBUS_RESET" : hardware.pinH,
    "MIKROBUS_SPI" : hardware.spiBCAD,
    "MIKROBUS_PWM" : hardware.pinU,
    "MIKROBUS_INT" : hardware.pinXD,
    "MIKROBUS_UART" : hardware.uart1,
    "MIKROBUS_I2C" : hardware.i2cJK,

    "XBEE_RESET" : hardware.pinH,
    "XBEE_AND_RS232_UART": hardware.uart0,
    "XBEE_DTR_SLEEP" : hardware.pinXD,

    "RS485_UART" : hardware.uart2,
    "RS485_nRE" : hardware.pinL,

    "WIZNET_SPI" : hardware.spi0,
    "WIZNET_RESET" : hardware.pinXA,
    "WIZNET_INT" : hardware.pinXC,

    "USB_EN" : hardware.pinR,
    "USB_LOAD_FLAG" : hardware.pinW
}

class App {

    static DEVICE_ADDRESS = 0x01;
    static CLICK_AD1V_ADDR = 0x7000;
    static CLICK_Y1_ADDR = 8192;
    static CLICK_Y2_ADDR = 8193;
    static CLICK_Y3_ADDR = 8194;
    static CLICK_Y4_ADDR = 8195;
    static CLICK_OUT_ON = true;
    static CLICK_OUT_OFF = false;
    static NUM_READ_BYTES = 2;
    static B_THERM = 3988;
    static T0_THERM = 265;


    modbus = null;
    readingTimer = null;

    constructor(_readingTimer, debug = false) {
        readingTimer = _readingTimer;
        local opts = (debug) ? {"debug" : true} : {};
        modbus = Modbus485Master(FieldbusGateway_005.RS485_UART, FieldbusGateway_005.RS485_nRE, opts);
    }

    function run() {
        modbus.read(DEVICE_ADDRESS, MODBUSRTU_TARGET_TYPE.INPUT_REGISTER, CLICK_AD1V_ADDR, NUM_READ_BYTES, readHandler.bindenv(this))
        imp.wakeup(readingTimer, run.bindenv(this));
    }

    function readHandler(err, res) {
        if (err) {
            server.error(err);
            return;
        }
        if (typeof res == "array" && res.len() == 2) {
            local b = blob(4);
            foreach (item in res) {
                b.writen(item, 's');
            }
            b.seek(0, 'b');
            local reading = b.readn('f');
            // server.log(reading);
            local temp = convertReading(reading);
            agent.send("temp", temp);
        } else {
            print(res);
        }
    }

    function convertReading(reading) {
        local v_rat = reading / 100.0;
        local ln_therm = 0;

        ln_therm = math.log((1.0 - v_rat) / v_rat);
        local kelvin = (T0_THERM * B_THERM) / (B_THERM - T0_THERM * ln_therm);
        local celsius = kelvin - 273.15;
        server.log("Temp " + celsius + "°C");
        return celsius;
    }

    function setOutput(addr, state) {
        modbus.write(DEVICE_ADDRESS, MODBUSRTU_TARGET_TYPE.COIL, addr, 1, state, function(err, res) {
            if (err) server.error(err);
        })
    }
}

// Logs Modbus Library UART Traffic
local DEBUG = false;

// Time between temperature readings
local READING_TIMER_SEC = 10;

// Initialize Click App
local app = App(READING_TIMER_SEC, DEBUG);

// Start temperature reading loop
app.run();