/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpViewController.m                                                                              ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov28/14 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "ntpViewController.h"

@interface ntpViewController () {

    NetworkClock *                  netClock;

}

@end

@implementation ntpViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    netClock = [NetworkClock sharedNetworkClock];

#ifdef ONECLOCK

    [netClock xmitTime];

#else

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a timer that will fire every second to refresh the text labels in the UI.                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    NSTimer * repeatingTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0]
                                                        interval:1.0
                                                          target:self
                                                        selector:@selector(timerFireMethod:)
                                                        userInfo:nil
                                                         repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer
                                 forMode:NSDefaultRunLoopMode];

#endif

}

#ifndef ONECLOCK

- (void) timerFireMethod:(NSTimer *) theTimer {
    NSDate *            systemTime = [NSDate date];
    NSDate *            networkTime = netClock.networkTime;

    _sysClockLabel.text = [NSString stringWithFormat:@"%@", systemTime];
    _netClockLabel.text = [NSString stringWithFormat:@"%@", networkTime];
    _differenceLabel.text = [NSString stringWithFormat:@"%5.3f",
                            [networkTime timeIntervalSinceDate:systemTime]];
}

#endif

@end