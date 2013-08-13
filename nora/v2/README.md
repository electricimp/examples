

This nora (v2) example classes and agent encapsulate most of the functionality of the nora. The developer can make use of most of the functions of the nora without touching the device code, just by calling the device functions remotely from the agent.

| Sensor        | Methods            | Result
| --------------|--------------------|------------------------
| thermistor    | `read`             | returns temperature and humidity
| pressure      | `read`             | returns the ambient pressure
| light         | `read`             | returns the ambient light
| battery       | `read`             | returns the battery voltage and % capacity
| temperature   | `read`             | returns the temperature in celcius
|               | `thermostat`       | wakes the imp up when the temperature passes through the max or min temperatures provided
|               | `read_temp`        | reads the temperature without disturbing the thermostat
| accelerometer | `read`             | reads the acceleration on the X, Y and Z directions
|               | `threshold`        | sends an event every time the thresholds are passed in the givven axies
|               | `free_fall_detect` | wakes the imp up when the accelerometer detects falling at or above the speed of gravity
|               | `inertia_detect`   | wakes the imp up when the accelerometer detects inertia on any of the axies
|               | `movement_detect`  | wakes the imp up when the accelerometer detects movement
|               | `position_detect`  | wakes the imp up when the accelerometer detects a change in position
|               | `click_detect`     | wakes the imp up when the accelerometer detects a clicking motion
| nora          | `read`             | returns all the sensors then goes to sleep and offline. wakes up for more readings until the buffer is full and sends these offline
|               | `sleep`            | waits some time then puts the imp to deep sleep
| --------------|--------------------------------------------
