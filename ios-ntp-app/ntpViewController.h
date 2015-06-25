/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntpViewController.h                                                                              ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov28/14 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <UIKit/UIKit.h>
#import "ios-ntp.h"

@interface ntpViewController : UIViewController <NetAssociationDelegate>

@property (weak, nonatomic) IBOutlet UILabel *  sysClockLabel;
@property (weak, nonatomic) IBOutlet UILabel *  netClockLabel;
@property (weak, nonatomic) IBOutlet UILabel *  offsetLabel;

@property (weak, nonatomic) IBOutlet UILabel *  timeCheckLabel;

@end
