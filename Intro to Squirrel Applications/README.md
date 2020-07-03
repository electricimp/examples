# An Introduction To Squirrel Applications

**An Introduction To Squirrel Applications** is intended to help developers quickly become proficient in Electric Imp application development. It comprises a sequence of working examples which demonstrate key imp features, functionality, concepts and techniques, and which range from simple to advanced applications. What you learn in a given example builds on the skills learned in the previous example. You will gain a solid working knowledge of how to assemble production-ready Electric Imp applications.

The examples start with the assumption that you have only a basic familiarity with the Electric Imp Platform — that you have completed the [**Getting Started Guide**](https://developer.electricimp.com/gettingstarted) to learn how to create an Electric Imp account, to configure your development device with Electric Imp’s BlinkUp™ technology, to use the Electric Imp IDE, impCentral™, and to discover the two-part nature of Electric Imp applications: device-side code and cloud-hosted agent code.

If you are new to the Electric Imp Platform and have not completed the [**Getting Started Guide**](https://developer.electricimp.com/gettingstarted), we strongly recommend that you do so now. It should certainly be the first project you attempt after receiving your first Electric Imp development device.

Please note that the first few examples here are not intended to be power efficient and will drain battery powered devices quickly.

## The Basics

### Example 1 - Reading A Sensor

Begin by learning the basics of programming Electric Imp. We will use Electric Imp’s [HTS221 library](https://developer.electricimp.com/libraries/hardware/hts221) to take temperature and humidity readings from a sensor. We will also use Electric Imp’s [Initial State library](https://developer.electricimp.com/libraries/webservices/initialstate) to send the data we collect from the sensor to the cloud. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

[Go to the Example](./Ex1%20-%20Reading%20A%20Sensor)

## Beginner Applications

### Example 2 — Simple Refrigerator Monitor

In this example we will create an simple refrigerator monitoring application that takes synchronous readings from the temperature/humidity sensor and the internal light sensor. The light reading is used to determine if the refrigerator door is open or closed. The door status, temperature and humidity readings are sent to the cloud using the Initial State cloud service. We will use a Hardware Abstraction Layer (HAL) to reference all hardware objects, and to organize our application code we will use a class. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

[Go to the Example](./Ex2%20-%20Simple%20Refrigerator%20Monitor)

### Example 3 — Simple Remote Monitoring Application

In this example we will create an simple remote monitoring application that takes synchronous readings from multiple sensors and sends them to the cloud using the Initial State cloud service. We will use a Hardware Abstraction Layer (HAL) to reference all hardware objects, and to organize our application code we will use a class. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

[Go to the Example](Ex3%20-%20Simple%20Remote%20Monitoring%20Application)

## Intermediate Applications

### Example 4 — Refrigerator Monitor

In this example we will create a refrigerator monitoring application that takes an asynchronous reading from the temperature/humidity senor. We will use the internal light senor to determine if the refrigerator door is open. We will conserve power by disconnecting from WiFi or the cellular network and taking readings while offline then connecting periodically to send the readings we have collected to the cloud. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

[Go to the Example](Ex4%20-%20Refrigerator%20Monitor)

### Example 5 — Asynchronous Remote Monitoring Application]

In this example we will create a remote monitoring application that takes asynchronous sensor readings using Electric Imp’s [Promise library](https://developer.electricimp.com/libraries/utilities/promise). We will conserve power by disconnecting from WiFi or the cellular network and taking readings while offline then connecting periodically to send the readings we have collected. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

[Go to the Example](Ex5%20-%20Asynchronous%20Remote%20Monitoring%20Application)

## Advanced Applications

### Example 6 - Power Efficient Remote Monitoring Application

In this example we will create a remote monitoring application that takes asynchronous sensor readings using Electric Imp’s [Promise library](https://developer.electricimp.com/libraries/utilities/promise). We will conserve power by putting the device to sleep between readings and connecting periodically to send the readings we have collected. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

[Go to the Example](Ex6%20-%20Power%20Efficient%20Remote%20Monitoring%20Application)

### Example 7 — Remote Monitoring Application with an Interrupt

In this example we will create a remote monitoring application that takes asynchronous sensor readings using Electric Imp’s [Promise library](https://developer.electricimp.com/libraries/utilities/promise) and detects freefall events. We will conserve power by putting the device to sleep between readings. The device will connect periodically to send readings and will also wake and connect if a freefall is detected. This code can be easily configured for use with an imp006 Breakout Kit, impExplorer Kit, impAccelerator Battery Powered Sensor Node or impC001 Breakout Board.

[Go to the Example](Ex7%20-%20Remote%20Monitoring%20with%20Interrupt)

### Example 8 — Power Efficient Refrigerator Monitor

In this example we will create a refrigerator monitoring application. The application monitors the temperature and humidity of the refrigerator and sends alerts if the temperature or humidity is higher than a set threshold for too long. The application also monitors the refrigerator door using the accelerometer to wake on motion and the internal light sensor to determine the door status. The application saves power by sleeping between readings when the door is closed, and only connecting to WiFi or the cellular network periodically to upload readings or when an alert is triggered. This code can be easily configured for use with an imp006 Breakout Board Kit, impExplorer Developer Kit (imp001 model only), impAccelerator Battery Powered Sensor Node or impC001 Breakout Board Kit.

[Go to the Example](Ex8%20-%20Power%20Efficient%20Refrigerator%20Monitor)

## Adding Cloud Services

### Example 9 — Adding Cloud Services To Simple Remote Monitoring Application

In this example we will use the device code from [example 3](#example-simple-remote-monitoring-application), but adapt the agent code to send data to an additional cloud service, IBM Watson IoT.

[Go to the Example](Ex9%20-%20Adding%20Webservices%20to%20Simple%20Remote%20Monitoring%20Application)