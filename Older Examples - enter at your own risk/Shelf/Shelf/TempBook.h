//
//  ShelfSensor.h
//  Shelf
//
//  Created by Juan Albanell on 16/07/2014.
//
//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

@class ShelfHomeViewController;

#define hot1  [UIColor colorWithRed:255.0/255.0 green:100.0/255.0 blue:080.0/255.0 alpha:1]
#define hot2  [UIColor colorWithRed:255.0/255.0 green:180.0/255.0 blue:140.0/255.0 alpha:1]
#define warm1 [UIColor colorWithRed:255.0/255.0 green:200.0/255.0 blue:150.0/255.0 alpha:1]
#define warm2 [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:220.0/255.0 alpha:1]
#define ok1   [UIColor colorWithRed:230.0/255.0 green:255.0/255.0 blue:230.0/255.0 alpha:1]
#define ok2   [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1]
#define cool1 [UIColor colorWithRed:150.0/255.0 green:220.0/255.0 blue:255.0/255.0 alpha:1]
#define cool2 [UIColor colorWithRed:220.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1]
#define cold1 [UIColor colorWithRed:100.0/255.0 green:125.0/255.0 blue:200.0/255.0 alpha:1]
#define cold2 [UIColor colorWithRed:100.0/255.0 green:200.0/255.0 blue:255.0/255.0 alpha:1]

@interface TempBook : UIView<UIAlertViewDelegate>

@property (nonatomic, strong)   IBOutlet UILabel *roomName;
@property (nonatomic, strong)   IBOutlet UIButton *tempButton;

@property (nonatomic, readonly) NSString *sensorID;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSString *room;
@property (nonatomic, readonly) int priority;
@property (nonatomic, readonly) float target;
@property (nonatomic, readonly) float temp;
@property (nonatomic, readonly) float tempF;
@property (nonatomic, readonly) float humidity;
@property (nonatomic, readonly) float battery;
@property (nonatomic, readonly) UIColor *roomColor1;
@property (nonatomic, readonly) UIColor *roomColor2;

- (id)initWith:(NSString *)sensorID
          room:(NSString *)room
        master:(ShelfHomeViewController *)master
         frame:(CGRect) frame;

- (void)updateTemp:(float)temp
          humidity:(float)humidity
           battery:(float)battery
            target:(float)target
          priority:(int)priority;

- (void)updateTarget:(float)target;

- (void)updateButton;

- (void)updateName:(NSString*)name;

- (void)roomSelected:(BOOL)selected;


@end
