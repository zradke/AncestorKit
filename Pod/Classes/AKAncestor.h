//
//  AKAncestor.h
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  AKAncestor a base class designed for subclasses to use as models or configuration objects. Subclasses can then inheirt property values from ancestor instances to limit the amount of configuration needed. Whenever a valid property on a descendant is nil, it will consult it's ancestor to try and find a value. In this way, you can view creating descendants as creating copies which remember their parent instance. This behavior can also be disabled per-property on individual instances. This ancestor is strongly retained by its descendants, so some caution is advised to avoid creating retain cycles.
 *
 *  AKAncestor also provides special attention to KVC if your descendants and ancestors need it. If a descendant is inheriting a property value from an ancestor, and that ancestor changes it's property value, the descendant also sends out a key-value notification so any observers on the descendant are properly informed. This behavior can also be disabled per-instance if KVC is not necessary.
 *
 *  Subclasses should be aware that only object properties can be inherited. This happens automatically when a subclass is created, and the properties which can be inherited form the +propertiesPassedToDescendants set. Also, the property getters are swizzled by AKAncestor when the class initializes, so while a subclass is free to provide a custom getter implementation, swizzling the methods again may result in odd behavior. This also means that properties added at runtime are not supported.
 */
@interface AKAncestor : NSObject

#pragma mark - Creating descendants

/**
 *  Creates a descendant of the given ancestor. Equivalent to calling -initWithAncestor:inheritKeyValueNotifications: passing the given ancestor and YES.
 *
 *  @param ancestor The ancestor to inherit from. This may be nil.
 *
 *  @return A new instance of the receiver which derives attributes from its ancestor.
 */
+ (instancetype)descendantOf:(AKAncestor *)ancestor;

/**
 *  Designated initializer. Connects an instance to a given ancestor, and optionally adds key-value observations on the ancestor to vend notifications about property changes. If performance is important or key-value compliance is not an issue, then it may be more efficient to pass NO for shouldInheritKeyValueNotifications, since it will remove the additional overhead of adding and processing those notifications. All convenience initializers of this class pass YES for shouldInheritKeyValueNotifications.
 *
 *  @param ancestor                           An optional ancestor to inherit property values from. This may be nil.
 *  @param shouldInheritKeyValueNotifications YES to add key-value observations on the ancestor and vend notifications when inherited property values change, or NO to not add any key-value observatios on the ancestor.
 *
 *  @return An initialized instance of the receiver which will inherit property values from the ancestor if provided.
 */
- (instancetype)initWithAncestor:(AKAncestor *)ancestor inheritKeyValueNotifications:(BOOL)shouldInheritKeyValueNotifications NS_DESIGNATED_INITIALIZER;

/**
 *  Creates a descendant of the receiver with the same inheritsKeyValueNotifications as the receiver.
 *
 *  @return A new descendant of the receiver.
 */
- (instancetype)descendant;

/**
 *  Creates a descendant of the receiver with the given options for inheriting key-value notifications.
 *
 *  @param shouldInheritKeyValueNotifications YES to have the descendant inherit key-value notifications from the receiver or NO to not add any key-value observations on the receiver.
 *
 *  @return A new descendant of the receiver.
 */
- (instancetype)descendantInheritingKeyValueNotifications:(BOOL)shouldInheritKeyValueNotifications;


#pragma mark - Initialization properties

/**
 *  Returns the ancestor used to initialize the receiver if it exists.
 */
@property (strong, nonatomic, readonly) id ancestor;

/**
 *  YES if the receiver inherits key-value notifications of inherited property values from its ancestor, or NO if it does not. Note that even if the ancestor property is nil, this can still be set to YES.
 */
@property (assign, nonatomic, readonly) BOOL inheritsKeyValueNotifications;


#pragma mark - Limiting property inheritance

/**
 *  Stops the receiver from inheriting property values associated with the given property name. Note that this is only applicable when the requested property is nil on the receiver. Otherwise, the overriden property value is returned as usual. Passing the same property name multiple times will have no effect on subsequent calls.
 *
 *  @param propertyName The name of the property which should stop inheriting values. This must be a member of the +propertiesPassedToDescendants set.
 */
- (void)stopInheritingValuesForPropertyName:(NSString *)propertyName;

/**
 *  Resumes inheriting property values associated with the given property name. Note that this is only applicable when the requested property is nil on the receiver. Otherwise the overriden property value is returned as usual. Passing a property name which was not stopped from inheriting values has no effect.
 *
 *  @param propertyName The name of the property which should resume inheriting values from its ancestors.
 */
- (void)resumeInheritingValuesForPropertyName:(NSString *)propertyName;

/**
 *  Returns a set of AKPropertyDescription objects which are set to ignore inherited values. Note that this does not refer to properties of the receiver which have value overrides, but rather properties whose names were passed to the -stopInheritingValuesForPropertyName: method.
 */
@property (copy, nonatomic, readonly) NSSet *propertiesIgnoringInheritedValues;


#pragma mark - Reflection

/**
 *  Returns the set of AKPropertyDescription objects representing properties whose values may be inherited or passed to instances.
 */
+ (NSSet *)propertiesPassedToDescendants;

@end
