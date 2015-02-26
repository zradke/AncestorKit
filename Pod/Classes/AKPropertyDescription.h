//
//  AKPropertyDescription.h
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, AKPropertyType)
{
    AKPropertyTypeUnknown = 0,
    AKPropertyTypeChar,
    AKPropertyTypeInt,
    AKPropertyTypeShort,
    AKPropertyTypeLong,
    AKPropertyTypeLongLong,
    AKPropertyTypeUnsignedChar,
    AKPropertyTypeUnsignedInt,
    AKPropertyTypeUnsignedShort,
    AKPropertyTypeUnsignedLong,
    AKPropertyTypeUnsignedLongLong,
    AKPropertyTypeFloat,
    AKPropertyTypeDouble,
    AKPropertyTypeBool,
    AKPropertyTypeBlock,
    AKPropertyTypeObject
};

/**
 *  Class which provides a description of an Objective-C property for easier use when introspecting code.
 */
@interface AKPropertyDescription : NSObject

/**
 *  Designated initializer. Initializes the receiver with property attributes taken from the given primitive type.
 *
 *  @param property The primitive property type to extract information from. This must not be nil.
 *
 *  @return An initialized instance of the receiver.
 */
- (instancetype)initWithProperty:(objc_property_t)property NS_DESIGNATED_INITIALIZER;

@property (copy, nonatomic, readonly) NSString *propertyName;
@property (copy, nonatomic, readonly) NSString *propertyAttributesString;

@property (copy, nonatomic, readonly) NSString *propertyTypeString;
@property (assign, nonatomic, readonly) AKPropertyType propertyType;

/**
 *  If the property is an object property with a distinct class, this will return that class. Otherwise, this will return nil.
 */
@property (copy, nonatomic, readonly) Class propertyClass;

@property (assign, nonatomic, readonly) BOOL isReadonly;
@property (assign, nonatomic, readonly) BOOL isCopy;
@property (assign, nonatomic, readonly) BOOL isRetained;
@property (assign, nonatomic, readonly) BOOL isNonatomic;
@property (assign, nonatomic, readonly) BOOL isDynamic;
@property (assign, nonatomic, readonly) BOOL isWeak;

/**
 *  Returns the selector used as the getter for this property. If a custom getter is provided it will be used. Otherwise, the property name is converted into a selector.
 */
@property (assign, nonatomic, readonly) SEL propertyGetter;

/**
 *  Returns the selector used as the setter for this property. If a custom setter is provided it will be used. Otherwise, the property name's first letter is uppercased then prepended by "set" and appended with ":" then converted into a selector.
 */
@property (assign, nonatomic, readonly) SEL propertySetter;

/**
 *  Checks if two property descriptions are equal. This is determined by comparing their names and attribute strings.
 *
 *  @param propertyDescription The property description to compare against.
 *
 *  @return YES if the properties described are the same, or NO if they are different.
 */
- (BOOL)isEqualToProperty:(AKPropertyDescription *)propertyDescription;

@end
