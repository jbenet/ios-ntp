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

#ifdef ONECLOCK

    netClock = [NetworkClock sharedNetworkClock];
    [netClock xmitTime];

#else

    netClock = [NetworkClock sharedNetworkClock];               // gather up the ntp servers ...

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
    _differenceLabel.text = [NSString stringWithFormat:@"%7.6f",
                            [networkTime timeIntervalSinceDate:systemTime]];
}

#endif

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end