# Intro to Squirrel Applications

The examples here range from simple to advanced programming.  Each example builds on the skills learned in the previous example.  

## The Basics

### Example 1 - Reading a Sensor

Begin by learning the basics of programming Electric Imp. We will use Electric Imp HTS221 library to take temperature and humidity readings from a sensor. We will also use the Initial State libary to send the data we collect from the sensor to the cloud. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node.  

## Beginner Applications

### Example 2 - Simple Smart Refrigerator

In this example we will create an simple refrigerator monitoring application that takes synchronous readings from the temperature/humidity sensor and the internal light sensor. The light reading is used to determine if the refrigerator door is open or closed. The door status, temperature and humidity readings are sent to the cloud using the Initial State webservice. We will use a Hardware Abstraction Layer (HAL) to reference all hardware objects, and to organize our application code we will use a class. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node. 

### Example 3 - Simple Remote Monitoring Application

In this example we will create an simple remote monitoring application that takes synchronous readings from multiple sensors and sends them to the cloud using the Initial State webservice. We will use a Hardware Abstraction Layer (HAL) to reference all hardware objects, and to organize our application code we will use a class. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node.  

## Intermediate

### Example 4 - Asynchronous Remote Monitoring Application

In this example we will create a remote monitoring application that takes asynchronous sensor readings using the Promise libary. We will conserve power by turning off the WiFi and taking readings while offline then connecting periodically to send the readings we have collected. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node. 

### Example 5 - Smart Refrigerator

## Advanced

### Example 6 - Power Efficient Remote Monitoring Application

### Example 7 - Remote Monitoring Application with an Interrupt

### Example 8 - Advanced Smart Refrigerator