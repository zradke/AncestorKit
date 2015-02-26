//
//  AKTestPerson.h
//  AncestorKit
//
//  Created by Zachary Radke | AMDU on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import <AncestorKit/AncestorKit.h>

@interface AKTestPerson : AKAncestor

@property (copy, nonatomic) NSString *firstName;
@property (copy, nonatomic) NSString *lastName;

- (NSString *)fullName;

@end
