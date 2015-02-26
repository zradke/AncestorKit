//
//  AKTestPerson.m
//  AncestorKit
//
//  Created by Zachary Radke | AMDU on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "AKTestPerson.h"
#import <FormatterKit/TTTOrdinalNumberFormatter.h>

@implementation AKTestPerson

+ (TTTOrdinalNumberFormatter *)ordinalFormatter
{
    static TTTOrdinalNumberFormatter *ordinalFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ordinalFormatter = [TTTOrdinalNumberFormatter new];
        [ordinalFormatter setLocale:[NSLocale currentLocale]];
    });
    
    return ordinalFormatter;
}

- (NSString *)description
{
    return [self fullName];
}

- (NSString *)fullName
{
    NSUInteger occurencesOfFirstName = 1;
    AKTestPerson *ancestor = self;
    while ((ancestor = ancestor.ancestor))
    {
        if (self.firstName && [ancestor.firstName isEqualToString:self.firstName])
        {
            occurencesOfFirstName++;
        }
    }
    
    NSString *decorator = nil;
    if (occurencesOfFirstName == 2)
    {
        decorator = @"Jr.";
    }
    else if (occurencesOfFirstName > 2)
    {
        decorator = [[[self class] ordinalFormatter] stringFromNumber:[NSNumber numberWithUnsignedInteger:occurencesOfFirstName]];
    }
    
    NSMutableArray *nameComponents = [NSMutableArray array];
    if (self.firstName)
    {
        [nameComponents addObject:self.firstName];
    }
    
    if (decorator)
    {
        [nameComponents addObject:decorator];
    }
    
    if (self.lastName)
    {
        [nameComponents addObject:self.lastName];
    }
    
    return [nameComponents componentsJoinedByString:@" "];
}

@end
