# impAcclerator&trade; Battery Powered Sensor Node Basic Example

This example provides a low-power application for the impAccelerator Battery Powered Sensor Nnode that takes environmental sensor readings.

## Hardware

- [imp003-based impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/featured-products/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)
- Two AA batteries

## Software Dependencies

- Electric Imp [Promise Library](https://github.com/electricimp/Promise)
- Electric Imp [Message Manager Library](https://github.com/electricimp/MessageManager)
- Electric Imp [LIS3DH Library](https://github.com/electricimp/LIS3DH)
- Electric Imp [HTS221 Library](https://github.com/electricimp/HTS221)
- Electric Imp [LPS22HB Library](https://github.com/electricimp/LPS22HB)

## Device Code

To ensure low power consumption, the Battery Powered Sensor Node’s imp003 is put to sleep whenever possible. The device wakes up to take readings from the on-board accelerometer, temperature/humidity and air pressure sensors. The readings are stored and the device is put back to sleep. After a set amount of time, the device will, when awake, connect to the server and upload the stored readings to its agent. The reading and reporting intervals can be adjusted to extend battery life.

**Note** When the device is first booted it doesn't go to sleep immediately. This is done intentionally to allow enough time to perform BlinkUp.

## Agent Code

The agent code receives readings from the device and logs them. To improve this example, add your favorite cloud-based database or web service to push the environmental data to.
