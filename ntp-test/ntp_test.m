/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ ntp_test.m                                                                                       ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Jun04/15 ... Copyright 2010-16 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <XCTest/XCTest.h>
#import "NetAssociation.h"

@interface ntp_test : XCTestCase

@end

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
void ntp2unix(const union ntpTime * ntp, struct timeval * tv) {
    tv->tv_sec  = ntp->partials.wholeSeconds - JAN_1970;
    tv->tv_usec = (uint32_t)((double)ntp->partials.fractSeconds / (1LL<<32) * 1.0e6);
}

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ get (ntpTime2 - ntpTime1) in (double) seconds                                                    │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
double ntpDiffSecondsB(union ntpTime * start, union ntpTime * stop) {
    return (start->floating - stop->floating) / -4294967296.0;
}



@implementation ntp_test

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}



/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ TEST CONVERSIONS .. convert unix "zerotime" to ntp(32-bit,32-bit) format and back and compare .. ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void)testConvertA1 {
    union ntpTime       netStamp = {0, JAN_1970};           // network time for 1 January 1970, GMT
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval      sysStamp;
    ntp2unix(&netStamp, &sysStamp);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime       newStamp = unix2ntp(&sysStamp);

    printf("Start with ntp(32-bit,32-bit) .. convert to unix .. convert back to ntp and compare ..\n");
    printf("             ntp:         %08x:%08x (%016llx)\n",
           netStamp.partials.wholeSeconds, netStamp.partials.fractSeconds, netStamp.floating);
    printf("       ntp->unix: %016lx:%08x\n", sysStamp.tv_sec,       sysStamp.tv_usec);
    printf("  ntp->unix->ntp:         %08x:%08x (%016llx)\n",
           newStamp.partials.wholeSeconds, newStamp.partials.fractSeconds, newStamp.floating);

    double              tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);

    XCTAssert(fabs(tDiff) < 0.000001, @"Pass");
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ TEST CONVERSIONS .. convert unix "zerotime" to ntp(64-bit) format and back and compare ..        ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void)testConvertA2 {
    union ntpTime       netStamp;
    netStamp.floating = JAN_1970 << 32;                     // network time for 1 January 1970, GMT
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval      sysStamp;
    ntp2unix(&netStamp, &sysStamp);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime       newStamp = unix2ntp(&sysStamp);

    printf("Start with ntp(64-bit) .. convert to unix() .. convert back and compare ..\n");
    printf("             ntp:         %08x:%08x (%016llx)\n",
           netStamp.partials.wholeSeconds, netStamp.partials.fractSeconds, netStamp.floating);
    printf("       ntp->unix: %016lx:%08x\n", sysStamp.tv_sec,       sysStamp.tv_usec);
    printf("  ntp->unix->ntp:         %08x:%08x (%016llx)\n",
           newStamp.partials.wholeSeconds, newStamp.partials.fractSeconds, newStamp.floating);

    double              tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);

    XCTAssert(fabs(tDiff) < 0.000001, @"Pass");             // pass if < 1μS
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ TEST CONVERSIONS .. convert unix "zerotime+nudge" to ntp format and back and compare ..          ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void)testConvertB1 {
    union ntpTime       netStamp = {+0x02000, JAN_1970};      // network time for 1 January 1970, GMT
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval      sysStamp;
    ntp2unix(&netStamp, &sysStamp);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime       newStamp = unix2ntp(&sysStamp);

    printf("Start with ntp() .. convert to unix() .. convert back and compare ..\n");
    printf("             ntp:         %08x:%08x (%016llx)\n",
           netStamp.partials.wholeSeconds, netStamp.partials.fractSeconds, netStamp.floating);
    printf("       ntp->unix: %016lx:%08x\n", sysStamp.tv_sec,       sysStamp.tv_usec);
    printf("  ntp->unix->ntp:         %08x:%08x (%016llx)\n",
           newStamp.partials.wholeSeconds, newStamp.partials.fractSeconds, newStamp.floating);

    double              tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);

    tDiff = ntpDiffSecondsB(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);

    XCTAssert(fabs(tDiff) < 0.000001, @"Pass");
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ TEST CONVERSIONS .. convert unix "zerotime-nudge" to ntp format and back and compare ..          ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void)testConvertB2 {
    union ntpTime       netStamp = {-0x02000, JAN_1970};      // network time for 1 January 1970, GMT
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval      sysStamp;
    ntp2unix(&netStamp, &sysStamp);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime       newStamp = unix2ntp(&sysStamp);

    printf("Start with ntp() .. convert to unix() .. convert back and compare ..\n");
    printf("             ntp:         %08x:%08x (%016llx)\n",
           netStamp.partials.wholeSeconds, netStamp.partials.fractSeconds, netStamp.floating);
    printf("       ntp->unix: %016lx:%08x\n", sysStamp.tv_sec,       sysStamp.tv_usec);
    printf("  ntp->unix->ntp:         %08x:%08x (%016llx)\n",
           newStamp.partials.wholeSeconds, newStamp.partials.fractSeconds, newStamp.floating);

    double              tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);

    XCTAssert(fabs(tDiff) < 2.0E-6, @"Pass");
}




/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ TEST CONVERSIONS .. convert unix "ntp-zerotime" to ntp format and back and compare ..            ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void)testConvertC {
    union ntpTime       netStamp = {0, 0x23aa7e80};         // ..
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval      sysStamp;
    ntp2unix(&netStamp, &sysStamp);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime       newStamp = unix2ntp(&sysStamp);

    printf("Start with ntp() .. convert to unix() .. convert back and compare ..\n");
    printf("             ntp:         %08x:%08x (%016llx)\n",
           netStamp.partials.wholeSeconds, netStamp.partials.fractSeconds, netStamp.floating);
    printf("       ntp->unix: %016lx:%08x\n", sysStamp.tv_sec,       sysStamp.tv_usec);
    printf("  ntp->unix->ntp:         %08x:%08x (%016llx)\n",
           newStamp.partials.wholeSeconds, newStamp.partials.fractSeconds, newStamp.floating);

    double              tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);
    
    XCTAssert(fabs(tDiff) < 2.0E-6, @"Pass");
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ TEST CONVERSIONS .. convert unix "ntp-zerotime" to ntp format and back and compare ..            ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
- (void)testConvertD {
    union ntpTime       netStamp = {0, 0xa3aa7e80};         // ..
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    struct timeval      sysStamp;
    ntp2unix(&netStamp, &sysStamp);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime     newStamp = unix2ntp(&sysStamp);

    printf("Start with ntp() .. convert to unix() .. convert back and compare ..\n");
    printf("             ntp:         %08x:%08x (%016llx)\n",
           netStamp.partials.wholeSeconds, netStamp.partials.fractSeconds, netStamp.floating);
    printf("       ntp->unix: %016lx:%08x\n", sysStamp.tv_sec,       sysStamp.tv_usec);
    printf("  ntp->unix->ntp:         %08x:%08x (%016llx)\n",
           newStamp.partials.wholeSeconds, newStamp.partials.fractSeconds, newStamp.floating);

    double              tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);
    
    XCTAssert(fabs(tDiff) < 2.0E-6, @"Pass");
}

- (void)testConvert5 {
    union ntpTime           netStamp = {-1, 0x23aa7e80};
    struct timeval          sysStamp;
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime     newStamp = unix2ntp(&sysStamp);

    printf("Start with ntp() .. convert to unix() .. convert back and compare ..\n");
    printf("             ntp:         %08x:%08x (%016llx)\n",
           netStamp.partials.wholeSeconds, netStamp.partials.fractSeconds, netStamp.floating);
    printf("       ntp->unix: %016lx:%08x\n", sysStamp.tv_sec,       sysStamp.tv_usec);
    printf("  ntp->unix->ntp:         %08x:%08x (%016llx)\n",
           newStamp.partials.wholeSeconds, newStamp.partials.fractSeconds, newStamp.floating);

    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    printf(" μseconds difference: %+6.3f\n", tDiff * 1000000.0);

    XCTAssert(fabs(tDiff) < 2.0E-6, @"Pass");
}

- (void)testConvert6 {
    union ntpTime     netStamp = {-1, 0xa3aa7e80};
    struct timeval          sysStamp;
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from NTP time to Unix time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    ntp2unix(&netStamp, &sysStamp);
    
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert from Unix time to NTP time                                                               │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    union ntpTime     newStamp = unix2ntp(&sysStamp);
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(fabs(tDiff) < 2.0E-6, @"Pass");
}

- (void)testConvert7 {
    union ntpTime     netStamp = {0x80000000, JAN_1970};
    union ntpTime     newStamp = {0, JAN_1970};
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff+0.5 < 2.0E-6, @"Pass");
}

- (void)testConvert8 {
    union ntpTime     netStamp = {0, JAN_1970+1};
    union ntpTime     newStamp = {0, JAN_1970};

    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff+1.0 < 2.0E-6, @"Pass");
}

- (void)testConvert9 {
    union ntpTime     netStamp = {0, JAN_1970};
    union ntpTime     newStamp = {0x80000000, JAN_1970};
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff-0.5 < 2.0E-6, @"Pass");
}

- (void)testConvert10 {
    union ntpTime     netStamp = {0, JAN_1970};
    union ntpTime     newStamp = {0, JAN_1970+1};
    
    double  tDiff = ntpDiffSeconds(&netStamp, &newStamp);
    
    printf("%12.10f\n", tDiff);
    XCTAssert(tDiff-1.0 < 2.0E-6, @"Pass");
}

//- (void)testConvert11 {
//    struct timeval          sysStamp;
//    
//    gettimeofday(&sysStamp, NULL);
//    printf("%08lx:%08x\n", sysStamp.tv_sec, sysStamp.tv_usec);
//    XCTAssert(true, @"Pass");
//}

- (void)testPerformanceExample {
    [self measureBlock:^{
        union ntpTime time = ntp_time_now();
    }];
}

@end
