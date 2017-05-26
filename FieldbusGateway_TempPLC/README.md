# FieldbusGateway_TempPLC

This example uses an impAccelerator Fielbus Gateway, the Electric Imp Modbus Library, a Click PLC, and a thermister to monitor temperature. The thermister is connected to an analog input on the PLC. The imp polls the analog input and sends the temperature reading to IBM Watson and Dweet.io.

## Hardware

- [Imp 005 ImpAccelerator Fielbus Gateway](https://store.electricimp.com/collections/featured-products/products/impaccelerator-fieldbus-gateway?variant=31118564754)
- [C0-02DD1-D Click PLC](https://www.automationdirect.com/adc/Shopping/Catalog/Programmable_Controllers/CLICK_Series_PLCs_(Stackable_Micro_Brick)/PLC_Units/C0-02DD1-D?utm_source=google&utm_medium=product-search&gclid=CPeB4NWljNQCFUlNfgod9l4OVg)
- Pump
- Thermistor
- Power Supply

## Software Dependencies

- Electric Imp [Modbus Library](https://github.com/electricimp/Modbus)
- Electric Imp [IBMWatson Library](https://github.com/electricimp/IBMWatson)
- Electric Imp [Dweetio Library](https://github.com/electricimp/Dweetio)

## Device Code
The Imp polls the PLC for temperature readings sends them to the agent.

## Agent Code
The agent sends the temperature readings to IBM Watson and Dweet.io.

Note: Dweet.io uses the Imp's Device ID as a unique identifier. IBM Watson requires an account and keys to push data. The keys have been removed from this example code, and so will have to be configured and pasted into the appropriate variables before the agent can push data.
