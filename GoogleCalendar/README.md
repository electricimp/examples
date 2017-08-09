# GoogleCalendar Example

This is example code for using the imp with Google Calendar. The example provided allows you to schedule turning on lights on the device (an imp explorer kit) by adding an event titled "lights" to your calendar. The example code, however, also provides methods within a GoogleCalendar class which let you schedule, modify, delete, and view events from your calendar. By setting them up with ```device.on``` calls from the agent and ```device.send``` calls from the device, you can perform these actions by interacting with the device as well.

## Steps to Setup and Run Example

1. At [this link](https://console.developers.google.com/flows/enableapi?apiid=calendar), select "Select a project". Click the plus button to create a project.

2. Enter a project name, choose whether you would like to receive emails from Google, and agree to the terms of service. Then click "Create". Creating your project will take a few moments.

3. Refresh the page, then click select a project again. Now, you should see your project name. Click on it.

4. In the page that you are directed to, search calendar. Click on "Google Calendar API", and then select "Enable".

5. Select "Credentials" under API Manager on the left side of the screen.

6. Click "Create credentials" and select "API key". Be sure to note this key.

7. Click "OAuth consent screen". Enter a Product name and then click "Save".

8. Next, click "Create credentials" again and select OAuth client ID. Choose "Other" for Application type. This should give you a client ID and a client secret. Note both of these.

9. Go to your Google Calendar which you wish to use for this project. On the left side of the screen under "My calendars", hover over the Calendar you wish to use and open the drop down menu by clicking the arrow that appears. Select "Calendar settings".

10. Find your Calendar ID next to "Calendar Address". Note this ID.

11. Go to your model IDE and set the values of apiKey, clientId, clientSecret, and calendarId to the values you obtained in the previous steps. Uncomment the lines at the bottom of the agent code which instantiate a RefreshToken object and then call ```getAndPrintRefreshToken()```.

12. Run the agent code. In the log, a code and a url should appear. Enter the url into your browser. You will be prompted to log into your Google account. Do so, and then enter the code you received in the log into the prompt. Select "NEXT" and then "Allow". Return to the model.

13. In the log, you should now have a refresh token. Set the ```refreshToken``` variable's value to this refresh token by copying it from the log.

14. Set the value of tzOffset. This should be your timezone offset from UTC. For example, if you live in the US Pacific Time region, you should set its value to -7.

15. Return to the Credentials section of the Google API wizard. Click "Domain verification" and then "Add domain". In the text box that appears, enter your agent url. This can be found in your model IDE between the log and the text editor. In the pop-up that appears titled "Verify ownership", select "TAKE ME THERE".

16. Select "ADD A PROPERTY" and enter your agent url again. On the next page, click "this HTML verification file" to download a verification file. 

17. Open the HTML file in a text editor and copy its contents. In your IDE, find "verificationHtml" and set its value to the contents of the HTML file which you just copied.

18. Comment out the code you used to obtain a refresh token. Uncomment the instantiation of a Google Calendar object as well as the call to verifyWebhook, and then run the code.

19. On the Google page you were on (verify property), select "VERIFY".

20. Return to the API manager page, click "Credentials" again and then "Domain verification." Click "Add domain" and enter the agent url again. When you click "ADD DOMAIN", the agent url should appear under the list of Allowed domains.

21. Return to the model IDE. Comment out the call to ```verifyWebhook(*link*)``` and uncomment the calls to ```registerWebhook(*id*)``` and ```watchForEvent(*watchCb*)```. Run the code.

22. Go to your calendar and add an event titled "lights". To see the effects of the code quickly, schedule it for a few minutes ahead of the current time. Be sure to put it on the correct calendar.

23. In your IDE log, you should now see a few messages. These messages should display the time the lights are scheduled for as well as how many seconds from the current time they are scheduled for.

24. Once it is the time you have scheduled the lights for, your device should start flashing!


You can modify ```watchCb(*eventChange*)``` in order to respond to other actions or respond differently to added events. *eventChange* is an array of two entries. The first entry is a description of the event change, and will have the value "modified", "added", or "deleted". The second entry in the *eventChange* array will be either a json object which is the added or deleted event, or, if an event was modified, it will contain a table with two entries. The entries' keys are "new" and "old", and they map to the old and new json describing the event. 

Additionally, you can make the following method calls to interact with your calendar:

### addSimpleEvent(*start*, *end*, *title*[, *minutes*, *emails*])

The *addSimpleEvent(start, end, title[, minutes, emails])* method allows you to add an event to your calendar. *start* and *end* are formatted dateTime strings. You can create these by calling the *getTimeStamp(seconds, minutes, hour, day, month, year)* method and passing the required parameters. Then, you can pass the return value into *addSimpleEvent*. The *title* parameter should be the title of your event. The optional *minutes* parameter is the number of minutes before which you would like to receive a reminder about the event. The optional *emails* parameter is an array of emails which you would like to be reminded about the event.


### addCustomEvent(*customParameters*)

The *addCustomEvent(customParameters)* method allows you to create an event by passing *customParameters*, which is json containing the fields you wish the event to contain. See this [link](https://developers.google.com/google-apps/calendar/v3/reference/events/insert) for all available fields.

### deleteEventByNameAndTime(*name*, *start*)

The *deleteEventByNameAndTime(name, start)* method allows you to delete an event from your calendar by passing its *name* and *start* time as a dateTime string (which can be created through a call to *getTimeStamp*, as described in the *addSimpleEvent* method description).


### deleteEventById(*eventId*)

The *deleteEventById(eventId)* method allows you to delete an event from your calendar by passing its id.


### updateEvent(*name*, *currentStart*, *start*, *end*[, *minutes*, *emails*])

The *updateEvent(name, currentStart, start, end[, minutes, emails])* method allows you to update an event by passing its *name*, current start time, new desired *start* time, and new desired *end* time. The current start time, new start time, and new end time must be passed as formatted time stamps, which can be created by calls to the *getTimeStamp* method as described in the *addSimpleEvent* method description. There are two optional parameters, *minutes*, which allows you to choose how many minutes before the event you would like to be reminded of it, and *emails*, an array of email strings which you would like to receive reminders.

### getNextMeeting(*cb*)

The *getNextMeeting(cb)* method will return a sorted (by start time) array of events on your calendar. *cb* is a callback which receives this array.
