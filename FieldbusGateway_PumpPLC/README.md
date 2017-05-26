# FieldbusGateway_PumpPLC

This example uses an impAccelerator Fielbus Gateway and the Electric Imp Modbus Library to contol a Click PLC. The PLC listens for a button press and activates a pump. When active the pump pushes water into a tank, and the PLC monitors the water level, and the Imp uploads the current status of the water level and pump status to several cloud services.

## Hardware

- [Imp 005 ImpAccelerator Fielbus Gateway](https://store.electricimp.com/collections/featured-products/products/impaccelerator-fieldbus-gateway?variant=31118564754)
- [C0-02DD1-D Click PLC](https://www.automationdirect.com/adc/Shopping/Catalog/Programmable_Controllers/CLICK_Series_PLCs_(Stackable_Micro_Brick)/PLC_Units/C0-02DD1-D?utm_source=google&utm_medium=product-search&gclid=CPeB4NWljNQCFUlNfgod9l4OVg)
- Pump
- [Level Sensor](https://www.amazon.com/KUS-USA-Water-Level-Sensor/dp/B00Y831Q0S/ref=sr_1_8?ie=UTF8&qid=1495758476&sr=8-8&keywords=gas+level+sensor)
- [Button](https://www.amazon.com/Big-Dome-Push-Button-Red/dp/B00CYGTH9I/ref=sr_1_1?ie=UTF8&qid=1495758339&sr=8-1&keywords=big+red+button)
- [Stack Light](https://www.amazon.com/uxcell-Bulbs-Yellow-Industrial-Signal/dp/B019OGDR32/ref=sr_1_4_a_it?ie=UTF8&qid=1495758536&sr=8-4&keywords=stack+light)
- Power Supply

## Software Dependencies

- Electric Imp [Modbus Library](https://github.com/electricimp/Modbus)
- Electric Imp [IBMWatson Library](https://github.com/electricimp/IBMWatson)
- Electric Imp [InitialState Library](https://github.com/electricimp/InitialState)
- Electric Imp [AutodeskFusionConnect Library](https://github.com/electricimp/AutodeskFusionConnect)

## Device Code
The Imp polls the PLC for changes in the button state and the level of the water level sensor. When a button state change is detected the pump is turned on or off. The status LEDs on the Fieldbus Accelerator are toggled to indicate when the button is pressed and when the pump is active. Water level is monitored by a sensor and when it reaches thresholds a stack light is turned on.  If the water level reaches a maximum threshold the pump will be turned off automatically.  The device reports all pump state and water level changes to the agent.

## Agent Code
The agent sends all water level and pump status data to Autodesk Fusion Connect, IBM Watson, and Initial state. The maximum water level threshold is set in the Autodesk application, and the agent listens for changes and passes those to the device.

Note: The web services all require accounts and keys to push data. The keys have been removed from this example code, and so will have to be configured and pasted into the appropriate variables before the agent can push data to the various web services.
