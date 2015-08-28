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
    // Generate the textures for every instrument
    for i in instruments {
      // Bind the framebuffer for this instrument
      drawing.bind(i.framebuffer)
      
      // Reassign the projection matrix. Upside-down, to match texture
      drawing.program.projection = GLKMatrix4MakeOrtho(0,
        Float(i.instrument.screenSize.w), Float(i.instrument.screenSize.h), 0, -10, 10)
      i.instrument.draw()
    }

    // Revert back to the main framebuffer
    drawing.bind(Framebuffer.Default)
    
    drawing.program.projection = GLKMatrix4MakeOrtho(0, 1, 0, 1, -10, 10)
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    
    // Work out the best way to pack all the instruments...
    let _aspect = drawing.screenAspect

    // The maximum size for a single instrument
    let maxSize : Size2D<Float>
    var drawOffset : Size2D<Float> = Size2D(w: 0.0, h: 0.0)
    
    if _aspect < 1 {
      // Portrait. Divide vertically.
      // Work out the maximum aspect size that a single instrument can be
      maxSize = Size2D(w: 1, h: (1.0/_aspect) / Float(instruments.count))
      // Do we need to be offset?
      // Work out if the whole area needs to be shrunk. Is the width the constraining
      // factor?
      // Calculate the aspect of the whole area
      let totalSize = Size2D(w: instruments.map({ $0.instrument.screenSize.aspect }).maxElement()!,
                             h: Float(instruments.count))
      if totalSize.constrainingSide(maxSize) == .Width {
        // It is wider than it is tall, and so will not fill the whole screen
        let proportionalHeight = (1 / totalSize.aspect) / (1/_aspect)
        drawOffset = Size2D(w: 0, h: (1-proportionalHeight)/2)
      }
    } else {
      // landscape. Divide Horizontally
      maxSize = Size2D(w: _aspect / Float(instruments.count), h: 1)
      // Calculate the aspect of the whole area
      let totalAspect = Float(instruments.count) / instruments.map({ $0.instrument.screenSize.aspect }).minElement()!

      let totalSize = Size2D(w: totalAspect, h: 1)
      if totalSize.constrainingSide(maxSize) == .Height {
        // Taller than it is wide.
        let proportionalWidth = totalSize.aspect / _aspect
        drawOffset = Size2D(w: (1-proportionalWidth)/2, h: 0)
      }
    }
    

    for (i, instrument) in instruments.enumerate() {
      // Work out the aspect ratio of this...
      let scale = instrument.framebuffer.size.scaleForFitInto(maxSize)
      let drawSize : Size2D<Float>
      if (_aspect < 1) {
        drawSize = Size2D(w: scale * Float(instrument.framebuffer.size.w),
                          h: scale * Float(instrument.framebuffer.size.h) / (1/_aspect))
      } else {
        drawSize = Size2D(w: scale * Float(instrument.framebuffer.size.w) / _aspect,
                          h: scale * Float(instrument.framebuffer.size.h))
      }
      let drawPos : Point2D
      if _aspect < 1 {
        // Center horizontally
        let y = 1 - drawSize.h*Float(i+1) - drawOffset.h
        let x = 0.5 - drawSize.w*0.5 + drawOffset.w
        drawPos = (x, y)
      } else {
        // Center vertically
        let y = 0.5 - drawSize.h*0.5 - drawOffset.h
        let x = drawSize.w * Float(i) + drawOffset.w
        drawPos = (x, y)
      }
      
      // Now, draw the textured square
      drawing.bind(instrument.framebuffer.texture)
      drawing.DrawTexturedSquare(drawPos.x, bottom: drawPos.y,
        right: drawPos.x+drawSize.w, top: drawPos.y+drawSize.h)
    }
    processGLErrors()
  }
  
  func AddInstrument(item : Instrument)
  {
    // Work out how big we can draw this on a full screen, both ways round
    let drawSize = item.screenSize
    let screenSize = Size2D(w: Float(UIScreen.mainScreen().bounds.size.width),
                            h: Float(UIScreen.mainScreen().bounds.size.height))
    var screenAspect = screenSize.w / screenSize.h
    if screenAspect < 1 {
      screenAspect = 1.0 / screenAspect
    }
    let drawAspect = drawSize.aspect
    let normAspect = drawAspect < 1 ? 1.0 / drawAspect : drawAspect

    // In landscape, Height is height. Width is height * aspect
    let landscapeHeight = min(screenSize.w, screenSize.h)
    let scale = Float(UIScreen.mainScreen().scale)
    let pixelSize : Size2D<Int>
    if drawAspect >= 1 {
      pixelSize = Size2D( w: Int(landscapeHeight*normAspect*scale),
                          h: Int(landscapeHeight*scale))
    } else {
      pixelSize = Size2D( w: Int(landscapeHeight*scale),
                          h: Int(landscapeHeight*normAspect*scale))
    }
    
    let buffer = drawing.createTextureFramebuffer(pixelSize, depth: false, stencil: true)

    let newInst = PanelEntry(instrument: item, framebuffer: buffer)
    instruments.append(newInst)
  }
}