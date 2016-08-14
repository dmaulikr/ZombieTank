//
//  Utilities.h
//  ZombieTank
//
//  Created by Rafal Kampa on 13.08.2016.
//  Copyright © 2016 Rafal Kampa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>

@interface Utilities : NSObject
+ (CGPoint)positionOfRespawnPlaceFromNodesArray:(NSArray *)nodesArray respawnName:(NSString *)respawnName;
@end