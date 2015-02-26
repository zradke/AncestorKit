//
//  AKPropertyDescription.h
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/**
 *  Enumeration of possible property value types.
 */
typedef NS_ENUM(NSInteger, AKPropertyType){
    /**
     *  The property type is unknown. This may occur if the property is a struct or union, neither of which AKPropertyDescription supports.
     */
    AKPropertyTypeUnknown = 0,
    /**
     *  The property is a char.
     */
    AKPropertyTypeChar,
    /**
     *  The property is an int.
     */
    AKPropertyTypeInt,
    /**
     *  The property is a short.
     */
    AKPropertyTypeShort,
    /**
     *  The property is a long.
     */
    AKPropertyTypeLong,
    /**
     *  The property is a long long.
     */
    AKPropertyTypeLongLong,
    /**
     *  The property is an unsigned char.
     */
    AKPropertyTypeUnsignedChar,
    /**
     *  The property is an unsigned int.
     */
    AKPropertyTypeUnsignedInt,
    /**
     *  The property is an unsigned short.
     */
    AKPropertyTypeUnsignedShort,
    /**
     *  The property is an unsigned long.
     */
    AKPropertyTypeUnsignedLong,
    /**
     *  The property is an unsigned long long.
     */
    AKPropertyTypeUnsignedLongLong,
    /**
     *  The property is a float.
     */
    AKPropertyTypeFloat,
    /**
     *  The property is a double.
     */
    AKPropertyTypeDouble,
    /**
     *  The property is a BOOL.
     */
    AKPropertyTypeBool,
    /**
     *  The property is a block.
     */
    AKPropertyTypeBlock,
    /**
     *  The property is an object.
     */
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

/**
 *  Returns the property's name. This is what is used for key-value coding.
 */
@property (copy, nonatomic, readonly) NSString *propertyName;

/**
 *  Returns the property's attribute string. For more details see property_getAttributes.
 */
@property (copy, nonatomic, readonly) NSString *propertyAttributesString;

/**
 *  Returns the property's type string. The UTF8 version of this string can be @encode compared to determine the type.
 */
@property (copy, nonatomic, readonly) NSString *propertyTypeString;

/**
 *  Returns the type of the property as described by the AKPropertyType enum. Note that this enum does not account for structs or unions. For those types, please consult the propertyTypeString directly.
 */
@property (assign, nonatomic, readonly) AKPropertyType propertyType;

/**
 *  If the property is an object property with a distinct class, this will return that class. Otherwise, this will return nil.
 */
@property (copy, nonatomic, readonly) Class propertyClass;

/**
 *  YES if the property is read only. NO if it is read-write.
 */
@property (assign, nonatomic, readonly) BOOL isReadonly;

/**
 *  YES if the property will attempt to copy values when setting them. NO if it will not. Note that this only applies to object types, and may apply to read only properties.
 */
@property (assign, nonatomic, readonly) BOOL isCopy;

/**
 *  YES if the property will retain its values, NO if the value is unretained.
 */
@property (assign, nonatomic, readonly) BOOL isRetained;

/**
 *  YES if the property is not atomic, NO if the property is atomic.
 */
@property (assign, nonatomic, readonly) BOOL isNonatomic;

/**
 *  YES if the property's getter and setter are dynamically generated, NO if they are not.
 */
@property (assign, nonatomic, readonly) BOOL isDynamic;

/**
 *  YES if the property weakly retains its values, NO if they are not.
 */
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
