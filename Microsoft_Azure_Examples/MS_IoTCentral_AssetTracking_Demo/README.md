# Microsoft Azure IoT Central Asset Tracking Demo

This repository uses an impC breakout board plus GPS and/or an impExplorer to implement a Asset Tracking demo with IoT Central.

![IoT Central Asset Tracking screen shot](imgs/Asset-Tracker-screen-shot.png)

## Features implememented:

**NOTE:** This is still an early version with shortcomings, but shows all the basic concepts and works pretty reliably. Features implemented so far:

* Cloud agents connect to the respective IoT Central IoT Hub via MQTT, see (Azure IoT Hub integration)[https://github.com/electricimp/AzureIoTHub]
* Devices must currently be pre-registered in IoT Central for this demo. To generate a device connection string for the cloud agent, use use the dps_cstr command, see (Getting a Device Connection String)[https://docs.microsoft.com/en-us/azure/iot-central/concepts-connectivity#getting-device-connection-string]
* Once started, the cloud agent connects to IoT Hub and enables direct sending of data (for telemetry measurements), Device Twins (for device properties and device settings), and direct methods
* Telemetry measurements: The device periodically sends temperature, humidity, and acceleration data to IoT Hub. Note that eventhough IoT Hub receives the data almost immediately from the cloud agent it typically takes IoT Central 15 to 20 seconds to update the visualization, so telemetry data appears sluggish.
* Shock alert: When the accleration exceeds a certain value the device triggers a shock alert and immediately sends the telemetry data 
* Device properties: The device sends via Device Twin Properies the location coordinates, device online/offline state, and software version which are displayed in the IoT Central "Properties" tab.
* Device settings: Through the IoT Central "Settings" tab the user can make changes to the reporting interval and the LED color -- updated values are sent to the device via desired Device Twin properties
* Direct methods: Through the IoT Central "Commands" tab the user can trigger a "Restart Device" command which results in the device rebooting the VM and restarting the application

## Limitations:
* The device always starts up with default settings for reporting interval and LED color rather than updating it's settings from the desired Device Twin Properties. To workaround, explicitly use the "Settings" tab to set the settings again. This will be fixed soon.
* The device code is purposely kept simple and is not optimized for power consumption/battery life, communication volume, or connectivity handling. A real asset tracking device application will be much more intelligent by entering power save modes, reducing radio time, minimize communication traffic (only send data when necessary), and handling various connectivity states (e.g. intermittent connectivity with batching of data, etc).
