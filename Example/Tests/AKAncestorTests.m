//
//  AKAncestorTests.m
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <AncestorKit/AncestorKit.h>
#import <XCTest/XCTest.h>
#import "AKTestFixtures.h"

@interface AKAncestorTests : XCTestCase

@end

@implementation AKAncestorTests

+ (NSDateFormatter *)dateFormatter
{
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"yyyy/MM/dd";
    });
    return dateFormatter;
}


#pragma mark - Creating ancestors

- (void)testInitRoot
{
    AKTestPerson *person = [AKTestPerson new];
    person.firstName = @"James";
    person.lastName = @"Potter";
    
    XCTAssertEqualObjects(person.firstName, @"James");
    XCTAssertEqualObjects(person.lastName, @"Potter");
    XCTAssertEqualObjects([person fullName], @"James Potter");
    XCTAssertTrue(person.inheritsKeyValueNotifications);
}

- (void)testInitDescendant
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"James";
    personA.lastName = @"Potter";
    
    AKTestPerson *personB = [personA descendant];
    personB.firstName = @"Harry";
    
    XCTAssertEqualObjects(personA.firstName, @"James");
    XCTAssertEqualObjects(personB.firstName, @"Harry");
    XCTAssertEqualObjects(personB.lastName, @"Potter");
    XCTAssertEqualObjects([personB fullName], @"Harry Potter");
    
    XCTAssertEqual(personB.ancestor, personA);
    XCTAssertEqual(personB.inheritsKeyValueNotifications, personA.inheritsKeyValueNotifications);
}

- (void)testInitDescendantWithDifferentInheritance
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"James";
    personA.lastName = @"Potter";
    
    AKTestPerson *personB = [personA descendantInheritingKeyValueNotifications:NO];
    personB.firstName = @"Harry";
    
    XCTAssertEqual(personB.ancestor, personA);
    XCTAssertFalse(personB.inheritsKeyValueNotifications);
}


#pragma mark - Property inheritance

- (void)testMethodsUsingProperties
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"Lily";
    personA.lastName = @"Potter";
    
    AKTestPerson *personB = [personA descendant];
    personB.firstName = @"Harry";
    
    AKTestPerson *personC = [personB descendant];
    personC.firstName = @"Lily";
    
    XCTAssertEqualObjects([personA fullName], @"Lily Potter");
    XCTAssertEqualObjects([personB fullName], @"Harry Potter");
    XCTAssertEqualObjects([personC fullName], @"Lily Jr. Potter");
}

- (void)testSubclassOverridesProperties
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"Lily";
    personA.lastName = @"Potter";
    
    AKTestPersonSubclass *personB = [AKTestPersonSubclass descendantOf:personA];
    personB.firstName = @"Harry";
    
    XCTAssertEqualObjects([personA fullName], @"Lily Potter");
    XCTAssertEqualObjects([personB fullName], @"HARRY Potter");
}

- (void)testOverrideThenNilResumesInheritance
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"Grandma";
    personA.lastName = @"Evans";
    
    AKTestPerson *personB = [personA descendant];
    personB.firstName = @"Lily";
    personB.lastName = @"Potter";
    
    XCTAssertEqualObjects(personB.lastName, @"Potter");
    
    personB.lastName = nil;
    
    XCTAssertEqualObjects(personB.lastName, @"Evans");
}

- (void)testStopInheritingProperty
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"Lily";
    personA.lastName = @"Potter";
    
    AKTestPerson *personB = [personA descendant];
    personB.firstName = @"Harry";
    
    [personB stopInheritingValuesForPropertyName:NSStringFromSelector(@selector(lastName))];
    
    XCTAssertNil(personB.lastName);
    
    personB.lastName = @"Weasley";
    
    XCTAssertEqualObjects(personB.lastName, @"Weasley");
    
    personB.lastName = nil;
    [personB resumeInheritingValuesForPropertyName:NSStringFromSelector(@selector(lastName))];
    
    XCTAssertEqualObjects(personB.lastName, @"Potter");
}

- (void)testNoPrimitivePropertyInheritance
{
    AKTestPersonDeepSubclass *personA = [AKTestPersonDeepSubclass new];
    personA.firstName = @"Lily";
    personA.lastName = @"Potter";
    
    AKTestPersonDeepSubclass *personB = [personA descendant];
    personB.firstName = @"Harry";
    
    personA.isMarried = YES;
    
    XCTAssertTrue(personA.isMarried);
    XCTAssertFalse(personB.isMarried);
    
    XCTAssertEqualObjects([personA fullName], @"LILY Potter");
    XCTAssertEqualObjects([personB fullName], @"HARRY Potter");
}

- (void)testOverridPropertiesAvailableForInheritance
{
    AKTestPersonDeepSubclass *personA = [AKTestPersonDeepSubclass new];
    personA.firstName = @"Harry";
    personA.middleName = @"James";
    personA.lastName = @"Potter";
    
    AKTestPersonDeepSubclass *personB = [personA descendant];
    personB.firstName = @"Lily";
    
    XCTAssertEqualObjects([personA fullName], @"HARRY James Potter");
    XCTAssertEqualObjects([personB fullName], @"LILY Potter");
}

- (void)testComposedPrimitivePropertyInheritance
{
    AKCollectionViewAttributes *attrsA = [AKCollectionViewAttributes new];
    attrsA.sectionInsets = UIEdgeInsetsMake(15.0, 15.0, 15.0, 15.0);
    
    AKCollectionViewAttributes *attrsB = [attrsA descendant];
    
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(attrsA.sectionInsets, attrsB.sectionInsets));
    
    attrsB.sectionInsets = UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);
    
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(attrsA.sectionInsets, UIEdgeInsetsMake(15.0, 15.0, 15.0, 15.0)));
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(attrsB.sectionInsets, UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0)));
}

- (void)testBlockPropertiesNotInherited
{
    AKTestPersonDeepSubclass *personA = [AKTestPersonDeepSubclass new];
    personA.firstName = @"Harry";
    personA.middleName = @"James";
    personA.lastName = @"Potter";
    
    personA.fullNameDidChangeBlock = ^{
        NSLog(@"Full name did change.");
    };
    
    AKTestPersonDeepSubclass *personB = [personA descendant];
    personB.firstName = @"Lily";
    
    XCTAssertNil(personB.fullNameDidChangeBlock);
}


#pragma mark - KVC

- (void)testInheritedKVC
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"Lily";
    personA.lastName = @"Potter";
    
    AKTestPerson *personB = [personA descendant];
    personB.firstName = @"Harry";
    
    [self keyValueObservingExpectationForObject:personB keyPath:NSStringFromSelector(@selector(lastName)) expectedValue:@"Evans"];
    
    personA.lastName = @"Evans";
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testInheritanceOverridenKVC
{
    AKTestPersonDeepSubclass *personA = [AKTestPersonDeepSubclass new];
    personA.firstName = @"Lily";
    personA.lastName = @"Evans";
    
    AKTestPersonDeepSubclass *personB = [AKTestPersonDeepSubclass new];
    personB.firstName = @"Harry";
    personB.lastName = @"P.";
    personB.fullNameDidChangeBlock = ^{
        XCTFail(@"The last name should not generate a key-value notification.");
    };
    
    [self keyValueObservingExpectationForObject:personA keyPath:NSStringFromSelector(@selector(lastName)) expectedValue:@"Potter"];
    
    personA.lastName = @"Potter";
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testDeepInheritedKVC
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"Lily";
    personA.lastName = @"Potter";
    
    AKTestPerson *personB = [personA descendant];
    personB.firstName = @"Harry";
    
    AKTestPerson *personC = [personB descendant];
    personC.firstName = @"Lily";
    
    [self keyValueObservingExpectationForObject:personC keyPath:NSStringFromSelector(@selector(lastName)) expectedValue:@"Evans"];
    
    personA.lastName = @"Evans";
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testSubclassKVCToBaseClass
{
    NSDateFormatter *dateFormatter = [[self class] dateFormatter];
    
    AKTestPersonSubclass *personA = [AKTestPersonSubclass new];
    personA.firstName = @"Harry";
    personA.lastName = @"Potter";
    personA.birthDate = [dateFormatter dateFromString:@"1980/07/30"];
    
    AKTestPerson *personB = [AKTestPerson descendantOf:personA];
    
    XCTAssertNoThrow(personA.birthDate = [dateFormatter dateFromString:@"1980/07/31"]);
    XCTAssertNotNil(personB);
}

- (void)testComposedPrimitivePropertyKVC
{
    AKCollectionViewAttributes *attrsA = [AKCollectionViewAttributes new];
    attrsA.sectionInsets = UIEdgeInsetsMake(15.0, 15.0, 15.0, 15.0);
    
    AKCollectionViewAttributes *attrsB = [attrsA descendant];
    
    [self keyValueObservingExpectationForObject:attrsB keyPath:NSStringFromSelector(@selector(sectionInsets)) expectedValue:[NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(12.0, 12.0, 12.0, 12.0)]];
    
    attrsA.sectionInsets = UIEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testKVCRemovedOnDealloc
{
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"James";
    personA.lastName = @"Potter";
    
    @autoreleasepool
    {
        AKTestPerson *personB = [personA descendant];
        personB.firstName = @"Harry";
        
        [self keyValueObservingExpectationForObject:personB keyPath:NSStringFromSelector(@selector(lastName)) expectedValue:@"Evans"];
        
        personA.lastName = @"Evans";
        
        [self waitForExpectationsWithTimeout:5.0 handler:nil];
    }
    
    XCTAssertNoThrow(personA.lastName = @"Potter");
}


#pragma mark - Class mismatches

- (void)testSubclassInheritsFromBaseClass
{
    NSDateFormatter *dateFormatter = [[self class] dateFormatter];
    
    AKTestPerson *personA = [AKTestPerson new];
    personA.firstName = @"James";
    personA.lastName = @"Potter";
    
    AKTestPersonSubclass *personB = [AKTestPersonSubclass descendantOf:personA];
    personB.firstName = @"Harry";
    personB.birthDate = [dateFormatter dateFromString:@"1980/07/31"];
    
    XCTAssertEqualObjects(personB.firstName, @"HARRY");
    XCTAssertEqualObjects(personB.lastName, @"Potter");
    XCTAssertEqualObjects(personB.birthDate, [dateFormatter dateFromString:@"1980/07/31"]);
}

- (void)testBaseClassInheritFromSubclass
{
    NSDateFormatter *dateFormatter = [[self class] dateFormatter];
    
    AKTestPersonSubclass *personA = [AKTestPersonSubclass new];
    personA.firstName = @"Harry";
    personA.lastName = @"Potter";
    personA.birthDate = [dateFormatter dateFromString:@"1980/07/31"];
    
    AKTestPerson *personB = [AKTestPerson descendantOf:personA];
    personB.firstName = @"Lily";
    
    XCTAssertEqualObjects(personB.firstName, @"Lily");
    XCTAssertEqualObjects(personB.lastName, @"Potter");
    XCTAssertThrows([(id)personB birthDate]);
}

- (void)testSubclassProperties
{
    NSDateFormatter *dateFormatter = [[self class] dateFormatter];
    
    AKTestPersonSubclass *personA = [AKTestPersonSubclass new];
    personA.firstName = @"James";
    personA.lastName = @"Potter";
    
    AKTestPersonSubclass *personB = [personA descendant];
    personB.firstName = @"Harry";
    personB.birthDate = [dateFormatter dateFromString:@"1980/07/31"];
    
    XCTAssertEqualObjects(personA.firstName, @"JAMES");
    XCTAssertEqualObjects(personB.firstName, @"HARRY");
    XCTAssertEqualObjects(personB.lastName, @"Potter");
    XCTAssertEqualObjects(personB.birthDate, [dateFormatter dateFromString:@"1980/07/31"]);
}


#pragma mark - Performance tests

- (void)testInitWithWithKVC
{
    AKTestPerson *baseDescendant = [AKTestPerson new];
    
    [self measureBlock:^{
        AKTestPerson *person = [[AKTestPerson alloc] initWithAncestor:baseDescendant inheritKeyValueNotifications:YES];
    }];
}

- (void)testInitWithoutKVC
{
    AKTestPerson *baseDescendant = [AKTestPerson new];
    
    [self measureBlock:^{
        AKTestPerson *person = [[AKTestPerson alloc] initWithAncestor:baseDescendant inheritKeyValueNotifications:NO];
    }];
}

@end
