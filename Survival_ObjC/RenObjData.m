//
//  RenObjData.m
//  Survival
//
//  Created by Richard Tesch on 2021-02-27.
//

#import <Foundation/Foundation.h>
#import "RenObjData.h"

@implementation RenObjData

REN_OBJ_DATA_MIN data;

@synthesize objID;
@synthesize modelId;
@synthesize tagID;
@synthesize textureID;
@synthesize textureSysId;
@synthesize pos;
@synthesize rot;
@synthesize scale;
@synthesize rgb;
@synthesize visible;
@synthesize mvp;
@synthesize nm;
@synthesize updateData;
@synthesize elapsedTime;
@synthesize collisionDetectionOn;
@synthesize collissionHit;
@synthesize collissionHitWith;
@synthesize collissionHitWithTag;


// ----------------------------------------------------------------------------------------
//  Method to support with quick population of an object. Will typoically be used in the
//   object creation to assure that it will have appropriate values to represent an object
-(id)populate: (REN_OBJ)objID : (MODEL_ID)modelId : (REN_TAG_ID)tagID : (REN_TEXTURE_ID)textureID : (GLenum)textureSysId : (GLKVector3)pos : (GLKVector3)rot : (GLKVector3)scale : (GLKVector3)rgb : (bool)visible : (bool)collisionDetectionOn
{
    self.objID = objID;
    self.modelId = modelId;
    self.tagID = tagID;
    self.textureID = textureID;
    self.textureSysId = textureSysId;
    self.pos = pos;
    self.rot = rot;
    self.scale = scale;
    self.rgb = rgb;
    self.visible = visible;
    self.collisionDetectionOn = collisionDetectionOn;
    self.collissionHit = false;
    self.collissionHitWith = REN_OBJ_NULL;
    self.collissionHitWithTag = REN_TAG_NONE;
    
    return self;
}


// ----------------------------------------------------------------------------------------
//  Method to return this objects minimum data that is used in registered callbacks
-(REN_OBJ_DATA_MIN*)buildObjDataMin
{
    data.objID = objID;
    data.modelId = modelId;
    data.tagID = tagID;
    data.pos = pos;
    data.rot = rot;
    data.scale = scale;
    data.rgb = rgb;
    data.visible = visible;
    data.elapsedTime = elapsedTime;
    data.collision.detectionOn = collisionDetectionOn;
    data.collision.isHit = collissionHit;
    data.collision.hitWith = collissionHitWith;
    data.collision.tagID = collissionHitWithTag;
    
    return &data;
}


// ----------------------------------------------------------------------------------------
//  Method to commit the changes that would have occurred from a register callback appying
//   new changes to this object suchs as position, rotation, etc.
-(bool)updateObjDataMin
{
    // Will only update data IF ALL the inData is valid
    if (   data.objID >= 0 && data.objID < REN_OBJ_COUNT
        && data.modelId >= 0 && data.modelId < MODEL_ID_COUNT)
    {
        objID = data.objID;
        modelId = data.modelId;
        tagID = data.tagID;
        pos = data.pos;
        rot = data.rot;
        scale = data.scale;
        rgb = data.rgb;
        visible = data.visible;
        // Note: elapsed time is not updated as it means nothing it is not updated
        collisionDetectionOn = data.collision.detectionOn;
        collissionHit = data.collision.isHit;
        collissionHitWith = data.collision.hitWith;
        collissionHitWithTag = data.collision.tagID;
        
        return true;
    }
    
    return false;
}

@end
