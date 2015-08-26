//
//  InstrumentPanel.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 26/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit


private struct PanelEntry {
  var instrument  : Instrument
  let framebuffer : FramebufferInfo
}

private struct FramebufferInfo {
  let buffer : GLuint
  let texture : GLuint
  let stencil : GLuint
}

class InstrumentPanel
{
  var connection : TelemachusInterface? {
    didSet {
      for var i in instruments {
        i.instrument.dataProvider = connection
      }
    }
  }
  
  private let drawing : DrawingTools
  private var instruments : [PanelEntry] = []
  
  init(tools : DrawingTools)
  {
    drawing = tools
  }
  
  deinit
  {
    for i in instruments
    {
      var buffer = i.framebuffer.stencil
      glDeleteFramebuffers(1, &buffer)
      buffer = i.framebuffer.texture
      glDeleteTextures(1, &buffer)
      buffer = i.framebuffer.buffer
      glDeleteFramebuffers(1, &buffer)
    }
  }

  func update()
  {
    for i in instruments {
      i.instrument.update()
    }
  }
  
  func draw()
  {
    processGLErrors()
    for i in instruments {
      // Bind the framebuffer for this instrument
      glBindFramebuffer(GLenum(GL_FRAMEBUFFER), i.framebuffer.buffer)
      // Reassign the projection matrix
      drawing.program.projection = GLKMatrix4MakeOrtho(
        0, i.instrument.screenHeight, 0, i.instrument.screenWidth, -10, 10)
      i.instrument.draw()
    }
    
//    processGLErrors()
//    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
//    let fbStatus = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
//    if !(fbStatus == GLenum(GL_FRAMEBUFFER_COMPLETE)) {
//      if (fbStatus == GLenum(GL_FRAMEBUFFER_UNDEFINED)) {
//        fatalError("Framebuffer undefined");
//      } else {
//        fatalError("Framebuffer incomplete");
//      }
//    }
    
//        processGLErrors()
    drawing.setFramebuffer(0)
    // Now, draw all of the instrument buffers
    drawing.program.projection = GLKMatrix4MakeOrtho(0, 1, 0, 1, -10, 10)
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    
    glDisable(GLenum(GL_BLEND));
    for i in instruments {
      //      drawing.BindTexture(GLenum(GL_TEXTURE_2D), texture: i.framebuffer.texture)
      drawing.BindTexture(GLenum(GL_TEXTURE_2D), texture: i.framebuffer.texture)
      // Now, draw the textured square
      drawing.DrawTexturedSquare(0.5, bottom: 0.5, right: 1, top: 0)
    }
    processGLErrors()
  }
  
  func AddInstrument(item : Instrument)
  {
    var defaultFBO : GLint = 0
    glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &defaultFBO)
    var adefaultFBO : GLint = 0
    glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING_OES), &adefaultFBO)
    
    processGLErrors()
    // Generate a framebuffer
    var fb : GLuint = 0
    glGenFramebuffers(1, &fb)
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fb)

    // Work out how big in pixels this needs to be, to fill the screen
    let pixelSize = (w: item.screenWidth * Float(UIScreen.mainScreen().scale),
      h: item.screenHeight * Float(UIScreen.mainScreen().scale))
    
    // Generate a texture in this size
    var texColorBuffer : GLuint = 0
    glGenTextures(1, &texColorBuffer)
    glBindTexture(GLenum(GL_TEXTURE_2D), texColorBuffer)
    glTexImage2D(GLenum(GL_TEXTURE_2D),
      0, GL_RGBA, GLint(pixelSize.w), GLint(pixelSize.h),
      0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
    //    Unsupported texture wrap parameter	Issue
    // Attach this texture to the framebuffer
    glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER),
      GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D),
      texColorBuffer, 0);
    
    // Create a stencil buffer to attach, because we use it
    var stencil : GLuint = 0
    glGenRenderbuffers(1, &stencil)
    glBindRenderbuffer(GLenum(GL_RENDERBUFFER), stencil)
    glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_STENCIL_INDEX8), GLint(pixelSize.w), GLint(pixelSize.h))
//    glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_STENCIL_ATTACHMENT), GLenum(GL_RENDERBUFFER), stencil)
    glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_STENCIL_ATTACHMENT), GLenum(GL_RENDERBUFFER), stencil)
    
    if !(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE)) {
      fatalError("Framebuffer incomplete");
    }
    // Unbind the framebuffer
    drawing.setFramebuffer(0)
    
    // Save this information with the instrument
    let fbi = FramebufferInfo(buffer: fb, texture: texColorBuffer, stencil: stencil)
    let newI = PanelEntry(instrument: item, framebuffer: fbi)
    instruments.append(newI)
    processGLErrors()
  }
}