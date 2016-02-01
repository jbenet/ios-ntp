/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpViewController.m                                                                              ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov28/14 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "ntpViewController.h"

@interface ntpViewController () {

    NetworkClock *          netClock;           // complex clock
    NetAssociation *        netAssociation;     // one-time server

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
  │ Add the screen refresh repeating timer to the run-loop ..                                        │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer
                                 forMode:NSDefaultRunLoopMode];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ The method executed by the timer -- gets the latest times and displays them.                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) timerFireMethod:(NSTimer *) theTimer {
    _sysClockLabel.text = [NSString stringWithFormat:@"System Clock: %@", [NSDate date]];
    _netClockLabel.text = [NSString stringWithFormat:@"Network Clock: %@", netClock.networkTime];
    _offsetLabel.text = [NSString stringWithFormat:@"Clock Offet: %5.3f mSec", netClock.networkOffset * 1000.0];
}



/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Gets a single NetAssociation and tells it to get the time from its server.                       ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (IBAction) timeCheck:(id)sender {
    netAssociation = [[NetAssociation alloc] initWithServerName:[NetAssociation ipAddrFromName:@"time.apple.com"]];
    netAssociation.delegate = self;
    [netAssociation sendTimeQuery];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Called when that single NetAssociation has a network time to report.                             ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) reportFromDelegate {
    _timeCheckLabel.text = [NSString stringWithFormat:@"System ahead by: %5.3f mSec",
                            netAssociation.offset * 1000.0];
}

@end
