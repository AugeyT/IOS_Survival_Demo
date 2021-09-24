//
//  Copyright © Borna Noureddin. All rights reserved.
//

#ifndef Renderer_h
#define Renderer_h
#import <GLKit/GLKit.h>
#import <SceneKit/SceneKit.h>
#import "ViewController.h"
#import "Resources/cube.h"
#include "RenObjData.h"


@interface Renderer : NSObject

@property float playerPosX, playerPosY;
@property float pickupPosX, pickupPosY;
@property GLKVector4 specularComponent, ambientComponent;

- (void)setup:(GLKView *)view;
- (void)loadModels;
- (void)update;
- (void)draw:(CGRect)drawRect;
- (void)registerUpdate:(REN_OBJ)getUpdatesfor theUpdatefunc:(SEL)func fromObject:(id) object;
- (REN_OBJ_DATA_MIN*)updateData:(REN_OBJ)objId;
- (bool)updateCommit:(REN_OBJ)objId;

- (bool)checkCollidePos:(float) x andPosY: (float)y;

- (void)changeFloorTexture:(bool)useIce;

@end

#endif /* Renderer_h */
