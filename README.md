# ios-ntp

A network time protocol client and application testbed for iOS.
This is a continues to be a work in progress.

Created by Gavin Eadie on Oct 17, 2010

----
**November 19, 2014:** A large update was made today to bring ios-ntp
into the modern world. The changes do include one bug fix, but are
mostly related to making the code comply with the recent Xcode changes
and requirements.  Such things are sometimes tricky, so make sure you
test carefully when you adopt today's changes.

Some of jbenet's "Usage" notes below aren't completely accurate as a
result of these changes, and I will update the text soon.

Finally, note that this code was written when there were only 32-bit iOS
devices. As I write this there are still 32-bit devices which run the
latest version of iOS (iPhone 4S, for example), but all newer iOS
devices have a 64-bit architecture (iPhone 6, for example).  Since the
representation of "Unix time" uses an 'signed long' for seconds since
Unix epoch (01 Jan 1970), this value rolls over on 19 Jan 2038 on older
iOS devices.  This is not too worrying, however, since "NTP time" rolls
over before that, on 08 Feb 2036.  Which is all by way of saying (a) be
careful with arithmetic, and (b) you should not be using this code in 20
years, or setting your device's clock past 2038 !!

----
### About

The clock on an older iPhone, iTouch or iPad is not closely synchronized
to the correct time. In the case of a device which is obtaining its time
from the telephone system, there is a setting to enable synchronizing to
the phone company time, but that time has been known to be over a minute
different from UTC.

In addition, users may change their device time and severely affect
applications that rely on correct times to enforce functionality.

This project contains code to provide time obtained from standard time
servers using the simple network time protocol (SNTP: RFC 5905). The
implementation is not a rigorous as described in those RFCs since the
goal was to improve time accuracy to less than a second, not to
microseconds.

### This Fork

----
**November 19, 2014:** jbenet and I (gavineadie) have agreed that I will resume
taking care of this project and will let the old version at Google Code fade away.
I've come to enjoy git much more than svn also.

----
This is a fork from the original source at
[http://code.google.com/p/ios-ntp/](http://code.google.com/p/ios-ntp/) that
provides ios-ntp as a *static* iOS framework. This makes its use easier and
avoids symbol clashing.

Why fork? Well, because git and github are much more convenient than google code
for me. I (jbenet) am subscribed to the RSS feed of the original project and
will merge any upstream changes.

### License

The [MIT](http://www.opensource.org/licenses/mit-license.php) License
Copyright (c) 2010-4, Ramsay Consulting

### Usage

----
**November 19, 2014:** Some of the words below are not true.  That will be fixed soon.

----
Download [ios-ntp.tar.gz](https://raw.github.com/jbenet/ios-ntp/master/release/ios-ntp.tar.gz),
and add `ios-ntp.framework` to your project. Make sure the file `ntp.hosts` is
added to the project. I should show within the ios-ntp.framework/Headers
directory.*

This project depends on CocoaAsyncSocket, so you may need to
[get it](http://code.google.com/p/cocoaasyncsocket/). ios-ntp only needs
`AyncUdpSocket`.

Edit ntp.hosts to add or remove any NTP servers. Make sure it is OK to use them.

Then, simply call:

[NSDate networkDate];

As soon as you call it, the NTP process will begin. If you wish to start it at
boot time, so that the time is well synchronized by the time you actually want
to use it, just call it in your AppDelegate's didFinishLaunching function.


* Note: The ntp.hosts is currently inside Headers to both bundle it with the
framework AND coax Xcode to automatically add it, as it does not add the
Resources directory of frameworks.

### Building

To build the static framework, build the `ios-ntp` target from the xcode
project. Make sure you build BOTH the `iPhone Simulator` and `iOS Device`
architectures.