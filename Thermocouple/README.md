# Thermocouple Examples

This example has simple code for reading temperature from a thermocouple click board and also an application that sends temperature data to Initial State. 

## Hardware
- [Imp 005 ImpAccelerator Fieldbus Gateway](https://store.electricimp.com/collections/featured-products/products/impaccelerator-fieldbus-gateway?variant=31118564754)
- [Thermocouple click board](https://shop.mikroe.com/thermo-click)

Plug the click board into the mikroBUS header on the Fieldbus Gateway. This example code uses the hardware.spiBCAD peripheral exposed by the mikroBUS header.  

**Please note:** This example code can be modified for use with a different imp by simply changing the spi configuration. MOSI is not necessary to read the thermocouple.

## Basic Usage - Read Temperature from a Thermocouple

This example shows how to read temperature from a thermocouple click board and log the result. It shows how to configure the SPI and has one function **readThermoCoupleTemp()**, which will return the temperature as an integer. The thermocouple runs on 3.3v. The range of the thermocouple is -270 to 1372 degrees celsius.

### Instructions

This example has side device code only. 

* Navigate to the [Electric Imp IDE](https://ide.electricimp.com)
* Copy and paste the [BasicUsageThermocoupleExample.device.nut](./BasicUsageThermocoupleExample.device.nut) file into the divice code window in the IDE
* Hit Build and Run to start the code

## Simple Application - Send Temperature Data to Inital State

This example sends temperature data read from a thermocouple click board to the cloud service Initial State. 

### Device Code 

The device code builds on the Basic Usage example to create a Thermocouple class. It uses the FiedbusGateway HAL (Hardware Abstraction Layer) to configure the hardware. The example then uses an Application class to read temperature from the Thermocouple and send it to the agent in a loop. The application also sets up a listener that recieves a blink message from the agent that will blink one of the LEDs on the Fielbus Gateway.  

### Agent Code

The Agent code listens for temperature readings from the device. When a reading is received the temperature is checked to see if it is above a threshold. Then both the tempertature and temperatureAlert are sent to Initial State. When the data is received by Initial State a blink message is then sent to the device.

### Instructions

* Navigate to the [Electric Imp IDE](https://ide.electricimp.com)
* Copy and paste the [SimpleApplicationThermocouleExample.device.nut](/.SimpleApplicationThermocouleExample.device.nut) file into the divice code window in the IDE 
* Copy and paste the [SimpleApplicationThermocouleExample.agent.nut](/.SimpleApplicationThermocouleExample.device.nut) file into the agent code window in the IDE
* Sign into [Initial State](https://app.initialstate.com/#/login/account)
* Find your Streaming Access Key on the [My Account page](https://app.initialstate.com/#/account)
* Navigate to back to the [Electric Imp IDE](https://ide.electricimp.com)
* In the Agent code enter your Initial State Streaming Access Key into the Application class static STREAMING_ACCESS_KEY variable
* Hit Build and Run to start the code