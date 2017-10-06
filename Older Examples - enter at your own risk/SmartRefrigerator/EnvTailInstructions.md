#Salesforce Smart Refrigerator

The following Trailhead project will use  the Electric Imp platform to connect and monitor a refrigerator and a Salesforce *Connected App* to track the current temperature and humidity in the fridge.  This example will also *open a case* in Salesforce if:  1) the refrigerator door is open for more than 30 seconds, or 2) the temperature remains over 11°C for more than 15 min, or 3) the relative humidity is over 70% for more than 15 min.  To track the current temperature and humidity we will create a Salesforce *custom object*, then update it with new readings every 15 seconds.


## 1 Intro - What you need

### General
 - Your WIFI *network name* and *password*
 - A smartphone (iOS or Android)
 - A computer with a web browser

### Accounts
  - An [Electric Imp developer account](https://ide.electricimp.com/login)
  - The Electric Imp BlinkUp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
  - A [Salesforce developer account](https://developer.salesforce.com/signup?d=70130000000td6N)

### Hardware
  - An Electric Imp developer kit
    - Imp 001
    - April Breakout Board
    - Environmental Sensor Tail

And if you want to install the board into a fridge:

  - [USB AC adapter](https://www.amazon.com/Omni-Universal-Adapter-Charger-Samsung/dp/B00YG0QALS/ref=sr_1_2?ie=UTF8&qid=1470954944&sr=8-2&keywords=usb+ac+adapter+5v)
  - [Electrical tape](https://www.amazon.com/Duck-299006-4-Inch-Utility-Electrical/dp/B001B19JLS/ref=sr_1_1?s=industrial&ie=UTF8&qid=1470867277&sr=1-1)

## Getting Started

### Step 2: Setup the Electric Imp hardware

First we will need to assemble the Electric Imp Developer Kit.  The kit comes with (1) the imp001 card, which has a WiFi radio and micorocontroller which drives all the logic for the board, (2) the breakout board into which the card is plugged and (3) an environmental sensor "tail".  A tail is a specific kind of board which clips onto the breakout board and provides a set of sensors and peripherals which are ready to use. For this project the environmental sensor tail will read temperature, humidity and light to determine the current state of your fridge.

#### Hardware Setup
 - Plug the imp001 card into the breakout board slot
 - Connect the Env Sensor tail to the April breakout board
 - Power up your Imp with the USB cable and power adapter
 - The Imp001 should now have power and be blinking amber/red

Assmbled it should look like this:

<img src="http://i.imgur.com/erBvo7d.jpg" width="400">

#### Electric Imp BlinkUp

Use the Electric Imp mobile app to BlinkUp your device

 - Log into your Electric Imp account
 - Enter your WIFI credentials
 - Follow the instructions in the app to [BlinkUp](https://electricimp.com/platform/blinkup/) your device

 If you have any issues getting started with your Electric Imp account or device, see [the full getting started guide](https://electricimp.com/docs/gettingstarted/quickstartguide/).

### Step 3: Add Code for the Electric Imp

#### How Electric Imp's connectivity platform works


The Electric Imp IoT Connectivity Platform has two main components -- the impDevice and the impCloud.  The impDevice runs the device code, which in this use case consolidates the data gathered by the temperature/humidity/light sensors.  Each device is paired one-to-one with a "virtual twin" -- or, as we call it, an agent -- in the impCloud.  The device sends this data to its agent, which runs agent code. In this example the agent code executes the logic on the sensor data (e.g. light values show fridge is open) and communicates with the Salesforce cloud.  Here's a broad overview of this flow:

<img src="http://i.imgur.com/VpZHzdS.jpg" width="600">

The Electric Imp IDE provides all the tools you need to write and deploy the software (to the device and agent) that will control your imp-enabled connected product. The IDE runs in a desktop web browser and communicates between the device and cloud solutions.

 If you'd like a quick overview of the IDE features please visit the Electric Imp [Dev Center](https://electricimp.com/docs/gettingstarted/ide/).

#### Electric Imp IDE / Code

 - In your favorite web browser log into the [Electric Imp IDE](https://ide.electricimp.com/login)
 - Click the *+* button to create a new model

![Empty IDE](http://i.imgur.com/Ui7w8eG.png)

 - In the pop up name your code model, select your device and click *Create Model* button
 - Copy and Paste the [agent code](https://raw.githubusercontent.com/electricimp/Salesforce/master/examples/SmartRefrigerator/SmartRefrigerator_Salesforce.agent.nut) from github into the left side agent window
 - Copy and Paste the [device code](https://raw.githubusercontent.com/electricimp/Salesforce/master/examples/SmartRefrigerator/SmartRefrigerator_Salesforce.device.nut) from github into the right side device window
 - Near the bottom of the IDE is the logs window where you can find your agent url. It will look something like this ```"https://agent.electricimp.com/szPc0sLfAqlu"```
 - Make a note of your agent url. You will need the it when creating your connected app in Salesforce.

 ![IDE code windows](http://i.imgur.com/IfVDZoq.png)

### Step 4: Create a Salesforce Connected App

#### Creating a Connected App in Salesforce

Step by step instructions to create a Connected App:

  1. Log into Salesforce and click on the **Setup** tab in the top right navigation menu
  ![Salesforce Navbar](http://i.imgur.com/mhYIfBx.png)
  2. In the sidebar under **Build** unfold the **Create** menu and select **Apps**
  3. At the bottom of the page under **Connected apps** click the **New** button
  ![Salesforce Apps](http://i.imgur.com/40aXTlL.png)
  4. In the **New Connected App** form fill in:
    - Basic Information
      - Connect App Name: "Electric Imp SmartFridge"
      - API Name should fill out to be "Electric_Imp_SmartFridge"
      - Contact Email should be your email
    - API (Enable OAuth Settings)
      - Check the *Enable OAuth Settings* Box
      - Callback URL - this should be your agent URL from the Electic Imp IDE (see last step)
      - Selected OAuth Scopes
        - Select *Access and manage your data (api)*
        - then click *Add*
    - When above info is filled out click **Save**
  5. You will be redirected to the *Connected App Name - your app name* page
    - Make a note of your Consumer Key (you will need to enter this into your agent code)
    - Click on Consumer Secret *Click to reveal*
    - Make note of your Consumer Secret (you will need to enter this into your agent code)
  ![Salesforce Keys](http://i.imgur.com/uussyzV.png)

#### Adding API keys to your Electric Imp Code

Open the Electric Imp IDE & select your device.  Find the *SALESFORCE CONSTANTS* section at the bottom of the Agent code and enter your **Consumer Key** and **Consumer Secret**.

![IDE with code](http://i.imgur.com/XaooQ9r.png)


### Step 5: Create a Custom Object in Salesforce

#### Creating a Custom Object in Salesforce

You will need to create a custom object with fields that correspond to each key in the reading table.  Here are the step by step instructions for creating a Custom Object:

1. Log into Salesforce and click on the **Setup** tab in the top right navigation menu
![Salesforce Navbar](http://i.imgur.com/mhYIfBx.png)
2. In the sidebar under **Build** unfold the **Create** menu and select **Objects**
3. At the top of the page click the **New Custom Object** button
![Salesforce Custom Object](http://i.imgur.com/FhF0J8w.png)
4. In the **New Custom Object** form fill in:
    - Custom Object Information
      - **Label** - for example *SmartFridge*
      - **Plural Label** - for example *SmartFridges*
      - **Object Name** - for example *SmartFridge*
    - Enter Record Name Label and Format
      - **Record Name** - for example *Reading Id*
      - **Data Type** select **Auto Number**
      - **Display Format** - for example *R-{0000}*
    - When above info is filled out click **Save**
5. On the **Custom Objects Page** click on your object name
6. You will be redirected to the *Custom Object - your object name* page <br> You will repeat step 7 four times to add fields for each sensor reading collected <br> The **Field Name** must match the data table from the device. The **Field Names** in the exmple code are: **temperature**, **humidity** , **door**, **ts**.
7. At the bottom of the page under **Custom Fields & Relationships** click the **New** button
    - Step 1 *Data Type*
      - Select **Number** for temperature and humidity, **Text** for door, or **Date/Time** for ts
      - then click **Next** button
    - Step 2 of 4
      - Enter **Field Label** - for example *temperature*, *humidity*, *door*, or *ts*
      - Enter **Length** - for temperature and humidity *4*, for door *10*
      - Enter **Decimal Places** - for temperature and humidity *2*
      - Enter **Field Name** - this must match the keys from the device code, *temperature*, *humidity*, *door*, or *ts*
      - Enter **Description** - for example *Temperature reading in °C*
      - then click **Next** button
    - Step 3 of 4
      - click **Next** button
    - Step 4 of 4
      - click **Save & New** <br>
      **Repeat** Steps 1-4 for humidity,
8. We need to create one more Field the *Device Id field*
    - Step 1 *Data Type*
      - Select **text**
      - then click **Next** button
    - Step 2 of 4
      - Enter **Field Label** enter **deviceId**
      - Enter **Length** - for example *16*
      - Enter **Field Name** enter **deviceId**
      - check **Required**
      - check **Unique**
      - check **Test "ABC" and "abc" as different values (case sensitive)**
      - check **External ID**
      - then click **Next** button
    - Step 3 of 4
      - click **Next** button
    - Step 4 of 4
      - click **Save**
9. You will be redirected to the *Custom Object - your object name* page
    - Make a note of your **API Name** (you will need to enter this into your agent code)
![Salesforce API Name](http://i.imgur.com/tL6ar7Z.png)

#### Adding Object Name to your Electric Imp Code

Open the Electric Imp IDE & select your device.  Find the *SALESFORCE CONSTANTS* section at the bottom of the Agent code and enter your **OBJ_API_NAME**.

![IDE with code](http://i.imgur.com/XaooQ9r.png)

### Step 6: Create a Custom Case Field in Salesforce

We want the cases opened to contain the Device ID for our refrigerator.  To do this we need to create a custom field for our Salesforce case.  Here are the step by step instructions for creating a Custom Case Field:

1. Log into Salesforce and click on the **Setup** tab in the top right navigation menu
![Salesforce Navbar](http://i.imgur.com/mhYIfBx.png)
2. In the sidebar under **Build** unfold the **Customize** menu then unfold **Cases** and select **Fields**
3. Scroll to the bottom of the page and under **Case Custom Fileds & Relationships** click the **New** button
![Salesforce Case Custom Field](http://i.imgur.com/XJf6KSg.png)
4. In the **New Custom Field** form fill in:
    - Step 1 *Data Type*
      - Select **Lookup**
      - then click **Next** button
      - Select "SmartFridge" as the related object
    - Step 2 of 4
      - Enter **Field Label** enter **Related Fridge**
      - Enter **Field Name** enter **Related_Fridge**
      - Enter **Description** (optional) for example *Device Id of the associated refrigerator*
      - then click **Next** button
    - Step 3 of 4
      - click **Next** button
    - Step 4 of 4
      - click **Save**
9. You will be redirected to the *Case Custom Field - your field name* page
    - Make a note of your **API Name** - this must be *Related_Fridge__c*
![Salesforce Case Custom Field](http://i.imgur.com/UuEJDnh.png)

### Step 7: Build and Run the Electric Imp Application

These examples use OAuth 2.0 for authentication, so the agent has been set up as a web server to handle the log in.
Go to the Electric Imp IDE and select your device from the sidebar for the final setup steps.

- Hit **Build and Run** to save and launch the code
- Click on the agent url to launch the log in page
- Log into salesforce

![IDE Screenshot](http://i.imgur.com/epCLa2O.png)

Your App should now be up and running.  You can monitor the device logs in the IDE, or log into Salesforce web portal to see updates there.

### Step 8: Install Device in Refrigerator

Open your refrigerator and tape the Imp and Env Tail inside with the sensors facing away from the refrigerator ceiling/wall.

Run the USB cable to the outside of the refrigerator and plug into power.

<img src="http://i.imgur.com/BUuEpjt.png" width="400">

If you don't have a fridge handy for this scenario, you can also test the door being open or close covering and uncovering the Environment Sensor board with your hand.  A door open for thirty seconds should register a case.

### Step 9: Monitor the data in Salesforce1

Now that you have connected your Imp to Salesforce, it might be handy to see that data on a mobile device.  Using Salesforce1, it is easy to keep track of your Smart Fridge on the go.


#### Create a Custom Object Tab

First, let's give the custom object a tab so that Salesforce1 can add it to the left navigation.

1. Log in to your Developer Edition.
2. In the top nav, click Setup.
3. In Setup, enter Tab into the Quick Find box and select *Build* | *Create* | *Tabs*.
4. Under Custom Object Tabs, click *New*
5. Choose *SmartFridge* from the Object dropdown
6. Choose Thermometer as the Tab Style

![Custom Object](http://i.imgur.com/eXyOmd6.png)

7. Click *Next*, *Next*, and then *Save*

#### Open Salesforce1 in Chrome

You can access the Salesforce1 mobile app in three ways:

*As a downloadable mobile app (Salesforce1) that you install on your phone from the Apple AppStore or Google Play
*By navigating to login.salesforce.com using a mobile browser
*By using the Chrome Developer Tools

For this step, we'll use the last option. First ensure that Salesforce1 is available through a desktop browser and is enabled for your user:

1. Log in to your Developer Edition.
2. In the top nav, click *Setup*.
3. In Setup, enter Salesforce1 into the Quick Find box and select *Administer* | *Salesforce1* | *Salesforce1 Settings*.
4. Ensure the Enable the Salesforce1 mobile browser app is checked.

![App settings checkbox](http://i.imgur.com/Tigi9eK.png)

5. In Setup, enter Users into the Quick Find box and select *Administer* | *Manage Users* | *Users*.
6. Click *Edit* next to the name you used to create your developer edition.
7. Ensure that Salesforce1 User is checked. (Update and save as needed.)

![Salesforce1 User checkbox](http://i.imgur.com/svdRddT.png)

Next we’ll emulate the Salesforce1 Mobile App in the Chrome web browser:

1. Open a new tab in your Chrome browser and open the Developer Tools by clicking *View* | *Developer* | *Developer Tools*
2. Click the Toggle Device Mode button to simulate your browser as a mobile device.

![Chrome Tools Mobile Simulator](http://i.imgur.com/hzb2F0N.png)

3.To simulate the Salesforce1 app in your browser, copy and paste in the URL from the previous tab. Remove the part of the URL immediately after salesforce.com/. For example:

![URL original](http://i.imgur.com/jGgVki5.jpg)
![URL removed](http://i.imgur.com/t5GVzgS.jpg)

4. Append `/one/one.app` to the end of the URL after salesforce.com to start the Salesforce1 Application simulator. For example:

![URL one/one.app](http://i.imgur.com/0WKCcTx.jpg)

5. If the display is too small, change the size to 100%.

![URL one/one.app](http://i.imgur.com/BvmL50q.png)

6. Click the three white bars in the upper left to open the left navigation

7. Under the "Recent" section, scroll down and click *More*

![Menu](http://i.imgur.com/xv2YL52.png)

8. You will see "SmartFridges" somewhere on the list. Click *SmartFridges*

![Menu](http://i.imgur.com/GHcC0gG.png)

9. Select a record to view the details of the reading.


### Step 10: Use Process Builder to Chatter Fridge data

Finally, let's add some finesse to our application by using Process Builder to drive a Chatter conversation based on the incoming readings which create the case.


#### Create a new Process Builder
1. Log in to your Developer Edition.
2. In the top nav, click *Setup*.
3. In Setup, enter Process Builder into the Quick Find box and select *Create* | *Workflow & Approvals* | *Process Builder*.
4. Click *New*.
5. Name the new process *Post SmartFridge Case to Chatter*.
6. Click *Save*.
7. Click *Add Object*.
8. In the Find an Object dropdown, select *Case*.
9. Click *Save*.

![Object](http://i.imgur.com/6yEeL2W.png)

#### Setup the Process Criteria

Next we’ll set up the criteria that will fire the process:

1. Click *Add Criteria*.
2. For Criteria Name, enter *Related to SmartFridge*.
3. In set conditions, click *Find a Field*.
4. Use field selector to find *Related_Fridge__c*.
5. For Operator, select *Is null*.
6. Keep the values of *Boolean* and *False*.
7. Click *Save*.

![Criteria](http://i.imgur.com/B3DeySV.png)

#### Add an Action

In the Immediate Actions box next to your new criteria, click *Add Action* and configure as follows:

1. Action Type: *Post to Chatter*
2. Action name: *Post SmartFridge Case Data*
3. Post to: *User*
4. User: *Select a user from a record*
5. Click in the Find a user… box, select *OwnerID*, and then click *Choose*.
6. Copy and paste the following text into the Add a message, mention a user or group… text box:

```The case ({![Case].Id}) was opened regarding the Smart Fridge {![Case].Related_Fridge__r.DeviceId__c}. This fridge was recorded at a temperature of {![Case].Related_Fridge__r.Temperature__c}, humidity of {![Case].Related_Fridge__r.Humidity__c}, and a door status of {![Case].Related_Fridge__r.Door__c}.```

![Action](http://i.imgur.com/vzEp8n7.png)

1. Click Save. Your process should now look like this:

![Process Builder](http://i.imgur.com/TIXIMnV.png)

2. Click Activate.

Now whenever a case is created that has a related Smart Fridge, the important data about that fridge will be accessible right from the case owners's chatter feed.

#### Test Your Process

Let’s try out the process by keeping the fridge door open for over 30 seconds. This should trigger Salesforce to create a case. Because the case is related to a fridge, the case will be posted to your Chatter feed.

![Chatter](http://i.imgur.com/yT8bR09.png)
