/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetAssociation.h                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov03/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ║──────────────────────────────────────────────────────────────────────────────────────────────────║
  ║ This NetAssociation manages the communication and time calculations for one server.              ║
  ║                                                                                                  ║
  ║ Multiple servers are used in a process in which each client/server pair (association) works to   ║
  ║ obtain its own best version of the time.  The client sends small UDP packets to the server and   ║
  ║ the server overwrites certain fields in the packet and returns it immediately.  As each packet   ║
  ║ is received, the offset between the client's network time and the system clock is derived with   ║
  ║ associated statistics delta, epsilon, and psi.                                                   ║
  ║                                                                                                  ║
  ║ Each association makes a best effort at obtaining an accurate time and reports these times and   ║
  ║ their estimated accuracy to a process that selects, clusters, and combines the various servers   ║
  ║ to determine the most accurate and reliable candidates to provide an overall best time.          ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <UIKit/UIKit.h>
#import <sys/time.h>

@protocol NetAssociationDelegate <NSObject>

- (void) reportFromDelegate;

@end

#import "GCDAsyncUdpSocket.h"

@interface NetAssociation : NSObject <GCDAsyncUdpSocketDelegate, NetAssociationDelegate>

@property (nonatomic, weak) id delegate;

@property (readonly) BOOL               trusty;             // is this clock trustworthy
@property (readonly) double             offset;             // offset from device time (secs)

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ create a NetAssociation with the provided server                                                 ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (instancetype) initWithServerName:(NSString *) serverName NS_DESIGNATED_INITIALIZER;

- (void) enable;
- (void) finish;

- (void) sendTimeQuery;

@end