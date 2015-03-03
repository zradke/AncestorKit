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
#import <libkern/OSAtomic.h>

NSString *const AKAncestorNonObjectPropertyException = @"AKAncestorNonObjectPropertyException";
NSString *const AKAncestorUnknownPropertyException = @"AKAncestorUnknownPropertyException";

static void *AKAncestorKVOContext = &AKAncestorKVOContext;

@interface AKAncestor ()
{
    // Spin locks require using an Ivar or a static variable, so unfortunately we can't enjoy property goodness here.
    OSSpinLock _ak_spinLock;
}

@property (strong, nonatomic, readonly) NSMutableSet *ak_ignoredPropertyNames;

@end

@implementation AKAncestor

#pragma mark - Swizzling

static NSArray *AKAncestorSubclasses()
{
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    NSMutableArray *subclasses = [NSMutableArray array];
    for (unsigned int i = 0; i < classCount; i++)
    {
        Class class = classes[i];
        
        if (class == [AKAncestor class])
        {
            continue;
        }
        
        BOOL shouldAddClass = NO;
        Class currentClass = class;
        while (currentClass)
        {
            if (currentClass == [AKAncestor class])
            {
                shouldAddClass = YES;
                break;
            }
            
            currentClass = class_getSuperclass(currentClass);
        }
        
        if (!shouldAddClass)
        {
            continue;
        }
        
        // The order of these classes is important only in the case of subclasses. If ClassA is a subclass of AKAncestor, and ClassB is a subclass of ClassA, then ClassA's properties must be swizzled before ClassB's. However, if ClassC is also a direct subclass of AKAncestor, it doesn't matter whether its properties are swizzled before ClassA or ClassB. If this isn't done, and ClassB's properties are swizzled before ClassA, then ClassB's property implementations will be an infinite loop due to double swizzling. We could fix this by only swizzling the result of -intersectSet: between the class' +propertiesPassedToDescendants and it's defined properties, but this would prevent users from adding to +propertiesPassedToDescendants which may be too hand-holdy.
        NSInteger insertionIndex = 0;
        Class superclass = class_getSuperclass(class);
        while (superclass && superclass != [AKAncestor class])
        {
            NSInteger foundIndex = [subclasses indexOfObject:superclass];
            if (foundIndex != NSNotFound && (foundIndex + 1) > insertionIndex)
            {
                insertionIndex = (foundIndex + 1);
            }
            
            superclass = class_getSuperclass(superclass);
        }
        
        [subclasses insertObject:class atIndex:insertionIndex];
    }
    
    return subclasses;
}

static SEL AKAncestorSwizzledPropertyGetter(AKPropertyDescription *property)
{
    NSCParameterAssert(property);
    
    NSString *selectorString = [NSString stringWithFormat:@"_ak_%@", NSStringFromSelector(property.propertyGetter)];
    return NSSelectorFromString(selectorString);
}

static void AKAncestorSwizzlePropertyGetter(Class class, AKPropertyDescription *property)
{
    NSCParameterAssert(class);
    NSCParameterAssert(property);
    
    if (property.propertyType != AKPropertyTypeObject)
    {
        [NSException raise:AKAncestorNonObjectPropertyException format:@"Property \"%@\" is not an object property and cannot be inherited by %@", property.propertyName, class];
        return;
    }
    
    SEL originalGetter = property.propertyGetter;
    SEL swizzledGetter = AKAncestorSwizzledPropertyGetter(property);
    
    Method originalMethod = class_getInstanceMethod(class, originalGetter);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledGetter);
    
    // We only swizzle each property once, so if a method has been registered we bail early
    if (swizzledMethod)
    {
        return;
    }
    
    IMP originalImplementation = class_getMethodImplementation(class, originalGetter);
    
    NSString *propertyName = property.propertyName;
    IMP swizzledImplementation = imp_implementationWithBlock(^id (id self) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:swizzledGetter]];
        
        // Using the swizzled getter will act as though we are retreiving the property normally.
        [invocation setSelector:swizzledGetter];
        [invocation invokeWithTarget:self];
        
        __unsafe_unretained id returnValue;
        [invocation getReturnValue:&returnValue];
        
        OSSpinLockLock(&((AKAncestor *)self)->_ak_spinLock);
        BOOL isIgnoredProperty = [[self ak_ignoredPropertyNames] containsObject:propertyName];
        OSSpinLockUnlock(&((AKAncestor *)self)->_ak_spinLock);
        
        // If there isn't a return value, we'll check the ancestor for a value
        if (!returnValue && [self ancestor] && !isIgnoredProperty)
        {
            // Note that we change the selector to the original getter, this ensures that if the ancestor doesn't have a value it can continue down the chain.
            [invocation setSelector:originalGetter];
            [invocation invokeWithTarget:[self ancestor]];
            [invocation getReturnValue:&returnValue];
        }
        
        return returnValue;
    });
    
    // Though this really shouldn't happen, first we try and add a method with the original selector to the class.
    if (!class_addMethod(class, originalGetter, swizzledImplementation, method_getTypeEncoding(originalMethod)))
    {
        // If we couldn't add the method because it was already part of the class, then we simply replace the original implementation with our swizzled one.
        originalImplementation = class_replaceMethod(class, originalGetter, swizzledImplementation, method_getTypeEncoding(originalMethod));
    }
    
    // Either way, this should be the first time we add the swizzled selector.
    class_addMethod(class, swizzledGetter, originalImplementation, method_getTypeEncoding(originalMethod));
}

+ (void)load
{
    // Following the wisdom of http://nshipster.com/method-swizzling/ we put all swizzling in +load and a dispatch_once block
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // Following the wisdom of https://www.mikeash.com/pyblog/friday-qa-2009-05-22-objective-c-class-loading-and-initialization.html we wrap this in an autorelease pool since we're creating autoreleased objects in it.
        @autoreleasepool {
            
            // We iterate through each subclass of AKAncestor and swizzle it's properties' getter methods.
            for (Class subclass in AKAncestorSubclasses())
            {
                NSSet *propertiesToSwizzle = [subclass propertiesPassedToDescendants];
                for (AKPropertyDescription *property in propertiesToSwizzle)
                {
                    AKAncestorSwizzlePropertyGetter(subclass, property);
                }
            }
            
        }
    });
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
    _ak_spinLock = OS_SPINLOCK_INIT;
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
    // Create a copy to prevent any shady business
    NSString *name = [propertyName copy];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", NSStringFromSelector(@selector(propertyName)), name];
    if ([[[self class] propertiesPassedToDescendants] filteredSetUsingPredicate:predicate].count == 0)
    {
        [NSException raise:AKAncestorUnknownPropertyException format:@"No property with the name \"%@\" is being inherited by %@.", name, [self class]];
    }
    
    OSSpinLockLock(&_ak_spinLock);
    [self.ak_ignoredPropertyNames addObject:name];
    OSSpinLockUnlock(&_ak_spinLock);
}

- (void)resumeInheritingValuesForPropertyName:(NSString *)propertyName
{
    // Create a copy to prevent any shady business
    NSString *name = [propertyName copy];
    
    OSSpinLockLock(&_ak_spinLock);
    [self.ak_ignoredPropertyNames removeObject:name];
    OSSpinLockUnlock(&_ak_spinLock);
}

- (NSSet *)propertiesIgnoringInheritedValues
{
    OSSpinLockLock(&_ak_spinLock);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", NSStringFromSelector(@selector(propertyName)), self.ak_ignoredPropertyNames];
    OSSpinLockUnlock(&_ak_spinLock);
    
    return [[[self class] propertiesPassedToDescendants] filteredSetUsingPredicate:predicate];
}


#pragma mark - Reflection

+ (NSSet *)propertiesPassedToDescendants
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %i", NSStringFromSelector(@selector(propertyType)), AKPropertyTypeObject];
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
    
    NSString *propertiesDescription = [self _descriptionOfPropertiesWithLocale:locale indent:level];
    if (propertiesDescription.length > 0)
    {
        [description appendFormat:@"\n%@Properties", padding];
        [description appendString:propertiesDescription];
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
    
    OSSpinLockLock(&_ak_spinLock);
    BOOL isIgnoredProperty = [self.ak_ignoredPropertyNames containsObject:keyPath];
    OSSpinLockUnlock(&_ak_spinLock);
    
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
        [NSException raise:AKAncestorUnknownPropertyException format:@"Received key-value notification for unknown property \"%@\" in %@", keyPath, [self class]];
        
        [object removeObserver:self forKeyPath:keyPath context:context];
        return;
    }
    
    SEL swizzledGetter = AKAncestorSwizzledPropertyGetter(property);
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
    
    NSMutableSet *propertiesToUnobserve = [NSMutableSet setWithSet:[[self class] propertiesPassedToDescendants]];
    [propertiesToUnobserve intersectSet:[[ancestor class] propertiesPassedToDescendants]];
    
    for (AKPropertyDescription *propertyDescription in propertiesToUnobserve)
    {
        [ancestor removeObserver:self forKeyPath:propertyDescription.propertyName context:AKAncestorKVOContext];
    }
}

- (NSString *)_descriptionOfPropertiesWithLocale:(id)locale indent:(NSUInteger)level
{
    NSMutableString *description = [NSMutableString string];
    
    OSSpinLockLock(&_ak_spinLock);
    NSSet *ignoredPropertyNames = [NSSet setWithSet:self.ak_ignoredPropertyNames];
    OSSpinLockUnlock(&_ak_spinLock);
    
    NSSet *propertyNames = [[[self class] _allInheritedProperties] valueForKey:NSStringFromSelector(@selector(propertyName))];
    NSArray *sortedPropertyNames = [[propertyNames allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    id propertyValue;
    for (NSString *propertyName in sortedPropertyNames)
    {
        propertyValue = [self valueForKey:propertyName];
        
        if (!propertyValue && [ignoredPropertyNames containsObject:propertyName])
        {
            propertyValue = @"nil";
        }
        
        if (propertyValue)
        {
            NSString *padding = [@"" stringByPaddingToLength:(level + 2) withString:@"\t" startingAtIndex:0];
            NSString *valueDescription = [[self class] _descriptionOfValue:propertyValue withLocale:locale indent:level];
            
            [description appendFormat:@"\n%@%@: %@", padding, propertyName, valueDescription];
            
            if ([ignoredPropertyNames containsObject:propertyName])
            {
                [description appendString:@" (ignoring inheritance)"];
            }
            
            [description appendString:@","];
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

+ (NSSet *)_allInheritedProperties
{
    // This isn't thread safe, but it also probably doesn't need to be since this method should always return the same objects regardless.
    NSSet *properties = objc_getAssociatedObject(self, _cmd);
    if (properties)
    {
        return properties;
    }
    
    NSMutableSet *mutableProperties = [NSMutableSet set];
    
    Class currentClass = self;
    while (currentClass && currentClass != [AKAncestor class])
    {
        [mutableProperties unionSet:[AKPropertyDescription propertyDescriptionsOfClass:currentClass]];
        currentClass = [currentClass superclass];
    }
    
    properties = [mutableProperties copy];
    objc_setAssociatedObject(self, _cmd, properties, OBJC_ASSOCIATION_COPY);
    return properties;
}

@end
