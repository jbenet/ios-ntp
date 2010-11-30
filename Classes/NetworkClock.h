/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetworkClock.h                                                                                   ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Oct17/10                                                               ║
  ║ Copyright 2010 Ramsay Consulting. All rights reserved.                                           ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import "AsyncUdpSocket.h"
#import "NetAssociation.h"

@interface NetworkClock : NSObject {

    NSTimeInterval          timeIntervalSinceDeviceTime;

    NSMutableArray *        timeAssociations;

@private
    
    NSSortDescriptor *      dispersionSortDescriptor;
    NSArray *               sortDescriptors;
    
}

+ (NetworkClock *) sharedNetworkClock;

- (void) createAssociations;
- (void) reportAssociations;
- (void) finishAssociations;

- (NSDate *) networkTime;

@end