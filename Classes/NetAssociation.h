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
    
    NSTimer *               repeatingTimer;                 // fires off an ntp request ...
    
    struct ntpTimestamp     ntpClientSendTime, 
                            ntpServerRecvTime, 
                            ntpServerSendTime, 
                            ntpClientRecvTime, 
                            ntpServerBaseTime;
    
    double                  root_delay, dispersion,         // milliSeconds
                            el_time, st_time, skew1, skew2; // seconds
    
    int                     li, vn, mode, stratum, poll, prec, refid;
    
}

@property (readonly) BOOL               useful;             // is this clock trustworthy
@property (retain) AsyncUdpSocket *     socket;
@property (retain) NSString *           server;             // ip address "xx.xx.xx.xx"
@property (readonly) double             offset;             // offset from device time (secs)

- (void) start;
- (void) stop;

@end

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ conversions of 'NTP Timestamp Format' fractional part to/from microseconds ...                   ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
#define uSec2Frac(x)    ( 4294*(x) + ( (1981*(x))>>11 ) )
#define Frac2uSec(x)    ( ((x) >> 12) - 759 * ( ( ((x) >> 10) + 32768 ) >> 16 ) )

#define JAN_1970        0x83aa7e80      /* 2208988800 1970 - 1900 in seconds */