# impAccelerator&trade; Battery Powered Sensor Node Battery Check Example

This example was written for the [impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/featured-products/products/impaccelerator-battery-powered-sensor-node?variant=33499292818) to determine the battery voltage. 

The Battery class included in this example can be used for other devices provided there is an analog pin that is connected directly to the battery. As a result, this code can't be used to determine the battery voltage on the impExplorer&trade; Kit, since no analog pins are connected directly to its battery.  

## Device Code

### SensorNode_003 HAL

This example makes use of the Battery Powered Sensor Node's Hardware Abstraction Layer (HAL). For more details, please [click here](https://github.com/electricimp/SensorNodeHAL).

### Battery Class

#### Constructor: Battery(*pin[, threshold]*)

The constructor takes one required parameter, *pin*, an analog hardware pin. It also offers one optional parameter, *threshold*, which specifies the voltage that is used to determine if the battery is getting low. The constructor configures the *pin* as an analog input and sets a default *threshold* of 2.1V if a value is not passed in.

#### getVoltage()

This method returns the current voltage of the battery. It uses the analog pin passed into the constructor and the imp API method [**hardware.voltage()**](https://electricimp.com/docs/api/hardware/voltage/) to determine the voltage of the battery.

#### isLow()

This method returns a boolean: `true` if the battery is getting close to a threshold value set by the constructor, otherwise `false`. The default threshold value of 2.1V is just above the voltage where the device will no longer be able to connect to WiFi. If the device cannot connect to WiFi, logs will stop being transmitted and no data will be passed to the agent.  

## Runtime Code

The example's code provides basic usage for the Battery Class and the Battery Powered Sensor Node. The code logs the results from each of the Battery class' methods.
