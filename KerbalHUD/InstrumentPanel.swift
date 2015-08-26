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
  let framebuffer : Framebuffer
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
      drawing.deleteFramebuffer(i.framebuffer)
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
      drawing.bind(i.framebuffer)
      glViewport(0, 0, GLsizei(i.framebuffer.size.w), GLsizei(i.framebuffer.size.h))
      
      // Reassign the projection matrix. Upside-down, to match texture
      drawing.program.projection = GLKMatrix4MakeOrtho(0,
        i.instrument.screenWidth, i.instrument.screenHeight, 0, -10, 10)
      i.instrument.draw()
    }

    // Revert back to the main framebuffer
    drawing.bind(Framebuffer.Default)
    
    // Now, draw all of the instrument buffers
    drawing.program.projection = GLKMatrix4MakeOrtho(0, 1, 0, 1, -10, 10)
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.program.setColor(red: 1, green: 1, blue: 1)
//    glDisable(GLenum(GL_BLEND));
    
    for i in instruments {
      // Now, draw the textured square
      drawing.bind(i.framebuffer.texture)
      drawing.DrawTexturedSquare(0.5, bottom: 0, right: 1, top: 0.5)
    }
    processGLErrors()
  }
  
  func AddInstrument(item : Instrument)
  {
    // Work out how big we can draw this on a full screen, both ways round
    let drawSize = Size2D(item.screenWidth, item.screenHeight)
    let screenSize = Size2D(Float(UIScreen.mainScreen().bounds.size.width),
                            Float(UIScreen.mainScreen().bounds.size.height))
    var screenAspect = screenSize.w / screenSize.h
    if screenAspect < 1 {
      screenAspect = 1.0 / screenAspect
    }
    let drawAspect = drawSize.w / drawSize.h
    let normAspect = drawAspect < 1 ? 1.0 / drawAspect : drawAspect

    // In landscape, Height is height. Width is height * aspect
    let landscapeHeight = min(screenSize.w, screenSize.h)
    let scale = Float(UIScreen.mainScreen().scale)
    let pixelSize : Size2DInt
    if drawAspect >= 1 {
      pixelSize = ( w: Int(landscapeHeight*normAspect*scale),
                    h: Int(landscapeHeight*scale))
    } else {
      pixelSize = ( w: Int(landscapeHeight*scale),
                    h: Int(landscapeHeight*normAspect*scale))
    }
    
    let buffer = drawing.createTextureFramebuffer(pixelSize, depth: false, stencil: true)

    let newInst = PanelEntry(instrument: item, framebuffer: buffer)
    instruments.append(newInst)
  }
}