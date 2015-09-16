
//
//  Shader.fsh
//  KerbalHUD
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//
precision highp float;

uniform lowp vec4 color;
uniform sampler2D tex;

varying vec2 Texcoord;

void main()
{
    gl_FragColor = texture2D(tex, Texcoord)*color;
}
