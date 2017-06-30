# Arrow Imp005 EZ Eval Examples

Examples for use with the Imp005 EZ Eval board.

## Refrigerator Monitor

In this example we will create a refrigerator monitoring application that takes an asynchronous reading from the temperature/humidity senor. We will use the internal light senor to determine if the refrigerator door is open. We will conserve power by turning off the WiFi and taking readings while offline then connecting periodically to send the readings we have collected to the cloud. This code has been written for the Imp005 EZ Eval board and has hardware specific referecnes in the device code. 

## Asset Tracker Application

In this example we will create an asset tracking application. We will use an accelerometer to detect movement, and when the device is moved we will send a WiFi scan to Google Maps API to determine the device's location. We will send this location data to Watson so we can display. This code has been written for the Imp005 EZ Eval board and has hardware specific referecnes in the device code. 