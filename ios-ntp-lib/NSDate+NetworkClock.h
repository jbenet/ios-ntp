/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ Author: Juan Batiz-Benet                                                                         ║
  ║                                                                                                  ║
  ║ Category on NSDate to provide convenience access to NetworkClock.                                ║
  ║                                                        To use, simply call [NSDate networkDate]; ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

#import <Foundation/Foundation.h>

@interface NSDate (NetworkClock)

@property (NS_NONATOMIC_IOSONLY, readonly) NSTimeInterval timeIntervalSinceNetworkDate;

+ (NSTimeInterval) timeIntervalSinceNetworkDate;

+ (NSDate *) networkDate;

    // the threadsafe version guards against reading a double that could be
    // potentially being updated at the same time. Since doubles are 8 words,
    // and arm is 32bit, this is not atomic and could provide bad values.

+ (NSDate *) threadsafeNetworkDate;

@end