//
//  AKPropertyDescription.m
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "AKPropertyDescription.h"

AKPropertyType AKPropertyTypeFromTypeString(NSString *propertyTypeString)
{
    const char *type = [propertyTypeString UTF8String];
    if (strcmp(type, @encode(char)) == 0)
    {
        return AKPropertyTypeChar;
    }
    if (strcmp(type, @encode(int)) == 0)
    {
        return AKPropertyTypeInt;
    }
    if (strcmp(type, @encode(short)) == 0)
    {
        return AKPropertyTypeShort;
    }
    if (strcmp(type, @encode(long)) == 0)
    {
        return AKPropertyTypeLong;
    }
    if (strcmp(type, @encode(long long)) == 0)
    {
        return AKPropertyTypeLongLong;
    }
    if (strcmp(type, @encode(unsigned char)) == 0)
    {
        return AKPropertyTypeUnsignedChar;
    }
    if (strcmp(type, @encode(unsigned int)) == 0)
    {
        return AKPropertyTypeUnsignedInt;
    }
    if (strcmp(type, @encode(unsigned short)) == 0)
    {
        return AKPropertyTypeUnsignedShort;
    }
    if (strcmp(type, @encode(unsigned long)) == 0)
    {
        return AKPropertyTypeUnsignedLong;
    }
    if (strcmp(type, @encode(unsigned long long)) == 0)
    {
        return AKPropertyTypeUnsignedLongLong;
    }
    if (strcmp(type, @encode(float)) == 0)
    {
        return AKPropertyTypeFloat;
    }
    if (strcmp(type, @encode(double)) == 0)
    {
        return AKPropertyTypeDouble;
    }
    if (strcmp(type, @encode(_Bool)) == 0)
    {
        return AKPropertyTypeBool;
    }
    if (strstr(type, @encode(dispatch_block_t)) != NULL)
    {
        return AKPropertyTypeBlock;
    }
    if (strstr(type, @encode(id)) != NULL || strstr(type, @encode(Class)) != NULL)
    {
        return AKPropertyTypeObject;
    }
    
    return AKPropertyTypeUnknown;
};

Class AKPropertyClassFromTypeString(NSString *propertyTypeString)
{
    NSMutableCharacterSet *validClassCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
    [validClassCharacters removeCharactersInString:@"@\"<>"];
    
    NSArray *explodedType = [propertyTypeString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@\""]];
    
    NSString *cleanedEncoding = [explodedType componentsJoinedByString:@""];
    
    NSScanner *scanner = [NSScanner scannerWithString:cleanedEncoding];
    NSString *protocolEncoding = nil;
    [scanner scanUpToString:@"<" intoString:NULL];
    [scanner scanUpToString:@">" intoString:&protocolEncoding];
    
    if (protocolEncoding)
    {
        protocolEncoding = [protocolEncoding stringByAppendingString:@">"];
        cleanedEncoding = [cleanedEncoding stringByReplacingOccurrencesOfString:protocolEncoding withString:@""];
    }
    
    if (!cleanedEncoding || cleanedEncoding.length == 0) { return NULL; }
    
    return NSClassFromString(cleanedEncoding);
}

@implementation AKPropertyDescription

- (instancetype)initWithProperty:(objc_property_t)property
{
    NSParameterAssert(property);
    
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _propertyName = [NSString stringWithUTF8String:property_getName(property)];
    _propertyAttributesString = [NSString stringWithUTF8String:property_getAttributes(property)];
    
    NSArray *attributes = [_propertyAttributesString componentsSeparatedByString:@","];
    
    _propertyTypeString = [attributes.firstObject substringFromIndex:1];
    _propertyType = AKPropertyTypeFromTypeString(_propertyTypeString);
    
    if (_propertyType == AKPropertyTypeObject)
    {
        _propertyClass = AKPropertyClassFromTypeString(_propertyTypeString);
    }
    
    _isReadonly = [attributes containsObject:@"R"];
    _isCopy = [attributes containsObject:@"C"];
    _isRetained = [attributes containsObject:@"&"];
    _isNonatomic = [attributes containsObject:@"N"];
    _isDynamic = [attributes containsObject:@"D"];
    _isWeak = [attributes containsObject:@"W"];
    
    NSString *getterAttribute = [[attributes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", @"G"]] firstObject];
    if (getterAttribute)
    {
        getterAttribute = [getterAttribute substringFromIndex:1];
    }
    else
    {
        getterAttribute = _propertyName;
    }
    _propertyGetter = NSSelectorFromString(getterAttribute);
    
    NSString *setterAttribute = [[attributes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", @"S"]] firstObject];
    if (setterAttribute)
    {
        setterAttribute = [setterAttribute substringFromIndex:1];
    }
    else
    {
        setterAttribute = [NSString stringWithFormat:@"set%@%@:", [[_propertyName substringToIndex:1] uppercaseString], [_propertyName substringFromIndex:1]];
    }
    _propertySetter = NSSelectorFromString(setterAttribute);
    
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithProperty:nil];
}

- (NSString *)description
{
    return [self debugDescription];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@:%p> name: %@, attributes: %@", [self class], self, self.propertyName, self.propertyAttributesString];
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    else if (![object isKindOfClass:[self class]])
    {
        return NO;
    }
    
    return [self isEqualToProperty:object];
}

- (BOOL)isEqualToProperty:(AKPropertyDescription *)propertyDescription
{
    if (!propertyDescription)
    {
        return NO;
    }
    
    return [self.propertyName isEqualToString:propertyDescription.propertyName] && [self.propertyAttributesString isEqualToString:propertyDescription.propertyAttributesString];
}

- (NSUInteger)hash
{
    return self.propertyName.hash ^ self.propertyAttributesString.hash;
}

@end
