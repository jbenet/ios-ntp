/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ NetworkClock.m                                                                                   ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Oct17/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <CFNetwork/CFNetwork.h>

#import "NetworkClock.h"
#import "NetAssociation.h"

#import <UIKit/UIApplication.h>

@interface NetworkClock () {

    NSTimeInterval          timeIntervalSinceDeviceTime;
    NSMutableArray *        timeAssociations;
    NSArray *               sortDescriptors;

}

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

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Return the device clock time adjusted for the offset to network-derived UTC.  Since this could   ┃
  ┃ be called very frequently, we recompute the average offset every 30 seconds.                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (NSDate *) networkTime {
    return [[NSDate date] dateByAddingTimeInterval:-timeIntervalSinceDeviceTime];
}

#pragma mark -
#pragma mark                        I n t e r n a l  •  M e t h o d s

- (id) init {
    if (!(self = [super init])) return nil;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Prepare a sort-descriptor to sort associations based on their dispersion, and then create an     │
  │ array of empty associations to use ...                                                           │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"dispersion" ascending:YES]];
    timeAssociations = [NSMutableArray arrayWithCapacity:64];
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ .. and fill that array with the time hosts obtained from "ntp.hosts" ..                          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[[NSOperationQueue alloc] init] addOperation:[[NSInvocationOperation alloc]
                                                  initWithTarget:self
                                                        selector:@selector(createAssociations)
                                                          object:nil]];
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ applicationBack -- catch the notification when the application goes into the background          │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil queue:nil
                                                  usingBlock:^(NSNotification * note)
     {
         NTP_Logging(@"Application -> Background");
         [self finishAssociations];
     }];

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ applicationFore -- catch the notification when the application comes out of the background       │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil queue:nil
                                                  usingBlock:^(NSNotification * note)
     {
         NTP_Logging(@"Application -> Foreground");
//       [self enableAssociations];
     }];

    return self;
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Read the "ntp.hosts" file from the resources and derive all the IP addresses they refer to,      ┃
  ┃ remove any duplicates and create an 'association' for each one (individual host clients).        ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) createAssociations {
    NSArray *           ntpDomains;
    NSString *          filePath = [[NSBundle mainBundle] pathForResource:@"ntp.hosts" ofType:@""];
    if (nil == filePath) {
        ntpDomains = @[@"0.pool.ntp.org", @"1.pool.ntp.org", @"2.pool.ntp.org", @"3.pool.ntp.org",
                       @"0.US.pool.ntp.org", @"1.US.pool.ntp.org", @"2.US.pool.ntp.org", @"3.US.pool.ntp.org",
                       @"asia.pool.ntp.org", @"europe.pool.ntp.org",
                       @"north-america.pool.ntp.org", @"south-america.pool.ntp.org", @"oceania.pool.ntp.org",
                       @"time.apple.com"];
    }
    else {
        NSString *      fileData = [[NSString alloc] initWithData:[[NSFileManager defaultManager]
                                                                   contentsAtPath:filePath]
                                                         encoding:NSUTF8StringEncoding];

        ntpDomains = [fileData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  for each NTP service domain name in the 'ntp.hosts' file : "0.pool.ntp.org" etc ...             │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    NSMutableSet *      hostAddresses = [NSMutableSet setWithCapacity:64];

    for (NSString * ntpDomainName in ntpDomains) {
        if ([ntpDomainName length] == 0 ||
            [ntpDomainName characterAtIndex:0] == ' ' ||
            [ntpDomainName characterAtIndex:0] == '#') {
            continue;
        }

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  ... resolve the IP address of the named host : "0.pool.ntp.org" --> [123.45.67.89], ...         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        CFHostRef ntpHostName = CFHostCreateWithName (nil, (__bridge CFStringRef)ntpDomainName);
        if (nil == ntpHostName) {
            NTP_Logging(@"CFHostCreateWithName ntpHost <nil>");
            continue;                                           // couldn't create 'host object' ...
        }

        CFStreamError   nameError;
        if (!CFHostStartInfoResolution (ntpHostName, kCFHostAddresses, &nameError)) {
            NTP_Logging(@"CFHostStartInfoResolution error %li", nameError.error);
            CFRelease(ntpHostName);
            continue;                                           // couldn't start resolution ...
        }

        Boolean         nameFound;
        CFArrayRef      ntpHostAddrs = CFHostGetAddressing (ntpHostName, &nameFound);

        if (!nameFound) {
            NTP_Logging(@"CFHostGetAddressing: NOT resolved");
            CFRelease(ntpHostName);
            continue;                                           // resolution failed ...
        }

        if (ntpHostAddrs == nil) {
            NTP_Logging(@"CFHostGetAddressing: no addresses resolved");
            CFRelease(ntpHostName);
            continue;                                           // NO addresses were resolved ...
        }
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  for each (sockaddr structure wrapped by a CFDataRef/NSData *) associated with the hostname,     │
  │  drop the IP address string into a Set to remove duplicates.                                     │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        for (NSData * ntpHost in (__bridge NSArray *)ntpHostAddrs) {
            [hostAddresses addObject:[self hostAddress:(struct sockaddr_in *)[ntpHost bytes]]];
        }
        CFRelease(ntpHostName);
    }

    NTP_Logging(@"%@", hostAddresses);

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ associationTrue -- notification from a 'truechimer' association of a trusty offset               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserverForName:@"assoc-good" object:nil queue:nil
                                                  usingBlock:^(NSNotification *note)
    {
        NTP_Logging(@"*** true association: %@ (%i left)", [note object], [timeAssociations count]);
        [self offsetAverage];
    }];

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ associationFake -- notification from an association that became a 'falseticker'                  │
  │ .. if we already have 8 associations in play, drop this one.                                     │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    [[NSNotificationCenter defaultCenter] addObserverForName:@"assoc-fail" object:nil queue:nil
                                                  usingBlock:^(NSNotification *note)
    {
        if ([timeAssociations count] > 8) {
            NetAssociation *    association = [note object];
            NTP_Logging(@"*** false association: %@ (%i left)", association, [timeAssociations count]);
            [timeAssociations removeObject:association];
            [association finish];
            association = nil;
        }
    }];

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  ... now start an 'association' (network clock object) for each address.                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    for (NSString * server in hostAddresses) {
        NetAssociation *    timeAssociation = [[NetAssociation alloc] init:server];

        [timeAssociations addObject:timeAssociation];
        [timeAssociation enable];                               // starts are randomized internally
    }
}

- (void) enableAssociations {

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

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ be called very frequently, we recompute the average offset every 30 seconds.                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) offsetAverage {
    if ([timeAssociations count] == 0) return;

    timeIntervalSinceDeviceTime = 0.0;
    NSArray *       sortedArray = [timeAssociations sortedArrayUsingDescriptors:sortDescriptors];
    short           usefulCount = 0;

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

    return @(addrBuf);
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
    NTP_Logging(@"*** application -> Background");
    [self finishAssociations];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ applicationFore -- catch the notification when the application comes out of the background       ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) applicationFore:(NSNotification *) notification {
    NTP_Logging(@"*** application -> Foreground");
    [self enableAssociations];
}

@end