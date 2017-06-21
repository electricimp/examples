# Battery Check Example

This example was written for the Battery Powered Sensor Node to determine the battery voltage. The battery class included in this example can be used for other devices as long as there is an analog pin that is connected directly to the battery. **Please note** this code is not usable for determining the battery voltage on the impExplorer Developer Kit, since no analog pins are connected directly to the battery.  

## Device Code

### SensorNode_003 HAL
This example makes use of the Battery Powered Sensor Node's Hardware Abstraction Layer (HAL). For more details [click here](https://github.com/electricimp/SensorNodeHAL)

### Battery Class

#### Constructor: Battery(*pin[, threshold]*)

The constructor takes one required parameter *pin*: an analog hardware pin, and one optional parameter *threshold*: the voltage that is used to determine if the battery is getting low. The constructor configures the *pin* as an analog input and sets a default *threshold* of 2.1 volts if one is not passed in.

#### getVoltage()

The getVoltage method returns the current voltage of the battery. This method uses the analog pin passed into the constructor and the imp API method [hardware.voltage](https://electricimp.com/docs/api/hardware/voltage/) to determine the voltage of the battery.

#### isLow()

The isLow method returns a boolean, true if the battery is getting close to a threshold value set by the constructor. The default value of 2.1 volts is just above the voltage where the device will no longer be able to connect to WiFi. If the device cannot connect to WiFi logs will stop being transmitted and no data will be passed to the agent.  

## Runtime Code

Shows basic usage for the Battery Class and the Sensor Node. The code logs the results from each of the Battery class methods.
