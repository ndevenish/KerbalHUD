//
//  Framebuffers.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 26/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

struct Framebuffer : Equatable {
  let name : GLuint
  let texture : Texture
  let stencil : GLuint
  let size : Size2D<Int>
}


func ==(first: Framebuffer, second: Framebuffer) -> Bool {
  return first.name == second.name
    && first.texture == second.texture
    && first.stencil == second.stencil
    && first.size == second.size
}

extension Framebuffer {
  static var Default : Framebuffer {
    return Framebuffer(name: 0, texture: Texture.None, stencil: 0, size: Size2D(w: 0,h: 0))
  }
}

extension DrawingTools {
  func createTextureFramebuffer(
    size : Size2D<Int>, depth: Bool, stencil : Bool) -> Framebuffer
  {
    // Generate a framebuffer
    var fb : GLuint = 0
    glGenFramebuffers(1, &fb)
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fb)
    
    // Generate a texture in the requested size
    var texColorBuffer : GLuint = 0
    glGenTextures(1, &texColorBuffer)
    glBindTexture(GLenum(GL_TEXTURE_2D), texColorBuffer)
    glTexImage2D(GLenum(GL_TEXTURE_2D),
      0, GL_RGBA, GLint(size.w), GLint(size.h),
      0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
    // Non power-of-two textures require non-wrapping settings
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
    // Attach this texture to the framebuffer
    glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER),
      GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D),
      texColorBuffer, 0);

    // Create a stencil buffer to attach, if we want it
    var stencilBuffer : GLuint = 0
    if stencil {
      glGenRenderbuffers(1, &stencilBuffer)
      glBindRenderbuffer(GLenum(GL_RENDERBUFFER), stencilBuffer)
      glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_STENCIL_INDEX8), GLint(size.w), GLint(size.h))
      glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_STENCIL_ATTACHMENT), GLenum(GL_RENDERBUFFER), stencilBuffer)
    }
    
    if !(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE)) {
      fatalError("Framebuffer generation failed");
    }

    // Unbind the new framebuffer
    forceBind(Framebuffer.Default)
    
    return Framebuffer(name: fb,
      texture: Texture(glk: nil, name: texColorBuffer, target: GLenum(GL_TEXTURE_2D)),
      stencil: stencilBuffer,
      size: size)
  }
  
  func deleteFramebuffer(buffer : Framebuffer, texture : Bool = true) {
    var val : GLuint = 0
    if buffer.stencil != 0 {
      val = buffer.stencil
      glDeleteFramebuffers(1, &val)
    }
    if texture {
      deleteTexture(buffer.texture)
    }
    if buffer.name != 0 {
      val = buffer.name
      glDeleteFramebuffers(1, &val)
    }
  }
}