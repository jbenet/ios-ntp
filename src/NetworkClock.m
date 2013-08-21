/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║  NetworkClock.m                                                                                  ║
  ║                                                                                                  ║
  ║  Created by Gavin Eadie on Oct17/10                                                              ║
  ║  Copyright 2010 Ramsay Consulting. All rights reserved.                                          ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <netinet/in.h>
#import "NetworkClock.h"

@interface NetworkClock (PrivateMethods)

- (void) offsetAverage;

- (NSString *) hostAddress:(struct sockaddr_in *) sockAddr;

- (void) associationTrue:(NSNotification *) notification;
- (void) associationFake:(NSNotification *) notification;

- (void) applicationBack:(NSNotification *) notification;
- (void) applicationFore:(NSNotification *) notification;

@end

#pragma mark -
#pragma mark                        N E T W O R K • C L O C K

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ NetworkClock is a singleton class which will provide the best estimate of the difference in time ┃
  ┃ between the device's system clock and the time returned by a collection of time servers.         ┃
  ┃                                                                                                  ┃
  ┃ The method <networkTime> returns an NSDate with the network time.                                ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

@implementation NetworkClock

+ (id)sharedNetworkClock {
    static id sharedNetworkClockInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedNetworkClockInstance = [[self alloc] init];
    });
    return sharedNetworkClockInstance;
}

- (id) init {
    if (!(self = [super init])) return nil;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Prepare a sort-descriptor to sort associations based on their dispersion, and then create an     │
  │ array of empty associations to use ...                                                           │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    dispersionSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dispersion" ascending:YES];
    sortDescriptors = [[NSArray arrayWithObject:dispersionSortDescriptor] retain];
    timeAssociations = [[NSMutableArray arrayWithCapacity:48] retain];

    associationDelegateQueue = dispatch_queue_create("org.ios-ntp.delegates", 0);
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ .. and fill that array with the time hosts obtained from "ntp.hosts" ..                          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [self createAssociations];                  
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ prepare to catch our application entering and leaving the background ..                          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBack:)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationFore:)
												 name:UIApplicationWillEnterForegroundNotification
											   object:nil];
    return self;
}

- (void)dealloc {
    [self finishAssociations];
    dispatch_release(associationDelegateQueue);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ be called very frequently, we recompute the average offset every 30 seconds.                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) offsetAverage {
    timeIntervalSinceDeviceTime = 0.0;

    short       assocsTotal = [timeAssociations count];
    if (assocsTotal == 0) return;

    NSArray *   sortedArray = [timeAssociations sortedArrayUsingDescriptors:sortDescriptors];
    short       usefulCount = 0;

    for (NetAssociation * timeAssociation in sortedArray) {
        if (timeAssociation.trusty) {
            usefulCount++;
            timeIntervalSinceDeviceTime += timeAssociation.offset;
        }
        if (usefulCount == 8) break;                // use 8 best dispersions
    }

    if (usefulCount > 0) {
        timeIntervalSinceDeviceTime /= usefulCount;
    }
//###ADDITION?
  if (usefulCount ==8)
  {
    //stop it for now
    //
//    [self finishAssociations];
  }
//###
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Return the device clock time adjusted for the offset to network-derived UTC.  Since this could   ┃
  ┃ be called very frequently, we recompute the average offset every 30 seconds.                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (NSDate *) networkTime {
    return [[NSDate date] dateByAddingTimeInterval:-timeIntervalSinceDeviceTime];

    //[[NSNotificationCenter defaultCenter] postNotificationName:@"net-time" object:self];

}

#pragma mark                        I n t e r n a l  •  M e t h o d s

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Read the "ntp.hosts" file from the resources and derive all the IP addresses they refer to,      ┃
  ┃ remove any duplicates and create an 'association' for each one (individual host clients).        ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) createAssociations {
    NSString *  filePath = [[NSBundle mainBundle] pathForResource:@"ntp.hosts" ofType:@""];

    NSString *  fileData = [[NSString alloc] initWithData:[[NSFileManager defaultManager]
                                                           contentsAtPath:filePath]
                                                 encoding:NSUTF8StringEncoding];

    NSArray *   ntpDomains = [fileData componentsSeparatedByCharactersInSet:
                                                                [NSCharacterSet newlineCharacterSet]];
    [fileData release];

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  for each NTP service domain name in the 'ntp.hosts' file : "0.pool.ntp.org" etc ...             │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    for (NSString * ntpDomainName in ntpDomains) {
        if ([ntpDomainName length] == 0 ||
            [ntpDomainName characterAtIndex:0] == ' ' || [ntpDomainName characterAtIndex:0] == '#') {
            continue;
        }
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  ... start an 'association' (network clock object) for each address.                             │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        NetAssociation* timeAssociation = [[NetAssociation alloc] initWithServerName:ntpDomainName queue:associationDelegateQueue];
        [timeAssociations addObject:timeAssociation];
        [timeAssociation release];
    }

    // Enable associations.
    [self enableAssociations];
}

- (void) enableAssociations {
    [timeAssociations makeObjectsPerformSelector:@selector(enable)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(associationTrue:) name:@"assoc-good" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(associationFake:) name:@"assoc-fail" object:nil];
}

- (void) reportAssociations {

}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Stop all the individual ntp clients ..                                                           ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) finishAssociations {
    [timeAssociations makeObjectsPerformSelector:@selector(finish)];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"assoc-good" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"assoc-fail" object:nil];
}

#import <arpa/inet.h>

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ ... obtain IP address, "xx.xx.xx.xx", from the sockaddr structure ...                            ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (NSString *) hostAddress:(struct sockaddr_in *) sockAddr {
  char addrBuf[INET_ADDRSTRLEN];

  if (inet_ntop(AF_INET, &sockAddr->sin_addr, addrBuf, sizeof(addrBuf)) == NULL) {
    [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot convert address to string."];
  }

  return [NSString stringWithCString:addrBuf encoding:NSASCIIStringEncoding];
}

#pragma mark                        N o t i f i c a t i o n • T r a p s

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ associationTrue -- notification from a 'truechimer' association of a trusty offset               ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) associationTrue:(NSNotification *) notification {
    NTP_Logging(@"*** true association: %@ (%i left)",
                    [notification object], [timeAssociations count]);
    [self offsetAverage];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ associationFake -- notification from an association that became a 'falseticker'                  ┃
  ┃ .. if we already have 8 associations in play, drop this one.                                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) associationFake:(NSNotification *) notification {
    if ([timeAssociations count] > 8) {
        NetAssociation *    association = [notification object];
        NTP_Logging(@"*** false association: %@ (%i left)", association, [timeAssociations count]);
        [timeAssociations removeObject:association];
        [association finish];
        association = nil;
    }
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ applicationBack -- catch the notification when the application goes into the background          ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) applicationBack:(NSNotification *) notification {
    LogInProduction(@"*** application -> Background");
    [self finishAssociations];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ applicationFore -- catch the notification when the application comes out of the background       ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) applicationFore:(NSNotification *) notification {
    LogInProduction(@"*** application -> Foreground");
    [self enableAssociations];
}

@end