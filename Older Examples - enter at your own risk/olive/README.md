Olive is a reference design for an RFID/NFC reader connected to an Electric Imp.
It was first mentioned in the blog at: http://blog.electricimp.com/post/58924766992/managing-wifis-effects-on-battery-life-through-the
The code here was first written by Siddartho Bhattacharya, an Electric Imp intern, and adapted by Aron Steg, an Electric Imp engineer.

One thing worth noting is that there are three wireless devices in the Olive. The Imp (which uses WiFi), the capacitive sensor, and the NFC reader. They interfere with each other if they are active at the same time. So the code has a bit of a workload to keep things off when they are not required. The WiFi and NFC are off until the capacitive sensor finds a potential device. Then the cap sense is turned off and the NFC works its magic. Once it detects and successfully reads a UID, the NFC is shutdown and the WiFi takes over. The cycle then starts again.

**This really is not complete reference code yet. It doesn't complete the protocol (for example it doesn't detect and manage collisions) but it functions well as a simple scanner. Please feel free to add your own finishing touches and improvements and submit a pull request.**
