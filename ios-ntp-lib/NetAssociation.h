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
  ║ associated statistics.                                                                           ║
  ║                                                                                                  ║
  ║ Each association makes a best effort at obtaining an accurate time and makes it available as a   ║
  ║ property.  Another process may use this to select, cluster, and combine the various servers'     ║
  ║ data to determine the most accurate and reliable candidates to provide an overall best time.     ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <UIKit/UIKit.h>
#import "GCDAsyncUdpSocket.h"

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  NTP Timestamp Structure                                                                         │
  │                                                                                                  │
  │   0                   1                   2                   3                                  │
  │   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │  |  Seconds                                                      |                               │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │  |  Seconds Fraction (0-padded)  |       |       |       |       | <-- 4294967296 = 1 second     │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │                  |               |       |   |   |               |                               │
  │                  |               |       |   |   |              233 picoseconds                  │
  │                  |               |       |   | 59.6 nanoseconds (mask = 0xffffff00)              │
  │                  |               |       |  238 nanoseconds (mask = 0xfffffc00)                  │
  │                  |               |      0.954 microsecond (mask = 0xfffff000)                    │
  │                  |             15.3 microseconds (mask = 0xffff0000)                             │
  │                 3.9 milliseconds (mask = 0xff000000)                                             │
  │                                                                                                  │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/

#define JAN_1970    		((uint64_t)0x83aa7e80)          // UNIX epoch in NTP's epoch:
                                                            // 1970-1900 (2,208,988,800s)
union ntpTime {

    struct {
        uint32_t    fractSeconds;
        uint32_t    wholeSeconds;
    }           partials;

    uint64_t    floating;

} ;

union ntpTime   ntp_time_now(void);
union ntpTime   unix2ntp(const struct timeval * tv);
double          ntpDiffSeconds(union ntpTime * start, union ntpTime * stop);

@protocol NetAssociationDelegate <NSObject>

- (void) reportFromDelegate;

@end

@protocol GCDAsyncUdpSocketDelegate;

@interface NetAssociation : NSObject <GCDAsyncUdpSocketDelegate, NetAssociationDelegate>

@property (nonatomic, weak) id delegate;

@property (readonly) NSString *         server;             // server address "123.45.67.89"
@property (readonly) BOOL               active;             // is this clock running yet?
@property (readonly) BOOL               trusty;             // is this clock trustworthy
@property (readonly) double             offset;             // offset from device time (secs)

- (instancetype) init NS_UNAVAILABLE;
/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ create a NetAssociation with the provided server name .. just sitting idle ..                    ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (instancetype) initWithServerName:(NSString *) serverName NS_DESIGNATED_INITIALIZER;

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ empty the time values fifo and start the timer which queries the association's server ..         ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) enable;                                            // ..
/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ snooze: stop the timer in a way that let's start it again ..                                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) snooze;                                            // stop the timer but don't delete it
/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ finish: stop the timer and invalidate it .. it'll die and disappear ..                           ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) finish;                                            // ..

- (void) sendTimeQuery;                                     // send one datagram to server ..

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ utility method converts domain name to numeric dotted address string ..                          ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
+ (NSString *) ipAddrFromName: (NSString *) domainName;

@end
