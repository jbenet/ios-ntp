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

#include <Foundation/Foundation.h>
#include <CFNetwork/CFNetwork.h>

#include <sys/time.h>

#include "GCDAsyncUdpSocket.h"

#define JAN_1970    0x83aa7e80          // UNIX epoch in NTP's epoch: 1970-1900 (2,208,988,800s)

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
struct ntpTimestamp {
	uint32_t      fullSeconds;
	uint32_t      partSeconds;
};

@interface NetAssociation : NSObject <GCDAsyncUdpSocketDelegate> {

    GCDAsyncUdpSocket *     socket;                         // NetAssociation UDP Socket
    NSString *              server;                         // server name "123.45.67.89"

    NSTimer *               repeatingTimer;                 // fires off an ntp request ...
    int                     pollingIntervalIndex;           // index into polling interval table

    struct ntpTimestamp     ntpClientSendTime,
                            ntpServerRecvTime,
                            ntpServerSendTime,
                            ntpClientRecvTime,
                            ntpServerBaseTime;

    double                  root_delay, dispersion,         // milliSeconds
                            el_time, st_time, skew1, skew2; // seconds

    int                     li, vn, mode, stratum, poll, prec, refid;

    double                  fifoQueue[8];
    short                   fifoIndex;

}

@property (readonly) BOOL               trusty;             // is this clock trustworthy
@property (readonly) double             offset;             // offset from device time (secs)

- (instancetype) init:(NSString *) serverName NS_DESIGNATED_INITIALIZER;
- (void) enable;
- (void) finish;

@end

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ conversions of 'NTP Timestamp Format' fractional part to/from microseconds ...                   ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
#define uSec2Frac(x)    ( 4294*(x) + ( (1981*(x))>>11 ) )
#define Frac2uSec(x)    ( ((x) >> 12) - 759 * ( ( ((x) >> 10) + 32768 ) >> 16 ) )
