# Reading a sensor

Begin by learning the basics of programming Electric Imp. We will use Electric Imp HTS221 library to take temperature and humidity readings from a sensor. We will also use the Initial State libary to send the data we collect from the sensor to the cloud. This code can be easily configured for use with an impExplorer Developer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board Kit.

## Skill level

**Beginner**

This example will focus on writing squirrel code. Please visit the [getting started guide](https://developer.electricimp.com/gettingstarted) on the Electric Imp Dev Center for insturctions on how to configure your device with BlinkUp and how to use the Electric Imp IDE, impCentral.

## What You Learn

* How to use Electric Imp libraries
* How to configure a sensor and take synchronous readings
* How to send data between device and agent
* How to send data to Initial State

## What You Need

* Your 2.4GHz 802.11bgn WiFi network name (SSID) and password (not needed for Cellular, impC001)
* A computer with a web browser
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
* A free [Electric Imp Developer Account](https://impcentral.electricimp.com/login)
* A free [Initial State Account](https://www.initialstate.com/)
* HTS221 temperature/humidity sensor wired to an imp enabled device. The hardware listed below has all the required hardware for this example.
    * [impExplorer Developer Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130)
    * [impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/featured-products/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)
    * [impC001 Cellular Breakout Board Kit](https://store.electricimp.com/collections/featured-products/products/impc001-breakout-board-kit-preorder?variant=7599263973399)

## Instructions

* BlinkUp your device.
* Log into the [impCentral](https://impcentral.electricimp.com/login).
* Create a new [Product](https://developer.electricimp.com/tools/impcentral/impcentralintroduction#app-products) and [Development Device Group](https://developer.electricimp.com/tools/impcentral/impcentralintroduction#app-development-devicegroup).
* Copy and Paste the Device Code into the Device coding pane in the impCentral code editor.
* Enter the [i2c hardware object](https://electricimp.com/docs/api/hardware/i2c/) for your device into the i2c variable on line 33.
* Copy and paste the Agent Code into the Agent Code pane in the impCentral code editor.
* Sign into [Initial State](https://app.initialstate.com/#/login/account).
* Find your Streaming Access Key on the [My Account page](https://app.initialstate.com/#/account).
* Navigate back to the [impCentral](https://impcentral.electricimp.com/).
* In the Agent code enter your Initial State Streaming Access Key into the STREAMING_ACCESS_KEY constant on line 19.
* Hit Build and Force Restart button to start the code.
* Note the agent ID in the logs.
* Navigate back to Initial State, find the Bucket that matches your agent ID.
* Watch your data update in the Source, Lines, Waves, and Tile views on the Inital State website.
