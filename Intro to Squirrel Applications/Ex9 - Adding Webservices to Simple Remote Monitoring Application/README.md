# Adding Webservices to Simple Remote Monitoring Application

In this example we will use the device code from example 3, but adapt the agent code to send data to an additional webservice, IBM Watson IoT.

## Skill level

**Beginner**

This example will focus on writing squirrel code. Please visit the [getting started guide](https://developer.electricimp.com/gettingstarted) on the Electric Imp Dev Center for insturctions on how to configure your device with BlinkUp and how to use the Electric Imp IDE, impCentral.

## What You Learn

* How to update agent code to send to multiple webservices

## What You Need

* Your 2.4GHz 802.11bgn WiFi network name (SSID) and password (not needed for Cellular, impC001)
* A computer with a web browser
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
* A free [Electric Imp Developer Account](https://impcentral.electricimp.com/login)
* A free [Initial State Account](https://www.initialstate.com/)
* A [IBM Bluemix account](https://console.ng.bluemix.net/registration/)
* One of the imp hardware boards listed below
    * [imp006 Breakout Board Kit](https://store.electricimp.com/collections/breakout-boards/products/imp006-cellular-and-wifi-breakout-board-kit?variant=30294487924759)
    * [impExplorer Developer Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130)
    * [impAccelerator Battery Powered Sensor Node](https://developer.electricimp.com/hardware/resources/reference-designs/sensornode)
    * [impC001 Cellular Breakout Board Kit](https://developer.electricimp.com/hardware/resources/reference-designs/impc001breakout)

## Instructions

* Follow the first 6 instructions in Example 3 to get the device code running.
* Copy and Paste the Agent Code in this folder into the Agent Code pane in the impCentral code editor.
* Configure Initial State:
    * Sign into [Initial State](https://app.initialstate.com/#/login/account)
    * Find your Streaming Access Key on the [My Account page](https://app.initialstate.com/#/account)
    * Navigate back to the [impCentral](https://impcentral.electricimp.com/)
    * In the Agent code enter your Initial State Streaming Access Key into the runtime constant IS_STREAMING_ACCESS_KEY
* Configure IBM Watson IoT
    * Watson IoT takes quite a bit more setup. Follow the instructions [here](https://developer.ibm.com/recipes/tutorials/electric-imp-smart-refrigerator-2/) to get the keys you will need from Watson IoT
    * Copy and paste your API_KEY, AUTH_TOKEN, and ORG_ID into the runtime constants WATSON_API_KEY, WATSON_AUTH_TOKEN, and WATSON_ORG_ID
* Hit Build and Force Restart button to start the code.
* Use the webservices to visualize your data.
