//
//  ntpViewController.h
//  ios-ntp
//
//  Created by Gavin Eadie on 11/28/14.
//  Copyright (c) 2014 Ramsay Consulting. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ios-ntp.h"

@interface ntpViewController : UIViewController {

@private

    NetworkClock *                  netClock;

}

@property IBOutlet UILabel *        sysClockLabel;
@property IBOutlet UILabel *        netClockLabel;
@property IBOutlet UILabel *        differenceLabel;

@end
