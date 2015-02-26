//
//  AKTestPersonSubclass.m
//  AncestorKit
//
//  Created by Zachary Radke | AMDU on 2/24/15.
//  Copyright (c) 2015 Zach Radke. All rights reserved.
//

#import "AKTestPersonSubclass.h"

@implementation AKTestPersonSubclass

- (NSString *)firstName
{
    return [[super firstName] uppercaseString];
}

@end
