# ArduCAM OV2640 Example 

This example contains a facial recognition application and a driver class for the OV2640 ArduCAM. 

The camera driver can be used to develop other camera applications. For a full description of the driver [see below](#camera-driver-class).

The facial recognition application uses the Kairos Facial Recognition API to detect and recognize faces. To run this application you will need to set up an account on Kairos and get an app ID and API key.

## Facial Recognition Application 

Follow these steps to set up the facial recognition application.

### Setting up Kairos Account

1. Go to the [Kairos Developer Page](http://kairos.com/docs/) and click GET YOUR API KEY
2. Scroll to the bottom and select **GET YOUR FREE API KEY**
3. Fill in your information and be sure to select **YES** as your answer to "Are you a software developer" in order to create an account and get your app ID and API key.

### Running the code

1. Open the Electric Imp IDE and copy and paste the following files into the agent and device coding windows
    * [FacialRecognition.agent.nut](./FacialRecognition.agent.nut)
    * [FacialRecognition.device.nut](./FacialRecognition.device.nut)
2. In the agent code, add your **app ID** and **API key**.

It's now time to enroll some faces! You have two options.

#### Option 1: Enroll an image through your device and agent code.
1. At the bottom of the device code, comment out capture_loop() and uncomment enroll().
2. In your agent code, enter the subject's name as the value of subjectName.
2. When you are ready to take a picture of your face and enroll it, hit Build and Run. When your device connects and starts, it will immediately take a picture and attempt to enroll it. 

#### Option 2: Enroll an image through a command line python script.
1. On the command line, run the python script kairos_upload.py with the filepath to the image the subject's name.

##### Example
```
C:\Users\Liam\CSE\ArduCAM>python kairos_upload.py liam.jpg Liam
```

##### Template
```
YOUR CMD_LINE PATH> python kairos_upload.py IMAGE_FILEPATH IMAGE_NAME
```

### Recognizing Faces

Once you've enrolled some images of a person's face (you can enroll multiple images of the same face to increase the likelihood of it being recognized), make sure capture_loop() is uncommented in the device code and run the code. The code will take RGB images in a loop and compare them to the previous image taken to see if something has come into frame. If it is determined that something entered the frame, a jpeg image will be taken and sent to the agent, which will pass the image on to kairos to be analyzed. If the image contains a recognized face, the agent will log the name of the recognized individual to the server.


## Camera Driver Class

This class provides driver code for the ArduCAM mini 2MP / OV2640 camera.

To add this class to your project, copy and paste the [Camera.class.nut](./Camera.class.nut) file to top of your device code. Then add your application code after.

### Class Usage 

#### Constructor: Camera(*spi*, *cs_l*, *i2c*)
The constructor takes three required parameters: a pre-configured spi bus, a chip select pin for spi (it need not be pre-configured), and a pre-configured i2c bus. The spi bus, according to the camera datasheet, should have a maximum data rate of 8MHz, and the i2c bus, according to the camera datasheet, should have a data rate of 400kHz. The spi bus must have CPOL = CPHA = 0.
##### Example
```
spi <- hardware.spiBCAD;
// SCK max is 10 MHz for the device
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, SPI_CLKSPEED);

cs_l <- hardware.pinD;

i2c <- hardware.i2cJK;
i2c.configure(I2C_CLKSPEED);

// Set up camera
myCamera <- Camera(spi, cs_l, i2c);
```

### Class Methods

#### reset()
The *reset()* method resets the OV2640 registers to their default state and loads default parameter sets. By default, it sets the image mode as 320x240 JPEG.

##### Example
```
myCamera.reset();
```

#### capture()
The *capture()* method takes a picture and loads it into the fifo buffer.

##### Example
```
myCamera.capture();
```

#### set_jpeg_size(*size*)
The *set_jpeg_size(size)* method will configure the camera to take a jpeg of the passed size. Supported sizes are 160x120, 176x144, 320x240, 352x288, 640x480, 800x600, 1024x768, 1280x960, and 1600x1200. You must pass the desired width. If a non-supported width is passed, by default 320x240 will be selected.

##### Example
```
myCamera.set_jpeg_size(800);
```

#### setRGB()
The *setRGB()* method will configure the camera to take images in the RGB565 format.

##### Example
```
myCamera.setRGB();
```

#### setYUV422()
The *setYUV422()* method will configure the camera to take images in the YUV422 format.

##### Example
```
myCamera.setYUV422();
```

#### saveLocal()
The *saveLocal()* method will return the image in the fifo buffer. This method is used to get a copy of the image on the device.

##### Example
```
myCamera.setRGB();
myCamera.capture();
local img = myCamera.saveLocal();
// Do something with the image here...
```

#### brighten()
The *brighten()* image will brighten the image taken by the camera.

##### Example
```
myCamera.brighten();
```

#### setExposure(*exp*)
The *setExposure(exp)* method will set the exposure of the images taken by the camera. The parameter to setExposure should be a 16-bit number, with larger numbers corresponding to longer exposure times.

##### Example
```
myCamera.setExposure(0xffff);
```

# License
The ArduCAM library is licensed under the [MIT License](./LICENSE)