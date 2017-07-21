# Thermocouple Example

This is simple example code to read temperature from a [thermocouple click board](https://shop.mikroe.com/thermo-click). To read the thermocouple, call the function **readThermoCoupleTemp()**, which will return the temperature as an integer. The thermocouple runs on 3.3v. The range of the thermocouple is -270 to 1372 degrees celsius.

## Hardware
- [Imp 005 ImpAccelerator Fieldbus Gateway](https://store.electricimp.com/collections/featured-products/products/impaccelerator-fieldbus-gateway?variant=31118564754)
- [Thermocouple click board](https://shop.mikroe.com/thermo-click)

Plug the click board into the mikroBUS header on the Fieldbus. This example code uses the hardware.spiBCAD peripheral exposed by the mikroBUS header.  

**Please note:** This example code can be modified for use with a different imp by simply changing the spi configuration. MOSI is not necessary to read the thermocouple.
