//
//  ShelfSensor.m
//  Shelf
//
//  Created by Juan Albanell on 16/07/2014.
//
//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

#import "TempBook.h"
#import "ShelfHomeViewController.h"

@interface TempBook ()
  @property (nonatomic, assign)   BOOL deletingRoom;
  @property (nonatomic, weak)     ShelfHomeViewController *master;
@end

static NSString *const kPriority = @" LM H";

@implementation TempBook

- (id)initWith:(NSString *)sensorID
          room:(NSString *)room
        master:(ShelfHomeViewController *)master
         frame:(CGRect) frame
{
  _sensorID = sensorID;
  _master = master;
  
  self = [super initWithFrame:frame];
  
  _roomName = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, frame.size.width-70, frame.size.height)];
  [_roomName setFont:[UIFont systemFontOfSize:18.0]];
  [_roomName setTextColor:[UIColor whiteColor]];
  [self updateName:room];
  [self addSubview:_roomName];
  _tempButton = [[UIButton alloc] initWithFrame:CGRectMake(12, frame.size.height/2-22, 45, 45)];
  [_tempButton addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
  [[_tempButton layer] setBorderWidth:1.0f];
  [[_tempButton layer] setBorderColor:[UIColor whiteColor].CGColor];
  [[_tempButton layer] setCornerRadius:_tempButton.frame.size.width/2];
  [self addSubview:_tempButton];
  [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:master action:@selector(selectRoom:)]];
  [self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(deleteRoom:)]];
  return self;
}

- (void)updateTemp:(float)temp
          humidity:(float)humidity
           battery:(float)battery
            target:(float)target
          priority:(int)priority
{
  _temp = temp;
  _tempF = temp*9.0/5.0 + 32.0;
  _humidity = humidity;
  _battery = battery;
  _priority = priority;
  [self updateButton];
  [self updateTarget:target];

}

- (void)updateName:(NSString*)name {
  _room = [name stringByReplacingOccurrencesOfString:@"_" withString: @" "];
  [_roomName setText:_room];
}

- (void)updateTarget:(float)target
{
  _target = target;
  
  if (_target-_temp >= 2) {
    _roomColor1 = cold1;
    _roomColor2 = cold2;
  } else if (_target-_temp >= 1) {
    _roomColor1 = cool1;
    _roomColor2 = cool2;
  } else if (_target-_temp <= -2) {
    _roomColor1 = hot1;
    _roomColor2 = hot2;
  } else if (_target-_temp <= -1) {
    _roomColor1 = warm1;
    _roomColor2 = warm2;
  } else {
    _roomColor1 = ok1;
    _roomColor2 = ok2;
  }
}

- (void)updateButton
{
  if (_master.isPriority) {
    [_tempButton setTitle:[[kPriority substringToIndex:_priority+1] substringFromIndex:_priority] forState:UIControlStateNormal];
  } else {
    int unit = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"userUnit"];
    float temp = _temp;
    if (unit == 0) {
      temp = _tempF;
    } else if (unit == 2) {
      temp += 273.15;
    }
    [_tempButton setTitle:[NSString stringWithFormat:@"%.0fº", temp] forState:UIControlStateNormal];
  }
  
}

- (void)deleteRoom:(UITapGestureRecognizer *)recognizer
{
  if (!_deletingRoom) {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Delete Room" message:@"Are you sure you want to delete this room?" delegate:self cancelButtonTitle:@"Yes" otherButtonTitles:@"No",nil];
    _deletingRoom = YES;
    [alert show];
  }
}

- (void)roomSelected:(BOOL)selected
{
  [_tempButton setBackgroundColor:(selected? [UIColor darkGrayColor] : [UIColor clearColor])];
}

#pragma mark ** IBActions **

- (IBAction)buttonClicked:(id)sender
{
  if (_master.isPriority) {
    _priority = (_priority*2);
    if (_priority > 4) {
      _priority = 1;
    }
    [self updateButton];
    [_master rearrangeRooms];
    [_master updateTarget:self];
  }
}

#pragma mark ** UIAlertView **

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
  if (buttonIndex == 0) {
    [_master deleteRoom:self];
  }
  _deletingRoom = NO;
}


@end
