//
//  CDHeaderIndex.m
//  code-dump
//
//  Created by Braden Thomas on 10/22/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDHeaderIndex.h"
#import "CDClassDefinition.h"

@implementation CDHeaderIndex

- (id) init
{
	self = [super init];
	if (self != nil) {
		xmlDocuments=[[NSMutableArray alloc] init];
		subclasses=[[NSMutableDictionary alloc] init];
	}
	return self;
}

- (id) initWithCoder:(NSCoder*)coder
{
	self = [super init];
	if (self != nil) {
		xmlDocuments=[[NSMutableArray alloc] initWithCoder:coder];
		subclasses=[[NSMutableDictionary alloc] initWithCoder:coder];
	}
	return self;	
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[xmlDocuments encodeWithCoder:encoder];
	[subclasses encodeWithCoder:encoder];
}

- (void)addSubclassData:(NSString*)data
{
	NSScanner* frameworkScanner = [NSScanner scannerWithString:data];
	while ([frameworkScanner scanUpToString:@"@interface" intoString:nil]&&[frameworkScanner scanString:@"@interface" intoString:nil])
	{
		NSString* classString;
		[frameworkScanner scanUpToString:@"@end" intoString:&classString];
		NSScanner* classScanner = [[NSScanner alloc] initWithString:classString];
		
		[classScanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];

		NSString* className,*categoryOf=nil;
		[classScanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@" \n\r\t("] intoString:&className];
		[classScanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];

		if ([classScanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"("] intoString:nil]) {
			[classScanner scanUpToString:@")" intoString:&categoryOf];	
			[classScanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@" \n\r\t)"] intoString:nil];
		}		
		// add subclasses to subclass dict
		NSString* subclass = nil;
		if ([classScanner scanString:@":" intoString:nil]) {
			[classScanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
			[classScanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@" \n\r\t(<"] intoString:&subclass];
		}
		if (subclass && className)
			[subclasses setObject:subclass forKey:className];
	}
}

- (void)addHeaderData:(NSString*)data
{					
	NSError* addErr;
	NSXMLDocument* headerData = [[NSXMLDocument alloc] initWithXMLString:data options:0 error:&addErr];
	if (addErr) {
		NSLog(@"Error processing bridge support: %@",addErr);
		return;
	}
	[xmlDocuments addObject:headerData];
}

- (NSXMLElement*)lookupSymbol:(CDSymbol*)sym
{
	NSMutableArray* foundElements = [NSMutableArray array];
	NSLog(@"index looking up %@",sym);
	for (NSXMLDocument* curDoc in xmlDocuments)
	{
		NSXMLElement* rootElem = [curDoc rootElement];
		NSArray* functionElems = [rootElem elementsForName:@"function"];
		for (NSXMLElement* function in functionElems) {
			if ([[[function attributeForName:@"name"] stringValue] isEqualToString:[sym name]])
				[foundElements addObject:function];
			if ([[sym name] hasPrefix:@"_"] && [[[function attributeForName:@"name"] stringValue] isEqualToString:[[sym name] substringFromIndex:1]])
				[foundElements addObject:function];
		}
	}
	if (![foundElements count])
		return nil;
	if ([foundElements count]>1)
		[NSException raise:@"NSNotImplemented" format:@"Found elements: %@",foundElements];
	return [foundElements objectAtIndex:0];
}

- (NSDictionary*)lookupSelector:(NSDictionary*)selector
{
	NSMutableDictionary* results = [[NSMutableDictionary alloc] init];
	[results setValue:[NSMutableArray array] forKey:@"Method"];
	[results setValue:[NSMutableArray array] forKey:@"Class"];
	NSLog(@"index looking up %@",selector);
	NSString* className = [selector objectForKey:@"ObjectName"];
	NSString* selName = [selector objectForKey:@"SelectorName"];
	if (!selName)
		[NSException raise:@"NSNotImplemented" format:@"Lookup for selector without selector name %@",selector];

	BOOL didFindSelector = NO;
	while (!didFindSelector) 
	{
		for (NSXMLDocument* curDoc in xmlDocuments)
		{
			NSXMLElement* rootElem = [curDoc rootElement];
			NSArray* classElems = [rootElem elementsForName:@"class"];
			for (NSXMLElement* class in classElems) {
				// XXX: not sure why I have this !className, when is className nil here?
				if (!className || [[[class attributeForName:@"name"] stringValue] isEqualToString:className])
				{
					NSArray* functionElems = [class elementsForName:@"method"];		
					for (NSXMLElement* function in functionElems) {
						if ([[[function attributeForName:@"selector"] stringValue] isEqualToString:selName])
						{
							[[results objectForKey:@"Method"] addObject:function];
							[[results objectForKey:@"Class"] addObject:class];
							didFindSelector = YES;
						}
					}
				}
			}
		}
		if (!didFindSelector) {
			className = [self subclassOf:className];
			if (!className) break;
		}
	}
	return results;
}

- (NSString*)subclassOf:(NSString*)className
{
	return [subclasses valueForKey:className];
}

@end
