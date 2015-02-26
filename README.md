# AncestorKit

[![CI Status](http://img.shields.io/travis/zradke/AncestorKit.svg?style=flat)](https://travis-ci.org/zradke/AncestorKit)
[![Version](https://img.shields.io/cocoapods/v/AncestorKit.svg?style=flat)](http://cocoadocs.org/docsets/AncestorKit)
[![License](https://img.shields.io/cocoapods/l/AncestorKit.svg?style=flat)](http://cocoadocs.org/docsets/AncestorKit)
[![Platform](https://img.shields.io/cocoapods/p/AncestorKit.svg?style=flat)](http://cocoadocs.org/docsets/AncestorKit)

Inspired by the 2014 WWDC Session ['Advanced User Interfaces with Collection Views,'](http://asciiwwdc.com/2014/sessions/232) AncestorKit provides a way to easily create instance-based inheritance of property values. With it, you can easily create models or configuration objects whose property values trickle down to descendants. Trust me, it makes way more sense when you see it in practice.

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

## Installation

AncestorKit is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "AncestorKit"

## Details and Caveats

AncestorKit uses the Objective-C runtime to inspect subclasses of `AKAncestor`, locate properties which can be inherited in instances, and swizzle those property getters. For the most part, consumers won't need to worry about this, but if you're planning on using a lot of runtime trickery yourself, be aware that the properties are swizzled in the `+initialize` method (so each subclass will swizzle its own properties). This means that any properties added dynamically through the runtime will not be inheritable.

Only object properties are eligable for inheritance. This is because object properties can be nil, which indicates that there is no value. AncestorKit relies on the concept of "no-value" to determine when it should search ancestors for a possible value. This makes it hard if not impossible to work with primitive types, since a `BOOL` property can be `NO` because it hasn't been set, or `NO` because it was intentionally set that way.

## License

AncestorKit is available under the MIT license. See the LICENSE file for more info.

