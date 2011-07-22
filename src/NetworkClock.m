/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║  NetworkClock.m                                                                                  ║
  ║                                                                                                  ║
  ║  Created by Gavin Eadie on Oct17/10                                                              ║
  ║  Copyright 2010 Ramsay Consulting. All rights reserved.                                          ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

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

- (id) init {
    if (nil == [super init]) return nil;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Prepare a sort-descriptor to sort associations based on their dispersion, and then create an     │
  │ array of empty associations to use ...                                                           │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    dispersionSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dispersion" ascending:YES];
    sortDescriptors = [[NSArray arrayWithObject:dispersionSortDescriptor] retain];
    timeAssociations = [[NSMutableArray arrayWithCapacity:48] retain];
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ .. and fill that array with the time hosts obtained from "ntp.hosts" ..                          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
#ifdef THREADING_DOESNT_WORK_SO_DONT_TRY_IT
    [[NSOperationQueue alloc] init] addOperation:[[NSInvocationOperation alloc]
                                                  initWithTarget:self
                                                        selector:@selector(createAssociations)
                                                          object:nil];
#else
    [self createAssociations];                  // this delays here, would be good to thread this ..
#endif
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
//		[self finishAssociations];
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
    NSMutableSet *          hostAddresses = [[NSMutableSet setWithCapacity:48] retain];

    for (NSString * ntpDomainName in ntpDomains) {
        if ([ntpDomainName length] == 0 ||
            [ntpDomainName characterAtIndex:0] == ' ' || [ntpDomainName characterAtIndex:0] == '#') {
            continue;
        }
        CFStreamError       nameError;
        Boolean             nameFound;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  ... resolve the IP address of the named host : "0.pool.ntp.org" --> [123.45.67.89], ...         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        CFHostRef ntpHostName = CFHostCreateWithName (kCFAllocatorDefault, (CFStringRef)ntpDomainName);
        if (ntpHostName == nil) {
            LogInProduction(@"CFHostCreateWithName ntpHost <nil>");
            continue;                                           // couldn't create 'host object' ...
        }

        if (!CFHostStartInfoResolution (ntpHostName, kCFHostAddresses, &nameError)) {
            LogInProduction(@"CFHostStartInfoResolution error %li", nameError.error);
            CFRelease(ntpHostName);
            continue;                                           // couldn't start resolution ...
        }

        CFArrayRef ntpHostAddrs = CFHostGetAddressing (ntpHostName, &nameFound);

        if (!nameFound) {
            LogInProduction(@"CFHostGetAddressing: NOT resolved");
            CFRelease(ntpHostName);
            continue;                                           // resolution failed ...
        }

        if (ntpHostAddrs == nil) {
            LogInProduction(@"CFHostGetAddressing: no addresses resolved");
            CFRelease(ntpHostName);
            continue;                                           // NO addresses were resolved ...
        }
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  for each (sockaddr structure wrapped by a CFDataRef/NSData *) associated with the hostname,     │
  │  drop the IP address string into a Set to remove duplicates.                                     │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        for (NSData * ntpHost in (NSArray *)ntpHostAddrs) {
            [hostAddresses addObject:[self hostAddress:(struct sockaddr_in *)[ntpHost bytes]]];
        }
        CFRelease(ntpHostName);
    }
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  get ready to catch any notifications from associations ...                                      │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(associationTrue:)
                                                 name:@"assoc-good" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(associationFake:)
                                                 name:@"assoc-fail" object:nil];
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  ... now start an 'association' (network clock object) for each address.                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    for (NSString * server in hostAddresses) {
        NetAssociation *    timeAssociation = [[[NetAssociation alloc] init:server] autorelease];

        [timeAssociations addObject:timeAssociation];
        [timeAssociation enable];                               // starts are randomized internally
    }
    [hostAddresses release];
}

- (void) reportAssociations {

}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Stop all the individual ntp clients ..                                                           ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) finishAssociations {
    for (NetAssociation * timeAssociation in timeAssociations) {
        [timeAssociation finish];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
//  [self finishAssociations];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ applicationFore -- catch the notification when the application comes out of the background       ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) applicationFore:(NSNotification *) notification {
    LogInProduction(@"*** application -> Foreground");
//  [self enableAssociations];
}

#import "SynthesizeSingleton.h"

#pragma mark -
#pragma mark                        S I N G L E T O N • B E H A V I O U R

SYNTHESIZE_SINGLETON_FOR_CLASS(NetworkClock);

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ the SYNTHESIZE_SINGLETON_FOR_CLASS macro expands thus:                                           ┃
  ┃──────────────────────────────────────────────────────────────────────────────────────────────────┃
  ┃                                                                                                  ┃
  ┃         static Singleton *sharedSingleton = ((void*)0);                                          ┃
  ┃                                                                                                  ┃
  ┃         + (Singleton *)sharedSingleton {                                                         ┃
  ┃             @synchronized(self) {                                                                ┃
  ┃                 if (sharedSingleton == ((void*)0)) {                                             ┃
  ┃                     sharedSingleton = [[self alloc] init];                                       ┃
  ┃                 }                                                                                ┃
  ┃             }                                                                                    ┃
  ┃             return sharedSingleton;                                                              ┃
  ┃         }                                                                                        ┃
  ┃                                                                                                  ┃
  ┃         + (id)allocWithZone:(NSZone *)zone {                                                     ┃
  ┃             @synchronized(self) {                                                                ┃
  ┃                 if (sharedSingleton == ((void*)0)) {                                             ┃
  ┃                     sharedSingleton = [super allocWithZone:zone];                                ┃
  ┃                     return sharedSingleton;                                                      ┃
  ┃                 }                                                                                ┃
  ┃             }                                                                                    ┃
  ┃             return ((void*)0);                                                                   ┃
  ┃         }                                                                                        ┃
  ┃                                                                                                  ┃
  ┃         - (id)copyWithZone:(NSZone *)zone {                                                      ┃
  ┃             return self;                                                                         ┃
  ┃         }                                                                                        ┃
  ┃                                                                                                  ┃
  ┃         - (id)retain {                                                                           ┃
  ┃             return self;                                                                         ┃
  ┃         }                                                                                        ┃
  ┃                                                                                                  ┃
  ┃         - (NSUInteger)retainCount {                                                              ┃
  ┃             return (2147483647L *2UL +1UL);                                                      ┃
  ┃         }                                                                                        ┃
  ┃                                                                                                  ┃
  ┃         - (void)release {                                                                        ┃
  ┃         }                                                                                        ┃
  ┃                                                                                                  ┃
  ┃         - (id)autorelease {                                                                      ┃
  ┃             return self;                                                                         ┃
  ┃         };                                                                                       ┃
  ┃                                                                                                  ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

@end