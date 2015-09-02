//
//  InstrumentPanel.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 26/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

private class PanelEntry {
  var instrument  : Instrument
  let framebuffer : Framebuffer
  var bounds : Bounds
  
  init(instrument: Instrument, buffer: Framebuffer, bounds: Bounds)
  {
    self.instrument = instrument
    self.framebuffer = buffer
    self.bounds = bounds
  }
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
  private var focus : PanelEntry? = nil
  private var drawOrder : [Int] = []
  
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
    if focus == nil { layout() }

    // Generate the textures for every instrument
    for i in instruments {
      // Bind the framebuffer for this instrument
      drawing.bind(i.framebuffer)
      
      // Reassign the projection matrix
      drawing.program.projection = GLKMatrix4MakeOrtho(0,
        Float(i.instrument.screenSize.w), 0, Float(i.instrument.screenSize.h), -i.instrument.screenSize.h/2, i.instrument.screenSize.h/2)
      i.instrument.draw()
    }

    // Revert back to the main framebuffer
    drawing.bind(Framebuffer.Default)
    
    drawing.program.projection = GLKMatrix4MakeOrtho(0, drawing.screenAspect, 0, 1, -10, 10)
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    
    for instrument in drawOrder.map({instruments[$0]}) {
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
    let newInst = PanelEntry(instrument: item, buffer: buffer, bounds: ErrorBounds())
    drawOrder.append(instruments.count)
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
        instrument.bounds = newBounds
//        instruments[i].bounds = newBounds
      } else {
        // Animate
        if let exB = instrument.bounds as? BoundsInterpolator {
          if FixedBounds(bounds: exB.end) != FixedBounds(bounds: newBounds) {
            instrument.bounds = BoundsInterpolator(from: exB, to: newBounds, seconds: 1)
          }
        } else {
          let previous = FixedBounds(bounds: instrument.bounds)
          instrument.bounds = BoundsInterpolator(from: previous, to: newBounds, seconds: 1)
        }
      }
    }
    previousArrangement = (layout, Clock.time)
  }
  
  func registerTap(loc: Point2D) {
    let myLoc = Point2D(x: loc.x, y: 1-loc.y)
    print (myLoc)
    // Find which instrument this corresponds to
    if focus != nil {
      setFocus(nil)
    } else {
      if let target = drawOrder.reverse().map({instruments[$0]}).filter({$0.bounds.contains(myLoc)}).first {
        setFocus(target)
      }
//      if let target = instruments.filter({$0.bounds.contains(myLoc)}).first {
//        setFocus(target)
//      }
      
    }
  }
  
  private func setFocus(pe : PanelEntry?) {
    if let panel = pe {
      let fullScreenPanel = FixedBounds(left: 0, bottom: 0, right: drawing.screenAspect, top: 1)
      let scale = panel.bounds.size.scaleForFitInto(fullScreenPanel.size)
      let size = panel.bounds.size * scale
      let newBound = FixedBounds(left: (drawing.screenAspect-size.w)/2,
                               bottom: (1-size.h)/2,
                                right: (drawing.screenAspect-size.w)/2 + size.w,
                                  top: (1-size.h)/2 + size.h)
//      let index = instruments.indexOf({$0.framebuffer == panel.framebuffer})!
//      instruments[index].bounds =
      let oldSize = panel.bounds.size
      panel.bounds = BoundsInterpolator(from: panel.bounds, to: newBound, seconds: 1)
      // Reorder
      let index = instruments.indexOf({$0 === panel})!
      drawOrder.removeAtIndex(drawOrder.indexOf({$0 == index})!)
      drawOrder.append(index)
      focus = panel
      
      // Move all the others to the middle
      let middlePos = FixedBounds(left: (drawing.screenAspect-oldSize.w)/2,
                                bottom: (1-oldSize.h)/2,
                                 width: oldSize.w,
                                height: oldSize.h)
      for other in instruments.filter({$0 !== panel}) {
        other.bounds = BoundsInterpolator(from: other.bounds, to: middlePos, seconds: 1)
      }
    } else {
      focus = nil
    }
  }
}