/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetAssociation.h                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov03/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ║──────────────────────────────────────────────────────────────────────────────────────────────────║
  ║ This NetAssociation manages the communication and time calculations for one server.              ║
  ║                                                                                                  ║
  ║ Multiple servers are used in a process in which each client/server pair (association) works to   ║
  ║ obtain its own best version of the time.  The client sends small UDP packets to each server      ║
  ║ which overwrites certain fields in the packet and returns it immediately.  As each NTP message   ║
  ║ is received, the offset between the network time and the system clock is computed along with     ║
  ║ associated statistics delta, epsilon, and psi.                                                   ║
  ║                                                                                                  ║
  ║ Each association does its own best effort at obtaining an accurate time and reports these times  ║
  ║ and their estimated accuracy to a system process that selects, clusters, and combines the        ║
  ║ various servers and reference clocks to determine the most accurate and reliable candidates to   ║
  ║ provide a best time.                                                                             ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <UIKit/UIKit.h>
#import <sys/time.h>

#import "GCDAsyncUdpSocket.h"

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  NTP Timestamp Structure                                                                         │
  │                                                                                                  │
  │   0                   1                   2                   3                                  │
  │   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │  |                           Seconds                             |                               │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │  |                  Seconds Fraction (0-padded)                  | <-- 4294967296 = 1 second     │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/

#define JAN_1970    		0x83aa7e80                      // UNIX epoch in NTP's epoch:
                                                            // 1970-1900 (2,208,988,800s)
struct ntpTimestamp {
	uint32_t      wholeSeconds;
	uint32_t      fractSeconds;
};

static struct ntpTimestamp NTP_1970 = {JAN_1970, 0};        // network time for 1 January 1970, GMT

@interface NetAssociation : NSObject <GCDAsyncUdpSocketDelegate> {

    NSString *              server;                         // server name "123.45.67.89"

    double                  root_delay, dispersion,         // milliSeconds
                            roundtrip, serverDelay,         // seconds
                            skew1, skew2;                   // seconds

    int                     li, vn, mode, stratum, poll, prec, refid;

}

@property (readonly) BOOL               trusty;             // is this clock trustworthy
@property (readonly) double             offset;             // offset from device time (secs)

- (instancetype) initWithServerName:(NSString *) serverName NS_DESIGNATED_INITIALIZER;

- (void) transmitPacket;

- (void) enable;
- (void) finish;

@end