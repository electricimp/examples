# Thermocouple Example

This is simple example code to read temperature from a [thermocouple click board](https://shop.mikroe.com/thermo-click). The code is written for the Fieldbus Gateway and uses the imp005's spiBCAD. To use it with a different imp, simply change the spi module. MOSI is not necessary to read the thermocouple. The thermocouple runs on 3.3v. The range of the thermocouple is -270 to 1372 degrees celsius. 

To read the thermocouple, call the function readThermoCoupleTemp(), which will return the temperature as an integer.
