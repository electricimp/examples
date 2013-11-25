Olive is a reference design for an RFID/NFC reader connected to an Electric Imp.
It was first mentioned in the blog at: http://blog.electricimp.com/post/58924766992/managing-wifis-effects-on-battery-life-through-the
The code here was first written by Siddartho Bhattacharya, an Electric Imp intern, an adapted by Aron Steg, an Electric Imp engineer.

One thing worth noting is that there are three wireless devices in the Olive. The wifi Imp, the capacitive sense and the NFC reader. They interfere with each other if they are active at the same time. So the code has a bit of a workload to keep things off when they are not required. So, the wifi and NFC are off until the cap sense finds a potential device. Then the cap sense is turned off and the NFC works it's magic. Once it detects and successfully reads a UID, the NFC is shutdown and the Wifi takes over. The cycle then starts again.

This really is not complete reference code yet. It doesn't complete the protocol (for example it doesn't detect and manage collisions) but it function well as a simple scanner. Please feel free to add your own finishing touches and improvements and submit a pull request.
