Sana
=======
The Sana reference design implements an internet-connected universal remote. Sana can learn and replay codes, and the agent code can easily be extended to add and store a new device if its codes are known. The carrier frequency and code timing parameters are configurable.

On the transmitting side, the Hardware PWM signal (Normally set as Pin11) and the raw SPI data (Normally Pin7 but may be Pin8) need to be ANDed creating an SPI signal modulated with the PWM carrier. On the receive side, the IR is fed into a GPIO input (commonly Pin2).

## Learning Codes
The code presented here does not store or send codes when they are received. Instead, when a new code is received, the code is simply printed in the device logs. To receive a code, simply point the remote at the IR sensor in the center of the board and press a button. The IR receiver will be triggered automatically. Copy the code string out of the logs for use later. 

## Sending Codes
Codes can be transmitted in two different ways: by sending the name of a known command, or by sending a raw code. 

### Sending known commands
The agent can store known command sets for different devices. Two example devices are presented in the agent code: A Samsung AA59 television remote, and a Sanyo 4VPIS4U Air Conditioner.

#### Show Selected Device
Send a GET request to \<agent URL\>/getselecteddev

```
10:11:37-tom$ curl http://agent.electricimp.com/abcd1234EFGH/getselecteddev
SANYO_4VPIS4U
```

#### List Available Devices
Send a GET request to \<agent URL\>/listdevices

```
10:11:37-tom$ curl http://agent.electricimp.com/abcd1234EFGH/listdevices
SANYO_4VPIS4U
SAMSUNG_AA59_00600A
```

#### Select a Different Device
Send a POST request with the new device name in the body to \<agent URL\>/selectdev

```
10:11:37-tom$ curl --data 'SANYO_4VPIS4U' http://agent.electricimp.com/abcd1234EFGH/selectdev
OK
```

#### List Available Commands on Currently-Selected Device
Send a GET request to \<agent URL\>/listcmds

```
10:11:37-tom$ curl http://agent.electricimp.com/abcd1234EFGH/listcmds
on 
off	
one_hour
ion_on	
ion_off 	
set_temp_60	
set_temp_62	
set_temp_64	
set_temp_66
set_temp_68 
set_temp_70	
set_temp_72
set_temp_74
set_temp_76	
set_temp_78	
set_temp_80 
cancel 
```

#### Transmit a Command
Send a POST request with the command name in the body to \<agent URL\>/sendcmd

```
10:11:37-tom$ curl --data 'ion_on' http://agent.electricimp.com/abcd1234EFGH/sendcmd
Sent Command ion_on to target device SANYO_4VPIS4U
```

### Sending Raw Codes
To transmit a code that is not part of the known command set for the selected device with the currently-set timing parameters, send a POST request with the code string in the body to \<agent URL\>/sendcode

```
10:11:37-tom$ curl --data '111000001110000010000110011110011' http://agent.electricimp.com/abcd1234EFGH/sendcode
OK
```
