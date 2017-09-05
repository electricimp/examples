# impAccelerator&trade; Battery Powered Sensor Node Factory Firmware

This example provides sample factory firmware code. It uses an impFactory&tade; as the factory fixture and impAccelerator Battery Powered Sensor Nodes as the devices being tested and blessed.

Please refer to the manufacturing guides in the [Electric Imp Dev Center](https://electricimp.com/docs/manufacturing/migration/) for infomation on developing factory firmware before running this code. This code will bless devices that pass tests, locking them to the production code that is linked in the factory setup.

## Hardware

- [imp005-based impFactory](https://store.electricimp.com/products/impfactory?variant=31163225426)
- [imp003-based impAccelerator Battery Powered Sensor Node](https://store.electricimp.com/collections/impaccelerator-quickstart-family/products/impaccelerator-battery-powered-sensor-node?variant=33499292818)
- Brother QL-720NW label printer
- 1-Wire sensor
- RJ12 I&sup2;C sensor (we wired up an env tail to an RJ12 connector)
- Two AA batteries

## Software Dependencies

- Electric Imp [FactoryTools Library](https://github.com/electricimp/FactoryTools)
- Electric Imp [CFAx33KL Library](https://github.com/electricimp/CFAx33-KL)
- Electric Imp [Promise Library](https://github.com/electricimp/Promise)
- Electric Imp [HTS221 Library](https://github.com/electricimp/HTS221)
- Electric Imp [LPS22HB Library](https://github.com/electricimp/LPS22HB)
- Electric Imp [LIS3DH Library](https://github.com/electricimp/LIS3DH)
- Electric Imp [Onewire Library](https://github.com/electricimp/Onewire)

## Device Code

The device code determines if the code is running on the factory fixture or the device under test (DUT), and runs an appropriate flow for each of these hardware types.

The factory fixture flow awaits a button press and triggers BlinkUp when the button is pressed. The fixture also listens for 'print label' messages from its agent and prints a label with the device under test's info when such a message is recieved.

The DUT flow runs tests. First, the two LEDs are tested: green and blue each turn on for a brief period. Second, the on-board sensors are tested by taking a reading from each and determining if the value received is in range. For each successful test the green LED turns on, or if the test fails the blue LED turns on. 

The RJ12 connector is tested next. For this test to pass, a 1-Wire and an i&sup2;C sensor need to be connected via the Sensor Node's RJ12 port. The port is pinged to test that we can find the expected sensors. The device is then put to sleep, so low power can be measured. After testing low power, the interrupt is tested. To wake the device from sleep a freefall event needs to trigger.

As each test is run the result is sent to the agent. At the end of the testing, the device gets the test results from the agent, and if the tests have all passe, the green LED is turned on, device data is sent to the agent, and the command to bless the device is sent. If any test has failed, the blue LED is turned on, and the bless command is called with test failed parameter. Then a message to clear the test results is sent to the agent.

## Agent Code

The agent code determines if the code is running as the factory fixture's agent, or the DUT's agent, and runs the appropriate flow.

The factory fixture agent flow listens for incomming HTTP messages from the DUT's agent. When device info is received, the agent passes it to the factory fixture to print a label showing the DUT's MAC address.

The DUT agent flow listens for individual test result messages from the DUT and tallies the number of tests passed and failed. It also listens for a signal from the DUT that all tests have run; when this is received, it sends the test results back to the DUT. The agent also listens for 'set label' messages and sends the device data to the factory fixtures agent via HTTP.
