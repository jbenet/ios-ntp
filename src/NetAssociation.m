/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetAssociation.m                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov03/10                                                               ║
  ║ Copyright 2010 Ramsay Consulting. All rights reserved.                                           ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "NetAssociation.h"

static double pollIntervals[18] = {
      16.0,    16.0,    16.0,    16.0,    16.0,     35.0,
      72.0,   127.0,   258.0,   511.0,  1024.0,   2048.0,
    4096.0,  8192.0, 16384.0, 32768.0, 65536.0, 131072.0
};

#define firstPollIntervalIndex (4)                // pollIntervals[4] = 16 seconds

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ This object manages the communication and time calculations for one server association.          ┃
  ┃                                                                                                  ┃
  ┃ Multiple servers are used in a process in which each client/server pair (association) works to   ┃
  ┃ obtain its own best version of the time.  The client sends small UDP packets to each server      ┃
  ┃ which overwrites certain fields in the packet and returns it immediately.  As each NTP message   ┃
  ┃ is received, the offset theta between the peer clock and the system clock is computed along      ┃
  ┃ with the associated statistics delta, epsilon, and psi.                                          ┃
  ┃                                                                                                  ┃
  ┃ Each association does its own best effort at obtaining an accurate time and reports these times  ┃
  ┃ and their estimated accuracy to a system process that selects, clusters, and combines the        ┃
  ┃ various servers and reference clocks to determine the most accurate and reliable candidates to   ┃
  ┃ provide a best time.                                                                             ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

@interface NetAssociation (PrivateMethods)

- (void) queryTimeServer:(NSTimer *) timer;     // query the association's server (fired by timer)

- (NSDate *)  dateFromNetworkTime:(struct ntpTimestamp *) networkTime;
- (NSData *) createPacket;
- (void) evaluatePacket;

- (NSString *) prettyPrintPacket;
- (NSString *) prettyPrintTimers;

@end

static double ntpDiffSeconds(struct ntpTimestamp * start, struct ntpTimestamp * stop);

#pragma mark -
#pragma mark                        N E T W O R K • A S S O C I A T I O N

@implementation NetAssociation

@synthesize trusty, offset;

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Initialize the association with a blank socket and prepare the time transaction to happen every  ┃
  ┃ 20 seconds (initial value) ...                                                                   ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (id) initWithServerName:(NSString *)serverName queue:(dispatch_queue_t)queue {
    if ((self = [super init]) == nil) return nil;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Set initial/default values for instance variables ...                                            │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    pollingIntervalIndex = 4;
    trusty = FALSE;                                         // don't trust this clock to start with ...
    offset = 0.0;                                           // start with clock on time (no offset)
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a UDP socket that will communicate with the time server and set its delegate ...          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    server = [serverName retain];
    socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:queue ? queue : dispatch_get_main_queue()];

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Create a first-in/first-out queue for time samples.  As we compute each new time obtained from   │
  │ the server we push it into the fifo.  We sample the contents of the fifo for quality and, if it  │
  │ meets our standards we use the contents of the fifo to obtain a weighted average of the times.   │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    for (short i = 0; i < 8; i++) fifoQueue[i] = 1E10;      // set fifo to all empty
    fifoIndex = 0;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Finally, initialize the repeating timer that queries the server, set it's trigger time to the    │
  │ infinite future, and put it on the run loop .. nothing will happen (yet)                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    repeatingTimer = [[NSTimer timerWithTimeInterval:pollIntervals[pollingIntervalIndex]
                                             target:self selector:@selector(queryTimeServer:)
                                           userInfo:nil repeats:YES] retain];
    [repeatingTimer setFireDate:[NSDate distantFuture]];
    [[NSRunLoop mainRunLoop] addTimer:repeatingTimer forMode:NSDefaultRunLoopMode];
    return self;
}

- (void)dealloc {
    [server release];
    [repeatingTimer invalidate];
    [repeatingTimer release];
    [socket release];
    [super dealloc];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Set the receiver and send the time query with 2 second timeout, ...                              ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) queryTimeServer:(NSTimer *) timer {
    [socket sendData:[self createPacket] toHost:server port:123L withTimeout:2.0 tag:0];
    
    NSError* error = nil;
    if(![socket beginReceiving:&error]) {
        NTP_Logging(@"Unable to start listening on socket for [%@] due to error [%@]", server, error);
        return;
    }
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ This starts the timer firing (sets the fire time randonly within the next five seconds) ...      ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) enable {
/*    NSError* error = nil;
    if(![socket beginReceiving:&error]) {
        NTP_Logging(@"Unable to start listening on socket for [%@] due to error [%@]", server, error);
        return;
    }*/
    [repeatingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:
                                 (double)(5.0 * (float)rand()/(float)RAND_MAX)]];

    NTP_Logging(@"enabled: [%@]", server);
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ This stops the timer firing (sets the fire time to the infinite future) ...                      ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) finish {
    [socket pauseReceiving];
    [repeatingTimer setFireDate:[NSDate distantFuture]];

    NTP_Logging(@"stopped: [%@]", server);
}

#pragma mark                        N e t w o r k • T r a n s a c t i o n s

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃      Create a time query packet ...                                                              ┃
  ┃──────────────────────────────────────────────────────────────────────────────────────────────────┃
  ┃                                                                                                  ┃
  ┃           1                   2                   3                                              ┃
  ┃           0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                        ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [ 0] | L | Ver |Mode |    Stratum    |     Poll      |   Precision   |                       ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [ 1] |                          Root  Delay                          |                       ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [ 2] |                       Root  Dispersion                        |                       ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [ 3] |                     Reference Identifier                      |                       ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [ 4] |                                                               |                       ┃
  ┃          |                    Reference Timestamp (64)                   |                       ┃
  ┃     [ 5] |                                                               |                       ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [ 6] |                                                               |                       ┃
  ┃          |                    Originate Timestamp (64)                   |                       ┃
  ┃     [ 7] |                                                               |                       ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [ 8] |                                                               |                       ┃
  ┃          |                     Receive Timestamp (64)                    |                       ┃
  ┃     [ 9] |                                                               |                       ┃
  ┃          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       ┃
  ┃     [10] |                                                               |                       ┃
  ┃          |                     Transmit Timestamp (64)                   |                       ┃
  ┃     [11] |                                                               |                       ┃
  ┃                                                                                                  ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (NSData *) createPacket {
	uint32_t        wireData[12];

	memset(wireData, 0, sizeof wireData);
	wireData[0] = htonl((0 << 30) |                                         // no Leap Indicator
                        (3 << 27) |                                         // NTP v3
                        (3 << 24) |                                         // mode = client sending
                        (0 << 16) |                                         // stratum (n/a)
                        (4 << 8) |                                          // polling rate (16 secs)
                        (-6 & 0xff));                                       // precision (~15 mSecs)
	wireData[1] = htonl(1<<16);
	wireData[2] = htonl(1<<16);

    struct timeval  now;
	gettimeofday(&now, NULL);

	ntpClientSendTime.fullSeconds = now.tv_sec + JAN_1970;
	ntpClientSendTime.partSeconds = uSec2Frac(now.tv_usec);

    wireData[10] = htonl(now.tv_sec + JAN_1970);                            // Transmit Timestamp
	wireData[11] = htonl(uSec2Frac(now.tv_usec));

    return [NSData dataWithBytes:wireData length:48];
}

- (void) evaluatePacket {
    double          packetOffset = 0.0;                     // initial untrustworthy offset
//  NTP_Logging(@"%@", [self prettyPrintPacket]);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ determine the quality of this particular time ..                                                 │
  │ .. if max_error is less than 50mS (and not zero) AND                                             │
  │ .. stratum > 0 AND                                                                               │
  │ .. the mode is 4 (packet came from server) AND                                                   │
  │ .. the server clock was set less than 1 hour ago                                                 │
  │ the packet is trustworthy -- compute and store offset in 8-slot fifo ...                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    if ((dispersion > 0.1 && dispersion < 50.0) && (stratum > 0) && (mode == 4) &&
        (-[[self dateFromNetworkTime:&ntpServerBaseTime] timeIntervalSinceNow] < 3600.0)) {
        el_time=ntpDiffSeconds(&ntpClientSendTime, &ntpClientRecvTime);     // .. (T4-T1)
        st_time=ntpDiffSeconds(&ntpServerRecvTime, &ntpServerSendTime);     // .. (T3-T2)
        skew1 = ntpDiffSeconds(&ntpServerSendTime, &ntpClientRecvTime);     // .. (T2-T1)
        skew2 = ntpDiffSeconds(&ntpServerRecvTime, &ntpClientSendTime);     // .. (T3-T4)
        packetOffset = (skew1+skew2)/2.0;                   // calulate trustworthy offset
    }

    fifoQueue[fifoIndex % 8] = packetOffset;                // store offset
    fifoIndex++;                                            // rotate index

    NTP_Logging(@"[%@] index=%i {%5.3f,%5.3f,%5.3f,%5.3f,%5.3f,%5.3f,%5.3f,%5.3f}", server,
                fifoIndex % 8, fifoQueue[0], fifoQueue[1], fifoQueue[2], fifoQueue[3], 
                               fifoQueue[4], fifoQueue[5], fifoQueue[6], fifoQueue[7]);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ look at the (up to eight) offsets in the fifo and and count 'good', 'fail' and 'not used yet'    │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    short           good = 0, fail = 0, none = 0;
    offset = 0.0;
    for (short i = 0; i < 8; i++) {
        if (fifoQueue[i] > 1E9) {                           // fifo slot is unused
            none++;
            continue;
        }
        if (fabs(fifoQueue[i]) < 1E-6) {                    // server can't be trusted
            fail++;
        }
        else {
            good++;
            offset += fifoQueue[i];
        }
    }
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │   .. if we have at least one 'good' server response or four or more 'fail' responses, we'll      │
  │      inform our management accordingly.  If we have less than four 'fails' we won't make any     │
  │      note of that ... we won't condemn a server until we get four 'fail' packets.                │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    if (good > 0 || fail > 3) {
        offset = offset / good;
        
        NTP_Logging(@"[%@] index=%i {good: %i; fail: %i; none: %i} offset=%3.1f", server,
                    fifoIndex, good, fail, none, offset * 1000.0);
        
        if (good+none < 5) {                                // four or more 'fails'
            trusty = FALSE;  
            [[NSNotificationCenter defaultCenter] postNotificationName:@"assoc-fail" object:self];
        }
        else {                                              // ...
            trusty = TRUE;  
            [[NSNotificationCenter defaultCenter] postNotificationName:@"assoc-good" object:self];
        }
    }
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │   .. if the association is providing times which don't vary much, we could increase its polling  │
  │      interval.  In practice, once things settle down, the standard deviation on any time server  │
  │      seems to fall in the 70-120mS range (plenty close for our work).  We usually pick up a few  │
  │      stratum=1 servers, it would be a Good Thing to not hammer those so hard ...                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    if (stratum == 1) pollingIntervalIndex = 6;
    if (stratum == 2) pollingIntervalIndex = 5;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Reschedule the timer if the time interval differs from that we've selected.
        if([repeatingTimer timeInterval] != pollIntervals[pollingIntervalIndex]) {
            NTP_Logging(@"[%@] poll interval adusted: %3.1f >> %3.1f", server,
                        [repeatingTimer timeInterval], pollIntervals[pollingIntervalIndex]);
            [repeatingTimer invalidate];
            [repeatingTimer release];
            repeatingTimer = [[NSTimer scheduledTimerWithTimeInterval:pollIntervals[pollingIntervalIndex]
                                                               target:self selector:@selector(queryTimeServer:)
                                                             userInfo:nil repeats:YES] retain];
        } 
    });    
}

#pragma mark                        N e t w o r k • C a l l b a c k s

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  grab the packet arrival time as fast as possible, before computations below ...                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval          arrival_time;
	gettimeofday(&arrival_time, NULL);

    ntpClientRecvTime.fullSeconds = arrival_time.tv_sec + JAN_1970;     // Transmit Timestamp coarse
	ntpClientRecvTime.partSeconds = uSec2Frac(arrival_time.tv_usec);    // Transmit Timestamp fine

    uint32_t                hostData[12];
    [data getBytes:hostData length:48];

	li      = ntohl(hostData[0]) >> 30 & 0x03;
	vn      = ntohl(hostData[0]) >> 27 & 0x07;
	mode    = ntohl(hostData[0]) >> 24 & 0x07;
	stratum = ntohl(hostData[0]) >> 16 & 0xff;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Poll: 8-bit signed integer representing the maximum interval between successive messages,       │
  │  in log2 seconds.  Suggested default limits for minimum and maximum poll intervals are 6 and 10. │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    poll    = ntohl(hostData[0]) >>  8 & 0xff;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Precision: 8-bit signed integer representing the precision of the system clock, in log2 seconds.│
  │  (-10 corresponds to about 1 millisecond, -20 to about 1 microSecond)                            │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    prec    = ntohl(hostData[0])      & 0xff;
    if (prec & 0x80) prec |= 0xffffff00;                                // -ve byte --> -ve int

    root_delay = ntohl(hostData[1]) * 0.0152587890625;                  // delay - round trip (mS)
    dispersion = ntohl(hostData[2]) * 0.0152587890625;                  // error - upper limit (mS)

    refid   = ntohl(hostData[3]);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  if the send time in the packet isn't the same as the remembered send time, ditch it ...         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    if (ntpClientSendTime.fullSeconds != ntohl(hostData[6]) ||
        ntpClientSendTime.partSeconds != ntohl(hostData[7])) return;

    ntpServerBaseTime.fullSeconds = ntohl(hostData[4]);
    ntpServerBaseTime.partSeconds = ntohl(hostData[5]);
    ntpServerRecvTime.fullSeconds = ntohl(hostData[8]);
    ntpServerRecvTime.partSeconds = ntohl(hostData[9]);
    ntpServerSendTime.fullSeconds = ntohl(hostData[10]);
    ntpServerSendTime.partSeconds = ntohl(hostData[11]);

    [self evaluatePacket];
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    NTP_Logging(@"Socket failed to connect to [%@] due to error : [%@]", server, error);            
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    NTP_Logging(@"Socket failed to send to [%@] due to error : [%@]", server, error);        
}

- (void) udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    NTP_Logging(@"Socket closed : [%@] error : [%@]", server, error);    
}

#pragma mark                        T i m e • C o n v e r t e r s

static double ntpDiffSeconds(struct ntpTimestamp * start, struct ntpTimestamp * stop) {
	int                 a;
	unsigned int        b;
	a = stop->fullSeconds - start->fullSeconds;
	if (stop->partSeconds >= start->partSeconds) {
		b = stop->partSeconds - start->partSeconds;
	} else {
		b = start->partSeconds - stop->partSeconds;
		b = ~b;
		a -= 1;
	}

	return a + b / 4294967296.0;
}

static struct ntpTimestamp NTP_1970 = {JAN_1970, 0};    // network time for 1 January 1970, GMT

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Make an NSDate from ntpTimestamp ... (via seconds from JAN_1970) ...                             ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (NSDate *)  dateFromNetworkTime:(struct ntpTimestamp *) networkTime {
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
                                "      dispersion: %7.3f (mS)\n"
                                "    reference ID: %3u.%u.%u.%u\n\n", root_delay, dispersion,
                                        refid>>24&0xff, refid>>16&0xff, refid>>8&0xff, refid&0xff];

    [prettyString appendFormat:@"  clock last set: %u.%.6u (%@)\n",
                        ntpServerBaseTime.fullSeconds, Frac2uSec(ntpServerBaseTime.partSeconds),
                        [self dateFromNetworkTime:&ntpServerBaseTime]];
    [prettyString appendFormat:@"client send time: %u.%.6u (%@)\n",
                        ntpClientSendTime.fullSeconds, Frac2uSec(ntpClientSendTime.partSeconds),
                        [self dateFromNetworkTime:&ntpClientSendTime]];
    [prettyString appendFormat:@"server recv time: %u.%.6u (%@)\n",
                        ntpServerRecvTime.fullSeconds, Frac2uSec(ntpServerRecvTime.partSeconds),
                        [self dateFromNetworkTime:&ntpServerRecvTime]];
    [prettyString appendFormat:@"server send time: %u.%.6u (%@)\n",
                        ntpServerSendTime.fullSeconds, Frac2uSec(ntpServerSendTime.partSeconds),
                        [self dateFromNetworkTime:&ntpServerSendTime]];
    [prettyString appendFormat:@"client recv time: %u.%.6u (%@)\n\n",
                        ntpClientRecvTime.fullSeconds, Frac2uSec(ntpClientRecvTime.partSeconds),
                        [self dateFromNetworkTime:&ntpClientRecvTime]];

    return prettyString;
}

- (NSString *) prettyPrintTimers {
    NSMutableString *   prettyString = [NSMutableString stringWithFormat:@"prettyPrintTimers\n\n"];

    [prettyString appendFormat:@"time server addr: [%@]\n"
                                " round trip time: %5.3f (mS)\n     server time: %5.3f (mS)\n"
                                "    network time: %5.3f (mS)\n    clock offset: %5.3f (mS)\n\n",
          server, el_time * 1000.0, st_time * 1000.0, (el_time-st_time) * 1000.0, offset * 1000.0];

    return prettyString;
}

- (NSString *) description {
    return [NSString stringWithFormat:@"[%@] stratum=%i; offset=%3.1f±%3.1fmS",
            server, stratum, offset *1000.0, dispersion];
}

@end


/* ----------------------------------------------------------------------------------------------------
 NTP_Logging(@"Read SUCCESS: [%@] clock offset: %5.3fs±%5.3fmS (%5.3f,%5.3f,%5.3f))", server, offset, dispersion, (offset-offset2)*1000.0, (offset-offset3)*1000.0, (offset-offset4)*1000.0);

 NTP_Logging(@"Read SUCCESS: [%@] (%i : %3.1fs))", server, stratum, - [[self  dateFromNetworkTime:&ntpServerBaseTime] timeIntervalSinceNow]);

 NTP_Logging(@"Read SUCCESS: [%@] clock offset: %5.3fs±%5.3fmS", server, offset, dispersion);

 NTP_Logging(@"Read SUCCESS: [%@] - %@ - offset: %5.3fs±%5.3fmS (%i - %i/%i)", server, trusty ? @"GOOD" : @"FAIL", offset, dispersion, [fifoQueue count], answerCount, trustyCount);
*/
