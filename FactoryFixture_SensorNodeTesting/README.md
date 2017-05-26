# FactoryFixtrure_SensorNodeTesting

This example contains an example of factory firmware code. It uses an impFactory™ as the factory fixture and impAccelerator™ Battery Powered Sensor Nodes as the devices being tested and produced.

Please refer to the manufacturing guides in the [dev center](https://electricimp.com/docs/manufacturing/migration/) for infomation on developing factory firmware before running this code. This code will bless devices that pass tests, locking them to the production code that is linked in the factory setup.

## Hardware

- [Imp 005 impFactory](https://store.electricimp.com/products/impfactory?variant=31163225426)
- [Imp 003 impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/impaccelerator-quickstart-family/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)
- Brother QL-720NW label printer
- OneWire sensor
- RJ12 i2c sensor (we wired up an env tail to an RJ12 connector)
- 2 AA batteries

## Software Dependencies

- Electric Imp [FactoryTools Library](https://github.com/electricimp/FactoryTools)
- Electric Imp [CFAx33KL Library](https://github.com/electricimp/CFAx33-KL)
- Electric Imp [Promise Library](https://github.com/electricimp/Promise)
- Electric Imp [HTS221 Library](https://github.com/electricimp/HTS221)
- Electric Imp [LPS22HB Library](https://github.com/electricimp/LPS22HB)
- Electric Imp [LIS3DH Library](https://github.com/electricimp/LIS3DH)
- Electric Imp [Onewire Library](https://github.com/electricimp/Onewire)

## Device Code
The device code determines if the code is running on the factory fixture or the device under test, and runs the appropriate flow.

The factory fixture flow listens for a button press and triggers a BlinkUp when pressed. The fixture also listens for print label messages from it's agent and prints a label with the device under test's info when a message is recieved.

The device under test flow runs tests. First the two LED's are tested, green and blue each turn on for a bit. Next the onboard sensors are tested by taking a reading from each and determine if the value received is in range. For each successful test the green LED turns on, or if the test fails the blue LED turns on. Next the RJ12 connector is tested. Note for this test to pass a one wire and an i2c sensor need to be plugged in. The RJ12 port is pinged to test that we can find the expected sensors. The device is then put to sleep, so low power can be measured. After testing low power the interrupt is tested. To wake the device from sleep a freefall event needs to trigger. As each test is run the result is sent to the agent. At the end of the testing the device gets the test results from the agent if tests have all passed the green LED is turned on, device data is sent to the agent and the command to bless the device is sent. If any test has failed the blue LED is turned on, and the bless command is called with test failed parameter. Then a message to clear the test results is sent to the agent.


## Agent Code
The agent code determines if the code is running on the factory fixture or the device under test, and runs the appropriate flow.

The factory fixture flow listens for incomming HTTP messages from the device under test's agent, and when device info is received it passes it to the factory fixture device to print a label with the device under test's mac address.

The device under test flow listens for individual test result messages from the device and tallies the number of tests passed and failed. It also listens and sends the total test results to the device. The agent also listens for set label messages and sends the device data to the factory fixtures agent via HTTP.
