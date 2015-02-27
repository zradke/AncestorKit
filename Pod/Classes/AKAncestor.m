//
//  AKAncestor.m
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "AKAncestor.h"
#import "AKPropertyDescription.h"
#import <objc/runtime.h>

NSString *const AKAncestorNonObjectPropertyException = @"AKAncestorNonObjectPropertyException";
NSString *const AKAncestorUnknownPropertyException = @"AKAncestorUnknownPropertyException";

static void *AKAncestorKVOContext = &AKAncestorKVOContext;

@interface AKAncestor ()

@property (strong, nonatomic, readonly) NSRecursiveLock *ak_lock;
@property (strong, nonatomic, readonly) NSMutableSet *ak_ignoredPropertyNames;

@end

@implementation AKAncestor

+ (void)initialize
{
    // We iterate through all the inherited properties and use them to create swizzled getters and setters. Note that we do the swizzling in +initialize so that every subclass of AKAncestor has this called on their own class with their own properties.
    for (AKPropertyDescription *property in [self propertiesPassedToDescendants])
    {
        [self _swizzleGetterForObjectProperty:property];
    }
}

#pragma mark - Lifecyle

+ (instancetype)descendantOf:(AKAncestor *)ancestor
{
    return [[self alloc] initWithAncestor:ancestor inheritKeyValueNotifications:ancestor.inheritsKeyValueNotifications];
}

- (instancetype)initWithAncestor:(AKAncestor *)ancestor inheritKeyValueNotifications:(BOOL)shouldInheritKeyValueNotifications
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _ancestor = ancestor;
    _ak_lock = [NSRecursiveLock new];
    _ak_ignoredPropertyNames = [NSMutableSet set];
    
    _inheritsKeyValueNotifications = shouldInheritKeyValueNotifications;
    if (_inheritsKeyValueNotifications && _ancestor)
    {
        [self _setupKeyValueObservationsOnAncestor:_ancestor];
    }
    
    return self;
}

- (instancetype)init
{
    return [self initWithAncestor:nil inheritKeyValueNotifications:YES];
}

- (instancetype)descendant
{
    return [self descendantInheritingKeyValueNotifications:self.inheritsKeyValueNotifications];
}

- (instancetype)descendantInheritingKeyValueNotifications:(BOOL)shouldInheritKeyValueNotifications
{
    return [[[self class] alloc] initWithAncestor:self inheritKeyValueNotifications:shouldInheritKeyValueNotifications];
}

- (void)dealloc
{
    if (_inheritsKeyValueNotifications && _ancestor)
    {
        [self _removeKeyValueObservationsOnAncestor:_ancestor];
    }
}


#pragma mark - Limiting property inheritance

- (void)stopInheritingValuesForPropertyName:(NSString *)propertyName
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", NSStringFromSelector(@selector(propertyName)), propertyName];
    if ([[[self class] propertiesPassedToDescendants] filteredSetUsingPredicate:predicate].count == 0)
    {
        [NSException raise:AKAncestorUnknownPropertyException format:@"No property with the name \"%@\" is being inherited by %@.", propertyName, [self class]];
    }
    
    [self.ak_lock lock];
    [self.ak_ignoredPropertyNames addObject:propertyName];
    [self.ak_lock unlock];
}

- (void)resumeInheritingValuesForPropertyName:(NSString *)propertyName
{
    [self.ak_lock lock];
    [self.ak_ignoredPropertyNames removeObject:propertyName];
    [self.ak_lock unlock];
}

- (NSSet *)propertiesIgnoringInheritedValues
{
    [self.ak_lock lock];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", NSStringFromSelector(@selector(propertyName)), self.ak_ignoredPropertyNames];
    [self.ak_lock unlock];
    
    return [[[self class] propertiesPassedToDescendants] filteredSetUsingPredicate:predicate];
}

+ (NSSet *)propertiesPassedToDescendants
{
    NSArray *acceptablePropertyTypes = @[@(AKPropertyTypeBlock), @(AKPropertyTypeObject)];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", NSStringFromSelector(@selector(propertyType)), acceptablePropertyTypes];
    return [[self _allInheritedProperties] filteredSetUsingPredicate:predicate];
}


#pragma mark - NSObject

- (NSString *)description
{
    return [self descriptionWithLocale:[NSLocale currentLocale] indent:0];
}

- (NSString *)debugDescription
{
    return [self descriptionWithLocale:[NSLocale currentLocale] indent:0];
}

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@:%p>", [self class], self];
    
    NSString *padding = [@"" stringByPaddingToLength:(level + 1) withString:@"\t" startingAtIndex:0];
    
    NSString *inheritedPropertiesDescription = [self _descriptionOfInheritedPropertiesWithLocale:locale indent:level];
    if (inheritedPropertiesDescription.length > 0)
    {
        [description appendFormat:@"\n%@Properties", padding];
        [description appendString:inheritedPropertiesDescription];
    }
    
    if (self.ancestor)
    {
        [description appendFormat:@"\n%@Ancestor ", padding];
        [description appendString:[[self class] _descriptionOfValue:self.ancestor withLocale:locale indent:level]];
    }
    
    return [description copy];
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != AKAncestorKVOContext)
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    [self.ak_lock lock];
    BOOL isIgnoredProperty = [self.ak_ignoredPropertyNames containsObject:keyPath];
    [self.ak_lock unlock];
    
    // If we're ignoring inheritance on this property, then it's value won't change with key value notifications
    if (isIgnoredProperty)
    {
        return;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", NSStringFromSelector(@selector(propertyName)), keyPath];
    AKPropertyDescription *property = [[[[self class] propertiesPassedToDescendants] filteredSetUsingPredicate:predicate] anyObject];
    
    if (!property)
    {
        // Somehow we're observing an unknown property!
        [NSException raise:AKAncestorUnknownPropertyException format:@"No property was found on %@ with the name \"%@\" despite it having key-value observations set.", [self class], keyPath];
        
        [object removeObserver:self forKeyPath:keyPath context:context];
        return;
    }
    
    SEL swizzledGetter = [[self class] _swizzledGetterForProperty:property];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:swizzledGetter]];
    [invocation setSelector:swizzledGetter];
    
    __unsafe_unretained id existingValue;
    [invocation invokeWithTarget:self];
    [invocation getReturnValue:&existingValue];
    
    // There is an override, so we can ignore the ancestor's key value notification
    if (existingValue)
    {
        return;
    }
    
    BOOL isPriorToChange = [change[NSKeyValueChangeNotificationIsPriorKey] boolValue];
    if (isPriorToChange)
    {
        [self willChangeValueForKey:keyPath];
    }
    else
    {
        id newValue = change[NSKeyValueChangeNewKey];
        id oldValue = change[NSKeyValueChangeOldKey];
        
        if ((newValue || oldValue) && (!oldValue || ![newValue isEqual:oldValue]))
        {
            [self didChangeValueForKey:keyPath];
        }
    }
}


#pragma mark - Private

- (void)_setupKeyValueObservationsOnAncestor:(AKAncestor *)ancestor
{
    NSParameterAssert(ancestor);
    
    NSMutableSet *propertiesToObserve = [NSMutableSet setWithSet:[[self class] propertiesPassedToDescendants]];
    [propertiesToObserve intersectSet:[[ancestor class] propertiesPassedToDescendants]];
    
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionPrior|NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld;
    for (AKPropertyDescription *propertyDescription in propertiesToObserve)
    {
        [ancestor addObserver:self forKeyPath:propertyDescription.propertyName options:options context:AKAncestorKVOContext];
    }
}

- (void)_removeKeyValueObservationsOnAncestor:(AKAncestor *)ancestor
{
    NSParameterAssert(ancestor);
    
    NSMutableSet *propertiesToObserve = [NSMutableSet setWithSet:[[self class] propertiesPassedToDescendants]];
    [propertiesToObserve intersectSet:[[ancestor class] propertiesPassedToDescendants]];
    
    for (AKPropertyDescription *propertyDescription in propertiesToObserve)
    {
        [ancestor removeObserver:self forKeyPath:propertyDescription.propertyName context:AKAncestorKVOContext];
    }
}

- (NSString *)_descriptionOfInheritedPropertiesWithLocale:(id)locale indent:(NSUInteger)level
{
    NSMutableString *description = [NSMutableString string];
    
    NSSet *propertyNames = [[[self class] _allInheritedProperties] valueForKey:NSStringFromSelector(@selector(propertyName))];
    NSArray *sortedPropertyNames = [[propertyNames allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    id propertyValue;
    for (NSString *propertyName in sortedPropertyNames)
    {
        propertyValue = [self valueForKey:propertyName];
        if (propertyValue)
        {
            NSUInteger whitespaceLength = [@"\t" length] * (level + 2);
            NSString *padding = [@"" stringByPaddingToLength:whitespaceLength withString:@"\t" startingAtIndex:0];
            NSString *valueDescription = [[self class] _descriptionOfValue:propertyValue withLocale:locale indent:level];
            
            [description appendFormat:@"\n%@%@: %@,", padding, propertyName, valueDescription];
        }
    }
    
    return description;
}

+ (NSString *)_descriptionOfValue:(id)value withLocale:(id)locale indent:(NSUInteger)level
{
    NSString *valueDescription;
    if ([value isKindOfClass:[NSString class]])
    {
        valueDescription = value;
    }
    else if ([value respondsToSelector:@selector(descriptionWithLocale:indent:)])
    {
        valueDescription = [value descriptionWithLocale:locale indent:(level + 1)];
    }
    else if ([value respondsToSelector:@selector(descriptionWithLocale:)])
    {
        valueDescription = [value descriptionWithLocale:locale];
    }
    else
    {
        valueDescription = [value description];
    }
    
    if (!valueDescription)
    {
        valueDescription = [NSString stringWithFormat:@"<%@:%p>", [value class], value];
    }
    
    return valueDescription;
}

+ (NSSet *)_definedProperties
{
    NSSet *properties = objc_getAssociatedObject(self, _cmd);
    if (properties)
    {
        return properties;
    }
    
    NSMutableSet *mutableProperties = [NSMutableSet set];
    
    unsigned int count = 0;
    objc_property_t *primitiveProperties = class_copyPropertyList([self class], &count);
    
    if (primitiveProperties)
    {
        for (unsigned int i = 0; i < count; i++)
        {
            AKPropertyDescription *propertyDescription = [[AKPropertyDescription alloc] initWithProperty:primitiveProperties[i]];
            [mutableProperties addObject:propertyDescription];
        }
        
        free(primitiveProperties);
    }
    
    properties = [mutableProperties copy];
    objc_setAssociatedObject(self, _cmd, properties, OBJC_ASSOCIATION_COPY);
    return properties;
}

+ (NSSet *)_allInheritedProperties
{
    NSSet *properties = objc_getAssociatedObject(self, _cmd);
    if (properties)
    {
        return properties;
    }
    
    NSMutableSet *mutableProperties = [NSMutableSet set];
    
    Class currentClass = self;
    while (currentClass && currentClass != [AKAncestor class])
    {
        [mutableProperties unionSet:[currentClass _definedProperties]];
        currentClass = [currentClass superclass];
    }
    
    properties = [mutableProperties copy];
    objc_setAssociatedObject(self, _cmd, properties, OBJC_ASSOCIATION_COPY);
    return properties;
}

+ (SEL)_swizzledGetterForProperty:(AKPropertyDescription *)property
{
    NSString *selectorString = [NSString stringWithFormat:@"_ak_%@", NSStringFromSelector(property.propertyGetter)];
    return NSSelectorFromString(selectorString);
}

+ (void)_swizzleGetterForObjectProperty:(AKPropertyDescription *)property
{
    NSParameterAssert(property);
    
    if (!property.propertyType == AKPropertyTypeObject)
    {
        [NSException raise:AKAncestorNonObjectPropertyException format:@"Property \"%@\" is not an object property and cannot be inherited by %@", property.propertyName, self];
        return;
    }
    
    SEL originalGetter = property.propertyGetter;
    SEL swizzledGetter = [self _swizzledGetterForProperty:property];
    
    Method originalMethod = class_getInstanceMethod([self class], originalGetter);
    Method swizzledMethod = class_getInstanceMethod([self class], swizzledGetter);
    
    // We only swizzle each property once, so if a method has been registered we bail early
    if (swizzledMethod)
    {
        return;
    }
    
    IMP originalImplementation = class_getMethodImplementation([self class], originalGetter);
    
    NSString *propertyName = property.propertyName;
    IMP swizzledImplementation = imp_implementationWithBlock(^id (id s) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[s methodSignatureForSelector:swizzledGetter]];
        
        // Using the swizzled getter will act as though we are retreiving the property normally.
        [invocation setSelector:swizzledGetter];
        [invocation invokeWithTarget:s];
        
        __unsafe_unretained id returnValue;
        [invocation getReturnValue:&returnValue];
        
        [[s ak_lock] lock];
        BOOL isIgnoredProperty = [[s ak_ignoredPropertyNames] containsObject:propertyName];
        [[s ak_lock] unlock];
        
        // If there isn't a return value, we'll check the ancestor for a value
        if (!returnValue && [s ancestor] && !isIgnoredProperty)
        {
            // Note that we change the selector to the original getter, this ensures that if the ancestor doesn't have a value it can continue down the chain.
            [invocation setSelector:originalGetter];
            [invocation invokeWithTarget:[s ancestor]];
            [invocation getReturnValue:&returnValue];
        }
        
        return returnValue;
    });
    
    // Though this really shouldn't happen, first we try and add a method with the original selector to this class.
    if (!class_addMethod([self class], originalGetter, swizzledImplementation, method_getTypeEncoding(originalMethod)))
    {
        // If we couldn't add the method because it was already part of this class, then we simply replace the original implementation with our swizzled one.
        originalImplementation = class_replaceMethod([self class], originalGetter, swizzledImplementation, method_getTypeEncoding(originalMethod));
    }
    
    // Either way, this should be the first time we add the swizzled selector.
    class_addMethod([self class], swizzledGetter, originalImplementation, method_getTypeEncoding(originalMethod));
}

@end
