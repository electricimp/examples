//
//  ShelfAppDelegate.m
//  Shelf
//
//  Created by Juan Albanell on 16/07/2014.
//
//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

#import "ShelfAppDelegate.h"
#import "ShelfHomeViewController.h"

@implementation ShelfAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  // Override point for customization after application launch.
  self.window.backgroundColor = [UIColor whiteColor];
  [self.window makeKeyAndVisible];
  
  ShelfHomeViewController *controller = [[ShelfHomeViewController alloc] initWithNibName:@"ShelfHomeViewController" bundle:nil];
  [self.window setRootViewController:controller];
  
  
  NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
  NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
  NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
  NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
  for(NSDictionary *prefSpecification in preferences)
  {
    NSString *key = [prefSpecification objectForKey:@"Key"];
    if(key)
    {
      [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
    }
  }
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
  
  NSInteger unit = [[NSUserDefaults standardUserDefaults] integerForKey:@"userUnit"];
  if (unit == -1) {
    if ([[[NSLocale currentLocale] objectForKey: NSLocaleCountryCode] isEqualToString:@"US"]) {
      [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"userUnit"];
    } else {
      [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"userUnit"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
  }

  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
