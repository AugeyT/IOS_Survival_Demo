//
//  RenObjData.h
//  Survival
//
//  Created by Richard Tesch on 2021-02-27.
//

#ifndef RenObjData_h
#define RenObjData_h
#import <GLKit/GLKit.h>
#import <Foundation/Foundation.h>

// Define our enumeration set for rendere object types
typedef enum : NSUInteger {
    REN_OBJ_GROUND_PLANE,
    REN_OBJ_TRAP_1,
    REN_OBJ_TRAP_2,
    REN_OBJ_TRAP_3,
    REN_OBJ_TRAP_4,
    REN_OBJ_TRAP_5,
    REN_OBJ_OBSTACLE_1,
    REN_OBJ_OBSTACLE_2,
    REN_OBJ_OBSTACLE_3,
    REN_OBJ_OBSTACLE_4,
    REN_OBJ_OBSTACLE_5,
    REN_OBJ_OBSTACLE_6,
    REN_OBJ_OBSTACLE_7,
//    REN_OBJ_OBSTACLE_8,
//    REN_OBJ_OBSTACLE_9,
//    REN_OBJ_OBSTACLE_10,
//    REN_OBJ_OBSTACLE_11,
//    REN_OBJ_OBSTACLE_12,
//    REN_OBJ_OBSTACLE_13,
    REN_OBJ_PICKUP_1,
    REN_OBJ_PICKUP_2,
    REN_OBJ_PICKUP_3,
    REN_OBJ_PICKUP_4,
    REN_OBJ_PICKUP_5,
    REN_OBJ_PLAYER,
    REN_OBJ_COUNT,
    REN_OBJ_NULL
} REN_OBJ;


// Define our enumeration set fot the model identifier types
typedef enum : NSUInteger {
    MODEL_ID_CUBE,
    MODEL_ID_SPHERE,
    MODEL_ID_QUAD,
    MODEL_ID_TREE,
    MODEL_ID_PLAYER,
    MODEL_ID_COUNT,
} MODEL_ID;


// Define our enumeration set for the renderer object tags
typedef enum : NSUInteger {
    REN_TAG_GND_PLANE,
    REN_TAG_TRAP,
    REN_TAG_OBSTACLE,
    REN_TAG_PICKUP,
    REN_TAG_PLAYER,
    REN_TAG_NONE,
    REN_TAG_COUNT,      // Add more tags if needed but must be before count
} REN_TAG_ID;


// Define our enumerator set for the renderer texture identifiers
typedef enum : NSUInteger {
    REN_TEXTURE_GRASS,
    REN_TEXTURE_ICE,
    REN_TEXTURE_TREE,          // Texture 2 -- Rename to something useful when using
//    REN_TEXTURE_3,          // Texture 3 -- Rename to something useful when using
//    REN_TEXTURE_4,          // Texture 4 -- Rename to something useful when using
//    REN_TEXTURE_5,          // Texture 5 -- Rename to something useful when using
    REN_TEXTURE_COUNT,      // Add more textures if needed but must be before count
    REN_TEXTURE_NONE        // DO NOT APPLY ANY TEXTURE
} REN_TEXTURE_ID;


// Define the collision data structure
typedef struct {
    bool detectionOn;
    bool isHit;
    REN_OBJ hitWith;
    REN_TAG_ID tagID;
} COLLISION_DATA;

// Define the minimum data object structure. This is what is needed
//  to pass data to registered callbacks
typedef struct {
    REN_OBJ objID;
    MODEL_ID modelId;
    REN_TAG_ID tagID;
    GLKVector3 pos;
    GLKVector3 rot;
    GLKVector3 scale;
    GLKVector3 rgb;
    bool visible;
    float elapsedTime;
    COLLISION_DATA collision;
} REN_OBJ_DATA_MIN;


// ----------------------------------------------------------------------------------------
//  Interface definition for the renderer object data class
@interface RenObjData : NSObject

// Identifiers
@property REN_OBJ objID;
@property MODEL_ID modelId;
@property REN_TAG_ID tagID;
@property REN_TEXTURE_ID textureID;
@property GLenum textureSysId;

// Update Matrices
@property GLKVector3 pos;
@property GLKVector3 rot;
@property GLKVector3 scale;
@property GLKVector3 rgb;

// Transformation matrices
@property GLKMatrix4 mvp;   // Model View Projection Matrix
@property GLKMatrix3 nm;    // Normal Matrix
@property GLKMatrix4 mv;    // Model View Matrix

// Used for updates with clients
@property bool visible;
@property SEL updateData;
@property id object;
@property float elapsedTime;
@property bool collisionDetectionOn;
@property bool collissionHit;
@property REN_OBJ collissionHitWith;
@property REN_TAG_ID collissionHitWithTag;


-(id)populate: (REN_OBJ)objID : (MODEL_ID)modelId : (REN_TAG_ID)tagID : (REN_TEXTURE_ID)textureID : (GLenum)textureSysId : (GLKVector3)pos : (GLKVector3)rot : (GLKVector3)scale : (GLKVector3)rgb : (bool)visible : (bool)collisionDetectionOn;

-(REN_OBJ_DATA_MIN*)buildObjDataMin;
-(bool)updateObjDataMin;

@end

#endif /* RenObjData_h */
