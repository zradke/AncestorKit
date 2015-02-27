//
//  AKAncestorTests.m
//  AncestorKit
//
//  Created by Zachary Radke | AMDU on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <AncestorKit/AncestorKit.h>
#import <XCTest/XCTest.h>
#import "AKTestPerson.h"
#import "AKTestPersonSubclass.h"

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

@end
