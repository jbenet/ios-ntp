/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║  NetworkClock.m                                                                                  ║
  ║                                                                                                  ║
  ║  Created by Gavin Eadie on Oct17/10                                                              ║
  ║  Copyright 2010 Ramsay Consulting. All rights reserved.                                          ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import "NetworkClock.h"

@interface NetworkClock (PrivateMethods)

- (NSString *) hostAddress:(struct sockaddr_in *) sockAddr;

@end

#pragma mark -
#pragma mark N E T W O R K • C L O C K

@implementation NetworkClock

- (id) init {
    if (nil == [super init]) return nil;
    
    timeAssociations = [[NSMutableArray arrayWithCapacity:48] retain];
    timeIntervalSinceDeviceTime = 0.0;
    
    return self;
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Scan the associations and get the best time offset, then return adjusted time                    ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (NSDate *) networkTime {
    short       usefulCount = 0;
    timeIntervalSinceDeviceTime = 0.0;

    for (NetAssociation * timeAssociation in timeAssociations) {
        if (timeAssociation.useful) {
            usefulCount++;
            timeIntervalSinceDeviceTime += timeAssociation.offset;
        }
    }
    
    if (usefulCount == 0)
        NSLog(@"no useful associations");
    else {
        timeIntervalSinceDeviceTime /= usefulCount;
    }

    return [[NSDate date] dateByAddingTimeInterval:-timeIntervalSinceDeviceTime];
}

#pragma mark I n t e r n a l  •  M e t h o d s

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Read the "ntp.hosts" file from the resources and derive all the IP addresses they refer to,      ┃
  ┃ remove any duplicates and create an 'association' for each one (individual host clients).        ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) loadAssociations {
    NSString *  filePath = [[NSBundle mainBundle] pathForResource:@"ntp.hosts" ofType:@""];
    
    NSString *  fileData = [[NSString alloc] initWithData:[[NSFileManager defaultManager] 
                                                           contentsAtPath:filePath] 
                                                 encoding:NSUTF8StringEncoding];
    
    NSArray *   ntpDomains = [[fileData stringByReplacingOccurrencesOfString:@"\r"
                                                                  withString:@""]
                              componentsSeparatedByString:@"\n"];
    [fileData release];
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  for each NTP service domain name in the 'ntp.hosts' file ...                                    │
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
  │  ... resolve the IP address of the named host ("0.pool.ntp.org" --> [123.45.67.89], ...)         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        CFHostRef ntpHostName = CFHostCreateWithName (kCFAllocatorDefault, (CFStringRef)ntpDomainName);
        if (ntpHostName == nil) {
            NSLog(@"CFHostCreateWithName ntpHost <nil>");
            continue;                                           // couldn't create 'host object' ...
        }
        
        if (!CFHostStartInfoResolution (ntpHostName, kCFHostAddresses, &nameError)) {
            NSLog(@"CFHostStartInfoResolution error %d", nameError.error);
            CFRelease(ntpHostName);
            continue;                                           // couldn't start resolution ...
        }

        CFArrayRef ntpHostAddrs = CFHostGetAddressing (ntpHostName, &nameFound);

        if (!nameFound) {
            NSLog(@"CFHostGetAddressing: NOT resolved");
            CFRelease(ntpHostName);
            continue;                                           // resolution failed ...
        }
        
        if (ntpHostAddrs == nil) {
            CFRelease(ntpHostName);
            continue;                                           // NO addresses were resolved
        }
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  for each (sockaddr structure wrapped by a CFDataRef/NSData *) associated with the hostname,     │
  │  drop the address into a Set to remove duplicates.                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
        for (NSData * ntpHost in (NSArray *)ntpHostAddrs) {
            [hostAddresses addObject:[self hostAddress:(struct sockaddr_in *)[ntpHost bytes]]];
        }
        CFRelease(ntpHostName);
    }
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  ... now start an 'association' (network clock object) for each address.                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    for (NSString * server in hostAddresses) {
        NetAssociation *    timeAssociation = [[NetAssociation alloc] init];
        timeAssociation.server = server;
        
        [timeAssociations addObject:timeAssociation];
        [timeAssociation start];                                // starts are randomized internally
    }
    [hostAddresses release];
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ Stop all the individual ntp clients ..                                                           ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void) stopAssociations {
    for (NetAssociation * timeAssociation in timeAssociations) {
        [timeAssociation stop];
    }
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

#import "SynthesizeSingleton.h"

#pragma mark -
#pragma mark S I N G L E T O N • B E H A V I O U R

SYNTHESIZE_SINGLETON_FOR_CLASS(NetworkClock);

@end
