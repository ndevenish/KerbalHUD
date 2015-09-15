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
  let size : Size2D<Int>?
}

func ==(first: Texture, second: Texture) -> Bool {
  return first.name == second.name
}
  
extension Texture {
  static var None : Texture { return Texture(glk: nil, name: 0, target: GLenum(GL_TEXTURE_2D), size: nil) }
  
  init (glk: GLKTextureInfo) {
    self.glk = glk
    self.name = glk.name
    self.target = glk.target
    self.size = Size2D(w: Int(glk.width), h: Int(glk.height))
  }
  init (name: GLuint, width: UInt, height: UInt, target: GLenum = GLenum(GL_TEXTURE_2D)) {
    self.glk = nil
    self.name = name
    self.target = target
    
    self.size = Size2D(w: Int(width), h: Int(height))
  }
  
  func debugName(name : String) {
    glLabelObjectEXT(GLenum(GL_TEXTURE), self.name, 0, name)
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


/// Builds a 1X1 white texture to use for non-texture drawing
func generate1X1Texture() -> Texture {
  var tex : GLuint = 0
  glGenTextures(1, &tex)
  glBindTexture(GLenum(GL_TEXTURE_2D), tex)
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT);
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT);
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR);
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR);
  var data : [GLubyte] = [255]
  glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_LUMINANCE, 1, 1, 0, GLenum(GL_LUMINANCE), GLenum(GL_UNSIGNED_BYTE), &data)
  glBindTexture(GLenum(GL_TEXTURE_2D), 0)
  return Texture(name: tex, width: 1, height: 1)
}
