# Asset Tracker Application

In this example we will create an asset tracking application. We will use an accelerometer to detect movement, and when the device is moved we will send a WiFi scan to Google Maps API to determine the device's location. We will send this location data to Watson so we can display. This code has been written for the Imp005 EZ Eval board and has hardware specific referecnes in the device code. 

## What You Need

* Your 2.4GHz 802.11bgn WiFi network name (SSID) and password
* A computer with a web browser
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
* A free [Electric Imp Developer Account](https://ide.electricimp.com/login)
* An [IBM Watson Bluemix Account](https://console.bluemix.net/registration/?target=%2Fdocs%2Fservices%2FIoT%2Findex.html)
* A Google API Key from the [developer console](https://console.developers.google.com/apis/credentials)
* An Arrow Imp005 EZ Eval board