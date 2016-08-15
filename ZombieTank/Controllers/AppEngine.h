//
//  AppEngine.h
//  ZombieTank
//
//  Created by Rafal Kampa on 15.08.2016.
//  Copyright © 2016 Rafal Kampa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppEngine : NSObject

@property (nonatomic, assign) BOOL goToNextLevel;

+ (instancetype)defaultEngine;

@end