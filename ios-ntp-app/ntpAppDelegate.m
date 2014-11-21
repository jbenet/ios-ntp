/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpAppDelegate.m                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov16/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "ntpAppDelegate.h"

#import "ios-ntp.h"

@implementation ntpAppDelegate

- (BOOL) application:(UIApplication *) app didFinishLaunchingWithOptions:(NSDictionary *) options {

    [NetworkClock sharedNetworkClock];                      // gather up the ntp servers ...

    [_window makeKeyAndVisible];
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a timer that will fire in one seconds and then every second thereafter to ask the network │
  │ clock what time it is.                                                                           │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    NSTimer * repeatingTimer = [[NSTimer alloc]
                                initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0]
                                        interval:1.0 target:self selector:@selector(repeatingMethod:)
                                        userInfo:nil repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer forMode:NSDefaultRunLoopMode];

    return YES;
}

- (void) repeatingMethod:(NSTimer *) theTimer {
    systemTime = [NSDate date];
    networkTime = [NSDate networkDate];

    sysClockLabel.text = [NSString stringWithFormat:@"%@", systemTime];
    netClockLabel.text = [NSString stringWithFormat:@"%@", networkTime];
    differenceLabel.text = [NSString stringWithFormat:@"%7.6f",
                            [networkTime timeIntervalSinceDate:systemTime]];
}

- (void)applicationWillTerminate:(UIApplication *)application {

    [[NetworkClock sharedNetworkClock] finishAssociations];   // be nice and let all the servers go ...
}


@end