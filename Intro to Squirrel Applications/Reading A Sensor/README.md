# Reading a sensor

Begin by learning the basics of working with Electric Imp. We will use Electric Imp HTS221 library to take temperature and humidity readings from a sensor. We will also use the Initial State libary to send the data we collect from the sensor to the cloud. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node.  

## Skill level

**Beginner**

This example will focus on writing squirrel code. Please visit the [getting started guide](https://electricimp.com/docs/gettingstarted/) on the Electric Imp Dev Center for insturctions on How to configure your device with BlinkUp and how to use the Electric Imp IDE.

## What You Learn

* How to use Electric Imp libraries
* How to configure a sensor and take sychonous readings
* How to send data between device and agent
* How to send data to Initial State

## What You Need

* Your 2.4GHz 802.11bgn WiFi network name (SSID) and password
* A computer with a web browser
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
* A free [Electric Imp Developer Account](https://ide.electricimp.com/login)
* A free [Initial State Account](https://www.initialstate.com/)
* HTS221 sensor wired to an imp enabled device
    * [impExplorer Developer Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130) 
    * [impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/featured-products/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)

## Instructions

* BlinkUp your device 
* Log into the [Electric Imp IDE](https://ide.electricimp.com/login)
* Create a New Model
* Copy and Paste the Device Code into the Device coding window in the IDE
* Enter the [i2c hardware object](https://electricimp.com/docs/api/hardware/i2c/) for your device into the i2c variable on line 32
* Copy and Paste the Agent Code into the Agent coding window in the IDE
* Sign into [Initial State](https://app.initialstate.com/#/login/account)
* Find your Streaming Access Key on the [My Account page](https://app.initialstate.com/#/account)
* Navigate back to the [Electric Imp IDE](https://ide.electricimp.com)
* In the Agent code enter your Initial State Streaming Access Key into the STREAMING_ACCESS_KEY constant on line 19
* Hit Build and Run to start the code
* Note the agent ID in the logs
* Navigate back to Initial State, find the Bucket that matches your agent ID
* Watch your data update in the Source, Lines, Waves, and Tile views. 
