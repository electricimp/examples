// Send Accelerometer data to Imp via LoRa radio
// Accelerometer: LIS3DH
// LoRa radio : RH_RF95

// Libraries
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_LIS3DH.h>
#include <Adafruit_Sensor.h>
#include <RH_RF95.h>
#include <Adafruit_NeoPixel.h>

// Accelerometer constants
#define LIS3DH_ADDR   0x18    // i2c address
#define INT1_PIN      13      // Interrupt pin

// LoRa Radio constants
#define RFM95_CS      8       // Chip select pin
#define RFM95_RST     4       // Reset pin
#define RFM95_INT     3       // Interrupt pin
#define RF95_FREQ     915.000 // Frequency, must match RX's freq

// Neopixels constants
#define LED_PIN       6       // Data pin for LEDs
#define NUMPIXELS     32      // Number of LEDs on the shield

// Initialize libraries
Adafruit_LIS3DH lis = Adafruit_LIS3DH();
RH_RF95 rf95(RFM95_CS, RFM95_INT);
Adafruit_NeoPixel pixels = Adafruit_NeoPixel(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

// for Zero, output on USB Serial console
#if defined(ARDUINO_ARCH_SAMD)
   #define Serial SerialUSB
#endif

// Application Variables
#define DEVICE_ID               "Ball_01"   // Name that identifies this ball - RED
#define LOOP_TIME               300         // Delay between loop function calls
bool debug =                    false;      // Activate logging

// Accelerometer variables
#define SEND_READING            6           // Send reading every n-th loop
int reading_loop_counter =      0;          // Count loops til next send
float freefall_threshold =      0.5;        // Threshold in G
int freefall_druation =         20;         // Num samples that must meet condition before interrupt triggered

// LED variables
#define LED_FX_DONE             6           // Stop LED FX after n-th loops
int led_loop_counter =          100;        // Counter resets to 0 when freefall event occurs, then counts up to LED_FX_DONE
bool led_on =                   false;      // Track led blink animation
uint32_t last_color;
uint32_t magenta;
uint32_t red;
uint32_t blue;
uint32_t off;

void setup() {
  Serial.begin(9600);
  delay(1000); // Wait for Serial port configuation

  ////// Neopixel Setup //////
  // Configure Color variables
  magenta = pixels.Color(255, 0, 255);
  red = pixels.Color(255, 0, 0);
  blue = pixels.Color(0, 0, 255);
  off = pixels.Color(0, 0, 0);
  last_color = blue;
  // This initializes the NeoPixel library.
  pixels.begin();
  fillPixels(off);

  //// LIS3DH Setup //////
  pinMode(INT1_PIN, INPUT_PULLUP);
  // Initialize Accelerometer
  if (debug) Serial.println("Initializing LIS3DH...");
  if (! lis.begin(LIS3DH_ADDR)) {
    if (debug) Serial.println("LIS3DH initialization falied");
    while (1);
  }
  if (debug) Serial.println("LIS3DH initialized");

  // Set accelerometer range
  lis.setRange(LIS3DH_RANGE_2_G);   // 2, 4, 8 or 16 G!
  if (debug) {
    Serial.print("Range = "); Serial.print(2 << lis.getRange()); Serial.println("G");
  }

  // Enable Freefall interrupt
  lis.getInt1(); // clear interrupt pin
  lis.setInertialInt(true, freefall_threshold, freefall_druation, (LIS3DH_X_LOW | LIS3DH_Y_LOW | LIS3DH_Z_LOW | LIS3DH_AOI));

  ////// RFM95 Setup //////
  // Configure Reset pin
  pinMode(RFM95_RST, OUTPUT);
  digitalWrite(RFM95_RST, HIGH);

  // Reset radio
  digitalWrite(RFM95_RST, LOW);
  delay(10);
  digitalWrite(RFM95_RST, HIGH);
  delay(10);

  // Initialize LoRa radio
  if (debug) Serial.println("Initializing LoRa TX radio...");
  while (!rf95.init()) {
    Serial.println("LoRa radio init failed");
    while (1);
  }
  if (debug) Serial.println("LoRa radio init OK");

  // Defaults after init are 434.0MHz, modulation GFSK_Rb250Fd250, +13dbM
  // Set radio frequency
  if (!rf95.setFrequency(RF95_FREQ)) {
    Serial.println("setFrequency failed");
    while (1);
  }
  Serial.print("Set Freq to: "); Serial.println(RF95_FREQ);

  // Defaults after init are 434.0MHz, 13dBm, Bw = 125 kHz, Cr = 4/5, Sf = 128chips/symbol, CRC on

  // The default transmitter power is 13dBm, using PA_BOOST.
  // If you are using RFM95/96/97/98 modules which uses the PA_BOOST transmitter pin, then
  // you can set transmitter powers from 5 to 23 dBm:
  rf95.setTxPower(23, false);
}


void loop() {
  reading_loop_counter++;
  bool freefall_detected = false;
  bool data_ready = false;

    // Check if time for a reading
  if (reading_loop_counter == SEND_READING) {
    // Reset loop counter
    reading_loop_counter = 1;
    // Get latest accel reading
    lis.read();
    data_ready = true;
  }

  // Check for Freefall event
  if (digitalRead(INT1_PIN) == HIGH) {
    // Read Int register to clear latch
    uint8_t interruptData = lis.getInt1();
    if ( (interruptData & 0x40) != 0 ) {
      freefall_detected = true;
      // Reset LED counter
      led_loop_counter = 0;
      if (debug) {
        // Log Interrupt events
        Serial.print("Freefall event detected. Events triggered: ");
        Serial.print("int1: "); Serial.print( ((interruptData & 0x40) != 0) ); Serial.print(",  ");
        Serial.print("xLow: "); Serial.print( ((interruptData & 0x01) != 0) ); Serial.print(",  ");
        Serial.print("xHigh: "); Serial.print( ((interruptData & 0x02) != 0) ); Serial.print(",  ");
        Serial.print("yLow: "); Serial.print( ((interruptData & 0x04) != 0) ); Serial.print(",  ");
        Serial.print("yHigh: "); Serial.print( ((interruptData & 0x08) != 0) ); Serial.print(",  ");
        Serial.print("zLow: "); Serial.print( ((interruptData & 0x010) != 0) ); Serial.print(",  ");
        Serial.print("zHigh: "); Serial.println( ((interruptData & 0x20) != 0) );
      }
    }
  }

  // Conditions met to blink LED
  if (led_loop_counter <= LED_FX_DONE) {
    led_loop_counter++;
    // toggle LED
    if (led_on) {
      // turn off
      led_on = false;
      fillPixels(off);
    } else {
      led_on = true;
      if (last_color == blue) {
        last_color = red;
        fillPixels(red);
      } else if (last_color == red) {
        last_color = magenta;
        fillPixels(magenta);
      } else if (last_color == magenta) {
        last_color = blue;
        fillPixels(blue);
      }
    }
  } else if (led_on) {
    // ensure that LEDs are off
    led_on = false;
    fillPixels(off);
  }

  // Conditions met to send data
  // Build packet and send
  if (freefall_detected || data_ready)  {

    // Start stringified data array with device id
    String data = "";
    data.concat(DEVICE_ID);

    if (freefall_detected) {
      // Append freefall event - true
      data.concat(",t");
    } else {
      // Append no event - false
      data.concat(",f");
    }

    if (data_ready) {
      // Append reading
      data.concat(","); data.concat(lis.x_g);
      data.concat(","); data.concat(lis.y_g);
      data.concat(","); data.concat(lis.z_g);
    }

    if (debug) Serial.println("Sending data to Imp...");
    if (debug) Serial.print(data);

    // Send Data to Imp
    rf95.send((uint8_t *)data.c_str(), (uint8_t)data.length());

    if (debug) Serial.println("Waiting for packet to complete...");
    delay(10);
    rf95.waitPacketSent();
    // Now wait for a reply
    uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
    uint8_t len = sizeof(buf);

    if (debug) Serial.println("Waiting for reply...");
    delay(10);
    if (rf95.waitAvailableTimeout(1000)) {
      // Should be a reply message for us now
      if (rf95.recv(buf, &len)) {
        if (debug) {
          Serial.print("Got reply: ");
          Serial.println((char*)buf);
          Serial.print("RSSI: ");
          Serial.println(rf95.lastRssi(), DEC);
        }
      } else {
        Serial.println("Receive failed");
      }
    } else {
      Serial.println("No reply, is there a listener around?");
    }
  }

  delay(LOOP_TIME);
}

void fillPixels(uint32_t color){
  for (int i = 0; i < NUMPIXELS; i++) {
    pixels.setPixelColor(i, color);
  }
  pixels.show();
}