/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetAssociation.m                                                                                 ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Nov03/10                                                               ║
  ║ Copyright 2010 Ramsay Consulting. All rights reserved.                                           ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "NetAssociation.h"

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ This object manages the communication and time calculations for one server association           ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

@interface NetAssociation (PrivateMethods)

- (void) queryTimeServer:(NSTimer *) timer;

- (NSString *) prettyPrintPacket;
- (NSString *) prettyPrintTimers;

- (NSDate *) dateFromNTP:(struct ntpTimestamp *) networkTime;

- (void) evaluatePacket;

@end

#pragma mark -
#pragma mark N E T W O R K • A S S O C I A T I O N

@implementation NetAssociation

@synthesize trusty, server, offset;

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Initialize the association with a blank socket and prepare the first time transaction to happen  ┃
  ┃ between 1 and 10 seconds from now .. random timing avoids the burst of network traffic expected  ┃
  ┃ if all the associations fired at the same time ...                                               ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (id) init {
    if ((self = [super init]) == nil) return nil;
    
    timeBetweenQueries = 20.0;                  // initial frequency of requests
    trusty = FALSE;                             // don't trust this clock to start with ...
    offset = 0.0;                               // start with clock on time (no offset)
    socket = [[AsyncUdpSocket alloc] initIPv4];
    [socket setDelegate:self];

    fifoQueue = [[NSMutableArray arrayWithCapacity:8] retain];
    answerCount = trustyCount = 0;
    
    repeatingTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:
                                                                            (1.0 + random()%900/90.0)]
                                              interval:timeBetweenQueries
                                                target:self 
                                              selector:@selector(queryTimeServer:)
                                              userInfo:nil 
                                               repeats:YES];
    
    return self;
}

- (void) enable {
    NSLog(@"association start: [%@]", server);
    
    [[NSRunLoop currentRunLoop] addTimer:repeatingTimer forMode:NSDefaultRunLoopMode];
    [repeatingTimer release];
}

- (void) finish {
    [repeatingTimer invalidate];
    repeatingTimer = nil;
}

#pragma mark T i m e • C o n v e r t e r s

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

static struct ntpTimestamp NTP_1970 = {0x83aa7e80, 0};

NSTimeInterval timeIntervalFromNetworkTime(struct ntpTimestamp * networkTime) {
    return ntpDiffSeconds(&NTP_1970, networkTime);
}

- (NSDate *) dateFromNTP:(struct ntpTimestamp *) networkTime {
    return [NSDate dateWithTimeIntervalSince1970:timeIntervalFromNetworkTime(&ntpServerBaseTime)];
}

#pragma mark N e t w o r k • T r a n s a c t i o n s

- (NSData *) createPacket {
	uint32_t        wireData[12];
    
	memset(wireData, 0, sizeof wireData);
	wireData[0] = htonl((0 << 30) | (3 << 27) | (3 << 24) | (0 << 16) | (4 << 8) | (-6 & 0xff));
	wireData[1] = htonl(1<<16);
	wireData[2] = htonl(1<<16);
    
    struct timeval  now;
	gettimeofday(&now, NULL);
    
	wireData[10] = htonl(now.tv_sec + JAN_1970);            // 1970 - 1900 in seconds
	wireData[11] = htonl(uSec2Frac(now.tv_usec));
    
    return [NSData dataWithBytes:wireData length:48];
}

- (void) evaluatePacket {
    trusty = (dispersion > 0.1 && dispersion < 50.0) && 
             (-[[self dateFromNTP:&ntpServerBaseTime] timeIntervalSinceNow] < 6.0 * 3600.0) &&
             (stratum > 0) && (mode == 4);
    
    if (trusty) {
        trustyCount++;
        
        el_time=ntpDiffSeconds(&ntpClientSendTime, &ntpClientRecvTime);     // .. (T4-T1)
        st_time=ntpDiffSeconds(&ntpServerRecvTime, &ntpServerSendTime);     // .. (T3-T2)
        skew1 = ntpDiffSeconds(&ntpServerSendTime, &ntpClientRecvTime);     // .. (T2-T1)
        skew2 = ntpDiffSeconds(&ntpServerRecvTime, &ntpClientSendTime);     // .. (T3-T4)
        
        if ([fifoQueue count] == 8) {
            [fifoQueue removeObjectAtIndex:0];
        }
        [fifoQueue addObject:[NSNumber numberWithDouble:(skew1+skew2)/2.0]];
        
        offset = [[fifoQueue valueForKeyPath:@"@avg.doubleValue"] doubleValue];
    //  [[NSNotificationCenter defaultCenter] postNotificationName:@"assoc-good" object:self];
    }
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ look at the collection of association's offsets and make some determination of their worth       │
  │   .. if we have four or more times and they average zero, we're not getting replies              │
  │   .. if we're not 'trusty' for more than half the queries, the server is wonky                   │
  │         tell anyone who cares that we're out of the game ...                                     │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    if (answerCount > 4 && fabs(offset) < 1.e-6 || (trustyCount > 0 && answerCount/trustyCount > 1))
        [[NSNotificationCenter defaultCenter] postNotificationName:@"assoc-fail" object:self];
    
/*────────────────────────────────────────────────────────────────────────────────────────────────────
    NSLog(@"Read data SUCCESS: [%@] clock offset: %5.3fs±%5.3fmS (%5.3f,%5.3f,%5.3f))", 
            server, offset, dispersion, 
            (offset-offset2)*1000.0, (offset-offset3)*1000.0, (offset-offset4)*1000.0);
     
    NSLog(@"Read data SUCCESS: [%@] (%i : %3.1fs))", server, stratum,
        - [[self dateFromNTP:&ntpServerBaseTime] timeIntervalSinceNow]);
     
    NSLog(@"Read data SUCCESS: [%@] clock offset: %5.3fs±%5.3fmS", server, offset, dispersion);
    
    NSLog(@"Read data SUCCESS: [%@] - %@ - offset: %5.3fs±%5.3fmS (%i - %i/%i)", 
          server, trusty ? @"GOOD" : @"FAIL", offset, dispersion, 
          [fifoQueue count], answerCount, trustyCount);
  └───────────────────────────────────────────────────────────────────────────────────────────────────*/
}

- (void) queryTimeServer:(NSTimer *) timer {
    [socket receiveWithTimeout:2.0 tag:0];
    
    if ([socket sendData:[self createPacket] toHost:server port:123L withTimeout:2.0 tag:0]) {

    }
    else {
        NSLog(@"Immediate FAILURE: [%@]", server);
    }
    
    [timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:timeBetweenQueries]];
}

#pragma mark N e t w o r k • C a l l b a c k s

- (void) onUdpSocket:(AsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
}

- (void) onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag 
          dueToError:(NSError *)error {
    NSLog(@"Send data FAILURE: [%@] %@", server, [error localizedDescription]); 
}

- (BOOL) onUdpSocket:(AsyncUdpSocket *)sender didReceiveData:(NSData *)data 
             withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port {
        
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  grab the packet arrival time as fast as possible, before computations below ...                 │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval          arrival_time;
	gettimeofday(&arrival_time, NULL);
    
    ntpClientRecvTime.fullSeconds = arrival_time.tv_sec + JAN_1970;    /* Transmit Timestamp coarse */
	ntpClientRecvTime.partSeconds = uSec2Frac(arrival_time.tv_usec);   /* Transmit Timestamp fine   */
    
    uint32_t                hostData[12];
    [data getBytes:hostData length:48];
    
	li      = ntohl(hostData[0]) >> 30 & 0x03;
	vn      = ntohl(hostData[0]) >> 27 & 0x07;
	mode    = ntohl(hostData[0]) >> 24 & 0x07;
	stratum = ntohl(hostData[0]) >> 16 & 0xff;
	poll    = ntohl(hostData[0]) >>  8 & 0xff;
	prec    = ntohl(hostData[0])       & 0xff;
	if (prec & 0x80) prec|=0xffffff00;
    root_delay = ntohl(hostData[1]) * 0.0152587890625;
    dispersion = ntohl(hostData[2]) * 0.0152587890625;    
	refid   = ntohl(hostData[3]);

	ntpServerBaseTime.fullSeconds = ntohl(hostData[4]);
	ntpServerBaseTime.partSeconds = ntohl(hostData[5]);
	ntpClientSendTime.fullSeconds = ntohl(hostData[6]);
	ntpClientSendTime.partSeconds = ntohl(hostData[7]);
	ntpServerRecvTime.fullSeconds = ntohl(hostData[8]);
	ntpServerRecvTime.partSeconds = ntohl(hostData[9]);
	ntpServerSendTime.fullSeconds = ntohl(hostData[10]);
	ntpServerSendTime.partSeconds = ntohl(hostData[11]);
    
    answerCount++;
    [self evaluatePacket];
    
    return YES;
}

- (void) onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag 
          dueToError:(NSError *)error {
    NSLog(@"Read data FAILURE: [%@] %@", server, [error localizedDescription]);
}

- (void) onUdpSocketDidClose:(AsyncUdpSocket *) sock  {
    NSLog(@"Socket closed : [%@]", server); 
}

#pragma mark P r e t t y P r i n t e r s

- (NSString *) prettyPrintPacket {
    NSMutableString *   prettyString = [NSMutableString stringWithFormat:@"prettyPrintPacket\n\n"];

    [prettyString appendFormat:@"  leap indicator: %3d\n"
                                "  version number: %3d\n"
                                "   protocol mode: %3d\n"
                                "         stratum: %3d\n"
                                "   poll interval: %3d\n"
                                "   precision exp: %3d\n\n",
     li, vn, mode, stratum, poll, prec];
    
    [prettyString appendFormat:@"      root delay: %7.3f (mS)\n"
                                "      dispersion: %7.3f (mS)\n"
                                "    reference ID: %3u.%u.%u.%u\n\n",
     root_delay, dispersion, refid>>24&0xff, refid>>16&0xff, refid>>8&0xff, refid&0xff];
    
    [prettyString appendFormat:@"  clock last set: %u.%.6u\n",   
     ntpServerBaseTime.fullSeconds, Frac2uSec(ntpServerBaseTime.partSeconds)];
    [prettyString appendFormat:@"client send time: %u.%.6u\n",
     ntpClientSendTime.fullSeconds, Frac2uSec(ntpClientSendTime.partSeconds)];
    [prettyString appendFormat:@"server recv time: %u.%.6u\n",   
     ntpServerRecvTime.fullSeconds, Frac2uSec(ntpServerRecvTime.partSeconds)];
    [prettyString appendFormat:@"server send time: %u.%.6u\n",   
     ntpServerSendTime.fullSeconds, Frac2uSec(ntpServerSendTime.partSeconds)];
    [prettyString appendFormat:@"client recv time: %u.%.6u\n\n",   
     ntpClientRecvTime.fullSeconds, Frac2uSec(ntpClientRecvTime.partSeconds)];
    
    return prettyString;
}

- (NSString *) prettyPrintTimers {
    NSMutableString *   prettyString = [NSMutableString stringWithFormat:@"prettyPrintTimers\n\n"];

    [prettyString appendFormat:@"time server addr: [%@]\n"
                                " round trip time: %5.3f (mS)\n"
                                "     server time: %5.3f (mS)\n"
                                "    network time: %5.3f (mS)\n"
                                "    clock offset: %5.3f (mS)\n\n", 
          server, el_time * 1000.0, st_time * 1000.0, (el_time-st_time) * 1000.0, offset * 1000.0];
    
    return prettyString;
}

- (NSString *) description {
    return [NSString stringWithFormat:@"[%@] %5.3f mS", server, offset];
}
@end