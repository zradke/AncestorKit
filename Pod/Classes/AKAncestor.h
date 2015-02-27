//
//  AKAncestor.h
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  Exception raised when AKAncestor attempts to swizzle a non-object property.
 */
FOUNDATION_EXPORT NSString *const AKAncestorNonObjectPropertyException;

/**
 *  Exception raised when an unknown property is encountered.
 */
FOUNDATION_EXPORT NSString *const AKAncestorUnknownPropertyException;


/**
 *  AKAncestor a base class designed for subclasses to use as models or configuration objects. Subclasses can then inheirt property values from ancestor instances to limit the amount of configuration needed. Whenever a valid property on a descendant is nil, it will consult it's ancestor to try and find a value. In this way, you can view creating descendants as creating copies which remember their parent instance. This behavior can also be disabled per-property on individual instances. This ancestor is strongly retained by its descendants, so some caution is advised to avoid creating retain cycles.
 *
 *  AKAncestor also provides special attention to KVC if your descendants and ancestors need it. If a descendant is inheriting a property value from an ancestor, and that ancestor changes it's property value, the descendant also sends out a key-value notification so any observers on the descendant are properly informed. This behavior can also be disabled per-instance if KVC is not necessary. The inheritsKeyValueNotifications property indicates whether the receiver was configured to vend these notifications or not.
 *
 *  Subclasses should be aware that only object properties can be inherited. This happens automatically when a subclass is created, and the properties which can be inherited form the +propertiesPassedToDescendants set.
 */
@interface AKAncestor : NSObject

#pragma mark - Creating descendants

/**
 *  Creates a descendant of the given ancestor. Equivalent to calling -initWithAncestor:inheritKeyValueNotifications: passing the given ancestor and the ancestor's inheritsKeyValueNotifications value.
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
 *  @param shouldInheritKeyValueNotifications YES to add key-value observations on the ancestor and vend notifications when inherited property values change, or NO to not add any key-value observations on the ancestor.
 *
 *  @return An initialized instance of the receiver which will inherit property values from the ancestor if provided.
 */
- (instancetype)initWithAncestor:(AKAncestor *)ancestor inheritKeyValueNotifications:(BOOL)shouldInheritKeyValueNotifications NS_DESIGNATED_INITIALIZER;

/**
 *  Equivalent to calling -initWithAncestor:inheritKeyValueNotifications: with nil and YES as the arguments.
 *
 *  @return An initialized instance of the receiver with no ancestor.
 */
- (instancetype)init;

/**
 *  Creates a descendant of the receiver with the same inheritsKeyValueNotifications value as the receiver.
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
 *  Stops the receiver from inheriting property values associated with the given property name. Note that this is only applicable when the requested property is nil on the receiver. Otherwise, the overriden property value is returned as usual. Passing the same property name multiple times without resuming inheritance of values will have no effect after the first call.
 *
 *  @see -resumeInheritingValuesForPropertyName:, propertiesIgnoringInheritedValues
 *
 *  @param propertyName The name of the property which should stop inheriting values. This must describe the propertyName of a member of the +propertiesPassedToDescendants set, or an AKAncestorUnknownPropertyException exception will be thrown.
 */
- (void)stopInheritingValuesForPropertyName:(NSString *)propertyName;

/**
 *  Resumes inheriting property values associated with the given property name. Note that this is only applicable when the requested property is nil on the receiver. Otherwise the overriden property value is returned as usual. Passing a property name which was not stopped from inheriting values has no effect.
 *
 *  @see -stopInheritingValuesForPropertyName:, propertiesIgnoringInheritedValues
 *
 *  @param propertyName The name of the property which should resume inheriting values from its ancestors.
 */
- (void)resumeInheritingValuesForPropertyName:(NSString *)propertyName;

/**
 *  Returns a set of AKPropertyDescription objects which are set to ignore inherited values. Note that this does not refer to properties of the receiver which have value overrides, but rather properties whose names were passed to the -stopInheritingValuesForPropertyName: method.
 *
 *  @see -stopInheritingValuesForPropertyName:, -resumeInheritingValuesForPropertyName:
 */
@property (copy, nonatomic, readonly) NSSet *propertiesIgnoringInheritedValues;


#pragma mark - Reflection

/**
 *  Returns the set of AKPropertyDescription objects representing properties whose values may be inherited or passed to instances.
 *
 *  By default this set includes all AKPropertyTypeObject properties of the receiving class up to and excluding those of AKAncestor. Subclasses can override this method to remove properties which should never be inheritable. Subclasses should always utilize super's implementation as a starting point. It is dangerous to add new properties to this set unless you configure your subclass to handle dynamic method resolution. Attempting to add non-object properties to this method will result in an AKAncestorNonObjectPropertyException exception being raised when AKAncestor loads.
 */
+ (NSSet *)propertiesPassedToDescendants;

@end
