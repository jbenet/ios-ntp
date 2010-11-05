//
//  ntpAAppDelegate.h
//  ntpA
//
//  Created by Gavin Eadie on 10/16/10.
//  Copyright (c) 2010 Ramsay Consulting. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ntpAViewController;

@interface ntpAAppDelegate : NSObject <UIApplicationDelegate> {
    
//  UIWindow *              window;
//  ntpAViewController *    viewController;

}

@property (nonatomic, retain) IBOutlet UIWindow *           window;
@property (nonatomic, retain) IBOutlet ntpAViewController * viewController;

- (void) repeatingMethod:(NSTimer*)theTimer;

@end
