# Adding Webservices to Simple Remote Monitoring Application

In this example we will use the device code from example 3, but adapt the agent code to send data to an additional webservice, IBM Watson IoT.  

## Skill level

**Beginner**

This example will focus on writing squirrel code. Please visit the [getting started guide](https://electricimp.com/docs/gettingstarted/) on the Electric Imp Dev Center for insturctions on How to configure your device with BlinkUp and how to use the Electric Imp IDE.

## What You Learn

* How to update agent code to send to multiple webservices

## What You Need

* Your 2.4GHz 802.11bgn WiFi network name (SSID) and password
* A computer with a web browser
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
* A free [Electric Imp Developer Account](https://ide.electricimp.com/login)
* A free [Initial State Account](https://www.initialstate.com/)
* A [IBM Bluemix account](https://console.ng.bluemix.net/registration/)
* One of the imp hardware boards listed below
    * [impExplorer Developer Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130) 
    * [impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/featured-products/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)

## Instructions

* Follow the first 6 instructions in Example 3 to get the device code
* Copy and Paste the Agent Code in this folder into the Agent coding window in the IDE
* Configure Initial State
    * Sign into [Initial State](https://app.initialstate.com/#/login/account)
    * Find your Streaming Access Key on the [My Account page](https://app.initialstate.com/#/account)
    * Navigate back to the [Electric Imp IDE](https://ide.electricimp.com)
    * In the Agent code enter your Initial State Streaming Access Key into the runtime constant IS_STREAMING_ACCESS_KEY
* Configure IBM Watson IoT
    * Watson IoT takes quite a bit more setup. Follow the instructions [here](https://developer.ibm.com/recipes/tutorials/electric-imp-smart-refrigerator-2/) to get the keys you will need from Watson IoT
    * Copy and paste your API_KEY, AUTH_TOKEN, and ORG_ID into the runtime constants WATSON_API_KEY, WATSON_AUTH_TOKEN, and WATSON_ORG_ID
* Hit Build and Run to start the code
* Use the webservices to visualize your data  
