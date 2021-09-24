//
//  Copyright © Borna Noureddin. All rights reserved.
//

#ifndef GLESRenderer_hpp
#define GLESRenderer_hpp

#include <stdlib.h>

#include <OpenGLES/ES3/gl.h>

class GLESRenderer
{
public:
    char *LoadShaderFile(const char *shaderFileName);
    GLuint LoadShader(GLenum type, const char *shaderSrc);
    GLuint LoadProgram(const char *vertShaderSrc, const char *fragShaderSrc);
    GLuint LinkProgram(GLuint programObject);

    int GenCube(float scale, float **vertices, float **normals,
                float **texCoords, int **indices, int *numVerts);
    int GenSphere(int numSlices, float radius, float **vertices, float **normals,
                  float **texCoords, int **indices, int *numVerts);
    int GenQuad(float scale, float **vertices, float **normals,
                float **texCoords, int **indices, int *numVerts);
    int GenTree(float scale, float **vertices, float **normals,
                float **texCoords, int *numVerts);
    int GenPlayer(float scale, float **vertices, float **normals,
                float **texCoords, int *numVerts);


private:
    GLuint vertexShader, fragmentShader;
};

#endif /* GLESRenderer_hpp */
