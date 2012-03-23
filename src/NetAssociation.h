/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetAssociation.h                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov03/10                                                               ║
  ║ Copyright 2010 Ramsay Consulting. All rights reserved.                                           ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import "GCDAsyncUdpSocket.h"
#include <sys/time.h>

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  NTP Timestamp Structure                                                                         │
  │                                                                                                  │
  │   1                   2                   3                                                      │
  │   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │  |                           Seconds                             |                               │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │  |                  Seconds Fraction (0-padded)                  | <-- 4294967296 = 1 second     │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
struct ntpTimestamp {
	uint32_t    fullSeconds;
	uint32_t    partSeconds;
};

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  NTP Short Format Structure                                                                      │
  │                                                                                                  │
  │   0                   1                   2                   3                                  │
  │   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  │  |          Seconds              |           Fraction            | <-- 65536 = 1 second          │
  │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
struct ntpShortTime {
	uint16_t    fullSeconds;
	uint16_t    partSeconds;
};

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ NetAssociation represents one time server.  When it is created, it sends the first time query,   │
  │ evaluates the quality of the reply, and keeps the queries running till the server goes 'bad'     │
  │ or its creator kills it ...                                                                      │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
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

- (id) initWithServerName:(NSString *)serverName queue:(dispatch_queue_t)queue;
- (void) enable;
- (void) finish;

@end

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ conversions of 'NTP Timestamp Format' fractional part to/from microseconds ...                   ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
#define uSec2Frac(x)    ( 4294*(x) + ( (1981*(x))>>11 ) )
#define Frac2uSec(x)    ( ((x) >> 12) - 759 * ( ( ((x) >> 10) + 32768 ) >> 16 ) )

#define JAN_1970        0x83aa7e80      /* 1970 - 1900 in seconds 2,208,988,800 | First day UNIX  */
                                                  // 1 Jan 1972 : 2,272,060,800 | First day UTC
