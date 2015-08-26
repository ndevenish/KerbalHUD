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
    glDisable(GLenum(GL_BLEND));
    
    for i in instruments {
      // Now, draw the textured square
      drawing.bind(i.framebuffer.texture)
      drawing.DrawTexturedSquare(0.5, bottom: 0, right: 1, top: 0.5)
    }
    processGLErrors()
  }
  
  func AddInstrument(item : Instrument)
  {
    // Work out how big in pixels this needs to be, to fill the screen
    let pixelSize = Size2DInt(
      w: Int(item.screenWidth * Float(UIScreen.mainScreen().scale)),
      h: Int(item.screenHeight * Float(UIScreen.mainScreen().scale)))

    let buffer = drawing.createTextureFramebuffer(pixelSize,
      depth: false, stencil: true)

    let newInst = PanelEntry(instrument: item, framebuffer: buffer)
    instruments.append(newInst)
  }
}