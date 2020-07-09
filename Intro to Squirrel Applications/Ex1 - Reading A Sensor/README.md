# Reading a sensor

Begin by learning the basics of programming Electric Imp. We will use Electric Imp [HTS221 library](https://developer.electricimp.com/libraries/hardware/hts221) to take temperature and humidity readings from a sensor. We will also use the [InitialState library](https://developer.electricimp.com/libraries/webservices/initialstate) to send the data we collect from the sensor to the cloud. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

## Skill level

**Beginner**

This example will focus on writing Squirrel code. Please visit the [**Getting Started Guide**](https://developer.electricimp.com/gettingstarted) on the Electric Imp Dev Center to learn how to configure your device with BlinkUp™ and how to use the Electric Imp IDE, impCentral™.

## What You Learn

* How to use Electric Imp libraries.
* How to configure a sensor and take synchronous readings.
* How to send data between device and agent.
* How to send data to a cloud service such as Initial State.

## What You Need

* Your WiFi network name (SSID) and password (not needed for cellular with imp006 or impC001).
* A computer with a web browser.
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp)) installed.
* A free [Electric Imp Developer Account](https://impcentral.electricimp.com/login).
* A free [Initial State Account](https://www.initialstate.com/).
* An HTS221 temperature/humidity sensor wired to an imp-enabled device. The hardware listed below has all the required hardware for this example.
    * [imp006 Breakout Kit](https://store.electricimp.com/collections/breakout-boards/products/imp006-cellular-and-wifi-breakout-board-kit?variant=30294487924759)
    * [impExplorer Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130)
    * [impAccelerator Battery Powered Sensor Node](https://developer.electricimp.com/hardware/resources/reference-designs/sensornode)
    * [impC001 Breakout Board](https://developer.electricimp.com/hardware/resources/reference-designs/impc001breakout)

## Instructions

* Activate your device with BlinkUp.
* Log into [impCentral](https://impcentral.electricimp.com/login).
* Create a new [Product](https://developer.electricimp.com/tools/impcentral/impcentralintroduction#app-products) and [Development Device Group](https://developer.electricimp.com/tools/impcentral/impcentralintroduction#app-development-devicegroup).
* Copy and Paste the Device Code into the **Device Code** pane in the impCentral code editor.
* Enter the [**i2c** object](https://developer.electricimp.com/api/hardware/i2c) for your device into the *i2c* variable on line 34.
* Copy and paste the Agent Code into the **Agent Code** pane in the impCentral code editor.
* Sign into [Initial State](https://api.init.st/auth/#/login/).
* Find your **Streaming Access Key** on the [My Account page](https://iot.app.initialstate.com/#/account).
* Navigate back to [impCentral](https://impcentral.electricimp.com/).
* In the Agent code enter your **Streaming Access Key** into the *STREAMING_ACCESS_KEY* constant on line 19.
* Hit the **Build and Force Restart** button to start the code.
* Note the agent ID in the logs.
* Navigate back to Initial State, find the Bucket that matches your agent ID.
* Watch your data update in the Source, Lines, Waves and Tile views on the Initial State website.
