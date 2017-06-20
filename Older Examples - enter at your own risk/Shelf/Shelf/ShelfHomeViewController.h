//
//  ShelfHomeViewController.h
//  Shelf
//
//  Created by Juan Albanell on 16/07/2014.
//
//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

#import <UIKit/UIKit.h>

// If you have the BlinkUp SDK import the framework and set BLINKUP to 1
#define BLINKUP 0
#if BLINKUP
#import <BlinkUp/BlinkUp.h>
#endif

@class TempBook;

typedef enum {
  kNoMaster,
  kNoSensors,
  kDone,
  kOff,
} ShelfState;

@interface ShelfHomeViewController : UIViewController<NSURLConnectionDelegate, UITextFieldDelegate, UIAlertViewDelegate>

@property (nonatomic, weak)     IBOutlet UIScrollView *roomsView;
@property (nonatomic, weak)     IBOutlet UIView *menuView;
@property (nonatomic, strong)   IBOutlet UIView *cover;
@property (nonatomic, strong)   IBOutlet UIImageView *coverLogo;
@property (nonatomic, strong)   IBOutlet UILabel *coverLabel;
@property (nonatomic, strong)   IBOutlet UITextField *roomLabel;
@property (nonatomic, strong)   IBOutlet UIButton *burgerButton;
@property (nonatomic, strong)   IBOutlet UIButton *modeButton;
@property (nonatomic, strong)   IBOutlet UIButton *hotButton;
@property (nonatomic, strong)   IBOutlet UIButton *warmButton;
@property (nonatomic, strong)   IBOutlet UIButton *okButton;
@property (nonatomic, strong)   IBOutlet UIButton *coolButton;
@property (nonatomic, strong)   IBOutlet UIButton *coldButton;

@property (nonatomic, readonly) NSMutableArray *sensors;
@property (nonatomic, readonly) TempBook *current;
@property (nonatomic, readonly) ShelfState state;
@property (nonatomic, readonly) BOOL isLoading;
@property (nonatomic, readonly) BOOL isPriority;
@property (nonatomic, readonly) int roomNum;


- (IBAction)newTarget:(id)sender;
- (IBAction)impConnect:(id)sender;
- (IBAction)changeMode:(id)sender;
- (IBAction)togglePower:(id)sender;
- (void)updateName:(NSString *)name forRoom:(TempBook *)room;
- (void)deleteRoom:(TempBook *)room;
- (void)selectRoom:(UITapGestureRecognizer *)recognizer;
- (void)updateTarget:(TempBook *)room;
- (void)rearrangeRooms;

@end
