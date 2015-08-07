//
//  Shader.fsh
//  HUDtest
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//
precision highp float;

//varying lowp vec4 colorVarying;

uniform lowp vec3 color;
uniform sampler2D tex;

varying vec2 Texcoord;

void main()
{
  gl_FragColor = vec4(color,1);
}
