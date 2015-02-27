//
//  AKTestFixtures.h
//  AncestorKit
//
//  Created by Zach Radke on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <AncestorKit/AncestorKit.h>
#import <UIKit/UIKit.h>

@interface AKTestPerson : AKAncestor

@property (copy, nonatomic) NSString *firstName;
@property (copy, nonatomic) NSString *lastName;

- (NSString *)fullName;

@end

@interface AKTestPersonSubclass : AKTestPerson
@property (strong, nonatomic) NSDate *birthDate;
@end

@interface AKTestPersonDeepSubclass : AKTestPersonSubclass
@property (copy, nonatomic) NSString *middleName;
@property (assign, nonatomic) BOOL isMarried;
@end

@interface AKCollectionViewAttributes : AKAncestor
@property (assign, nonatomic) UIEdgeInsets sectionInsets;
@end
