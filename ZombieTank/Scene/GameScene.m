//
//  GameScene.m
//  ZombieTank
//
//  Created by Rafal Kampa on 12.08.2016.
//  Copyright (c) 2016 Rafal Kampa. All rights reserved.
//
#import "StagesParent.h"
#import "StageOne.h"
#import "StageTwo.h"
#import "StageThree.h"
#import "StageFour.h"


#import "GameScene.h"
#import "StartingPosition.h"

#import "Defines.h"
#import "GameSceneViewModel.h"
#import "ShootingBall.h"
#import "FireRing.h"
#import "TankBody.h"
#import "Zombie.h"
#import "Ghost.h"
#import "Actions.h"
#import "Utilities.h"
#import "AppEngine.h"
#import "GameOver.h"

@interface GameScene () <SKPhysicsContactDelegate, StagesParentDelegate>
@property (nonatomic , strong) SKAction *rotateAction;
@property (nonatomic, strong) SKSpriteNode *tankRifle;
@property (nonatomic, strong) SKLabelNode *labelEndingWave;
@property (nonatomic, strong) SKSpriteNode *bangNode;
@property (nonatomic, strong) SKSpriteNode *tankBody;

@property (nonatomic, assign) CGPoint selectedPoint;
@property (nonatomic, assign) BOOL rotating;
@property (nonatomic, assign) BOOL moving;
@property (nonatomic, assign) double lastAngle;
@property (nonatomic, strong) NSTimer *shieldAndBombTimer;

@property (nonatomic, strong) GameSceneViewModel *viewModel;
@property (nonatomic, strong) ShootingBall *shootingBall;
@property (nonatomic, strong) FireRing *fireRing;
@end

@implementation GameScene

-(void)didMoveToView:(SKView *)view {
    self.viewModel = [[GameSceneViewModel alloc] init];
    self.viewModel.wavesCounter = 0;
    self.physicsWorld.contactDelegate = self;
    
    self.labelEndingWave = (SKLabelNode *)[self childNodeWithName:spriteNameLabelEndingWave];
    [self.labelEndingWave runAction:[SKAction fadeOutWithDuration:0.01]];
    self.tankRifle = (SKSpriteNode *)[self childNodeWithName:spriteNameTankRifle];
    self.bangNode = (SKSpriteNode *)[self childNodeWithName:spriteNameBang];
    self.tankBody = (SKSpriteNode *)[self childNodeWithName:spriteNameTankBody];
    [TankBody tankBodySpriteNode:self.tankBody];
    [Utilities createPhysicBodyWithoutContactDetection:self.tankRifle];
    [Utilities createPhysicBodyWithoutContactDetection:self.bangNode];
    self.bangNode.alpha = 0;

    [self.physicsWorld addJoint:[Utilities jointPinBodyA:self.tankRifle.physicsBody toBodyB:self.bangNode.physicsBody atPosition:self.tankRifle.position]];
    [self.physicsWorld addJoint:[Utilities jointPinBodyA:self.tankBody.physicsBody toBodyB:self.tankRifle.physicsBody atPosition:self.tankBody.position]];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
    [view addGestureRecognizer:longPress];
    [self createWorldAtSelectedLevel:self.selectedLevel];
}

- (void)update:(NSTimeInterval)currentTime{
    [self.viewModel updateEnemyPosition:self.children basePosition:self.tankRifle.position enemyNames:self.viewModel.arrayWithMonsters];
}

- (void)didSimulatePhysics{
    SKCameraNode *camera = (SKCameraNode *)[self childNodeWithName:@"camera"];
    camera.position = CGPointMake(self.tankBody.position.x, self.tankBody.position.y);
    self.camera = camera;
}

#pragma mark - Gesture Recognizer action
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [[event allTouches] anyObject];
    self.selectedPoint = [touch locationInNode:self];
    if (![self.tankBody containsPoint:self.selectedPoint]) {
        if (!self.rotating && !self.moving) {
            self.rotating = YES;
            self.bangNode.alpha = 0;
            CGPoint positionInScene = [[touches anyObject] locationInNode:self];
            self.bangNode.texture = [SKTexture textureWithImage:[UIImage imageNamed:[self.viewModel setBangSpriteImage]]];
            [self startObjectAnimationToPosition:positionInScene];
        }
    }
}

- (void)longPressAction:(UILongPressGestureRecognizer *)recognizer{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.viewModel.chargingLevel = 0;
        [self.shieldAndBombTimer invalidate];
        if ([self.tankBody containsPoint:self.selectedPoint]) {
            NSLog(@"charging");
            self.shieldAndBombTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(charging) userInfo:nil repeats:YES];
        }
    }
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self.gameSceneDelegate stopCharging];
        [self.shieldAndBombTimer invalidate];
    }
}

#pragma mark - Sprite Contact
- (void)didBeginContact:(SKPhysicsContact *)contact{
    SKPhysicsBody *firstBody;
    if (contact.bodyA.categoryBitMask > contact.bodyB.categoryBitMask) {
        firstBody = contact.bodyA;
    }else{
        firstBody = contact.bodyB;
    }
    if ([self.viewModel contact:contact isEqualToFirstPhysicBody:self.tankBody.physicsBody]) { 
        if (![self.viewModel contact:contact isEqualToFirstPhysicBody:self.fireRing.physicsBody]) {
            [self.viewModel createCartoonLabelsWithName:@"boom" atPosition:self.tankBody.position inScene:self];
            [self.tankBody removeFromParent];
            [self.tankRifle removeFromParent];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.gameSceneDelegate gameOver];
                self.scene.view.paused = YES;
            });
        }
    }
    
    if (firstBody == self.shootingBall.physicsBody || firstBody == self.fireRing.physicsBody) {
        if (contact.bodyB != self.fireRing.physicsBody && contact.bodyB != self.tankBody.physicsBody) {
            [self.collisionDelegate collisionNodeA:[self.viewModel spriteNodeFromChildren:self.scene.children fromContactBody:contact.bodyB] nodeB:[self.viewModel spriteNodeFromChildren:self.scene.children fromContactBody:contact.bodyA]];
            if ([self.viewModel healthIsZeroFromChildren:self.scene.children contactBody:contact.bodyB]) {
                [contact.bodyB.node removeFromParent];
            }
        }
        if (contact.bodyA != self.fireRing.physicsBody && contact.bodyA != self.tankBody.physicsBody) {
            [self.collisionDelegate collisionNodeA:[self.viewModel spriteNodeFromChildren:self.scene.children fromContactBody:contact.bodyB] nodeB:[self.viewModel spriteNodeFromChildren:self.scene.children fromContactBody:contact.bodyA]];
            if ([self.viewModel healthIsZeroFromChildren:self.scene.children contactBody:contact.bodyA]) {
                [contact.bodyA.node removeFromParent];
            }
        }
      
        if (firstBody == self.fireRing.physicsBody) {
            [self.collisionDelegate shieldCollisionWithNode:[self.viewModel nodeAfterCollisionWithFireShield:contact]];
        }else{
            [self.viewModel createCartoonLabelsWithName:@"boom" atPosition:firstBody.node.position inScene:self];
        }
        
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

#pragma mark - Charging special Attack
- (void)charging{
     [self.gameSceneDelegate chargingLevel:self.viewModel.chargingLevel maxLevel:self.viewModel.maxChargingLevel];
    self.viewModel.chargingLevel++;
    if (self.viewModel.chargingLevel == self.viewModel.maxChargingLevel) {
        [self.gameSceneDelegate stopCharging];
        [self.shieldAndBombTimer invalidate];
        self.fireRing = [FireRing fireSpriteNode];
         self.fireRing.position = self.tankBody.position;
        [self addChild:self.fireRing];
        if (!self.viewModel.bossLevel) {
            [Actions shakeScreenFor:10 withIntensity:CGVectorMake(2, 2) andDuration:1 scene:self.scene];
            [self.fireRing runAction:[SKAction scaleXBy:20 y:10 duration:3] completion:^{
            [self.fireRing removeFromParent]; 
            }];
        }else{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.fireRing removeFromParent];
            });
        }
    }
}

#pragma mark - Create actual Level
- (void)createWorldLevel {
    self.view.paused = NO;
    [self createWorldLevel:self.viewModel.level];
}

- (void)createWorldLevel:(int)level{
    [self showLevelLabel:level customTextLabel:@""];
    switch (level) {
        case 1:
        {
            StageOne *stageOne = [StageOne nodeWithFileNamed:stageNameStageOne];
            stageOne.viewModel = self.viewModel;
            [stageOne arrayWithMonsters];
            stageOne.parentSceneDelegate = self;
            [stageOne createMonstersFromScene:self];
            break;
        }
        case 2:
        {
            StageTwo *stageTwo = [StageTwo nodeWithFileNamed:stageNameStageTwo];
            stageTwo.viewModel = self.viewModel;
            [stageTwo arrayWithMonsters];
            stageTwo.parentSceneDelegate = self;
            [stageTwo createMonstersFromScene:self];
            break;
        }
        case 3:
        {
            StageThree *stageThree = [StageThree nodeWithFileNamed:stageNameStageThree];
            stageThree.viewModel = self.viewModel;
            stageThree.parentSceneDelegate = self;
            [stageThree arrayWithMonsters];
            [stageThree createMonstersFromScene:self];
            break;
        }
        case 4:
        {
            StageFour *stageFour = [StageFour nodeWithFileNamed:stageNameStageFour];
            stageFour.viewModel = self.viewModel;
            stageFour.parentSceneDelegate = self;
            [stageFour arrayWithMonsters];
            [stageFour createMonstersFromScene:self];
            break;
        }
        default:
            break;
    }
}

#pragma mark - Delegate Scene
- (void)showLevelLabel:(int)level customTextLabel:(NSString *)textLabel{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.viewModel.wavesCounter ++;
        self.labelEndingWave.fontColor = [Utilities colorWithHexString:[self.viewModel labelHexColorWithLevel:level]];
        self.labelEndingWave.position = CGPointMake(self.tankBody.position.x + 100, self.tankBody.position.y + 150);
        
        if (textLabel.length > 0) {
            self.labelEndingWave.text = textLabel;
        }else{
            self.labelEndingWave.text = [NSString stringWithFormat:@"Wave %i",self.viewModel.wavesCounter];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.labelEndingWave runAction:[Actions fadeInFadeOutActionForLabels]];
        });
    });
}

- (void)bossWasHit:(int)health maxHealth:(int)maxHealth{
    [self.gameSceneDelegate bossWasHitBy:health maxHealth:maxHealth];
}

#pragma mark - Helper methods
- (void)createWorldAtSelectedLevel:(NSInteger)level{
    [self.viewModel selectedLevel:level];
    self.tankRifle.position = CGPointMake(self.viewModel.moveByX + self.tankRifle.position.x, self.viewModel.moveByY + self.tankRifle.position.y);
    [self createWorldLevel:self.viewModel.level];
}

- (void)checkNodes{
    BOOL monsters = [self.viewModel areMonstersInScene:self.scene];
    if (monsters == NO && [AppEngine defaultEngine].goToNextLevel) {
        self.viewModel.level++;
        [self.viewModel unlockLevel];
        [StartingPosition startingPositionBasedOnLvl:self.viewModel.level viewModel:self.viewModel];
        self.moving = YES;
        [self.tankBody runAction:[Actions rotateToAngle:self.viewModel.moveByAngle andMoveByX:self.viewModel.moveByX + baseCenterX moveByY:self.viewModel.moveByY + baseCenterY]];
        [self.tankRifle runAction:[Actions rotateToAngle:self.viewModel.moveByAngle andMoveByX:self.viewModel.moveByX + baseCenterX moveByY:self.viewModel.moveByY + baseCenterY] completion:^{
            
            self.moving = NO;
            self.view.paused = YES;
            [self.gameSceneDelegate createMonsterInfoPopupWithLevel:self.viewModel.level];
        }];
        [AppEngine defaultEngine].goToNextLevel = NO;
    }
}

-(void)startObjectAnimationToPosition:(CGPoint)position {
    [self.tankRifle removeAllActions];
    self.viewModel.lastAngle = atan2(position.y - self.tankRifle.position.y, position.x - self.tankRifle.position.x);
    
    if (self.tankRifle.zRotation < 0) {
        self.tankRifle.zRotation = self.tankRifle.zRotation + M_PI * 2;
    }
    
    [self.tankRifle runAction:[SKAction rotateToAngle:self.viewModel.lastAngle duration:self.viewModel.speed shortestUnitArc:YES] completion:^{
        self.rotating = NO;
        [self shootBallToPosition:position];
        [self.bangNode runAction:[Actions fadeInFadeOutAction]];
    }];
}


@end
