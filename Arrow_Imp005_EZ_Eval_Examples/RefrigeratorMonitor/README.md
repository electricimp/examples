# Refrigerator Monitor Application

In this example we will create a refrigerator monitoring application that takes an asynchronous reading from the temperature/humidity senor. We will use the internal light senor to determine if the refrigerator door is open. We will conserve power by turning off the WiFi and taking readings while offline then connecting periodically to send the readings we have collected to the cloud. This code has been written for the Imp005 EZ Eval board and has hardware specific referecnes in the device code. 

## What You Need

* Your 2.4GHz 802.11bgn WiFi network name (SSID) and password
* A computer with a web browser
* A smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
* A free [Electric Imp Developer Account](https://ide.electricimp.com/login)
* An [IBM Watson Bluemix Account](https://console.bluemix.net/registration/?target=%2Fdocs%2Fservices%2FIoT%2Findex.html)
* (Optional) A free [Initial State Account](https://www.initialstate.com/)
* An Arrow Imp005 EZ Eval board