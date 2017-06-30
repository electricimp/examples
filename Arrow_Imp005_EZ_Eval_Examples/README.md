# Arrow Imp005 EZ Eval Examples

Examples for use with the Imp005 EZ Eval board.

## Refrigerator Monitor

In this example we will create a refrigerator monitoring application that takes an asynchronous reading from the temperature/humidity senor. We will use the internal light senor to determine if the refrigerator door is open. We will conserve power by turning off the WiFi and taking readings while offline then connecting periodically to send the readings we have collected to the cloud. This code has been written for the Imp005 EZ Eval board and has hardware specific referecnes in the device code. 