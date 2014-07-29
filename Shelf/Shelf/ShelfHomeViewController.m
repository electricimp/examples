//
//  ShelfHomeViewController.m
//  Shelf
//
//  Created by Juan Albanell on 16/07/2014.
//
//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

#import "ShelfHomeViewController.h"
#import "TempBook.h"

@interface ShelfHomeViewController ()
  @property (nonatomic, strong)   NSString *masterUrl;
  @property (nonatomic, strong)   NSMutableData *responseData;
  @property (nonatomic, strong)   CAGradientLayer *gradient;
  @property (nonatomic, strong)   NSTimer *updateTimer;
@end

#if BLINKUP
#define newImpUI \
BlinkUpController *blinkUpController = [[BlinkUpController alloc] init]; \
blinkUpController.planId = kBlinkUpPlan; \
blinkUpController.agentUrlTimeout = 10; \
NSError *err = [blinkUpController presentWifiSettingsWithDelegate:(NSObject<BlinkUpDelegate> *)self APIKey:kBlinkUpKey animated:NO];
#else
#define newImpUI \
UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Add device" message:@"Insert new 12 character device id" delegate:self cancelButtonTitle:@"Done" otherButtonTitles:nil]; \
alert.alertViewStyle = UIAlertViewStylePlainTextInput; \
[alert show];
#endif

static NSString *const kBlinkUpKey = @"";  //include your own BlinkUp API key if you have one
static NSString *const kBlinkUpPlan = @""; //include your own BlinkUp Plan ID if you have one

static NSString *const kLoad = @"Loading...";
static NSString *const kMaster = @"Welcome! Click to add your new Thermostat unit";
static NSString *const kSlave = @"Almost Done! \n Click to add a Tempbook";
static NSString *const kPower = @"Your Thermostat is off \n Click to turn on";
static NSInteger const kBlinkWidth = 300;
static NSInteger const kBlinkHeight = 300;
static NSInteger const kRoomHeight = 80;
static NSInteger const kMenuOffset = 50;
static NSInteger const kUpdateInterval = 10;
static CGRect    const kCoverLabelFrame = { {40.0f, 250.0f}, {240.0f, 100.0f}};
static CGRect    const kCoverLogoFrame = { {80.0f, 200.0f}, {160.0f, 50.0f}};

@implementation ShelfHomeViewController


#pragma mark ** View Handling **

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self hideMenu:YES];

  _gradient = [CAGradientLayer layer];
  _gradient.frame = self.view.bounds;
  [_gradient setColors:[NSArray arrayWithObjects:(id)[ok1 CGColor], (id)[ok2 CGColor], nil]];
  [self.view.layer insertSublayer:_gradient atIndex:0];
  
  // cover for welcome, off and loading screens
  _cover = [[UIView alloc] initWithFrame:self.view.frame];
  NSData *buffer = [NSKeyedArchiver archivedDataWithRootObject: _gradient];
  [_cover.layer insertSublayer:[NSKeyedUnarchiver unarchiveObjectWithData: buffer] atIndex:0];
  _coverLogo = [[UIImageView alloc] initWithFrame:kCoverLogoFrame];
  [_coverLogo setImage:[UIImage imageNamed:@"logo.png"]];
  [_cover addSubview:_coverLogo];
  _coverLabel = [[UILabel alloc] initWithFrame:kCoverLabelFrame];
  [_coverLabel setFont:[UIFont systemFontOfSize:20]];
  [_coverLabel setTextAlignment:NSTextAlignmentCenter];
  [_coverLabel setNumberOfLines:0];
  [_coverLabel setText:kLoad];
  [_cover addSubview:_coverLabel];
  [_cover addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(impConnect:)]];
  [self.view addSubview:_cover];
  [self showCover:NO];
  
  UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
  UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
  [swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
  [swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
  [self.view addGestureRecognizer:swipeLeft];
  [self.view addGestureRecognizer:swipeRight];
  
  //Set button skins
  int skin = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"userSkin"];
  [_hotButton setImage:[UIImage imageNamed:[NSString stringWithFormat:@"hot%d",skin]] forState:UIControlStateNormal];
  [_warmButton setImage:[UIImage imageNamed:[NSString stringWithFormat:@"warm%d",skin]] forState:UIControlStateNormal];
  [_okButton setImage:[UIImage imageNamed:[NSString stringWithFormat:@"ok%d",skin]] forState:UIControlStateNormal];
  [_coolButton setImage:[UIImage imageNamed:[NSString stringWithFormat:@"cool%d",skin]] forState:UIControlStateNormal];
  [_coldButton setImage:[UIImage imageNamed:[NSString stringWithFormat:@"cold%d",skin]] forState:UIControlStateNormal];
  
  _sensors = [[NSMutableArray alloc] init];
  _masterUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"masterUrl"];
  
  if (_masterUrl == nil) {
    _state = kNoMaster;
    [self updateCover];
  } else {
    _state = kNoSensors;
    _isLoading = YES;
    [self updateCover];
    [self checkState];
  }
}

- (void)viewDidLayoutSubviews
{
  [self hideMenu:NO];
}

- (void)updateBackground
{
  [CATransaction begin];
  [CATransaction setAnimationDuration:1.0];
  [_gradient setColors:[NSArray arrayWithObjects:(id)[_current.roomColor1 CGColor], (id)[_current.roomColor2 CGColor], nil]];
  [CATransaction commit];
}

- (void)rearrangeRooms
{
  _roomNum = 0;
  if (_sensors.count == 0) {
    NSLog(@"No Sensors");
    _state = kNoSensors;
    [self updateCover];
  } else {
    [_sensors sortUsingComparator:^NSComparisonResult(id a, id b) {
      return ((TempBook *)a).priority < ((TempBook *)b).priority;
    }];
    for (TempBook *sensor in _sensors) {
      sensor.frame = CGRectMake(0, kRoomHeight*_roomNum++, _roomsView.frame.size.width, kRoomHeight);
    }
    if (_current == nil || ![_sensors containsObject:_current]) {
      [self selectRoom:nil];
    }
  }
}

- (void)showMenu:(BOOL)animated
{
  if (_menuView.frame.origin.x != 0 && (_state == kDone || !animated)) {
    [UIView animateWithDuration:(animated?0.5:0.0) animations:^{
      [_menuView setFrame:CGRectMake(0, _menuView.frame.origin.y, _menuView.frame.size.width, _menuView.frame.size.height)];
      [_hotButton setFrame:CGRectMake(_hotButton.frame.origin.x+kMenuOffset, _hotButton.frame.origin.y, _hotButton.frame.size.width, _hotButton.frame.size.height)];
      [_warmButton setFrame:CGRectMake(_warmButton.frame.origin.x+kMenuOffset, _warmButton.frame.origin.y, _warmButton.frame.size.width, _warmButton.frame.size.height)];
      [_okButton setFrame:CGRectMake(_okButton.frame.origin.x+kMenuOffset, _okButton.frame.origin.y, _okButton.frame.size.width, _okButton.frame.size.height)];
      [_coolButton setFrame:CGRectMake(_coolButton.frame.origin.x+kMenuOffset, _coolButton.frame.origin.y, _coolButton.frame.size.width, _coolButton.frame.size.height)];
      [_coldButton setFrame:CGRectMake(_coldButton.frame.origin.x+kMenuOffset, _coldButton.frame.origin.y, _coldButton.frame.size.width, _coldButton.frame.size.height)];
      [_burgerButton setAlpha:0.0];
      [_roomLabel setAlpha:0.0];
    }];
  }
}

- (void)hideMenu:(BOOL)animated
{
  if (_menuView.frame.origin.x == 0 && (_state == kDone || !animated)) {
    [UIView animateWithDuration:(animated?0.5:0.0) animations:^{
      [_menuView setFrame:CGRectMake(-_menuView.frame.size.width, _menuView.frame.origin.y, _menuView.frame.size.width, _menuView.frame.size.height)];
      [_hotButton setFrame:CGRectMake(_hotButton.frame.origin.x-kMenuOffset, _hotButton.frame.origin.y, _hotButton.frame.size.width, _hotButton.frame.size.height)];
      [_warmButton setFrame:CGRectMake(_warmButton.frame.origin.x-kMenuOffset, _warmButton.frame.origin.y, _warmButton.frame.size.width, _warmButton.frame.size.height)];
      [_okButton setFrame:CGRectMake(_okButton.frame.origin.x-kMenuOffset, _okButton.frame.origin.y, _okButton.frame.size.width, _okButton.frame.size.height)];
      [_coolButton setFrame:CGRectMake(_coolButton.frame.origin.x-kMenuOffset, _coolButton.frame.origin.y, _coolButton.frame.size.width, _coolButton.frame.size.height)];
      [_coldButton setFrame:CGRectMake(_coldButton.frame.origin.x-kMenuOffset, _coldButton.frame.origin.y, _coldButton.frame.size.width, _coldButton.frame.size.height)];
      [_burgerButton setAlpha:1.0];
      [_roomLabel setAlpha:1.0];
    }];
  }
}

- (void)updateCover
{
  if (_isLoading) {
    [self showCover:NO];
    [_coverLabel setText:kLoad];
  } else if (_state == kOff) {
    [self showCover:YES];
    [_coverLabel setText:kPower];
  } else if (_state == kNoMaster) {
    [self showCover:NO];
    [_coverLabel setText:kMaster];
  } else if (_state == kNoSensors) {
    [self showCover:NO];
    [_coverLabel setText:kSlave];
  } else {
    [self hideCover:YES];
  }
}

- (void)showCover:(BOOL)animated
{
  [UIView animateWithDuration:(animated?0.5:0.0) animations:^{[_cover setAlpha:0.95];}];
}

- (void)hideCover:(BOOL)animated
{
  [UIView animateWithDuration:(animated?0.5:0.0) animations:^{[_cover setAlpha:0.0];}];
}

#pragma mark ** HTTP Requests **

- (void)checkState
{
  NSString *url = [NSString stringWithFormat:@"%@?check=all", _masterUrl];
  [self requestWithString:url];
}

- (void)updateTarget:(TempBook *)room
{
  NSString *url = [NSString stringWithFormat:@"%@?target=%@&temp=%f&priority=%d", _masterUrl, room.sensorID, room.target, room.priority];
  [self requestWithString:url];
}

- (void)deleteRoom:(TempBook *)room
{
  [_sensors removeObject:room];
  [room removeFromSuperview];
  [self rearrangeRooms];
  NSString *url = [NSString stringWithFormat:@"%@?remove=%@", _masterUrl, room.sensorID];
  [self requestWithString:url];
}

- (void)updateName:(NSString *)name forRoom:(TempBook *)room
{
  [room updateName:name];
  NSString *url = [NSString stringWithFormat:@"%@?room=%@&name=%@", _masterUrl, room.sensorID, [name stringByReplacingOccurrencesOfString:@" " withString: @"_"]];
  [self requestWithString:url];
}

- (void)addDevice:(NSString *) device {
  if (_state == kNoMaster) {
    _masterUrl = device;
    [[NSUserDefaults standardUserDefaults] setObject:_masterUrl forKey:@"masterUrl"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _isLoading = YES;
    [self checkState];
  } else {
    NSString *url = [NSString stringWithFormat:@"%@?master=%@", device, _masterUrl];
    [self requestWithString:url];
  }
}

- (void)requestWithString:(NSString *)url
{
  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
  NSLog(@"Request with url %@", url);
}

#pragma mark ** IBAction **

- (IBAction)newTarget:(id)sender
{
  [_current updateTarget:_current.temp+[sender tag]];
  [self updateBackground];
  [self updateTarget:_current];
}

- (IBAction)impConnect:(id)sender
{
  if (_state == kOff) { // When the click happens on the off screen cover
    [self togglePower:sender];
  } else if (!_isLoading) {
    newImpUI
  }
}

- (IBAction)changeMode:(id)sender
{
  _isPriority = !_isPriority;
  if (_isPriority) {
    [_modeButton setTitle:@"Show Temperatures" forState:UIControlStateNormal];
  } else {
    [_modeButton setTitle:@"Show Priorities" forState:UIControlStateNormal];
  }
  for (TempBook *sensor in _sensors) {
    [sensor updateButton];
  }
}

- (IBAction)burgerClicked:(id)sender
{
  [self showMenu:YES];
}

- (IBAction)togglePower:(id)sender
{
  NSString *url = [NSString stringWithFormat:@"%@?power=%@", _masterUrl,(_state == kOff?@"on":@"off")];
  [self requestWithString:url];
}

#pragma mark ** UIGestureRecognizer **

- (void)selectRoom:(UITapGestureRecognizer *)recognizer
{
  if (recognizer == nil) {
    _current = [_sensors objectAtIndex:0];
  } else {
    _current = (TempBook *)recognizer.view;
  }
  [_roomLabel setText:_current.room];
  [self updateBackground];
  for (TempBook *sensor in _sensors) {
    [sensor roomSelected:sensor == _current];
  }
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer
{
  if (recognizer.direction == UISwipeGestureRecognizerDirectionLeft) {
    [self hideMenu:YES];
  } else {
    [self showMenu:YES];
  }
}

#pragma mark ** UIAlertView **

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  if (_isLoading) {
    [self checkState];
    NSLog(@"Trying Again");
  } else if (alertView.alertViewStyle == UIAlertViewStylePlainTextInput) {
    NSString *url = [[alertView textFieldAtIndex:0] text];
    if (url.length == 12) {
      [self addDevice:[NSString stringWithFormat:@"https://agent.electricimp.com/%@",url]];
    }
  }
}

#pragma mark **UITextFieldDelegate **

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  NSString *name = textField.text;
  if (![name isEqualToString:_current.room]) {
    [self updateName:name forRoom:_current];
    NSLog(@"Name Updated");
  }
  [textField resignFirstResponder];
  return NO;
}

#pragma mark ** NSURLConnectionDelegate **

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
  _responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [_responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  NSError *error = nil;
  NSMutableDictionary *jsonDictionary = [[NSJSONSerialization JSONObjectWithData:_responseData options:0 error: &error] mutableCopy];
  if (!jsonDictionary) {
    NSString *responseString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
    NSLog(@"Response: %@", responseString);
    if ([responseString rangeOfString:@"Master"].location != NSNotFound) {
      [self checkState];
    } else if ([responseString rangeOfString:@"off"].location != NSNotFound) {
      _state = kOff;
      _isLoading = NO;
      [self updateCover];
    } else if (_state != kDone) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Server issues" message:@"We had some issues connecting to our servers, please try again" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
      [alert show];
    }
    
  } else {
    _isLoading = NO;
    if (jsonDictionary.count == 0) {
      NSLog(@"No Sensors");
      _state = kNoSensors;
      [self updateCover];
    } else {
      NSMutableArray *discards = [[NSMutableArray alloc] init];
      for (TempBook *sensor in _sensors) {
        NSDictionary *data = jsonDictionary[sensor.sensorID];
        [jsonDictionary removeObjectForKey:sensor.sensorID];
        if (data == nil) {
          [discards addObject:sensor];
          [sensor removeFromSuperview];
          NSLog(@"Discarding %@", sensor.sensorID);
        } else {
          [sensor updateTemp:[data[@"temp"] floatValue]
                    humidity:[data[@"rh"] floatValue]
                     battery:[data[@"bat"] floatValue]
                      target:[data[@"target"] floatValue]
                    priority:(int)[data[@"priority"] integerValue]];
        }
      }
      [_sensors removeObjectsInArray:discards];
      
      for (NSString *sensorID in jsonDictionary) {
        NSDictionary *data = jsonDictionary[sensorID];
        TempBook *sensor = [[TempBook alloc] initWith:sensorID
                                                  room:data[@"room"]
                                                master:self
                                                 frame:CGRectMake(0, kRoomHeight*_roomNum++, _roomsView.frame.size.width, kRoomHeight)];
        [sensor updateTemp:[data[@"temp"] floatValue]
                  humidity:[data[@"rh"] floatValue]
                   battery:[data[@"bat"] floatValue]
                    target:[data[@"target"] floatValue]
                  priority:(int)[data[@"priority"] integerValue]];
        [_sensors addObject:sensor];
        [_roomsView addSubview:sensor];
      }
      [self rearrangeRooms];
      _roomsView.contentSize = CGSizeMake(_roomsView.frame.size.width, _roomNum*kRoomHeight);
      _state = kDone;
      [self updateCover];
      [self updateBackground];
      _updateTimer = [NSTimer scheduledTimerWithTimeInterval:kUpdateInterval target:self selector:@selector(checkState) userInfo:nil repeats:NO];
      NSLog(@"Succesful Update");
    }
  }
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  NSLog(@"Connection failed with %@", error);
  if (_state != kDone && [error.description rangeOfString:@"unsupported URL"].location == NSNotFound) {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"No Internet Connection" message:@"We are having issues connecting to the internet, please try again" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
  }
}


#pragma mark ** NSURLConnectionDelegate **

#if BLINKUP
#define BlinkUpDelegate \
  - (void)blinkUp:(BlinkUpController *)blinkUpController flashCompleted:(BOOL)flashDidComplete; \
  { \
    NSLog(@"Blink Up Flash Completed"); \
    _isLoading = YES; \
    [self updateCover]; \
    if (_state == kDone) { \
      [_updateTimer invalidate]; \
    } \
  } \
  - (void)blinkUp:(BlinkUpController *)blinkUpController \
   statusVerified:(NSDate *)verifiedDate \
         agentURL:(NSURL *)agentURL \
          impeeId:(NSString *)impeeId \
            error:(NSError *)error; \
  { \
    _isLoading = NO; \
    if (error == nil) { \
      NSLog(@"Successful BlinkUp with %@ %@", agentURL, impeeId); \
      [self addDevice:agentURL.absoluteString]; \
    } else { \
      NSLog(@"Error: %@", error); \
      UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Blink Up Error" message:@"We had issues with blink up, please try again" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil]; \
      [alert show]; \
      [self updateCover]; \
    } \
  }
#else
#define BlinkUpDelegate
#endif

BlinkUpDelegate

@end
