//
//  Shader.vsh
//  KerbalHUD
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

attribute vec4 position;
attribute vec2 texcoord;
attribute vec4 colorAttrib;

//varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;

varying vec2 Texcoord;
varying vec4 colorVarying;

uniform lowp vec2 uvOffset;
uniform lowp vec2 uvScale;

void main()
{
//    vec3 eyeNormal = normalize(normalMatrix * normal);
//    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
//    vec4 diffuseColor = vec4(0.4, 0.4, 1.0, 1.0);
  
//    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
  
//    colorVarying = diffuseColor * nDotVP;
    colorVarying = colorAttrib;
    gl_Position = modelViewProjectionMatrix * position;
    Texcoord = texcoord*uvScale + uvOffset;
}
