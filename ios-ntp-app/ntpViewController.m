/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpViewController.m                                                                              ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov28/14 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "ntpViewController.h"

@interface ntpViewController () {

    NetworkClock *                  netClock;
    NetAssociation *                netAssociation;

}

@end

@implementation ntpViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    netClock = [NetworkClock sharedNetworkClock];

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a timer that will fire every second to refresh the text labels in the UI.                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    NSTimer * repeatingTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0]
                                                        interval:1.0
                                                          target:self
                                                        selector:@selector(timerFireMethod:)
                                                        userInfo:nil
                                                         repeats:YES];

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Add the repeating timer to the run-loop.                                                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer
                                 forMode:NSDefaultRunLoopMode];

}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ The method executed by the timer -- gets the latest times and displays them.                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) timerFireMethod:(NSTimer *) theTimer {
    NSDate *            systemTime = [NSDate date];
    NSDate *            networkTime = netClock.networkTime;

    _sysClockLabel.text = [NSString stringWithFormat:@"System Clock: %@", systemTime];
    _netClockLabel.text = [NSString stringWithFormat:@"Network Clock: %@", networkTime];
    _differenceLabel.text = [NSString stringWithFormat:@"Network ahead by (secs): %5.3f",
                            [networkTime timeIntervalSinceDate:systemTime]];
}


/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Gets a single NetAssociation and tells it to get the time from its server.                       ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (IBAction) timeCheck:(id)sender {
    netAssociation = [[NetAssociation alloc] initWithServerName:@"time.apple.com"];
    netAssociation.delegate = self;
    [netAssociation sendTimeQuery];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Called when that single NetAssociation has a network time to report.                             ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) reportFromDelegate {
    _timeCheckLabel.text = [NSString stringWithFormat:@"System ahead by (secs): %5.3f",
                            netAssociation.offset];
}

@end
