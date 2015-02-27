# AncestorKit

[![CI Status](http://img.shields.io/travis/zradke/AncestorKit.svg?style=flat)](https://travis-ci.org/zradke/AncestorKit)
[![Version](https://img.shields.io/cocoapods/v/AncestorKit.svg?style=flat)](http://cocoadocs.org/docsets/AncestorKit)
[![License](https://img.shields.io/cocoapods/l/AncestorKit.svg?style=flat)](http://cocoadocs.org/docsets/AncestorKit)
[![Platform](https://img.shields.io/cocoapods/p/AncestorKit.svg?style=flat)](http://cocoadocs.org/docsets/AncestorKit)

Inspired by the 2014 WWDC Session ['Advanced User Interfaces with Collection Views,'](http://asciiwwdc.com/2014/sessions/232) AncestorKit provides a way to easily create instance-based inheritance of property values. With it, you can create models or configuration objects whose property values trickle down to descendants. Trust me, it makes way more sense when you see it in practice.

## Usage

### Subclass AKAncestor

For example, let's say we were building a family tree:

	@interface Person : AKAncestor
	
	@property (copy, nonatomic) NSString *firstName;
	@property (copy, nonatomic) NSString *lastName;
	
	- (NSString *)fullName;
	
	@end

### Create ancestors and descendants

Now we've defined a class, we can create an ancestor:

	Person *arthur = [Person new];
	arthur.firstName = @"Arthur";
	arthur.lastName = @"Weasley";
	
	[arthur fullName]; // "Arthur Weasley"

From the ancestor, we can derive descendants:

	Person *bill = [charlus descendant];
	bill.firstName = @"William";
	
	[bill fullName]; // "William Weasley"

Surprise! Because we didn't define a `bill.lastName`, it inherits the value of `arthur.lastName`. Note that this only works for **object properties**. This can continue this descendant chain as long as we like:

	Person *victoire = [bill descendant];
	victoire.firstName = @"Victoire";
	
	[victoire fullName]; // "Victoire Weasley"

Now "Harry Potter and the Deathly Hallows" strongly implies that Victoire Weasley will end up marrying Teddy Lupin. If she decides to take his last name we can update our tree:

	victoire.lastName = @"Lupin";
	
	[victoire fullName]; // "Victoire Lupin"
	
By providing a value for `victoire.lastName`, we stop inheriting the value from its descendants just as we would expect!

### Stopping inheritance

While property value inheritance is the goal of AncestorKit, sometimes you need to disable inheritance on a specific property.

Using our existing `Person` model:

	Person *tony = [Person new];
	tony.firstName = @"Silvio";
	tony.lastName = @"Ciccone";
	
	[tony fullName]; // "Silvio Ciccone"

Tony Ciccone had a daughter:

	Person *madonna = [tony descendant];
	madonna.firstName = @"Madonna";
	
	[madonna fullName]; // "Madonna Ciccone"

Madonna Ciccone would shed her last name and become a pop star, so we need our model to stop inheriting its last name:

	[madonna stopInheritingValuesForPropertyName:@"lastName"];
	
	[madonna fullName]; // "Madonna"

Perfect!

## Advanced usage

### Primitive properties

Let's say you were using a subclass of `AKAncestor` to set section insets of a collection view:

	@interface CollectionViewSectionAttributes : AKAncestor
	
	// Interact with this property
	@property (assign, nonatomic) UIEdgeInsets sectionInsets;
	
	@end
	
	@interface CollectionViewSectionAttributes (Private)
	
	// This property acts as storage for the primitive sectionInsets property, and is inheritable
	@property (strong, nonatomic) NSValue *sectionInsetsValue;
	
	@end

If you can find a way to convert your primitive types into objects, you can use private storage properties to actually store the data, making them eligible for inheritance. Of course, this means creating appropriate getters and setters yourself for the primitive property:

	@implementation CollectionViewSectionAttributes
	
	- (UIEdgeInsets)sectionInsets
	{
		return (self.sectionInsetsValue) ? [self.sectionInsetsValue UIEdgeInsetsValue] : UIEdgeInsetsZero;
	}
	
	- (void)setSectionInsets:(UIEdgeInsets)sectionInsets
	{
		if (!UIEdgeInsetsEqualToEdgeInsets(self.sectionInsets, sectionInsets))
		{
			self.sectionInsetsValue = [NSValue valueWithUIEdgeInsets:sectionInsets];
		}
	}
	
	- (NSSet *)keyPathsAffectingSectionInsets
	{
		return [NSSet setWithObject:@"sectionInsetsValue"];
	}
	
	@end

### Key-Value Observations

Let's say we have to observe the `sectionInsets` property of our `CollectionViewSectionAttributes` objects:

	CollectionViewSectionAttributes *rootAttrs = [CollectionViewSectionAttributes new];
	rootAttrs.sectionInsets = UIEdgeInsetsMake(15.0, 15.0, 15.0, 15.0);
	
	...
	
	CollectionViewSectionAttributes *sectionAttrs = [rootAttrs descendant];
	[sectionAttrs addObserver:self forKeyPath:@"sectionInsets" options:0 context:nil];
	
Although we haven't done any extra work, we get key-value notifications of inherited property values for free! So for example:

	// We change the root section attributes
	rootAttrs.sectionInsets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);

Even though we're changing the ancestor, `sectionAttrs` will notify observers that its `sectionInset` has been updated like we'd expect. And also like we'd expect, we won't get phantom notifications if the instance has its own property value:

	// This will generate a notification
	sectionAttrs.sectionInsets = UIEdgeInsetsMake(40.0, 0.0, 10.0, 0.0);
	
	// This won't generate a notification on sectionAttrs now that sectionAttrs has its own sectionInsets value.
	rootAttrs.sectionInsets = UIEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);

This behavior can be disabled if you want to avoid the overhead of key-value coding using the more verbose initializer and descendant methods:

	sectionAttrs = [[CollectionViewSectionAttributes alloc] initWithAncestor:rootAttrs inheritKeyValueNotifications:NO];
	
	sectionAttrs = [rootAttrs descendantInheritingKeyValueNotifications:NO];

Note that the standard `-init` method and the `+new` method are equivalent to calling `-initWithAncestor:inheritKeyValueNotifications:` passing `YES`, while the `-descendant` and `-descendantOf:` methods will use the ancestor's `inheritsKeyValueNotifications` property instead.

## Installation

AncestorKit is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "AncestorKit"

## Details and Caveats

AncestorKit uses the Objective-C runtime to inspect subclasses of `AKAncestor`, locate properties which can be inherited in instances, and swizzle those property getters. For the most part, consumers won't need to worry about this, but if you're planning on using a lot of runtime trickery yourself, be aware that the properties are swizzled in the `+initialize` method (so each subclass will swizzle its own properties) so if you override this method in your subclass of `AKAncestor`, you **must** call `[super initialize]`. This also means that any properties added dynamically through the runtime will not be inheritable.

Only object properties are eligable for inheritance. This is because object properties can be nil, which indicates that there is no value. AncestorKit relies on the concept of "no-value" to determine when it should search ancestors for a possible value. This makes it hard if not impossible to work with primitive types, since a `BOOL` property can be `NO` because it hasn't been set, or `NO` because it was intentionally set that way.

## Contributing

Find an issue? Feel that something needs clarification or improvement? Feel free to open an issue in Github! I'm particularly interested in seeing how to test the performance of these classes when used intensively.

## License

AncestorKit is available under the MIT license. See the LICENSE file for more info.

