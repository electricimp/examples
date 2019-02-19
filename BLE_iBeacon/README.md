# BLE iBeacon Examples

These examples show how to use the imp API hardware.bluetooth to create iBeacon advertisers and listeners. Thess examples use 2 imp004m breakout boards with w1, w2, w5, and w7 connected to enable bluetooth.

## Passive Example

One imp004m creates an iBeacon formatted advertisement and broadcasts it via the imp API hardware.bluetooth. The other imp004m uses the imp API hardware.bluetooth to scan for iBeacons with the same UUID that the the first imp is broadcasting.

### Listener Code Files

[agent](./iBeaconListenerExample.agent.nut) <br>
[device](./iBeaconListenerExample.device.nut)

### Advertiser Code Files

[agent](./iBeaconAdevertiserExample.agent.nut) <br>
[device](./iBeaconAdevertiserExample.device.nut)

## ActiveExample

One imp004m creates an iBeacon formatted advertisement with a scan response that includes device state packet and broadcasts it via the imp API hardware.bluetooth. The other imp004m uses the imp API hardware.bluetooth to scan for iBeacons with the same UUID that the the first imp is broadcasting. If the broadcast type indicates a scan response is availible another scan filter is added to listen for response packets.

### Listener Code Files

[agent](./iBeaconActiveListenerExample.agent.nut) <br>
[device](./iBeaconActiveListenerExample.device.nut)

### Advertiser Code Files

[agent](./iBeaconActiveAdevertiserExample.agent.nut) <br>
[device](./iBeaconActiveAdevertiserExample.device.nut)