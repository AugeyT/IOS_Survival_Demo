#version 300 es
precision highp float;

in vec3 eyeNormal;
in vec4 eyePos;
in vec2 texCoordOut;
out vec4 fragColor;

uniform sampler2D texSampler;

// ### Set up lighting parameters as uniforms
uniform vec3 flashlightPosition;
uniform vec3 flashlightPositionPickup;
uniform vec3 diffuseLightPosition;
uniform vec4 diffuseComponent;
uniform float shininess;
uniform vec4 specularComponent;
uniform vec4 ambientComponent;
uniform float alpha;
uniform bool useFog;
uniform vec4 noTextureColor;
uniform bool useTextures;

void main()
{
    // ### Calculate phong model using lighting parameters and interpolated values from vertex shader
    vec4 ambient = ambientComponent;

    vec3 L1 = normalize(flashlightPosition - eyePos.xyz);
    vec3 L2 = normalize(flashlightPositionPickup - eyePos.xyz);
    
    vec3 N = normalize(eyeNormal);
    float nDotVP = max(0.0, dot(N, normalize(diffuseLightPosition.xyz)));
    vec4 diffuse = diffuseComponent * nDotVP;

    vec3 E = normalize(-eyePos.xyz);
    vec3 H1 = normalize(L1+E);
    vec3 H2 = normalize(L2+E);
    float Ks1 = 0.0;
    if (dot(N, H1) > cos(0.1)) {
        Ks1 = pow(max(dot(N, H1), 0.0), shininess);
    }
    vec4 specular1 = Ks1*specularComponent;
    if( dot(L1, N) < 0.0 ) {
        specular1 = vec4(0.0, 0.0, 0.0, 1.0);
    }
    
    float Ks2 = 0.0;
    if (dot(N, H2) > cos(0.05)) {
        Ks2 = pow(max(dot(N, H2), 0.0), shininess);
    }
    vec4 specular2 = Ks2*specularComponent;
    if( dot(L2, N) < 0.0 ) {
        specular2 = vec4(0.0, 0.0, 0.0, 1.0);
    }
        
    // Creaee our base fragment color
    fragColor = (ambient + diffuse + specular1 + specular2);
    
    // Is textures used for this pass?
    if (useTextures) {
        // Update fragment color with the texture matchinf fragment
        fragColor *= texture(texSampler, texCoordOut);
    } else {
        // No tetures so update fragment color with the selected objects assigned colours
        fragColor *= noTextureColor;
    }

    if (useFog)
    {
        // Fog effect added (linear)
        float fogDist = (gl_FragCoord.z / gl_FragCoord.w);
        vec4 fogColour = vec4(1.0, 1.0, 1.0, 1.0);
        float fogFactor = (1.2 - fogDist) / (1.2 - 1.0);
        fogFactor = clamp(fogFactor, 0.0, 1.0);
        fragColor = mix(fogColour, fragColor, fogFactor);
    }
    fragColor.a = alpha;
}
