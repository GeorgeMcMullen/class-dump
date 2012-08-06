//
//  CDDisassembly.m
//  code-dump
//
//  Created by Braden Thomas on 10/20/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDDisassembly.h"
#import "CDSection.h"
#import <sys/stat.h>

@implementation CDDisassembly

//TODO: Lipo requires fat files in order to work. If it's not a fat file, then it shouldn't be running.

- (id) initWithFile:(NSString*)path {
	self = [super init];
	if (self != nil) {
		assemblerIndex = 0;
		struct stat sb;
		if (stat("/usr/bin/otool",&sb))
		{
			printf("Error: Decompilation requires otool binary.  Install Apple Developer Tools.\n");
			return nil;
		}
		filePath = [path copy];
	}
	return self;
}

- (void)setSection:(CDSection*)sect
{
	textTextSection=sect;
}

- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	switch (assemblerIndex) {
		case(kOtool):
			{
				// use otool to disassemble
				NSPipe* otoolOut = [[NSPipe alloc] init];
				NSTask* otool = [[NSTask alloc] init];
				[otool setLaunchPath:@"/usr/bin/otool"];
				[otool setArguments:[NSArray arrayWithObjects:@"-tv",filePath,nil]];
				[otool setStandardOutput:otoolOut];
				[otool launch];
				NSData* otData = [[otoolOut fileHandleForReading] readDataToEndOfFile];
				[otool waitUntilExit];
				int status = [otool terminationStatus];
				if (status) {
					printf("Error: otool failed with error %d\n",status);
					return;
				}
				disassemblerOutput = [[NSString alloc] initWithData:otData encoding:NSASCIIStringEncoding];
			}
			break;
		case(kOtoolWithHeader):
			{
				// use otool to disassemble
				NSPipe* otoolOut = [[NSPipe alloc] init];
				NSTask* otool = [[NSTask alloc] init];
				[otool setLaunchPath:@"/usr/bin/otool"];
				[otool setArguments:[NSArray arrayWithObjects:@"-tv",@"-p",header,filePath,nil]];
				[otool setStandardOutput:otoolOut];
				[otool launch];
				NSData* otData = [[otoolOut fileHandleForReading] readDataToEndOfFile];
				[otool waitUntilExit];
				int status = [otool terminationStatus];
				if (status) {
					printf("Error: otool failed with error %d\n",status);
					return;
				}
				disassemblerOutput = [[NSString alloc] initWithData:otData encoding:NSASCIIStringEncoding];
                NSLog(@"DataOutput was: %@", disassemblerOutput);
			}
			break;
		default:
			[NSException raise:@"NSNotImplemented" format:@"Disassembler index %d not implemented",assemblerIndex];
			return;
	}
}

- (NSString*)instructionsString
{
	return disassemblerOutput;
}

- (BOOL)useNextDisassemblerForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	NSLog(@"Using another disassembler with header %@ and offset %@\n",header,offset);
	if (++assemblerIndex>[self numberOfDisassembler])
		return false;
	[self getDisassemblyForHeader:header atOffset:offset];	
	return true;
}

- (int)numberOfDisassembler
{
	return kNumberOfDisassemblers;
}

@end


@implementation CDPPCDisassembly
- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	switch (assemblerIndex) {
		case(kOtoolWithHeader):
		case(kOtool):
			{
				NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[filePath lastPathComponent]];
				NSTask* theTask=[NSTask launchedTaskWithLaunchPath:@"/usr/bin/lipo" arguments:
					[NSArray arrayWithObjects: 
						@"-extract_family",
						@"ppc",
						filePath,
						@"-o",
						resultPath,
						nil]];
				[theTask waitUntilExit];
				[super getDisassemblyForHeader:header atOffset:offset];		
			}
			break;
		default:
			return;
	}	
}
@end

@implementation CDARMDisassembly
- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	switch (assemblerIndex) {
		case(kOtoolWithHeader):
		case(kOtool):
        {
            NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[filePath lastPathComponent]];
            NSTask* theTask=[NSTask launchedTaskWithLaunchPath:@"/usr/bin/lipo" arguments:
                             [NSArray arrayWithObjects: 
                              @"-extract_family",
                              @"arm",
                              filePath,
                              @"-o",
                              resultPath,
                              nil]];
            [theTask waitUntilExit];
            [super getDisassemblyForHeader:header atOffset:offset];		
        }
			break;
		default:
			return;
	}	
}
@end

@implementation CDARMV6Disassembly
- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	switch (assemblerIndex) {
		case(kOtoolWithHeader):
		case(kOtool):
        {
            NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[filePath lastPathComponent]];
            NSTask* theTask=[NSTask launchedTaskWithLaunchPath:@"/usr/bin/lipo" arguments:
                             [NSArray arrayWithObjects: 
                              @"-extract_family",
                              @"armv6",
                              filePath,
                              @"-o",
                              resultPath,
                              nil]];
            [theTask waitUntilExit];
            [super getDisassemblyForHeader:header atOffset:offset];		
        }
			break;
		default:
			return;
	}	
}
@end

@implementation CDARMV7Disassembly
- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	switch (assemblerIndex) {
		case(kOtoolWithHeader):
		case(kOtool):
        {
            NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[filePath lastPathComponent]];
            NSTask* theTask=[NSTask launchedTaskWithLaunchPath:@"/usr/bin/lipo" arguments:
                             [NSArray arrayWithObjects: 
                              @"-extract_family",
                              @"armv7",
                              filePath,
                              @"-o",
                              resultPath,
                              nil]];
            [theTask waitUntilExit];
            [super getDisassemblyForHeader:header atOffset:offset];		
        }
			break;
		default:
			return;
	}	
}
@end

@implementation CDX86Disassembly
- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	switch (assemblerIndex) {
		case(kX86OtoolWithHeader):
		case(kX86Otool):
			{
				NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[filePath lastPathComponent]];
				NSTask* theTask=[NSTask launchedTaskWithLaunchPath:@"/usr/bin/lipo" arguments:
					[NSArray arrayWithObjects: 
						@"-extract_family",
						@"i386",
						filePath,
						@"-o",
						resultPath,
						nil]];
				[theTask waitUntilExit];
				[super getDisassemblyForHeader:header atOffset:offset];		
			}
			break;
		case (kX86Disasm):
			{
				NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"savedTextSegment"];
				NSData* segmentData = [[NSData alloc] initWithBytes:[textTextSection dataPointer] length:[textTextSection size]];
				if ([[NSFileManager defaultManager] createFileAtPath:resultPath contents:segmentData attributes:nil]==NO)
					[NSException raise:@"NSFileNotCreatedException" format:@"Temporary file couldn't be created for ndisasm disassembler"];
				[NSException raise:@"NSNotImplemented" format:@"Use of backup disassembler is not implemented"];				
			}
		default:
			return;
	}	
}

- (int)numberOfDisassembler
{
	return k86NumberOfDisassemblers;
}

@end

@implementation CDX8664Disassembly
- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset
{
	switch (assemblerIndex) {
		case(kX8664OtoolWithHeader):
		case(kX8664Otool):
        {
            NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[filePath lastPathComponent]];
            NSTask* theTask=[NSTask launchedTaskWithLaunchPath:@"/usr/bin/lipo" arguments:
                             [NSArray arrayWithObjects:
                              @"-extract_family",
                              @"x86_64",
                              filePath,
                              @"-o",
                              resultPath,
                              nil]];
            [theTask waitUntilExit];
            [super getDisassemblyForHeader:header atOffset:offset];
        }
			break;
		case (kX8664Disasm):
        {
            NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"savedTextSegment"];
            NSData* segmentData = [[NSData alloc] initWithBytes:[textTextSection dataPointer] length:[textTextSection size]];
            if ([[NSFileManager defaultManager] createFileAtPath:resultPath contents:segmentData attributes:nil]==NO)
                [NSException raise:@"NSFileNotCreatedException" format:@"Temporary file couldn't be created for ndisasm disassembler"];
            [NSException raise:@"NSNotImplemented" format:@"Use of backup disassembler is not implemented"];				
        }
		default:
			return;
	}	
}

- (int)numberOfDisassembler
{
	return k8664NumberOfDisassemblers;
}

@end