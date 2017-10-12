# Temperature PLC

This example uses an [impAccelerator&trade; Fielbus Gateway](https://electricimp.com/docs/hardware/resources/reference-designs/fieldbusgateway/), the Electric Imp Modbus Library, a Click Programmable Logic Controller (PLC) and a thermistor to monitor temperature. The thermistor is connected to an analog input on the PLC. The Fielbus Gateway polls this analog input and sends the temperature reading to IBM Watson and Dweet.io.

## Hardware

- [impAccelerator Fielbus Gateway](https://store.electricimp.com/collections/featured-products/products/impaccelerator-fieldbus-gateway?variant=31118564754)
- [C0-02DD1-D Click PLC](https://www.automationdirect.com/adc/Shopping/Catalog/Programmable_Controllers/CLICK_Series_PLCs_(Stackable_Micro_Brick)/PLC_Units/C0-02DD1-D?utm_source=google&utm_medium=product-search&gclid=CPeB4NWljNQCFUlNfgod9l4OVg)
- Pump
- Thermistor
- Power Supply

## Software Dependencies

- Electric Imp [Modbus Library](https://github.com/electricimp/Modbus)
- Electric Imp [IBMWatson Library](https://github.com/electricimp/IBMWatson)
- Electric Imp [Dweetio Library](https://github.com/electricimp/Dweetio)

## Device Code

The Fielbus Gateway’s imp005 polls the PLC for temperature readings and sends them to the agent.

## Agent Code

The agent sends the temperature readings to IBM Watson and Dweet.io.

**Note** Dweet.io uses the imp005’s device ID as a unique identifier. IBM Watson requires an account and access keys to push data to it. The keys have been removed from this example code, and so you will have sign up for IBM Watson and paste its access keys into the appropriate variables before the agent can push data to it.
