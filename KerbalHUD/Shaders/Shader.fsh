
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

varying vec2 Texcoord;

void main()
{
  if (useTex) {
    gl_FragColor = texture2D(tex, Texcoord)*vec4(color,1);
//    gl_FragColor = vec4(Texcoord,0,1);
  } else {
    gl_FragColor = vec4(color,1);
  }
}
