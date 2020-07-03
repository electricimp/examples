# Adding Cloud Services To The Simple Remote Monitoring Application

In this example we will use the device code from [Example 3](../Ex3%20-%20Simple%20Remote%20Monitoring%20Application), but adapt the agent code to send data to an additional cloud service, IBM Watson IoT.

## Skill level

**Beginner**

This example will focus on writing Squirrel code. Please visit the [**Getting Started Guide**](https://developer.electricimp.com/gettingstarted) on the Electric Imp Dev Center to learn how to configure your device with BlinkUp™ and how to use the Electric Imp IDE, impCentral™.

## What You Learn

* How to update agent code to send data to multiple cloud services.

## What You Need

* Your WiFi network name (SSID) and password (not needed for cellular with imp006 or impC001).
* A computer with a web browser.
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp)) installed.
* A free [Electric Imp Developer Account](https://impcentral.electricimp.com/login).
* A free [Initial State Account](https://www.initialstate.com/).
* An [IBM Bluemix account](https://console.ng.bluemix.net/registration/).
* One of the imp hardware boards listed below:
    * [imp006 Breakout Kit](https://store.electricimp.com/collections/breakout-boards/products/imp006-cellular-and-wifi-breakout-board-kit?variant=30294487924759)
    * [impExplorer Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130)
    * [impAccelerator Battery Powered Sensor Node](https://developer.electricimp.com/hardware/resources/reference-designs/sensornode)
    * [impC001 Breakout Board](https://developer.electricimp.com/hardware/resources/reference-designs/impc001breakout)

## Instructions

* Follow the first six instructions in [Example 3](../Ex3%20-%20Simple%20Remote%20Monitoring%20Application) to get the device code running.
* Copy and Paste the Agent Code in this folder into the **Agent Code** pane in the impCentral code editor.
* Configure Initial State:
    * Sign into [Initial State](https://app.initialstate.com/#/login/account).
    * Find your **Streaming Access Key** on the [My Account page](https://app.initialstate.com/#/account)
    * Navigate back to [impCentral](https://impcentral.electricimp.com/).
    * In the Agent code enter your **Streaming Access Key** into the runtime constant *IS_STREAMING_ACCESS_KEY*
* Configure IBM Watson IoT:
    * Watson IoT takes quite a bit more setup. Follow the instructions [here](https://developer.ibm.com/recipes/tutorials/electric-imp-smart-refrigerator-2/) to get the keys you will need from Watson IoT.
    * Copy and paste your *API_KEY*, *AUTH_TOKEN* and *ORG_ID* into the runtime constants *WATSON_API_KEY*, *WATSON_AUTH_TOKEN* and *WATSON_ORG_ID*.
* Hit the **Build and Force Restart** button to start the code.
* Use the cloud services to visualize your data.
