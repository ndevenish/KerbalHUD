
//
//  Shader.fsh
//  KerbalHUD
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//
precision highp float;

//varying lowp vec4 colorVarying;

uniform lowp vec3 color;
uniform sampler2D tex;
uniform bool useTex;
uniform lowp vec2 uvOffset;
uniform lowp vec2 uvScale;


varying vec2 Texcoord;

void main()
{
  if (useTex) {
    gl_FragColor = texture2D(tex, (Texcoord*uvScale)+uvOffset)*vec4(color,1);
//    gl_FragColor = vec4(1,1,1,1);
  } else {
    gl_FragColor = vec4(color,1);
  }
}
