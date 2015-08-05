//
//  Shader.fsh
//  HUDtest
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

//varying lowp vec4 colorVarying;

uniform lowp vec3 color;

void main()
{
  gl_FragColor = vec4(color,1);
}
