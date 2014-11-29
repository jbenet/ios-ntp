//
//  ntpViewController.m
//  ios-ntp
//
//  Created by Gavin Eadie on 11/28/14.
//  Copyright (c) 2014 Ramsay Consulting. All rights reserved.
//

#import "ntpViewController.h"

@implementation ntpViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    netClock = [NetworkClock sharedNetworkClock];               // gather up the ntp servers ...

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a timer that will fire in one second and then every second thereafter to ask the network  │
  │ clock what time it is and set the text labels in the UI.                                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    NSTimer * repeatingTimer = [[NSTimer alloc]
                                initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0]
                                interval:1.0 target:self selector:@selector(repeatingMethod:)
                                userInfo:nil repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer forMode:NSDefaultRunLoopMode];

}

- (void) repeatingMethod:(NSTimer *) theTimer {
    NSDate *            systemTime = [NSDate date];
    NSDate *            networkTime = netClock.networkTime;

    _sysClockLabel.text = [NSString stringWithFormat:@"%@", systemTime];
    _netClockLabel.text = [NSString stringWithFormat:@"%@", networkTime];
    _differenceLabel.text = [NSString stringWithFormat:@"%7.6f",
                            [networkTime timeIntervalSinceDate:systemTime]];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end