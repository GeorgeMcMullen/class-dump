// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "CDStructureInfo.h"

#import "NSError-CDExtensions.h"
#import "CDType.h"
#import "CDTypeParser.h"

@implementation CDStructureInfo

- (id)initWithTypeString:(NSString *)str;
{
    if ([super init] == nil)
        return nil;

    typeString = [str retain];
    referenceCount = 1;

    {
        CDTypeParser *parser;
        NSError *error;

        parser = [[CDTypeParser alloc] initWithType:typeString];
        type = [[parser parseType:&error] retain];
        if (type == nil)
            NSLog(@"Warning: (CDStructInfo) Parsing struct type failed, %@", [error myExplanation]);
        [parser release];
    }

    return self;
}

- (void)dealloc;
{
    [typeString release];
    [type release];

    [super dealloc];
}

- (NSString *)typeString;
{
    return typeString;
}

- (CDType *)type;
{
    return type;
}

- (NSUInteger)referenceCount;
{
    return referenceCount;
}

- (void)setReferenceCount:(NSUInteger)newCount;
{
    referenceCount = newCount;
}

- (void)addReferenceCount:(NSUInteger)count;
{
    referenceCount += count;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@:%p> depth: %u, refcount: %u, typeString: %@, type: %p",
                     NSStringFromClass([self class]), self,
                     [type structureDepth], referenceCount, typeString, type];
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"%u %u %@ %@", [type structureDepth], referenceCount, [type bareTypeString], typeString];
}

- (NSComparisonResult)ascendingCompareByStructureDepth:(CDStructureInfo *)otherInfo;
{
    NSUInteger thisDepth, otherDepth;

    thisDepth = [type structureDepth];
    otherDepth = [[otherInfo type] structureDepth];

    if (thisDepth < otherDepth)
        return NSOrderedAscending;
    else if (thisDepth > otherDepth)
        return NSOrderedDescending;

    return [typeString compare:[otherInfo typeString]];
}

@end