/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpAppDelegate.m                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov16/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "ntpAppDelegate.h"

@implementation ntpAppDelegate

- (BOOL) application:(UIApplication *) app didFinishLaunchingWithOptions:(NSDictionary *) options {

    return YES;

}

- (void)applicationWillTerminate:(UIApplication *) app {

//  [[NetworkClock sharedNetworkClock] finishAssociations];     // be nice and let all the servers go ...

}

@end