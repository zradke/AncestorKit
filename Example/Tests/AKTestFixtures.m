//
//  AKTestFixtures.m
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "AKTestFixtures.h"
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


@implementation AKTestPersonSubclass

- (NSString *)firstName
{
    return [[super firstName] uppercaseString];
}

@end


@implementation AKTestPersonDeepSubclass

- (NSString *)fullName
{
    NSMutableArray *nameParts = [NSMutableArray array];
    
    if (self.firstName)
    {
        [nameParts addObject:self.firstName];
    }
    
    if (self.middleName)
    {
        [nameParts addObject:self.middleName];
    }
    
    if (self.lastName)
    {
        [nameParts addObject:self.lastName];
    }
    
    return [nameParts componentsJoinedByString:@" "];
}

+ (NSSet *)propertiesPassedToDescendants
{
    static NSSet *properties;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K != %@", NSStringFromSelector(@selector(propertyName)), NSStringFromSelector(@selector(middleName))];
        properties = [[super propertiesPassedToDescendants] filteredSetUsingPredicate:predicate];
    });
    
    return properties;
}

@end


@interface AKCollectionViewAttributes ()
@property (strong, nonatomic) NSValue *sectionInsetsValue;
@end

@implementation AKCollectionViewAttributes

- (UIEdgeInsets)sectionInsets
{
    return (self.sectionInsetsValue) ? [self.sectionInsetsValue UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (void)setSectionInsets:(UIEdgeInsets)sectionInsets
{
    if (!UIEdgeInsetsEqualToEdgeInsets(self.sectionInsets, sectionInsets))
    {
        self.sectionInsetsValue = [NSValue valueWithUIEdgeInsets:sectionInsets];
    }
}

+ (NSSet *)keyPathsForValuesAffectingSectionInsets
{
    return [NSSet setWithObject:NSStringFromSelector(@selector(sectionInsetsValue))];
}

@end


