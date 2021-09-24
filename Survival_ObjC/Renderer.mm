//
//  Copyright © 2017 Borna Noureddin. All rights reserved.
//

#import "Renderer.h"
#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#include <chrono>
#include "C++ Files/GLESRenderer.hpp"
#include "RenObjData.h"

//===========================================================================
//  Constant definitions.

const float trapSIZE = 0.1f;
const float obstacleSIZE = 0.19f;
const float pickupSIZE = 0.12f;
const float playerSIZE = 0.05f;
const float cModelRadius = 1.0f;
const GLKVector4 defaultBackgroundColor = GLKVector4Make( 0.0f, 0.0f, 0.0f, 0.0f );
const GLKVector3 defTrapRGB = GLKVector3Make(1.0f, 0.0f, 0.0f);     // RED
const GLKVector3 defObstacleRGB = GLKVector3Make(0.0f, 1.0f, 0.0f); // GREEN
const GLKVector3 defPickupRGB = GLKVector3Make(1.0f, 1.0f, 1.0f);   // WHITE
const GLKVector3 defPlayerRGB = GLKVector3Make(1.0f, 1.0f, 0.0f);   // YELLOW
const GLKVector3 defFlashLightPos = GLKVector3Make(0.0f, 0.0f, -1.0f);
const GLKVector3 defDiffuseLightPos = GLKVector3Make(0.0f, 1.0f, 1.5f);
const GLKVector4 defDiffuseComponent = GLKVector4Make(1.0f, 1.0f, 1.0f, 1.0f);
const GLKVector4 defSpecularComponent = GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f);
const GLKVector4 defAmbientComponent = GLKVector4Make(0.65f, 0.65f, 0.65f, 1.0f);
const GLKVector4 defNoTextureColor = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
const GLKVector3 defGndPlaneSize = GLKVector3Make(4.0, 7.0, 0.1);
const float defShininess = 200.0f;
const float defAlphaValue = 1.0f;

//===========================================================================
//  GL uniforms, attributes, etc.

// List of uniform values used in shaders
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_TEXTURE,
    UNIFORM_MODELVIEW_MATRIX,
    // ### Add uniforms for lighting parameters here...
    UNIFORM_FLASHLIGHT_POSITION,
    UNIFORM_FLASHLIGHT2_POSITION,
    UNIFORM_DIFFUSE_LIGHT_POSITION,
    UNIFORM_SHININESS,
    UNIFORM_AMBIENT_COMPONENT,
    UNIFORM_DIFFUSE_COMPONENT,
    UNIFORM_SPECULAR_COMPONENT,
    UNIFORM_ALPHA_CHANNEL,
    UNIFORM_USE_FOG,
    UNIFORM_NO_TEXTURE_COLOR,
    UNIFORM_TEXTURE_STATE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_POSITION,
    ATTRIB_NORMAL,
    ATTRIB_TEXTURE_COORDINATE,
    NUM_ATTRIBUTES
};

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Defines the model data storage structure to allow for better encapsulation
//  of data such as those required by VBO & VBAs
struct MODEL_DATA {
    int *indices;
    int numIndices;
    int numVertices;
    float *vertices;
    float *normals;
    float *texCoords;

    // GLES buffer IDs
    GLuint _vertexArray;
    GLuint _vertexBuffers[3];
    GLuint _indexBuffer;

    int model_id;
};



//===========================================================================
//  Class interface
//
@interface Renderer () {
    
    // iOS hooks
    GLKView *theView;
    
    // GL ES Variables
    GLESRenderer glesRenderer;
    GLuint programObject;
    GLuint textureId[REN_TEXTURE_COUNT];
    
    // Lighting Parameters
    // ### Add lighting parameters here
    GLKVector4 diffuseComponent;
    float shininess;
    GLKVector3 flashlightPosition;
    GLKVector3 flashlightPositionPickup;
    GLKVector3 diffuseLightPosition;
    float alphaValue;
    bool useFog;
    GLKVector4 noTextureColor;
    bool useTextures;

    // All the data for our object models including transformation matrices for each
    MODEL_DATA model[MODEL_ID_COUNT];
    NSMutableArray *objDat;
        
    // Misc UI variables
    std::chrono::time_point<std::chrono::steady_clock> lastTime;
    float elapsedTime;
    GLKVector4 backgroundColor;
    
    ViewController *viewController;
}

@end

@implementation Renderer

@synthesize specularComponent;
@synthesize ambientComponent;
@synthesize playerPosX, playerPosY;
@synthesize pickupPosX, pickupPosY;

//==========================================================================
// Initial setup of GL using iOS view & all our fixed or pre-defined models
//==========================================================================
- (void)setup:(GLKView *)view
{
    viewController = [[ViewController alloc] init];
    // Create GL context
    view.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    if (!view.context) {
        NSLog(@"Failed to create ES context");
    }
    // Set up context
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    theView = view;
    [EAGLContext setCurrentContext:view.context];
    
    // Load in and set up shaders
    if (![self setupShaders])
        return;
    
    // Tell OpenGL how to setup the viewport, backgroud color, and enable depth test
    glViewport(0, 0, (int)theView.drawableWidth, (int)theView.drawableHeight);
    backgroundColor = defaultBackgroundColor;
    glClearColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a );
    glEnable(GL_DEPTH_TEST);
    
    // set up player and pickup position for light to follow
    playerPosX = playerPosY = 0.0f;
    pickupPosX = pickupPosY = 0.0f;
        
    // Create all the default object parqmeters based on their model assignments
    GLKVector3 defVal = GLKVector3Make(0.0f, 0.0f, 0.0f);
    GLKVector3 trapRGB = defTrapRGB;
    GLKVector3 trapSize = GLKVector3Make(trapSIZE, trapSIZE, trapSIZE);
    GLKVector3 obstacleRGB = defObstacleRGB;
    GLKVector3 obstacleSize = GLKVector3Make(obstacleSIZE, obstacleSIZE, obstacleSIZE);
    GLKVector3 pickupRGB = defPickupRGB;
    GLKVector3 pickupSize = GLKVector3Make(pickupSIZE, pickupSIZE, pickupSIZE);
    GLKVector3 playerRGB = defPlayerRGB;
    GLKVector3 playerSize = GLKVector3Make(playerSIZE, playerSIZE, playerSIZE);
    GLKVector3 gndPlaneRGB = GLKVector3Make(backgroundColor.r, backgroundColor.g, backgroundColor.b);
    GLKVector3 gndPlaneSize = defGndPlaneSize;

    // Start building the renderer objects
    // !!! NOTE !!!! This must follow the order of decleration of the REN_OBJ types
    //               as this is a flaw to the current design. Would like to convert to a naed object array
    //               to remove instantiation order.
    objDat = [NSMutableArray new];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_GROUND_PLANE :MODEL_ID_CUBE :REN_TAG_GND_PLANE :REN_TEXTURE_GRASS :GL_TEXTURE1 :defVal :defVal :gndPlaneSize :gndPlaneRGB :YES :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_TRAP_1 :MODEL_ID_SPHERE :REN_TAG_TRAP :REN_TEXTURE_NONE :GL_TEXTURE2 :defVal :defVal :trapSize :trapRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_TRAP_2 :MODEL_ID_SPHERE :REN_TAG_TRAP :REN_TEXTURE_NONE :GL_TEXTURE2 :defVal :defVal :trapSize :trapRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_TRAP_3 :MODEL_ID_SPHERE :REN_TAG_TRAP :REN_TEXTURE_NONE :GL_TEXTURE2 :defVal :defVal :trapSize :trapRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_TRAP_4 :MODEL_ID_SPHERE :REN_TAG_TRAP :REN_TEXTURE_NONE :GL_TEXTURE2 :defVal :defVal :trapSize :trapRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_TRAP_5 :MODEL_ID_SPHERE :REN_TAG_TRAP :REN_TEXTURE_NONE :GL_TEXTURE2 :defVal :defVal :trapSize :trapRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_1 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_2 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_3 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_4 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_5 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_6 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_7 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
//    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_8 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
//    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_9 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
//    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_10 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
//    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_11 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
//    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_12 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
//    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_OBSTACLE_13 :MODEL_ID_TREE :REN_TAG_OBSTACLE :REN_TEXTURE_TREE :GL_TEXTURE3 :defVal :defVal :obstacleSize :obstacleRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_PICKUP_1 :MODEL_ID_SPHERE :REN_TAG_PICKUP :REN_TEXTURE_NONE :GL_TEXTURE4 :defVal :defVal :pickupSize :pickupRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_PICKUP_2 :MODEL_ID_SPHERE :REN_TAG_PICKUP :REN_TEXTURE_NONE :GL_TEXTURE4 :defVal :defVal :pickupSize :pickupRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_PICKUP_3 :MODEL_ID_SPHERE :REN_TAG_PICKUP :REN_TEXTURE_NONE :GL_TEXTURE4 :defVal :defVal :pickupSize :pickupRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_PICKUP_4 :MODEL_ID_SPHERE :REN_TAG_PICKUP :REN_TEXTURE_NONE :GL_TEXTURE4 :defVal :defVal :pickupSize :pickupRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_PICKUP_5 :MODEL_ID_SPHERE :REN_TAG_PICKUP :REN_TEXTURE_NONE :GL_TEXTURE4 :defVal :defVal :pickupSize :pickupRGB :NO :NO]];
    [objDat addObject:[[RenObjData alloc] populate:REN_OBJ_PLAYER :MODEL_ID_PLAYER :REN_TAG_PLAYER :REN_TEXTURE_NONE :GL_TEXTURE5 :defVal :defVal :playerSize :playerRGB :NO :NO]];

    // Start up the clock to measure time between updates
    lastTime = std::chrono::steady_clock::now();
}


//===========================================================================
// Load and set up shaders
//===========================================================================
- (bool)setupShaders
{
    // Load shaders
    char *vShaderStr = glesRenderer.LoadShaderFile([[[NSBundle mainBundle] pathForResource:[[NSString stringWithUTF8String:"Shader.vsh"] stringByDeletingPathExtension] ofType:[[NSString stringWithUTF8String:"Shader.vsh"] pathExtension]] cStringUsingEncoding:1]);
    char *fShaderStr = glesRenderer.LoadShaderFile([[[NSBundle mainBundle] pathForResource:[[NSString stringWithUTF8String:"Shader.fsh"] stringByDeletingPathExtension] ofType:[[NSString stringWithUTF8String:"Shader.fsh"] pathExtension]] cStringUsingEncoding:1]);
    programObject = glesRenderer.LoadProgram(vShaderStr, fShaderStr);
    if (programObject == 0)
        return false;
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(programObject, ATTRIB_POSITION, "position");
    glBindAttribLocation(programObject, ATTRIB_NORMAL, "normal");
    glBindAttribLocation(programObject, ATTRIB_TEXTURE_COORDINATE, "texCoordIn");
    
    // Link shader program
    programObject = glesRenderer.LinkProgram(programObject);

    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(programObject, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(programObject, "normalMatrix");
    uniforms[UNIFORM_MODELVIEW_MATRIX] = glGetUniformLocation(programObject, "modelViewMatrix");
    uniforms[UNIFORM_TEXTURE] = glGetUniformLocation(programObject, "texSampler");
    // ### Add lighting uniform locations here...
    uniforms[UNIFORM_FLASHLIGHT_POSITION] = glGetUniformLocation(programObject, "flashlightPosition");
    uniforms[UNIFORM_FLASHLIGHT2_POSITION] = glGetUniformLocation(programObject, "flashlightPositionPickup");
    uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION] = glGetUniformLocation(programObject, "diffuseLightPosition");
    uniforms[UNIFORM_SHININESS] = glGetUniformLocation(programObject, "shininess");
    uniforms[UNIFORM_AMBIENT_COMPONENT] = glGetUniformLocation(programObject, "ambientComponent");
    uniforms[UNIFORM_DIFFUSE_COMPONENT] = glGetUniformLocation(programObject, "diffuseComponent");
    uniforms[UNIFORM_SPECULAR_COMPONENT] = glGetUniformLocation(programObject, "specularComponent");
    uniforms[UNIFORM_ALPHA_CHANNEL] = glGetUniformLocation(programObject, "alpha");
    uniforms[UNIFORM_USE_FOG] = glGetUniformLocation(programObject, "useFog");
    uniforms[UNIFORM_NO_TEXTURE_COLOR] = glGetUniformLocation(programObject, "noTextureColor");
    uniforms[UNIFORM_TEXTURE_STATE] = glGetUniformLocation(programObject, "useTextures");

    // Set up lighting parameters
    // ### Set default lighting parameter values here...
    diffuseLightPosition = defDiffuseLightPos;
    diffuseComponent = defDiffuseComponent;
    shininess = defShininess;
    specularComponent = defSpecularComponent;
    ambientComponent = defAmbientComponent;
    alphaValue = defAlphaValue;
    noTextureColor = defNoTextureColor;
    useTextures = FALSE;

    // Init any variables required for shaders
    useFog = NO;

    return true;
}

//===========================================================================
// Load model(s)
//===========================================================================
- (void)loadModels
{
    
    for (int idx = 0; idx < MODEL_ID_COUNT; idx++)
    {
        // Create VAOs
        glGenVertexArrays(1, &model[idx]._vertexArray);
        glBindVertexArray(model[idx]._vertexArray);

        // Create VBOs
        glGenBuffers(NUM_ATTRIBUTES, model[idx]._vertexBuffers);   // One buffer for each attribute
        glGenBuffers(1, &model[idx]._indexBuffer);                 // Index buffer

        // Generate vertex attribute values from model
        int numVerts = 0;
        switch (idx)
        {
            case MODEL_ID_CUBE:
                // Load the CUBE model data
                model[MODEL_ID_CUBE].model_id = MODEL_ID_CUBE;
                model[MODEL_ID_CUBE].numIndices = glesRenderer.GenCube(cModelRadius, &model[MODEL_ID_CUBE].vertices, &model[MODEL_ID_CUBE].normals, &model[MODEL_ID_CUBE].texCoords, &model[MODEL_ID_CUBE].indices, &numVerts);
                break;
                
            case MODEL_ID_SPHERE:
                // Load the SPHERE model data
                model[MODEL_ID_SPHERE].model_id = MODEL_ID_SPHERE;
                model[MODEL_ID_SPHERE].numIndices = glesRenderer.GenSphere(24, cModelRadius, &model[MODEL_ID_SPHERE].vertices, &model[MODEL_ID_SPHERE].normals, &model[MODEL_ID_SPHERE].texCoords, &model[MODEL_ID_SPHERE].indices, &numVerts);
                break;
                
            case MODEL_ID_QUAD:
                // Load the QUAD model data
                model[MODEL_ID_QUAD].model_id = MODEL_ID_QUAD;
                model[MODEL_ID_QUAD].numIndices = glesRenderer.GenQuad(cModelRadius, &model[MODEL_ID_QUAD].vertices, &model[MODEL_ID_QUAD].normals, &model[MODEL_ID_QUAD].texCoords, &model[MODEL_ID_QUAD].indices, &numVerts);
                break;
                
            case MODEL_ID_TREE:
                model[MODEL_ID_TREE].model_id = MODEL_ID_TREE;
                model[MODEL_ID_TREE].numIndices = glesRenderer.GenTree(cModelRadius, &model[MODEL_ID_TREE].vertices, &model[MODEL_ID_TREE].normals, &model[MODEL_ID_TREE].texCoords, &numVerts);
                break;
                
            case MODEL_ID_PLAYER:
                model[MODEL_ID_PLAYER].model_id = MODEL_ID_PLAYER;
                model[MODEL_ID_PLAYER].numIndices = glesRenderer.GenPlayer(cModelRadius, &model[MODEL_ID_PLAYER].vertices, &model[MODEL_ID_PLAYER].normals, &model[MODEL_ID_TREE].texCoords, &numVerts);
                break;
                
            default:
                NSLog(@"Unrecognized Model ID %i", idx);
                exit(1);
        }
        
        // Set up VBOs...
        
        // Position
        glBindBuffer(GL_ARRAY_BUFFER, model[idx]._vertexBuffers[0]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 3 * numVerts,
                        model[idx].vertices, GL_STATIC_DRAW);
        glEnableVertexAttribArray(ATTRIB_POSITION);
        glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE,
                                  3 * sizeof(float), BUFFER_OFFSET(0));
            
        // Normal vector
        glBindBuffer(GL_ARRAY_BUFFER, model[idx]._vertexBuffers[1]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 3 * numVerts,
                        model[idx].normals, GL_STATIC_DRAW);
        glEnableVertexAttribArray(ATTRIB_NORMAL);
        glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE,
                                  3 * sizeof(float), BUFFER_OFFSET(0));
            
        // Texture coordinate
        glBindBuffer(GL_ARRAY_BUFFER, model[idx]._vertexBuffers[2]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 3 * numVerts,
                        model[idx].texCoords, GL_STATIC_DRAW);
        glEnableVertexAttribArray(ATTRIB_TEXTURE_COORDINATE);
        glVertexAttribPointer(ATTRIB_TEXTURE_COORDINATE, 2, GL_FLOAT,
                                  GL_FALSE, 2 * sizeof(float), BUFFER_OFFSET(0));
        
        // Set up index buffer
        if (model[idx].model_id != MODEL_ID_TREE) {
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, model[idx]._indexBuffer);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*model[idx].numIndices, model[idx].indices, GL_STATIC_DRAW);
        }

        // Reset VAO
        glBindVertexArray(0);
    }
    
    // Load our textures by looping through the texture ids assigned in renderer
    //  object data class. However, we assign the texture id to our array
    //  representing the ids textureIds[REN_TEXTURE_COUNT]
    NSString *textureFile;
    GLenum glTextureId;
    for (int idx = 0; idx < REN_TEXTURE_COUNT; idx++)
    {
        switch (idx)
        {
            case REN_TEXTURE_GRASS:
                glTextureId = GL_TEXTURE1;
                textureFile = @"Dirt and Pebble (9by16).jpg";
                break;
            case REN_TEXTURE_ICE:
                glTextureId = GL_TEXTURE2;
                textureFile = @"Ice_9by16.jpg";
                break;
            case REN_TEXTURE_TREE:
                glTextureId = GL_TEXTURE3;
                textureFile = @"tree2.jpg";
                break;
/*
            case REN_TEXTURE_3:
                glTextureId = GL_TEXTURE4;
                textureFile = @"BothWalls.jpg";
                break;
            case REN_TEXTURE_4:
                glTextureId = GL_TEXTURE5;
                textureFile = @"Floor_1.jpg";
                break;
            case REN_TEXTURE_5:
                glTextureId = GL_TEXTURE6;
                textureFile = @"crate.jpg";
                break;
*/
            default:
                NSLog(@"Unrecognized texture file, %i", idx);
                exit(1);
                break;
        }
        
        // Load texture to apply and set up texture in GL
        textureId[idx] = [self setupTexture:textureFile];
        glActiveTexture(glTextureId);
        glBindTexture(GL_TEXTURE_2D, textureId[idx]);
        glGenerateMipmap(GL_TEXTURE_2D);
        glUniform1i(uniforms[UNIFORM_TEXTURE], textureId[idx]);
    }
}


//===========================================================================
// Load in and set up texture image (adapted from Ray Wenderlich)
//===========================================================================
- (GLuint)setupTexture:(NSString *)fileName
{
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }
    
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte *spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);
    return texName;
}


//===========================================================================
// Clean up code before deallocating renderer object
//===========================================================================
- (void)dealloc
{
    // Clean up the models
    for (int idx = 0; idx < MODEL_ID_COUNT; idx++)
    {
        if (model[idx].vertices)
            free(model[idx].vertices);
        if (model[idx].indices)
            free(model[idx].indices);
        if (model[idx].normals)
            free(model[idx].normals);
        if (model[idx].texCoords)
            free(model[idx].texCoords);
        
        // Delete GL buffers
        glDeleteBuffers(3, model[idx]._vertexBuffers);
        glDeleteBuffers(1, &model[idx]._indexBuffer);
        glDeleteVertexArrays(1, &model[idx]._vertexArray);
    }
    
    if (programObject)
    {
        glDeleteProgram(programObject);
        programObject = 0;
    }
}


//===========================================================================
// Update each frame
//===========================================================================
- (void)update
{
    auto currentTime = std::chrono::steady_clock::now();
    elapsedTime = std::chrono::duration_cast<std::chrono::milliseconds>(currentTime - lastTime).count();
    lastTime = currentTime;

    // To save time we only need to create the base model view matrix (the camera)
    //   once per update and apply it to every object.
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -5.0);
    
    // Loop through all our objects and call any registered updates.
    for (int objitem = 0; objitem < objDat.count; objitem++)
    {
        RenObjData* aRenObj = objDat[objitem];
        
        if (aRenObj.updateData != nullptr)
        {
            // Update ellapsed time since list update
            aRenObj.elapsedTime = elapsedTime;
            
            // There was a registered callback so call them
            [aRenObj.object performSelector:aRenObj.updateData];
        }
        
        // Only do work if its visible
        if (aRenObj.visible == YES)
        {
            // Perform all necessary transformations + rotations + scaling
            //
            // Start with identity matrix translated by X,Y,Z position all with offsets
            // to assure object is always away from camera view and not spliced in it.
            // Set up model view matrix (place model in world)
            aRenObj.mv = GLKMatrix4Translate(GLKMatrix4Identity, aRenObj.pos.x, aRenObj.pos.y, aRenObj.pos.z);
            aRenObj.mv = GLKMatrix4Rotate(aRenObj.mv, aRenObj.rot.x, 1.0f, 0.0f, 0.0f );
            aRenObj.mv = GLKMatrix4Rotate(aRenObj.mv, aRenObj.rot.y, 0.0f, 1.0f, 0.0f );
            aRenObj.mv = GLKMatrix4Rotate(aRenObj.mv, aRenObj.rot.z, 0.0f, 0.0f, 1.0f );
            aRenObj.mv = GLKMatrix4Scale(aRenObj.mv, aRenObj.scale.x, aRenObj.scale.y, aRenObj.scale.z);
            aRenObj.mv = GLKMatrix4Multiply(baseModelViewMatrix, aRenObj.mv);
            
            // Create the normal matrix needed for the shader calculations
            aRenObj.nm = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(aRenObj.mv), NULL);
            
            // Now apply the model view perspective using our display aspect ratio. Using
            //  aspect we can create perspective matrix using 60 degree field of view with a
            //  near plane of 1 and far plane of 20. This will define the viewing angle as well
            //  as the volume of the view
            float aspect = (float)theView.drawableWidth / (float)theView.drawableHeight;
            GLKMatrix4 perspective = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60.0f), aspect, 1.0f, 20.0f);

            // Calculate model-view-projection matrix
            aRenObj.mvp = GLKMatrix4Multiply(perspective, aRenObj.mv);
        }
    }
    
    // Setup use of flashlight which may or not be used in this particular implementation
    flashlightPosition = GLKVector3Make(playerPosX*2.5, playerPosY*2.5, 1.0f);
    flashlightPositionPickup = GLKVector3Make(pickupPosX*2.5, pickupPosY*2.5, 1.0f);
    
    // Perform a collision detect cycle.
    [self updateCollisionStates];
}


//===========================================================================
// Draw calls for each frame
//===========================================================================
- (void)draw:(CGRect)drawRect;
{

    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT2_POSITION], 1, flashlightPositionPickup.v);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    
    // Tell OpenGL to clear the screen, and use the
    //  fragment and vertex shaders we setup in setupShaders()
    glClear ( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        // Select Shaders
    glUseProgram ( programObject );
    
    // This code is commented out as some form of it would be required to texture the 3d models appropriately
    /*SCNRenderer *renderer = [SCNRenderer rendererWithContext:theView.context options:nil];
    SCNScene *scene = [SCNScene sceneNamed:@"art.scnassets/ball.scn"];
    
    SCNNode *camNode;
    camNode.camera = [SCNCamera camera];
    camNode.position = SCNVector3Make(0.0f, 0.0f, 0.0f);
    [scene.rootNode addChildNode:camNode];

    SCNNode *boxNode = [SCNNode nodeWithGeometry:[SCNBox geometry]];
    [boxNode runAction:[SCNAction repeatActionForever:[SCNAction rotateByX:1 y:1 z:1 duration:1]]];
    [scene.rootNode addChildNode:boxNode];
    
    renderer.scene = scene;
    renderer.pointOfView = camNode;
    [renderer setPlaying:true];*/

    // Loop through each of our objects applying there updated matrixes
    for (int objitem = 0; objitem < objDat.count; objitem++)
    {
        RenObjData* aRenObj = objDat[objitem];

        // Only do work if its visible
        if (aRenObj.visible == YES)
        {
            if (aRenObj.textureID != REN_TEXTURE_NONE)
            {
                // Select the shader to use for the object and texture assinge to this object
                glEnable(GL_TEXTURE_2D);
                glDisable(GL_CULL_FACE);
                glDisable(GL_BLEND);
                glActiveTexture(aRenObj.textureSysId);
                glBindTexture(GL_TEXTURE_2D, textureId[aRenObj.textureID]);
                glUniform1i(uniforms[UNIFORM_TEXTURE], textureId[aRenObj.textureID]);
                useTextures = YES;
                alphaValue = 1.0f;
            }
            else
            {
                // No textures being used for this object
                glDisable(GL_TEXTURE_2D);
                noTextureColor = GLKVector4Make(aRenObj.rgb.r, aRenObj.rgb.g, aRenObj.rgb.b, 1.0f);
                useTextures = NO;
            }

            // Select VAO
            glBindVertexArray(model[aRenObj.modelId]._vertexArray);

            // Set up uniforms
            glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, aRenObj.mvp.m);
            glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, aRenObj.nm.m);
            glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, aRenObj.mv.m);
            // ### Set values for lighting parameter uniforms here...
            glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
            glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
            glUniform1f(uniforms[UNIFORM_ALPHA_CHANNEL], alphaValue);
            glUniform4fv(uniforms[UNIFORM_NO_TEXTURE_COLOR], 1, noTextureColor.v);
            glUniform1i(uniforms[UNIFORM_TEXTURE_STATE], useTextures);
            
            // Only process if logic if current object is not a 3D model player or obstacle
            if (aRenObj.tagID != REN_TAG_OBSTACLE && aRenObj.tagID != REN_TAG_PLAYER) {
                // Select VBO and draw
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, model[aRenObj.modelId]._indexBuffer);
                glDrawElements(GL_TRIANGLES, model[aRenObj.modelId].numIndices, GL_UNSIGNED_INT, 0);
            } else {
                // This is player or obstacle that requires array buffers to draw the 3D models
                int numVertices;
                if (aRenObj.tagID == REN_TAG_PLAYER) {
                    numVertices = 9216;
                } else {
                    numVertices = 30;
                }
                glDrawArrays(GL_TRIANGLES, 0, numVertices);
            }
        }
    }
}


//===========================================================================
// Called by clients who want to register for object pre-updates
//===========================================================================
- (void)registerUpdate:(REN_OBJ)getUpdatesfor theUpdatefunc:(SEL)func fromObject:(id) object
{
    if (getUpdatesfor >= 0 && getUpdatesfor < REN_OBJ_COUNT) {
        if (func != nullptr) {
            RenObjData* aRenObj = objDat[getUpdatesfor];
            
            aRenObj.updateData = func;
            aRenObj.object = object;
        }
    }
 }


//===========================================================================
// Called by clients to update their modified data during a update callback
//===========================================================================
// Note required because I cannot get the arguments passed int the call back
-(REN_OBJ_DATA_MIN*)updateData:(REN_OBJ)objId
{
    REN_OBJ_DATA_MIN *dataptr = NULL;
    
    if (objId >= 0 && objId < REN_OBJ_COUNT)
    {
        RenObjData* aRenObj = objDat[objId];
        dataptr = [aRenObj buildObjDataMin];
    }
    return dataptr;
}


//===========================================================================
// Draw calls for each frame
//===========================================================================
// Note required because I cannot get the arguments passed int the call back
-(bool)updateCommit:(REN_OBJ)objId
{
    bool rslt = false;
    
    if (objId >= 0 && objId < REN_OBJ_COUNT)
    {
        RenObjData* aRenObj = objDat[objId];
        rslt = [aRenObj updateObjDataMin];
    }
    
    return rslt;
}

//===========================================================================
// Called post update to update collision states
//===========================================================================
-(void) updateCollisionStates
{
    RenObjData* playerObj = nullptr;
    bool playerFound = NO;
    
    // get the player data and then loop through each object seeing if there is a collision with it
    for (int j = 0; j < REN_OBJ_COUNT; j++)
    {
        playerObj = objDat[j];
        
        if (playerObj.objID == REN_OBJ_PLAYER)
        {
            playerFound = YES;
            break;
        }
    }
    
    if (playerFound == YES && playerObj != nullptr)
    {
        for (int i = 0; i < REN_OBJ_COUNT; i++)
        {
            RenObjData* aRenObj = objDat[i];
            
            if (   (aRenObj.objID != playerObj.objID && aRenObj.objID != REN_OBJ_GROUND_PLANE)
                && (aRenObj.collisionDetectionOn == TRUE || playerObj.collisionDetectionOn == TRUE)
                && (aRenObj.visible == TRUE && playerObj.visible == TRUE))
            {
                // Check if the current object has made contact with the player
                GLfloat distToCenters = GLKVector3Distance(aRenObj.pos, playerObj.pos);
                
                // NOTE: This is accepting a limitation that all objects are cylinder colliders
                //       there is no way at this time to have irregular shapes.
                
                // Determine the distance from each object centers
                GLfloat radiusOfObj = cModelRadius * aRenObj.scale.x;
                GLfloat radiusOfPlayer = cModelRadius * playerObj.scale.x;
                
                // Adjust the center to center distance so it is outside radius of objects
                // Npte a fudge factor is required to offset rounding as well as draw rates.
                distToCenters -= radiusOfObj + radiusOfPlayer - 0.12f;
                
                // Clamp the distance so it is always no less than zero (to be safe)
                distToCenters = MAX(distToCenters, 0.0f);
                
                // Last record if collision occurred with the objects
                bool collided = (distToCenters <= radiusOfObj);
                
                // Is there a collision to record with non player on=bject?
                // Note: It is up to solver to clear the hit flag when they no longer need it
                if (collided == YES && aRenObj.collisionDetectionOn == TRUE)
                {
                    // Record the collision information
                    aRenObj.collissionHit = TRUE;
                    aRenObj.collissionHitWith = playerObj.objID;
                    aRenObj.collissionHitWithTag = playerObj.tagID;
                }
                
                // Is there a collision to record with player object?
                // Note: It is up to solver to clear the hit flag when they no longer need it
                if (collided == YES && playerObj.collisionDetectionOn == TRUE)
                {
                    // Record the collision information
                    playerObj.collissionHit = TRUE;
                    playerObj.collissionHitWith = aRenObj.objID;
                    playerObj.collissionHitWithTag = aRenObj.tagID;
                }
            }
        }
    }
}


//===========================================================================
// Called to do look ahead for collision prediction based on a possible move
//===========================================================================
-(bool) checkCollidePos:(float) x andPosY: (float)y;
{
    bool result = false;
    RenObjData* playerObj = nullptr;
    
    // get the player data and then loop through each object seeing if there is a collision with it
    for (int j = 0; j < REN_OBJ_COUNT; j++)
    {
        RenObjData* aRod = objDat[j];
        
        if (aRod.objID == REN_OBJ_PLAYER)
        {
            playerObj = objDat[j];
            break;
        }
    }
    
    if (playerObj != nullptr)
    {
        for (int i = REN_OBJ_OBSTACLE_1; i < REN_OBJ_OBSTACLE_7; i++)
        {
            RenObjData* aRod = objDat[i];
            
            if (aRod.visible == TRUE)
            {
                // Check if the current object has made contact with the player
                GLKVector3 newPos = GLKVector3Make(x, y, 0.0f);
                GLfloat distToCenters = GLKVector3Distance(aRod.pos, newPos);
                
                // NOTE: This is accepting a limitation that all objects are cylinder colliders
                //       there is no way at this time to have irregular shapes.
                
                // Determine the distance from each object centers
                GLfloat radiusOfObj = cModelRadius * aRod.scale.x * 0.8;
                GLfloat radiusOfPlayer = cModelRadius * playerObj.scale.x;
                
                // Adjust the center to center distance so it is outside radius of objects
                // Npte a fudge factor is required to offset rounding as well as draw rates.
                distToCenters -= radiusOfObj + radiusOfPlayer - 0.12f;
                
                // Clamp the distance so it is always no less than zero (to be safe)
                distToCenters = MAX(distToCenters, 0.0f);
                
                // Last record if collision occurred with the objects
                result = (distToCenters <= radiusOfObj);
                if (result) break;
            }
        }
    }
    
    return result;
}


//===========================================================================
// Allows for requests to change an object texture to another registered texture
//===========================================================================
- (void)changeFloorTexture:(bool)useIce
{
    RenObjData* floorObj = nullptr;
    
    // get the player data and then loop through each object seeing if there is a collision with it
    for (int j = 0; j < REN_OBJ_COUNT; j++)
    {
        floorObj = objDat[j];
        
        if (floorObj.objID == REN_OBJ_GROUND_PLANE)
        {
            floorObj.textureID = (useIce) ? REN_TEXTURE_ICE : REN_TEXTURE_GRASS;
            floorObj.textureSysId = (useIce) ? GL_TEXTURE2 : GL_TEXTURE1;
            break;
        }
    }
}

@end

