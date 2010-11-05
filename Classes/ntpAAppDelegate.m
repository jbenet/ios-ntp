//
//  ntpAAppDelegate.m
//  ntpA
//
//  Created by Gavin Eadie on 10/16/10.
//  Copyright (c) 2010 Ramsay Consulting. All rights reserved.
//

#import "ntpAAppDelegate.h"
#import "ntpAViewController.h"
#import "NetworkClock.h"

@implementation ntpAAppDelegate

@synthesize window;
@synthesize viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [[NetworkClock sharedNetworkClock] loadAssociations];
    
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];

    NSTimer * repeatingTimer = [[NSTimer alloc] 
                                initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:10.0]
                                        interval:10.0
                                          target:self 
                                        selector:@selector(repeatingMethod:)
                                        userInfo:nil 
                                         repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer forMode:NSDefaultRunLoopMode];
    [repeatingTimer release];

    return YES;
}

- (void) repeatingMethod:(NSTimer*) theTimer {
    NSLog(@"sys clock: %@", [NSDate date]);
    NSLog(@"net clock: %@", [[NetworkClock sharedNetworkClock] networkTime]);
}

- (void)applicationWillTerminate:(UIApplication *)application {

    [[NetworkClock sharedNetworkClock] stopAssociations];
}

- (void)dealloc {

    [window release];
    [viewController release];
    [super dealloc];
}

@end
