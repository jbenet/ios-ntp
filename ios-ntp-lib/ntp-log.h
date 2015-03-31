#import <Availability.h>
#import <Foundation/Foundation.h>

#define NTP_Logging(fmt, ...)
#define LogInProduction(fmt, ...) \
    NSLog((@"%@|" fmt), [NSString stringWithFormat: @"%16s", \
        [[[self class] description] UTF8String]], ##__VA_ARGS__)

#ifdef IOS_NTP_LOGGING
    #undef NTP_Logging
    #define NTP_Logging(fmt, ...) \
        NSLog((@"%@|" fmt), [NSString stringWithFormat: @"%16s", \
            [[[self class] description] UTF8String]], ##__VA_ARGS__)
#endif
