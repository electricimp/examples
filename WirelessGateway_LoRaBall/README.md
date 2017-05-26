# WirelessGateway_LoRaBall

This example transmits accelerometer data from an Arduino Feather with a LoRa RH_RF95 to an impAccelerator Wireless Gateway with a LoRa RN2903 radio.

## Hardware

- Imp 005 ImpAccelerator Wireless
- [LoRa RN2903 Click Module](https://www.digikey.com/catalog/en/partgroup/lora-2-click/63162)
- [Arduino Feather M0 with LoRa RFM95 radio](https://www.adafruit.com/product/3178)
- [LIS3DH accelerometer](https://www.adafruit.com/product/2809)
- [NeoPixel FeatherWing 4x8 RGB LEDs](https://www.adafruit.com/product/2945)
- [Ball](https://www.amazon.com/JW-Hol-ee-Roller-Size-Assorted/dp/B00X1TMDAC/ref=sr_1_29?s=pet-supplies&ie=UTF8&qid=1495822944&sr=1-29&keywords=dog+ball)
- [Battery](https://www.adafruit.com/product/258?gclid=CNut6fqWjtQCFQ5Efgodk4AJ0w)

## Software Dependencies

- Electric Imp [IBM Watson Library](https://github.com/electricimp/IBMWatson)
- Electric Imp [Dweet.io Library](https://github.com/electricimp/Dweetio)

## Device Code
The device listens for messages from the LoRa radio attached to the Arduino. The imp filters the incoming accelerometer data for ball movement or freefall and sends these events to the agent.

## Agent Code
The agent receives events from the device and sends them to IBM Watson and Dweet.io.

Note: Dweet.io uses the Imp's Device ID as a unique identifier. IBM Watson requires an account and keys to push data. The keys have been removed from this example code, and so will have to be configured and pasted into the appropriate variables before the agent can push data.