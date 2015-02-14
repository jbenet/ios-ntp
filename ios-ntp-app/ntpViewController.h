/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpViewController.h                                                                              ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov28/14 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <UIKit/UIKit.h>
#import "ios-ntp.h"

@interface ntpViewController : UIViewController

@property IBOutlet UILabel *        sysClockLabel;
@property IBOutlet UILabel *        netClockLabel;
@property IBOutlet UILabel *        differenceLabel;

@end
