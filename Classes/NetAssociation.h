/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetAssociation.h                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov03/10                                                               ║
  ║ Copyright 2010 Ramsay Consulting. All rights reserved.                                           ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import "AsyncUdpSocket.h"
#include <sys/time.h>

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃   1                   2                   3                                                      ┃
  ┃   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                           Seconds                             |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                  Seconds Fraction (0-padded)                  | <-- 4294967296 = 1 second     ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃                                                                                                  ┃
  ┃                       NTP Timestamp Format                                                       ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

struct ntpTimestamp {
	uint32_t    fullSeconds;
	uint32_t    partSeconds;
};

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃   0                   1                   2                   3                                  ┃
  ┃   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |          Seconds              |           Fraction            | <-- 65536 = 1 second          ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃                                                                                                  ┃
  ┃                           NTP Short Format                                                       ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

struct ntpShortTime {
	uint16_t    fullSeconds;
	uint16_t    partSeconds;
};

@interface NetAssociation : NSObject {
        
    AsyncUdpSocket *        socket;                         // NetAssociation UDP Socket

    NSTimer *               repeatingTimer;                 // fires off an ntp request ...
    NSTimeInterval          pollingInterval;
    
    struct ntpTimestamp     ntpClientSendTime, 
                            ntpServerRecvTime, 
                            ntpServerSendTime, 
                            ntpClientRecvTime, 
                            ntpServerBaseTime;
    
    double                  root_delay, dispersion,         // milliSeconds
                            el_time, st_time, skew1, skew2; // seconds
    
    int                     li, vn, mode, stratum, poll, prec, refid;
    
    NSMutableArray *        fifoQueue;
    NSUInteger              answerCount, trustyCount;

}

@property (retain) NSString *           server;             // ip address "xx.xx.xx.xx"

@property (readonly) BOOL               trusty;             // is this clock trustworthy
@property (readonly) double             offset;             // offset from device time (secs)

- (void) enable;
- (void) finish;

@end

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃   1                   2                   3                                                      ┃
  ┃   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |LI | VN  |Mode |    Stratum    |     Poll      |   Precision   |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                          Root  Delay                          |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                       Root  Dispersion                        |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                     Reference Identifier                      |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                                                               |                               ┃
  ┃  |                    Reference Timestamp (64)                   |                               ┃
  ┃  |                                                               |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                                                               |                               ┃
  ┃  |                    Originate Timestamp (64)                   |                               ┃
  ┃  |                                                               |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                                                               |                               ┃
  ┃  |                     Receive Timestamp (64)                    |                               ┃
  ┃  |                                                               |                               ┃
  ┃  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               ┃
  ┃  |                                                               |                               ┃
  ┃  |                     Transmit Timestamp (64)                   |                               ┃
  ┃  |                                                               |                               ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ conversions of 'NTP Timestamp Format' fractional part to/from microseconds ...                   ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
#define uSec2Frac(x)    ( 4294*(x) + ( (1981*(x))>>11 ) )
#define Frac2uSec(x)    ( ((x) >> 12) - 759 * ( ( ((x) >> 10) + 32768 ) >> 16 ) )

#define JAN_1970        0x83aa7e80      /* 1970 - 1900 in seconds 2,208,988,800 | First day UNIX  */
// 1 Jan 1972 : 2,272,060,800 | First day UTC