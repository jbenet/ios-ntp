/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpAAppDelegate.h                                                                                ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov16/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <UIKit/UIKit.h>

@class ntpAViewController;

@interface ntpAAppDelegate : NSObject <UIApplicationDelegate> {

    NSDate *                        systemTime;
    NSDate *                        networkTime;

    IBOutlet UILabel *              sysClockLabel;
    IBOutlet UILabel *              netClockLabel;
    IBOutlet UILabel *              differenceLabel;

}

@property (nonatomic, strong) IBOutlet UIWindow *           window;
@property (nonatomic, strong) IBOutlet ntpAViewController * viewController;

- (void) repeatingMethod:(NSTimer*)theTimer;

@end
