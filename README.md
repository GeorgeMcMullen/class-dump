code-dump
=========
code-dump is a program built on class-dump that is designed to decompile Objective-C/Cocoa programs by relying on the structured nature of Objective-C. It simulates the effect of instructions and creates Objective-C which should have the same effect. 

A while back, Braden Thomas took Steve Nygard's class-dump and converted it to be an Objective-C decompiler for PPC by adding and parsing disassembly through OTool. The original project is at: http://code-dump.sourceforge.net/. A while later in 2007/2008 it was updated for use with i386 processors (http://code.google.com/p/i386codedump/). Since then, Steve Nygard's class-dump has gone through some major revisions and new processors have been added to the support including x86_64 and ARM based processors. OTool has been updated as well to accommodate the new processors and has a slightly different output than previously (it outputs 64-bit addresses for at least the new processors). Unfortunately, code-dump was never updated to class-dump's new code base, otool's new output, nor the new processors. In fact, it isn't actually known whether or not code-dump actually ever worked; you would need an older machine that is purely just PPC or i386 to check for that. 

This project aims to bring code-dump back into the fold and hopefully even extend it to be able to decompile for X86_64 and ARM based architectures. There is A LOT to do. It must be noted that this project is NOT YET AT AN OPERATIONAL WORKING STAGE! DO NOT COMPLAIN TO ME THAT IT DOESN'T WORK, because IT DOESN'T WORK! I am only doing this basically as an intellectual exercise. If you want a decompiler, check out Hopper. If you have the money, check out Ida Pro Hex Rays.

Mostly what has been done so far is the tedious stuff, including:
- Took the current class-dump code base and added the original i386codedump code. The project DOES compile and it should run without crashes (though there are exceptions built into the app for error checking purposes).
- There were massive amounts of warnings, mostly because of ARC and int size problems. In many places I replaced "int" with "NSUInteger" (while doing things like [NSArray count]). Hopefully this doesn't mess anything up severely.
- I added stubs for X86_64 and ARM simulation / disassembly. THESE ARE NOT MEANT TO WORK RIGHT NOW! It is just copy / pasted from the existing PPC and X86 simulator classes / disassembly.
- It looks like code-dump was originally just based on ObjC1 decompiling. class-dump includes a new ObjC2 pre-processor so I added some rudimentary checking for that. I'm not sure if that is all that needs to be done.

Still left to do (A LOT!):
- Address schemes etc. and the new OTool output need to be accounted for, for all included processors. This will include changing variable sizes from 32 bits (ints and longs) to 64 bits, etc.
- Disassembly parsing and simulation needs to be updated for X86_64 and ARM. This is going to be the most intense work (though I'm hoping X86_64 is a little easier)
- Lots of error checking. For example, there are a lot of "Warning!: curIndex not found!" errors when it runs. Those need to be tracked down and fixed.
- Everything else that still needed to be done for the original code-dump

In it's current state, it will go through an executable, get the first class, disassemble the first method and attempt decompile it by simulating the instructions. At the simulation level it then quits out on a programmed exception. The test executable I am using is itself (because it doesn't make sense yet to create a test "Hello World!" app yet when it doesn't even run correctly). 

If you'd like to help out or have any pointers, let me know.

Please do not bother Steve Nygard or Braden Thomas about this project.


class-dump
==========

class-dump is a command-line utility for examining the Objective-C
segment of Mach-O files.  It generates declarations for the classes,
categories and protocols.  This is the same information provided by
using 'otool -ov', but presented as normal Objective-C declarations.

The latest version and information is available at:

    http://www.codethecode.com/projects/class-dump

The source code is also available from my Github repository at:

    https://github.com/nygard/class-dump

Usage
-----

    class-dump 3.3.4 (64 bit)
    Usage: class-dump [options] <mach-o-file>

      where options are:
            -a             show instance variable offsets
            -A             show implementation addresses
            --arch <arch>  choose a specific architecture from a universal binary (ppc, ppc64, i386, x86_64)
            -C <regex>     only display classes matching regular expression
            -f <str>       find string in method name
            -H             generate header files in current directory, or directory specified with -o
            -I             sort classes, categories, and protocols by inheritance (overrides -s)
            -o <dir>       output directory used for -H
            -r             recursively expand frameworks and fixed VM shared libraries
            -s             sort classes and categories by name
            -S             sort methods by name
            -t             suppress header in output, for testing
            --list-arches  list the arches in the file, then exit
            --sdk-ios      specify iOS SDK version (will look in /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS<version>.sdk
            --sdk-mac      specify Mac OS X version (will look in /Developer/SDKs/MacOSX<version>.sdk
            --sdk-root     specify the full SDK root path (or use --sdk-ios/--sdk-mac for a shortcut)

- class-dump AppKit:

    class-dump /System/Library/Frameworks/AppKit.framework

- class-dump UIKit:

    class-dump /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS4.3.sdk/System/Library/Frameworks/UIKit.framework

- class-dump UIKit and all the frameworks it uses:

    class-dump /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS4.3.sdk/System/Library/Frameworks/UIKit.framework -r --sdk-ios 4.3

- class-dump UIKit (and all the frameworks it uses) from developer tools that have been installed in /Dev42 instead of /Developer:

    class-dump /Dev42/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/System/Library/Frameworks/UIKit.framework -r --sdk-root /Dev42/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk


License
-------

This file is part of class-dump, a utility for examining the
Objective-C segment of Mach-O files.
Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

Contact
-------

You may contact the author by:
   e-mail:  class-dump at codethecode.com
