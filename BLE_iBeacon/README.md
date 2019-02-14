# BLE iBeacon Example

This example shows how to use the imp API hardware.bluetooth to create iBeacon advertisers and listeners. This example uses 2 imp004m breakout boards with w1, w2, w5, and w7 connected to enable bluetooth. One imp004m creates an iBeacon formatted advertisement and broadcasts it via the imp API hardware.bluetooth. The other imp004m uses the imp API hardware.bluetooth to scan for iBeacons with the same UUID that the the first imp is broadcasting.

## Listener Code Files

[agent](./iBeaconListenerExample.agent.nut)
[device](./iBeaconListenerExample.device.nut)

## Advertiser Code Files

[agent](./iBeaconAdevertiserExample.agent.nut)
[device](./iBeaconAdevertiserExample.device.nut)