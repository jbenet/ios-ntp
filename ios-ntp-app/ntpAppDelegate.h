/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpAppDelegate.h                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov16/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <UIKit/UIKit.h>

@interface ntpAppDelegate : NSObject <UIApplicationDelegate> {

    NSDate *                        systemTime;
    NSDate *                        networkTime;

    IBOutlet UILabel *              sysClockLabel;
    IBOutlet UILabel *              netClockLabel;
    IBOutlet UILabel *              differenceLabel;

}

@property (nonatomic, strong) IBOutlet UIWindow *           window;

- (void) repeatingMethod:(NSTimer*)theTimer;

@end
