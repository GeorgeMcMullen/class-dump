//
//  CDClassDefinition.m
//  code-dump
//
//  Created by Braden Thomas on 10/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDClassDefinition.h"


@implementation CDClassDefinition

- (id)initWithClassName:(NSString*)class
{
	self = [super init];
	if (self != nil) {
		className = [class copy];
		protocols = [NSMutableSet setWithCapacity:2];
		ivars = [NSMutableArray array];
		methods = [NSMutableSet setWithCapacity:10];
		category=nil;
	}
	return self;
}


- (void)setCategory:(NSString*)cat
{
	category = [cat copy];
}

- (void)setSuperClass:(NSString*)superc
{
	superClass = [superc copy];
}

- (void)addProtocol:(NSString*)protocol
{
	[protocols addObject:[protocol copy]];
}

- (void)addIvarOfType:(NSString*)type andName:(NSString*)name isPublic:(BOOL)pub
{
	[ivars addObject:[NSArray arrayWithObjects:[type copy], [name copy], [NSNumber numberWithBool:pub], nil]];
}

- (void)addMethodSignature:(NSString*)signature
{
	[methods addObject:signature];
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@%@ %@ %ld ivars, %ld methods", 
		className, 
		category?[NSString stringWithFormat:@" (%@)",category]:@"",
		superClass?[NSString stringWithFormat:@": %@,",superClass]:@"",
		[ivars count],
		[methods count]];
}

@end
