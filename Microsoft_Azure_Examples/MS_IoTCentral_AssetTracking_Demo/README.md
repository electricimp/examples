# Microsoft Azure IoT Central Asset Tracking Demo

This repository uses an impC Breakout Board plus GPS and/or an impExplorer to implement a Asset Tracking demo with IoT Central:
* [impC Breakout Board](https://store.electricimp.com/collections/breakout-boards/products/impc001-breakout-board-kit-preorder?variant=7599263973399)
* [impExplorer](https://store.electricimp.com/collections/getting-started/products/impexplorer-developer-kit?variant=31118866130)

![IoT Central Asset Tracking screen shot](imgs/Asset-Tracker-screen-shot.png)

## Features implememented:

**NOTE:** This is still an early version with shortcomings, but shows all the basic concepts and works reliably. Features implemented so far:

* Cloud agents connect to the respective IoT Central IoT Hub via MQTT, see [Azure IoT Hub integration](https://github.com/electricimp/AzureIoTHub)
* Devices must currently be pre-registered in IoT Central for this demo. To generate a device connection string for the cloud agent, use use the `dps_cstr` command, see [Getting a Device Connection String](https://docs.microsoft.com/en-us/azure/iot-central/concepts-connectivity#getting-device-connection-string)
* Once started, the cloud agent connects to IoT Hub and enables direct sending of data (for telemetry measurements), Device Twins (for device properties and device settings), and Direct Methods (for device restarts)
* Telemetry measurements: The device periodically sends temperature, humidity, and acceleration data (from onboard sensors) to IoT Central. Note that eventhough IoT Hub receives the data almost immediately from the cloud agent it typically takes IoT Central 15 to 20 seconds to update the visualization, so telemetry data appears sluggish.
* Shock alert: When the accleration exceeds a certain value the device triggers a shock alert and immediately sends the telemetry data 
* Device properties: The device sends via Device Twin Properies the location coordinates, device online/offline state, networking information (carrier name or WiFi SSID) and software version which are displayed in the IoT Central "Properties" tab.
* Device settings: Through the IoT Central "Settings" tab the user can make changes to the reporting interval and the LED color -- updated values are sent to the device via desired Device Twin properties
* Direct methods: Through the IoT Central "Commands" tab the user can trigger a "Restart Device" command which results in the device rebooting the VM and restarting the application
* Device location: The impC Breakout Board code uses the Pixhawk GPS receiver for location, the impExplorer code uses the Google Maps/Places API to determine the location based on WiFi

## Limitations:
* ~~The device always starts up with default settings for reporting interval and LED color rather than updating it's settings from the desired Device Twin Properties. To workaround, explicitly use the "Settings" tab to set the settings again.~~ FIXED
* ~~Device settings that are changed in IoT Central are sent to the device, but not correctly confirmed back to IoT Central, so IoT Central doesn't show them as synced. FIXED~~
* The device code is purposely kept simple and is not optimized for power consumption/battery life, minimizing communication volume, or more robust connectivity handling. A real asset tracking device application will be much more intelligent by entering power save modes based on application state, reducing radio time to minimize power, reduce communication volume (only send data when necessary), and handling different connectivity states (e.g. intermittent connectivity with batching of data, etc).
