//
//  GameScene.m
//  ZombieTank
//
//  Created by Rafal Kampa on 12.08.2016.
//  Copyright (c) 2016 Rafal Kampa. All rights reserved.
//
#import "StageOne.h"
#import "StageTwo.h"
#import "StageThree.h"

#import "GameScene.h"

#import "Defines.h"
#import "GameSceneViewModel.h"
#import "ShootingBall.h"
#import "Zombie.h"
#import "Ghost.h"
#import "Actions.h"
#import "Utilities.h"
#import "AppEngine.h"
#import "GameOver.h"

@interface GameScene () <SKPhysicsContactDelegate>
@property (nonatomic, strong) SKSpriteNode *tankRifle;
@property (nonatomic , strong) SKAction *rotateAction;
@property (nonatomic, strong) GameSceneViewModel *viewModel;
@property (nonatomic, strong) ShootingBall *shootingBall;
@property (nonatomic, strong) SKSpriteNode *bangNode;
@property (nonatomic, strong) SKSpriteNode *tankBody;
@property (nonatomic, assign) BOOL rotating;
@property (nonatomic, assign) BOOL moving;
@property (nonatomic, assign) double lastAngle;
@property (nonatomic, assign) int level;
@end
@implementation GameScene

-(void)didMoveToView:(SKView *)view {
    self.viewModel = [[GameSceneViewModel alloc] init];
    self.physicsWorld.contactDelegate = self;
    
    self.tankRifle = (SKSpriteNode *)[self childNodeWithName:spriteNameTankRifle];
    self.bangNode = (SKSpriteNode *)[self childNodeWithName:spriteNameBang];
    self.tankBody = (SKSpriteNode *)[self childNodeWithName:spriteNameTankBody];

    [Utilities createPhysicBodyWithoutContactDetection:self.tankRifle];
    [Utilities createPhysicBodyWithoutContactDetection:self.bangNode];
    self.bangNode.alpha = 0;

    [self.physicsWorld addJoint:[Utilities jointPinBodyA:self.tankRifle.physicsBody toBodyB:self.bangNode.physicsBody atPosition:self.tankRifle.position]];
    [self.physicsWorld addJoint:[Utilities jointPinBodyA:self.tankBody.physicsBody toBodyB:self.tankRifle.physicsBody atPosition:self.tankBody.position]];
    
    self.level = 1;
    [self createWorldLevel:self.level];
}

- (void)update:(NSTimeInterval)currentTime{
    [self.viewModel updateEnemyPosition:self.children basePosition:self.tankRifle.position enemyNames:self.viewModel.arrayWithMonsters];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    if (!self.rotating && !self.moving) {
        self.rotating = YES;
        self.bangNode.alpha = 0;
        
        CGPoint positionInScene = [[touches anyObject] locationInNode:self];
        
        self.bangNode.texture = [SKTexture textureWithImage:[UIImage imageNamed:[self.viewModel setBangSpriteImage]]];
        [self startObjectAnimationToPosition:positionInScene];
    }
}

-(void)startObjectAnimationToPosition:(CGPoint)position {
    [self.tankRifle removeAllActions];
    self.rotating = NO;
    [self.tankRifle runAction:[SKAction rotateToAngle:[self.viewModel calculateRadiusAndDurationTimeFromTouchLocation:position spriteNode:self.tankRifle] duration:self.viewModel.speed] completion:^{
        [self shootBallToPosition:position];
        [self.bangNode runAction:[Actions fadeInFadeOutAction]];
    }];
}

- (void)didBeginContact:(SKPhysicsContact *)contact{
    SKPhysicsBody *firstBody;
    if (contact.bodyA.categoryBitMask > contact.bodyB.categoryBitMask) {
        firstBody = contact.bodyA;
    }else{
        firstBody = contact.bodyB;
    }
    
    if (firstBody == self.shootingBall.physicsBody) {
        [contact.bodyB.node removeFromParent];
        [contact.bodyA.node removeFromParent];
        [self.viewModel createCartoonLabelsWithName:@"boom" atPosition:firstBody.node.position inScene:self];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkNodes];
        });
        
    }else{
        [contact.bodyB.node removeFromParent];
    }
}

- (void)shootBallToPosition:(CGPoint)position{
    self.shootingBall = [ShootingBall shootingBallSpriteNodeWithStartPosition:self.bangNode.position];
    [self addChild:self.shootingBall];

    CGVector vector = CGVectorMake(position.x - self.tankRifle.position.x, position.y - self.tankRifle.position.y);
    [self.shootingBall.physicsBody applyImpulse:vector];
}

- (void)didSimulatePhysics{
    SKCameraNode *camera = (SKCameraNode *)[self childNodeWithName:@"camera"];
    camera.position = CGPointMake(self.tankBody.position.x, self.tankBody.position.y - 100);
    self.camera = camera;
}

- (void)checkNodes{
    BOOL monsters = NO;
    for (SKNode *node in self.children) {
        for (int i = 0; i < self.viewModel.arrayWithMonsters.count; i++) {
            if ([node.name isEqualToString:self.viewModel.arrayWithMonsters[i]]) {
                monsters = YES;
            }
        }
    }
    if (monsters == NO && [AppEngine defaultEngine].goToNextLevel) {
        self.moving = YES;
        [self.tankBody runAction:[Actions rotateToAngle:1.5 andMoveByX:0 moveByY:1200]];
        [self.tankRifle runAction:[Actions rotateToAngle:1.5 andMoveByX:0 moveByY:1200] completion:^{
            self.level++;
            self.moving = NO;
            [self createWorldLevel:self.level];
        }];
        [AppEngine defaultEngine].goToNextLevel = NO;
    }
}

- (void)createWorldLevel:(int)level{
    switch (level) {
        case 1:
        {
            StageOne *stageOne = [StageOne nodeWithFileNamed:stageNameStageOne];
            stageOne.viewModel = self.viewModel;
            [stageOne arrayWithMonsters];
            [stageOne createMonstersFromScene:self];

            break;
        }
        case 2:
        {
            StageTwo *stageTwo = [StageTwo nodeWithFileNamed:stageNameStageTwo];
            stageTwo.viewModel = self.viewModel;
            [stageTwo arrayWithMonsters];
            [stageTwo createMonstersFromScene:self];
            break;
        }
        default:
            break;
    }
}



@end
