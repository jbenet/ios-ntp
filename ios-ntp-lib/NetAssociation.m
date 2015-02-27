/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetAssociation.m                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov03/10 ... Copyright 2010-15 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "NetAssociation.h"

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

#pragma -
#pragma mark                        T i m e • C o n v e r t e r s

#define JAN_1970    		0x83aa7e80                      // UNIX epoch in NTP's epoch:
                                                            // 1970-1900 (2,208,988,800s)
struct ntpTimestamp {
    uint32_t      wholeSeconds;
    uint32_t      fractSeconds;
};

static struct ntpTimestamp NTP_1970 = {JAN_1970, 0};        // network time for 1 January 1970, GMT

static double pollIntervals[18] = {
    2.0,    16.0,    16.0,    16.0,    16.0,    35.0,    72.0,   127.0,    258.0,
    511.0,  1024.0,   2048.0, 4096.0,  8192.0, 16384.0, 32768.0, 65536.0, 131072.0
};

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
void unix2ntp(const struct timeval * tv, struct ntpTimestamp * ntp) {
    ntp->wholeSeconds = (uint32_t)(tv->tv_sec + JAN_1970);
    ntp->fractSeconds = (uint32_t)(((double)tv->tv_usec + 0.5) * (double)(1LL<<32) * 1.0e-6);
}

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
void ntp2unix(const struct ntpTimestamp * ntp, struct timeval * tv) {
    tv->tv_sec  = ntp->wholeSeconds - JAN_1970;
    tv->tv_usec = (uint32_t)((double)ntp->fractSeconds / (1LL<<32) * 1.0e6);
}

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ get current time in NTP format                                                                   │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
void ntp_time_now(struct ntpTimestamp * ntp) {
    struct timeval          now;
    gettimeofday(&now, (struct timezone *)NULL);
    unix2ntp(&now, ntp);
}

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ get (ntpTime2 - ntpTime1) in (double) seconds                                                    │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
double ntpDiffSeconds(struct ntpTimestamp * start, struct ntpTimestamp * stop) {
    int32_t         a;
    uint32_t        b;
    a = stop->wholeSeconds - start->wholeSeconds;
    if (stop->fractSeconds >= start->fractSeconds) {
        b = stop->fractSeconds - start->fractSeconds;
    }
    else {
        b = start->fractSeconds - stop->fractSeconds;
        b = ~b;
        a -= 1;
    }
    
    return a + b / 4294967296.0;
}

@interface NetAssociation () {

    NSString *              server;                         // server name "123.45.67.89"
    GCDAsyncUdpSocket *     socket;                         // NetAssociation UDP Socket

    NSTimer *               repeatingTimer;                 // fires off an ntp request ...
    int                     pollingIntervalIndex;           // index into polling interval table

    struct ntpTimestamp     ntpClientSendTime,
                            ntpServerRecvTime,
                            ntpServerSendTime,
                            ntpClientRecvTime,
                            ntpServerBaseTime;
    
    double                  root_delay, dispersion,         // milliSeconds
                            roundtrip, serverDelay;         // seconds
    
    int                     li, vn, mode, stratum, poll, prec, refid;

    double                  timerWobbleFactor;              // 0.75 .. 1.25
    
    double                  fifoQueue[8];
    short                   fifoIndex;

}

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSData *   createPacket;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * prettyPrintPacket;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * prettyPrintTimers;

@end

#pragma mark -
#pragma mark                        N E T W O R K • A S S O C I A T I O N

@implementation NetAssociation

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Initialize the association with a blank socket and prepare the time transaction to happen every  ┃
  ┃ 16 seconds (initial value) ...                                                                   ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (instancetype) initWithServerName:(NSString *) serverName {
    if (self = [super init]) {
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Set initial/default values for instance variables ...                                            │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        _delegate = self;
        pollingIntervalIndex = 0;                           // ensure the first timer firing is soon
        _trusty = FALSE;                                    // don't trust this clock to start with ...
        _offset = INFINITY;                                 // start with net clock meaningless
        server = serverName;

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a UDP socket that will communicate with the time server and set its delegate ...          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                               delegateQueue:dispatch_get_main_queue()];
    }

    return self;
}


/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ This sets the association in a mode where it repeatedly gets time from its server and performs   ┃
  ┃ statical check and averages on these multiple values to provide a more accurare time.            ┃
  ┃ starts the timer firing (sets the fire time randonly within the next five seconds) ...           ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) enable {
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a first-in/first-out queue for time samples.  As we compute each new time obtained from   │
  │ the server we push it into the fifo.  We sample the contents of the fifo for quality and, if it  │
  │ meets our standards we use the contents of the fifo to obtain a weighted average of the times.   │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    for (short i = 0; i < 8; i++) fifoQueue[i] = NAN;   // set fifo to all empty
    fifoIndex = 0;
    
#pragma mark                      N o t i f i c a t i o n • T r a p s

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ if associations are going to have a life, they have to react to their app being backgrounded.    ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ applicationBack -- catch the notification when the application goes into the background          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil queue:nil
                                                  usingBlock:^
     (NSNotification * note) {
         NTP_Logging(@"Application -> Background");
         [self finish];
     }];
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ applicationFore -- catch the notification when the application comes out of the background       │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil queue:nil
                                                  usingBlock:^
     (NSNotification * note) {
         NTP_Logging(@"Application -> Foreground");
         [self enable];
     }];
    
/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ if associations are going to have a life, they have to react to midnight and daylight saving.    ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ significantTimeChange -- trash the fifo ..                                                       │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationSignificantTimeChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^
     (NSNotification * note) {
         NTP_Logging(@"Application -> SignificantTimeChange");
         for (short i = 0; i < 8; i++) fifoQueue[i] = NAN;      // set fifo to all empty
         fifoIndex = 0;
     }];
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Finally, initialize the repeating timer that queries the server, set it's trigger time to the    │
  │ infinite future, and put it on the run loop .. nothing will happen (yet)                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    repeatingTimer = [NSTimer timerWithTimeInterval:MAXFLOAT
                                             target:self selector:@selector(queryTimeServer)
                                           userInfo:nil repeats:YES];
    repeatingTimer.tolerance = 1.0;                     // it can be up to 1 second late
    [[NSRunLoop mainRunLoop] addTimer:repeatingTimer forMode:NSDefaultRunLoopMode];
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ now start the timer .. fire the first one soon, and put some wobble in its timing some we don't  │
  │ get pulses of activity.                                                                          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    timerWobbleFactor = ((float)rand()/(float)RAND_MAX / 2.0) + 0.75;       // 0.75 .. 1.25
    NSTimeInterval  interval = pollIntervals[pollingIntervalIndex] * timerWobbleFactor;
    [repeatingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]];

    pollingIntervalIndex = 4;                           // subsequent timers fire at default intervals
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Set the receiver and send the time query with 2 second timeout, ...                              ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) queryTimeServer {
    [self sendTimeQuery];
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Put some wobble into the repeating time so they don't synchronize and thump the network          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    timerWobbleFactor = ((float)rand()/(float)RAND_MAX / 2.0) + 0.75;       // 0.75 .. 1.25
    NSTimeInterval  interval = pollIntervals[pollingIntervalIndex] * timerWobbleFactor;
    [repeatingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃                                                                 ...                              ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) sendTimeQuery {
    NSError *   error = nil;
    
    [socket sendData:[self createPacket] toHost:server port:123 withTimeout:2.0 tag:0];
    
    if(![socket beginReceiving:&error]) {
        NTP_Logging(@"Unable to start listening on socket for [%@] due to error [%@]", server, error);
        return;
    }
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ This stops the timer firing (sets the fire time to the infinite future) ...                      ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) finish {
    [repeatingTimer setFireDate:[NSDate distantFuture]];

    for (short i = 0; i < 8; i++) fifoQueue[i] = NAN;      // set fifo to all empty
    fifoIndex = 0;
}

#pragma mark                        N e t w o r k • T r a n s a c t i o n s

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │      Create a time query packet ...                                                              │
  │──────────────────────────────────────────────────────────────────────────────────────────────────│
  │                                                                                                  │
  │                               1                   2                   3                          │
  │           0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                        │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [ 0] | L | Ver |Mode |    Stratum    |     Poll      |   Precision   |                       │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [ 1] |                        Root  Delay (32)                       | in NTP short format   │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [ 2] |                     Root  Dispersion (32)                     | in NTP short format   │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [ 3] |                     Reference Identifier                      |                       │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [ 4] |                                                               |                       │
  │          |                    Reference Timestamp (64)                   | in NTP long format    │
  │     [ 5] |                                                               |                       │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [ 6] |                                                               |                       │
  │          |                    Originate Timestamp (64)                   | in NTP long format    │
  │     [ 7] |                                                               |                       │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [ 8] |                                                               |                       │
  │          |                     Receive Timestamp (64)                    | in NTP long format    │
  │     [ 9] |                                                               |                       │
  │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
  │     [10] |                                                               |                       │
  │          |                     Transmit Timestamp (64)                   | in NTP long format    │
  │     [11] |                                                               |                       │
  │                                                                                                  │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/

- (NSData *) createPacket {
	uint32_t        wireData[12];

	memset(wireData, 0, sizeof wireData);
	wireData[0] = htonl((0 << 30) |                                         // no Leap Indicator
                        (4 << 27) |                                         // NTP v4
                        (3 << 24) |                                         // mode = client sending
                        (0 << 16) |                                         // stratum (n/a)
                        (4 << 8)  |                                         // polling rate (16 secs)
                        (-6 & 0xff));                                       // precision (~15 mSecs)
	wireData[1] = htonl(1<<16);
	wireData[2] = htonl(1<<16);

    ntp_time_now(&ntpClientSendTime);

    wireData[10] = htonl(ntpClientSendTime.wholeSeconds);                   // Transmit Timestamp
	wireData[11] = htonl(ntpClientSendTime.fractSeconds);

    return [NSData dataWithBytes:wireData length:48];
}

- (void) decodePacket:(NSData *) data {
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  grab the packet arrival time as fast as possible, before computations below ...                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp_time_now(&ntpClientRecvTime);

    uint32_t        wireData[12];
    [data getBytes:wireData length:48];

	li      = ntohl(wireData[0]) >> 30 & 0x03;
	vn      = ntohl(wireData[0]) >> 27 & 0x07;
	mode    = ntohl(wireData[0]) >> 24 & 0x07;
	stratum = ntohl(wireData[0]) >> 16 & 0xff;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Poll: 8-bit signed integer representing the maximum interval between successive messages,       │
  │  in log2 seconds.  Suggested default limits for minimum and maximum poll intervals are 6 and 10. │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    poll    = ntohl(wireData[0]) >>  8 & 0xff;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Precision: 8-bit signed integer representing the precision of the system clock, in log2 seconds.│
  │  (-10 corresponds to about 1 millisecond, -20 to about 1 microSecond)                            │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    prec    = ntohl(wireData[0])       & 0xff;
    if (prec & 0x80) prec |= 0xffffff00;                                // -ve byte --> -ve int

    root_delay = ntohl(wireData[1]) * 0.0152587890625;                  // delay (mS) [1000.0/2**16].
    dispersion = ntohl(wireData[2]) * 0.0152587890625;                  // error (mS)

    refid   = ntohl(wireData[3]);

    ntpServerBaseTime.wholeSeconds = ntohl(wireData[4]);                // when server clock was wound
    ntpServerBaseTime.fractSeconds = ntohl(wireData[5]);

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  if the send time in the packet isn't the same as the remembered send time, ditch it ...         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    if (ntpClientSendTime.wholeSeconds != ntohl(wireData[6]) ||
        ntpClientSendTime.fractSeconds != ntohl(wireData[7])) return;   //  NO;

    ntpServerRecvTime.wholeSeconds = ntohl(wireData[8]);
    ntpServerRecvTime.fractSeconds = ntohl(wireData[9]);
    ntpServerSendTime.wholeSeconds = ntohl(wireData[10]);
    ntpServerSendTime.fractSeconds = ntohl(wireData[11]);
    
//  NTP_Logging(@"%@", [self prettyPrintPacket]);
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ determine the quality of this particular time ..                                                 │
  │ .. if max_error is less than 50mS (and not zero) AND                                             │
  │ .. stratum > 0 AND                                                                               │
  │ .. the mode is 4 (packet came from server) AND                                                   │
  │ .. the server clock was set less than 1 hour ago                                                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    _offset = INFINITY;                                                 // clock meaningless
    if ((dispersion < 50.0 && dispersion > 0.001) &&
        (stratum > 0) && (mode == 4) &&
        (ntpDiffSeconds(&ntpServerBaseTime, &ntpServerSendTime) < 3600.0)) {
        
        roundtrip   = ntpDiffSeconds(&ntpClientSendTime, &ntpClientRecvTime);   // .. (T4-T1)
        serverDelay = ntpDiffSeconds(&ntpServerRecvTime, &ntpServerSendTime);   // .. (T3-T2)
        
        double  t21 = ntpDiffSeconds(&ntpServerSendTime, &ntpClientRecvTime);   // .. (T2-T1)
        double  t34 = ntpDiffSeconds(&ntpServerRecvTime, &ntpClientSendTime);   // .. (T3-T4)

        _offset = (t21 + t34) / 2.0;                                            // calculate offset
        
//      NTP_Logging(@"%@", [self prettyPrintTimers]);
    }
    
    [_delegate reportFromDelegate];                           // tell delegate we're done
}

- (void) reportFromDelegate {
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ the packet is trustworthy -- compute and store offset in 8-slot fifo ...                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    
    fifoQueue[fifoIndex++ % 8] = _offset * 1000.0;                  // store offset in mSec
    fifoIndex %= 8;                                                 // rotate index in range
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ look at the (up to eight) offsets in the fifo and and count 'good', 'fail' and 'not used yet'    │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    short           good = 0, fail = 0, none = 0;
    _offset = 0.0;                                                  // reset for averaging
    
    for (short i = 0; i < 8; i++) {
        if (isnan(fifoQueue[i])) {                                  // fifo slot is unused
            none++;
            continue;
        }
        if (isinf(fifoQueue[i]) || fabs(fifoQueue[i]) < 0.0001) {   // server can't be trusted
            fail++;
            continue;
        }
        
        good++;
        _offset += fifoQueue[i];                                    // accumulate good times
    }
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │   .. if we have at least one 'good' server response or four or more 'fail' responses, we'll      │
  │      inform our management accordingly.  If we have less than four 'fails' we won't make any     │
  │      note of that ... we won't condemn a server until we get four 'fail' packets.                │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    double	stdDev = 0.0;
    if (good > 0 || fail > 3) {
        _offset = _offset / good;                                   // average good times
        
        for (short i = 0; i < 8; i++) {
            if (isnan(fifoQueue[i])) continue;
            
            if (isinf(fifoQueue[i]) || fabs(fifoQueue[i]) < 0.001) continue;
            
            stdDev += (fifoQueue[i] - _offset) * (fifoQueue[i] - _offset);
        }
        stdDev = sqrt(stdDev/(float)good);

        _trusty = (good+none > 4) &&                                // four or more 'fails'
                  (fabs(_offset) > stdDev*3.0);                     // s.d. < offset
        
//      NTP_Logging(@"  [%@] {%3.1f,%3.1f,%3.1f,%3.1f,%3.1f,%3.1f,%3.1f,%3.1f} ↑=%i, ↓=%i, %3.1f(%3.1f) %@", server,
//                  fifoQueue[0], fifoQueue[1], fifoQueue[2], fifoQueue[3],
//                  fifoQueue[4], fifoQueue[5], fifoQueue[6], fifoQueue[7],
//                  good, fail, _offset, stdDev, _trusty ? @"↑" : @"↓");

        [[NSNotificationCenter defaultCenter] postNotificationName:@"assoc-tick" object:self];
    }
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │   .. if the association is providing times which don't vary much, we could increase its polling  │
  │      interval.  In practice, once things settle down, the standard deviation on any time server  │
  │      seems to fall in the 70-120mS range (plenty close for our work).  We usually pick up a few  │
  │      stratum=1 servers, it would be a Good Thing to not hammer those so hard ...                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    if ((stratum == 1 && pollingIntervalIndex != 6) ||
        (stratum == 2 && pollingIntervalIndex != 5)) {
        pollingIntervalIndex = 7 - stratum;
    }
}

#pragma mark                        N e t w o r k • C a l l b a c k s

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    NTP_Logging(@"didConnectToAddress");
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    NTP_Logging(@"didNotConnect - %@", error.description);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    NTP_Logging(@"didNotSendDataWithTag - %@", error.description);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address withFilterContext:(id)filterContext {

    [self decodePacket:data];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    NTP_Logging(@"Socket closed : [%@]", server);
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Make an NSDate from ntpTimestamp ... (via seconds from JAN_1970) ...                             ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (NSDate *) dateFromNetworkTime:(struct ntpTimestamp *) networkTime {
    return [NSDate dateWithTimeIntervalSince1970:ntpDiffSeconds(&NTP_1970, networkTime)];
}

#pragma mark                        P r e t t y P r i n t e r s

- (NSString *) prettyPrintPacket {
    NSMutableString *   prettyString = [NSMutableString stringWithFormat:@"prettyPrintPacket\n\n"];

    [prettyString appendFormat:@"  leap indicator: %3d\n  version number: %3d\n"
                                "   protocol mode: %3d\n         stratum: %3d\n"
                                "   poll interval: %3d\n"
                                "   precision exp: %3d\n\n", li, vn, mode, stratum, poll, prec];

    [prettyString appendFormat:@"      root delay: %7.3f (mS)\n"
                                "      dispersion: %7.3f (mS)\n\n", root_delay, dispersion];

    struct timeval      tempTime;

    ntp2unix(&ntpClientSendTime, &tempTime);
    [prettyString appendFormat:@"client send time: %010u.%06d (%@)\n",
                        ntpClientSendTime.wholeSeconds,
                        tempTime.tv_usec,
                        [self dateFromNetworkTime:&ntpClientSendTime]];

    ntp2unix(&ntpServerRecvTime, &tempTime);
    [prettyString appendFormat:@"server recv time: %010u.%06d (%@)\n",
                        ntpServerRecvTime.wholeSeconds,
                        tempTime.tv_usec,
                        [self dateFromNetworkTime:&ntpServerRecvTime]];

    ntp2unix(&ntpServerSendTime, &tempTime);
    [prettyString appendFormat:@"server send time: %010u.%06d (%@)\n",
                        ntpServerSendTime.wholeSeconds,
                        tempTime.tv_usec,
                        [self dateFromNetworkTime:&ntpServerSendTime]];

    ntp2unix(&ntpClientRecvTime, &tempTime);
    [prettyString appendFormat:@"client recv time: %010u.%06d (%@)\n\n",
                        ntpClientRecvTime.wholeSeconds,
                        tempTime.tv_usec,
                        [self dateFromNetworkTime:&ntpClientRecvTime]];

    ntp2unix(&ntpServerBaseTime, &tempTime);
    [prettyString appendFormat:@"server clock set: %010u.%06d (%@)\n\n",
                        ntpServerBaseTime.wholeSeconds,
                        tempTime.tv_usec,
                        [self dateFromNetworkTime:&ntpServerBaseTime]];


    return prettyString;
}

- (NSString *) prettyPrintTimers {
    NSMutableString *   prettyString = [NSMutableString stringWithFormat:@"prettyPrintTimers\n\n"];

    [prettyString appendFormat:@"time server addr: [%@]\n"
                                " round trip time: %7.3f (mS)\n     server time: %7.3f (mS)\n"
                                "    clock offset: %7.3f (mS)\n\n",
          server, roundtrip * 1000.0, serverDelay * 1000.0, _offset * 1000.0];

    return prettyString;
}

- (NSString *) description {
    return [NSString stringWithFormat:@"%@ [%@] stratum=%i; offset=%3.1f±%3.1fmS",
            _trusty ? @"↑" : @"↓", server, stratum, _offset, dispersion];
}

@end
