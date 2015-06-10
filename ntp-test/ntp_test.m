//
//  ntp_test.m
//  ntp-test
//
//  Created by Gavin Eadie on 6/4/15.
//  Copyright (c) 2015 Ramsay Consulting. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <sys/time.h>

#define JAN_1970    		0x83aa7e80                      // UNIX epoch in NTP's epoch:
                                                            // 1970-1900 (2,208,988,800s)
struct ntpTimestamp {
    uint32_t      wholeSeconds;
    uint32_t      fractSeconds;
};

void ntp2unix(const struct ntpTimestamp * ntp, struct timeval * tv);
void unix2ntp(const struct timeval * tv, struct ntpTimestamp * ntp);
double ntpDiffSeconds(struct ntpTimestamp * start, struct ntpTimestamp * stop);
void ntp_time_now(struct ntpTimestamp * ntp);

@interface ntp_test : XCTestCase

@end

@implementation ntp_test

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConvert1 {
    struct ntpTimestamp     netStamp = {JAN_1970, 0};          // network time for 1 January 1970, GMT
    struct timeval          sysStamp;
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct ntpTimestamp     newStamp;
    unix2ntp(&sysStamp, &newStamp);
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%08x:%08x\n%08x:%08x\n", netStamp.wholeSeconds, netStamp.fractSeconds, newStamp.wholeSeconds, newStamp.fractSeconds);
    printf("%12.10f\n", tDiff);
    XCTAssert(fabs(tDiff) < 0.00001, @"Pass");
}

- (void)testConvert2 {
    struct ntpTimestamp     netStamp = {0x23aa7e80, 0};
    struct timeval          sysStamp;
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct ntpTimestamp     newStamp;
    unix2ntp(&sysStamp, &newStamp);
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(fabs(tDiff) < 1.0E-6, @"Pass");
}

- (void)testConvert3 {
    struct ntpTimestamp     netStamp = {0xa3aa7e80, 0};
    struct timeval          sysStamp;
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct ntpTimestamp     newStamp;
    unix2ntp(&sysStamp, &newStamp);
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(fabs(tDiff) < 1.0E-6, @"Pass");
}

- (void)testConvert4 {
    struct ntpTimestamp     netStamp = {JAN_1970, -1};          // network time for 1 January 1970, GMT
    struct timeval          sysStamp;
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct ntpTimestamp     newStamp;
    unix2ntp(&sysStamp, &newStamp);
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(fabs(tDiff) < 1.0E-6, @"Pass");
}

- (void)testConvert5 {
    struct ntpTimestamp     netStamp = {0x23aa7e80, -1};
    struct timeval          sysStamp;
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct ntpTimestamp     newStamp;
    unix2ntp(&sysStamp, &newStamp);
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(fabs(tDiff) < 1.0E-6, @"Pass");
}

- (void)testConvert6 {
    struct ntpTimestamp     netStamp = {0xa3aa7e80, -1};
    struct timeval          sysStamp;
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct ntpTimestamp     newStamp;
    unix2ntp(&sysStamp, &newStamp);
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(fabs(tDiff) < 1.0E-6, @"Pass");
}

- (void)testConvert7 {
    struct ntpTimestamp     netStamp = {JAN_1970, 0x80000000};
    struct ntpTimestamp     newStamp = {JAN_1970, 0};
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff+0.5 < 1.0E-6, @"Pass");
}

- (void)testConvert8 {
    struct ntpTimestamp     netStamp = {JAN_1970+1, 0};
    struct ntpTimestamp     newStamp = {JAN_1970, 0};
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff+1.0 < 1.0E-6, @"Pass");
}

- (void)testConvert9 {
    struct ntpTimestamp     netStamp = {JAN_1970, 0};
    struct ntpTimestamp     newStamp = {JAN_1970, 0x80000000};
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff-0.5 < 1.0E-6, @"Pass");
}

- (void)testConvert10 {
    struct ntpTimestamp     netStamp = {JAN_1970, 0};
    struct ntpTimestamp     newStamp = {JAN_1970+1, 0};
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff-1.0 < 1.0E-6, @"Pass");
}

- (void)testConvert11 {
    struct timeval          sysStamp;
    
    gettimeofday(&sysStamp, NULL);
    printf("%08lx:%08x\n", sysStamp.tv_sec, sysStamp.tv_usec);
    XCTAssert(true, @"Pass");
}

- (void)testPerformanceExample {
    [self measureBlock:^{
        struct ntpTimestamp time;
        ntp_time_now(&time);
    }];
}

@end
