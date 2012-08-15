/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpAAppDelegate.m                                                                                ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov16/10                                                               ║
  ║ Copyright © 2010 Ramsay Consulting. All rights reserved.                                         ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "ntpAAppDelegate.h"
#import "ntpAViewController.h"
#import <ios-ntp/ios-ntp.h>

@implementation ntpAAppDelegate

@synthesize window;
@synthesize viewController;

- (BOOL) application:(UIApplication *) app didFinishLaunchingWithOptions:(NSDictionary *) options {

    [NetworkClock sharedNetworkClock];                      // gather up the ntp servers ...

    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Create a timer that will fire in ten seconds and then every ten seconds thereafter to ask the   │
  │ network clock what time it is.                                                                   │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    NSTimer * repeatingTimer = [[NSTimer alloc]
                                initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0]
                                        interval:1.0 target:self selector:@selector(repeatingMethod:)
                                        userInfo:nil repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer forMode:NSDefaultRunLoopMode];
    [repeatingTimer release];

    return YES;
}

- (void) repeatingMethod:(NSTimer *) theTimer {
    systemTime = [NSDate date];
    networkTime = [NSDate networkDate];

    sysClockLabel.text = [NSString stringWithFormat:@"%@", systemTime];
    netClockLabel.text = [NSString stringWithFormat:@"%@", networkTime];
    differenceLabel.text = [NSString stringWithFormat:@"%5.3f",
                            [networkTime timeIntervalSinceDate:systemTime]];
}

- (void)applicationWillTerminate:(UIApplication *)application {

    [[NetworkClock sharedNetworkClock] finishAssociations];   // be nice and let all the servers go ...
}

- (void)dealloc {

    [window release];
    [viewController release];
    [super dealloc];
}

@end