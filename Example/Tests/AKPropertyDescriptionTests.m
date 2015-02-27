//
//  AKPropertyDescriptionTests.m
//  AncestorKit
//
//  Created by Zachary Radke | AMDU on 2/26/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AncestorKit/AncestorKit.h>

typedef struct AKTestStruct
{
    int structId;
    char *structName;
} AKTestStruct;

@interface AKPropertyDescriptionTests : XCTestCase

@property (assign) char charProp;
@property (assign) int intProp;
@property (assign) short shortProp;
@property (assign) long longProp;

@property (assign) unsigned char uCharProp;
@property (assign) unsigned int uIntProp;
@property (assign) unsigned short uShortProp;
@property (assign) unsigned long uLongProp;

@property (assign) float floatProp;
@property (assign) double doubleProp;
@property (assign) BOOL boolProp;
@property (copy) void (^blockProp)(int, NSError *);
@property (strong) id objProp;
@property (assign) Class classProp;
@property (assign) AKTestStruct structProp;

@property (strong) NSString *classTypeProp;
@property (strong) id<NSObject> protocolTypeProp;
@property (strong, nonatomic, readonly) id nonatomicReadonlyProp;
@property (copy) NSString *copyableProp;
@property (assign) NSInteger unretainedProp;
@property (strong) id dynamicProp;
@property (weak) id weakProp;
@property (assign, getter=customGetter, setter=customSetter:) BOOL customSelectorProp;
@property (assign) BOOL defaultSelectorProp;
@property (assign) BOOL customIvarProp;

@end

@implementation AKPropertyDescriptionTests
@dynamic dynamicProp;
@synthesize customIvarProp = _custom_ivar_prop;

- (id)dynamicProp
{
    return nil;
}

- (void)setDynamicProp:(id)dynamicProp
{}

+ (AKPropertyDescription *)_propertyDescriptionForName:(NSString *)propertyName
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", NSStringFromSelector(@selector(propertyName)), propertyName];
    NSSet *propertyDescriptions = [AKPropertyDescription propertyDescriptionsOfClass:[self class]];
    return [[propertyDescriptions filteredSetUsingPredicate:predicate] anyObject];
}

- (void)testPropertiesOfClass
{
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    free(properties);
    
    NSSet *propertyDescriptions = [AKPropertyDescription propertyDescriptionsOfClass:[self class]];
    
    XCTAssertEqual(propertyDescriptions.count, count);
}

- (void)testPropertyTypes
{
    AKPropertyDescription *prop;
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(charProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeChar);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(intProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeInt);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(shortProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeShort);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(longProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeLong);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(uCharProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeUnsignedChar);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(uIntProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeUnsignedInt);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(uShortProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeUnsignedShort);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(uLongProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeUnsignedLong);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(floatProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeFloat);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(doubleProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeDouble);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(boolProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeBool);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(blockProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeBlock);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(objProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeObject);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeObject);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(structProp))];
    XCTAssertEqual(prop.propertyType, AKPropertyTypeUnknown);
}

- (void)testIvarName
{
    AKPropertyDescription *prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(customIvarProp))];
    XCTAssertEqualObjects(prop.propertyIvarName, @"_custom_ivar_prop");
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(objProp))];
    XCTAssertEqualObjects(prop.propertyIvarName, @"_objProp");
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(dynamicProp))];
    XCTAssertNil(prop.propertyIvarName);
}

- (void)testClassType
{
    AKPropertyDescription *prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classTypeProp))];
    XCTAssertEqual(prop.propertyClass, [NSString class]);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(objProp))];
    XCTAssertNil(prop.propertyClass);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(protocolTypeProp))];
    XCTAssertNil(prop.propertyClass);
}

- (void)testAtomicity
{
    AKPropertyDescription *prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classTypeProp))];
    XCTAssertFalse(prop.isNonatomic);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(nonatomicReadonlyProp))];
    XCTAssertTrue(prop.isNonatomic);
}

- (void)testStorage
{
    AKPropertyDescription *prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classTypeProp))];
    XCTAssertTrue(prop.isRetained);
    XCTAssertFalse(prop.isCopy);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(copyableProp))];
    XCTAssertFalse(prop.isRetained);
    XCTAssertTrue(prop.isCopy);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(unretainedProp))];
    XCTAssertFalse(prop.isRetained);
    XCTAssertFalse(prop.isCopy);
}

- (void)testReadonly
{
    AKPropertyDescription *prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classTypeProp))];
    XCTAssertFalse(prop.isReadonly);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(nonatomicReadonlyProp))];
    XCTAssertTrue(prop.isReadonly);
}

- (void)testDynamic
{
    AKPropertyDescription *prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classTypeProp))];
    XCTAssertFalse(prop.isDynamic);
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(dynamicProp))];
    XCTAssertTrue(prop.isDynamic);
}

- (void)testCustomAccessors
{
    AKPropertyDescription *prop = [[self class] _propertyDescriptionForName:@"customSelectorProp"];
    XCTAssertEqual(prop.propertyGetter, NSSelectorFromString(@"customGetter"));
    XCTAssertEqual(prop.propertySetter, NSSelectorFromString(@"customSetter:"));
    
    prop = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(defaultSelectorProp))];
    XCTAssertEqual(prop.propertyGetter, @selector(defaultSelectorProp));
    XCTAssertEqual(prop.propertySetter, NSSelectorFromString(@"setDefaultSelectorProp:"));
}

- (void)testCopy
{
    AKPropertyDescription *propA = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classTypeProp))];
    AKPropertyDescription *propB = [propA copy];
    
    XCTAssertEqualObjects(propA, propB);
}

- (void)testCoding
{
    AKPropertyDescription *propA = [[self class] _propertyDescriptionForName:NSStringFromSelector(@selector(classTypeProp))];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:propA];
    AKPropertyDescription *propB = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertEqualObjects(propA, propB);
}

@end
