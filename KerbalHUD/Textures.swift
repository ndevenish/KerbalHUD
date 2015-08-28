//
//  Textures.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 27/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

struct Texture : Equatable {
  let glk : GLKTextureInfo?
  let name : GLuint
  let target : GLenum
}

func ==(first: Texture, second: Texture) -> Bool {
  return first.name == second.name
}
  
extension Texture {
  static var None : Texture { return Texture(glk: nil, name: 0, target: GLenum(GL_TEXTURE_2D)) }
  
  init (glk: GLKTextureInfo) {
    self.glk = glk
    self.name = glk.name
    self.target = glk.target
  }
}

extension DrawingTools {
  func deleteTexture(texture : Texture) {
    if texture.name != 0 {
      var val = texture.name
      glDeleteTextures(1, &val)
    }
  }
}