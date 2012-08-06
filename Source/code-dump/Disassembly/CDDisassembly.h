//
//  CDDisassembly.h
//  code-dump
//
//  Created by Braden Thomas on 10/20/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CDSection;

enum assemblerIndex {
	kOtool = 0,
	kOtoolWithHeader,
	kNumberOfDisassemblers
};

@interface CDDisassembly : NSObject {
	NSString* disassemblerOutput;
	CDSection* textTextSection;
	int assemblerIndex;
	NSString* filePath;
}
- (id) initWithFile:(NSString*)path;
- (void)getDisassemblyForHeader:(NSString*)header atOffset:(NSNumber*)offset;
- (void)setSection:(CDSection*)sect;
- (NSString*)instructionsString;
- (BOOL)useNextDisassemblerForHeader:(NSString*)header atOffset:(NSNumber*)offset;
- (int)numberOfDisassembler;
@end

@interface CDPPCDisassembly : CDDisassembly {
	
}
@end


@interface CDX86Disassembly: CDDisassembly {
	
}
enum x86AssemblerIndex {
	kX86Otool = 0,
	kX86OtoolWithHeader,
	kX86Disasm,
	k86NumberOfDisassemblers
};
@end

@interface CDX8664Disassembly: CDDisassembly {

}
enum x8664AssemblerIndex {
	kX8664Otool = 0,
	kX8664OtoolWithHeader,
	kX8664Disasm,
	k8664NumberOfDisassemblers
};
@end


@interface CDARMDisassembly : CDDisassembly {
	
}
@end

@interface CDARMV6Disassembly : CDDisassembly {
	
}
@end

@interface CDARMV7Disassembly : CDDisassembly {
	
}
@end



