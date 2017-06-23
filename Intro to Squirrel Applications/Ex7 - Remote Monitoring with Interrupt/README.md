# Remote Monitoring Application with Interrupt

In this example we will create a remote monitoring application that takes asynchronous sensor readings using the Promise libary and detects freefall events. We will conserve power by putting the device to sleep between readings. The device will connect periodically to send readings and will also wake and connect if a freefall is detected. This code can be easily configured for use with an impExplorer Developer Kit (imp001 model only) or impAccelerator Battery Powered Sensor Node. 

## Skill level

**Advanced**

This example will focus on writing squirrel code. Please visit the [getting started guide](https://electricimp.com/docs/gettingstarted/) on the Electric Imp Dev Center for insturctions on How to configure your device with BlinkUp and how to use the Electric Imp IDE.

## What You Learn

* How to use Electric Imp libraries
* How to use a Hardware Abstraction Layer (HAL)
* How to write a `class` in Squirrel
* How to configure sensors to take asychronous readings using the Promise library
* How to configure the acceleromter's freefall interrupt
* How to configure and use NV storage
* How to put the imp into sleep mode
* How to wake on an interrupt
* How to program your device to [run offline](https://electricimp.com/docs/resources/offline/)
* How to change the default connection policy
* How to send data between device and agent using Message Manager library
* How to send data to Initial State

## What You Need

* Your 2.4GHz 802.11bgn WiFi network name (SSID) and password
* A computer with a web browser
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
* A free [Electric Imp Developer Account](https://ide.electricimp.com/login)
* A free [Initial State Account](https://www.initialstate.com/)
* One of the imp hardware boards listed below
    * [impExplorer Developer Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130) 
    * [impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/featured-products/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)

## Instructions

* BlinkUp your device 
* Log into the [Electric Imp IDE](https://ide.electricimp.com/login)
* Create a New Model
* Copy and Paste the Device Code into the Device coding window in the IDE
* Locate the HAL for your hardware. The HAL files can be found on Github in the repositories linked below. Find the `.HAL.nut` file in the repository that matches your hardware. 
    * [impExplorer Developer Kit HAL](https://github.com/electricimp/ExplorerKitHAL)
    * [impAccelerator Battery Powered Sensor Node](https://github.com/electricimp/SensorNodeHAL)
* Copy and Paste the HAL table into the code in the HARDWARE ABSTRACTION LAYER section. Below is an example of what a HAL table will look like when insterted into the code. *Please note:* DO NOT copy and paste from thie example, use the HAL found in github. 

```
// HARDWARE ABSTRACTION LAYER
// ---------------------------------------------------
// HAL's are tables that map human readable names to 
// the hardware objects used in the application. 

// Copy and Paste Your HAL here
ExplorerKit_001 <- {
    "LED_SPI" : hardware.spi257,
    "SENSOR_AND_GROVE_I2C" : hardware.i2c89,
    "TEMP_HUMID_I2C_ADDR" : 0xBE,
    "ACCEL_I2C_ADDR" : 0x32,
    "PRESSURE_I2C_ADDR" : 0xB8,
    "POWER_GATE_AND_WAKE_PIN" : hardware.pin1,
    "AD_GROVE1_DATA1" : hardware.pin2,
    "AD_GROVE2_DATA1" : hardware.pin5
}


// POWER EFFICIENT REMOTE MONITORING APPLICATION CODE
// ---------------------------------------------------
```

* Assign your hardware class variables. In the Application class before the constructor you will find a number of class variables. You will need to re-assign the hardware variables so they look something like the example below. *Please note:* DO NOT copy and paste from thie example, as these values may differ from the ones in your HAL.

```
// REMOTE MONITORING INTERRUPT APPLICATION CODE
// --------------------------------------------------------
// Application code, take readings from our sensors
// and send the data to the agent 

class Application {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC = 30;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC = 300;
    // Max number of stored readings
    static MAX_NUM_STORED_READINGS = 20;
    // Time to wait after boot before turning off WiFi
    static BOOT_TIMER_SEC = 60;
    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 10;

    // Hardware variables
    i2c             = ExplorerKit_001.SENSOR_AND_GROVE_I2C; // Replace with your sensori2c
    tempHumidAddr   = ExplorerKit_001.TEMP_HUMID_I2C_ADDR; // Replace with your tempHumid i2c addr
    pressureAddr    = ExplorerKit_001.PRESSURE_I2C_ADDR; // Replace with your pressure i2c addr
    accelAddr       = ExplorerKit_001.ACCEL_I2C_ADDR; // Replace with your accel i2c addr
    wakePin         = ExplorerKit_001.POWER_GATE_AND_WAKE_PIN; // Replace with your wake pin

    // Sensor variables
    tempHumid = null;
    pressure = null;
    accel = null;

    // Message Manager variable
    mm = null;
    
    // Flag to track first disconnection
    _boot = true;

    constructor() {...}
```

* Copy and Paste the Agent Code into the Agent coding window in the IDE
* Sign into [Initial State](https://app.initialstate.com/#/login/account)
* Find your Streaming Access Key on the [My Account page](https://app.initialstate.com/#/account)
* Navigate back to the [Electric Imp IDE](https://ide.electricimp.com)
* In the Agent code enter your Initial State Streaming Access Key into the Application class static STREAMING_ACCESS_KEY variable on line 24
* Hit Build and Run to start the code
* Note the agent ID in the logs
* Navigate back to Initial State, find the Bucket that matches your agent ID
* Watch your data update in the Source, Lines, Waves, and Tile views on the Inital State website.  
