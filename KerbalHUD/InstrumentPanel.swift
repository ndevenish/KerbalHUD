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
  var bounds : Bounds
}

private enum PanelLayout {
  case None
  case Horizontal
  case Vertical
}

class InstrumentPanel
{
  var connection : TelemachusInterface? {
    didSet {
      for i in instruments {
        i.instrument.connect(connection!)
      }
    }
  }
  
  private let drawing : DrawingTools
  private var instruments : [PanelEntry] = []
  private var previousArrangement : (layout: PanelLayout, frame: Double) = (.None, -1)
  
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
    layout()

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
    
    drawing.program.projection = GLKMatrix4MakeOrtho(0, drawing.screenAspect, 0, 1, -10, 10)
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    
    for instrument in instruments {
      // Now, draw the textured square
      drawing.bind(instrument.framebuffer.texture)
      drawing.DrawTexturedSquare(instrument.bounds)
    }
    processGLErrors()
  }
  
  func AddInstrument(item : Instrument)
  {
    // Work out the maximum size this is required on a full screen
    let drawSize = item.screenSize
    let screenSize = Size2D(w: Float(UIScreen.mainScreen().bounds.size.width * UIScreen.mainScreen().scale),
                            h: Float(UIScreen.mainScreen().bounds.size.height * UIScreen.mainScreen().scale))
    
    let maxScale = max(drawSize.scaleForFitInto(screenSize), drawSize.scaleForFitInto(screenSize.flipped))
    let pixelSize = (drawSize * maxScale).map { Int($0) }
    let buffer = drawing.createTextureFramebuffer(pixelSize, depth: false, stencil: true)
    // Create the instrument entry
    let newInst = PanelEntry(instrument: item, framebuffer: buffer, bounds: ErrorBounds())
    instruments.append(newInst)
    
    // Recalculate the layouts
    layout()
  }
  
  func layout() {
    // Work out the packing for instruments, assuming they are all square
    
    // Work out the size of the entire array vertically
    let arraySize = Size2D(w: 1.0, h: Float(instruments.count))
    let screenSize = Size2D(w: drawing.screenAspect, h: 1)
    
    // See if we scale better vertically, or horizontally
    let bestVertically = arraySize.scaleForFitInto(screenSize) > arraySize.scaleForFitInto(screenSize.flipped)
    let layout : PanelLayout = bestVertically ? .Vertical : .Horizontal
    
    let instrumentSize : Size2D<Float>
    var offset : Size2D<Float> = Size2D(w: 0.0, h: 0.0)
    if layout == .Vertical {
      // Layout vertically, top-to-bottom
      if arraySize.constrainingSide(screenSize) == .Width {
        offset = Size2D(w: 0, h: (1-(Float(screenSize.w) / arraySize.aspect))/2)
      }
      instrumentSize = Size2D(w: screenSize.aspect, h: 1/Float(instruments.count))
    } else {
      // We layout horizontally
      let hSize = arraySize.flipped
      if hSize.constrainingSide(screenSize) == .Height {
        offset = Size2D(w: (1-Float(screenSize.h)*hSize.aspect)/2, h: 0)
      }
      instrumentSize = Size2D(w: screenSize.aspect/Float(instruments.count), h: 1)
    }

    for (i, instrument) in instruments.enumerate() {
      let scale = instrument.instrument.screenSize.scaleForFitInto(instrumentSize)
      let drawSize = instrument.instrument.screenSize * scale
      
      let newBounds : Bounds
      if layout == .Vertical {
        let y = (1 - instrumentSize.h * Float(i+1)) - offset.h
        // Center horizontally
        let x = (screenSize.aspect-drawSize.w)*0.5
        newBounds = FixedBounds(left: x, bottom: y, right: x+drawSize.w, top: y+drawSize.h)
      } else {
        let x = instrumentSize.w * Float(i) + offset.w
        let y = (1-drawSize.h)*0.5
        newBounds = FixedBounds(left: x, bottom: y, right: x+drawSize.w, top: y+drawSize.h)
      }
      
      // If we do not match the previous arrangement, jump. Else animate.
      if previousArrangement.frame == Clock.time
        || previousArrangement.layout != layout
        || instrument.bounds is ErrorBounds
      {
        // Jump
        instruments[i].bounds = newBounds
      } else {
        // Animate
        let previous = FixedBounds(bounds: instrument.bounds)
        instruments[i].bounds = BoundsInterpolator(from: previous, to: newBounds, seconds: 1)
      }
    }
    previousArrangement = (layout, Clock.time)
  }
}