//
//  CDRegVal.m
//  class-dump
//
//  Created by Braden Thomas on 4/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "CDRegVal.h"


@implementation CDRegVal

- (id)copyWithZone:(NSZone *)zone
{
	CDRegVal *copy;
	if (!valid)
		copy = [[[self class] allocWithZone: zone] initInvalid];
	else if (isSelf)
		copy = [[[self class] allocWithZone: zone] initWithSelf];
	else if (isLineRef)
		copy = [[[self class] allocWithZone: zone] initWithLine:lineRef];
	else
		copy = [[[self class] allocWithZone: zone] initWithValue:value];	
		
    return copy;
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		isSelf=NO;
		isLineRef=NO;
		valid=YES;
		isDeRef=NO;
	}
	return self;
}


- (id)initWithSelf
{
	if ([self init]==nil)
		return nil;
	isSelf = YES;
	return self;
}

- (id)initWithValue:(long)inVal
{
	if ([self init]==nil)
		return nil;
	value = inVal;
	return self;	
}

- (id)initWithLine:(NSUInteger)line
{
	if ([self init]==nil)
		return nil;
	lineRef = line;
	isLineRef = YES;
	return self;	
}

- (id)initWithSymbolDeRef:(CDSymbol*)in_symbol
{
	if ([self init]==nil)
		return nil;
	symbol = in_symbol;
	isDeRef = YES;
	return self;
}

- (id)initInvalid
{
	if ([self init]==nil)
		return nil;
	valid = NO;
	return self;
}

- (BOOL)data
{
	return valid&&!isSelf&&!isLineRef&&!isDeRef;
}

- (BOOL)deref
{
	return isDeRef;
}

- (BOOL)isEqualTo:(CDRegVal*)b
{
	if ((isSelf==[b isSelf])&&
		(isLineRef==[b isLineRef])&&
		(valid==[b valid])&&
		(value==[b value])&&
		(lineRef==[b lineRef])&&
		([symbol isEqualTo:[b symbol]])&&
		(isDeRef==[b deref]))
		return true;
	else
		return false;
}

- (NSString*)description
{
	if (!valid)
		return @"Invalid register";
	if (isLineRef)
		return [NSString stringWithFormat:@"LineRef to: %ld",lineRef,nil];
	if (isSelf)
		return @"self";
	if (isDeRef)
		return [NSString stringWithFormat:@"DeRef of %@",symbol];
	if (valid&&!isSelf&&!isLineRef)
		return [NSString stringWithFormat:@"Data: %ld",value,nil];
	return @"";
}

@synthesize isLineRef;
@synthesize valid;
@synthesize isSelf;
@synthesize lineRef;
@synthesize value;
@synthesize symbol;

@end
