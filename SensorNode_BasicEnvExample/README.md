# SensorNode_BasicEnvExample

This example shows a low power application for the ImpAccelerator Battery Powered Sensor node that takes environmental sensor readings.

## Hardware

- [Imp 003 ImpAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/featured-products/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)
- 2 AA Batteries

## Software Dependencies

- Electric Imp [Promise Library](https://github.com/electricimp/Promise)
- Electric Imp [Message Manager Library](https://github.com/electricimp/MessageManager)
- Electric Imp [LIS3DH Library](https://github.com/electricimp/LIS3DH)
- Electric Imp [HTS221 Library](https://github.com/electricimp/HTS221)
- Electric Imp [LPS22HB Library](https://github.com/electricimp/LPS22HB)

## Device Code
To create a low powered application the imp is put to sleep whenever possible. The device wakes up to take asynchonous readings from the onboard accelerometer, temperature/humidity, and air pressure sensors. The readings are stored and the device is put back to sleep.  After a set ammount of time the device will connect to the server to upload the stored readings to the agent. The reading and reporting intervals in the Application class can be adjusted to extend battery life.

Note: When the device is first booted it doesn't go to sleep immediately. This is done intentionally to allow enough time for a new BlinkUp.

## Agent Code
The agent code receives readings from the device and logs them. To improve this example add your favorite cloud based database or web service to push the environmental data to.