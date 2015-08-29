//
//  NavBall.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit


class NavBall : Instrument {
  /// The INTERNAL screen size e.g. the coordinate system this expects to draw on
  var screenSize : Size2D<Float>
  
  var drawing : DrawingTools
  
  /// Initialise with a toolset to draw with
  required init(tools : DrawingTools) {
    drawing = tools
    screenSize = Size2D(w: 1, h: 1)
  }
  
  /// Start communicating with the kerbal data store
  func connect(to : IKerbalDataStore){
    
  }
  /// Stop communicating with the kerbal data store
  func disconnect(from : IKerbalDataStore) {
    
  }
  
  /// Update this instrument
  func update() {
    
  }
  
  func draw() {
    
  }
  
  
  /// Generate a geometry grid, with UV indices, for a specified size projected
  func generateGeometryFor(size: Size2D<Float>, sphPoint: SphericalPoint) {
    let xSteps = 10
    let ySteps = 5
    
    var data : [Point2D] = []

    for iY in 0..<ySteps {
      for iX in 0...xSteps {
        // The offset points of this index specifically
        let xOffset = size.w/Float(xSteps) * Float(iX) - size.w/2
        let yOffset = size.h/Float(ySteps) * Float(iY) - size.h/2
        // If we have data already, double-up the first vertex as we will
        // need to do so for a triangle strip
        if iX == 0 && data.count > 0 {
          data.append(Point2D(x: xOffset, y: yOffset))
        }
        data.append(Point2D(x: xOffset, y: yOffset))
        // Calculate the y of the next one up
        let yOffset2 = size.h/Float(ySteps) * Float(iY+1) - size.h/2
        data.append(Point2D(x: xOffset, y: yOffset2))
      }
      // Finish the triangle strip line
      data.append(data.last!)
    }
    // Remove the last item as it will double up otherwise (empty triangle)
    data.removeLast()
    
    // Now, transform all of these points
    let geometry = data.flatMap { (point : Point2D) -> [GLfloat] in
      let uV = (x:(point.x + size.w/2)/size.w, y: (point.y+size.h/2)/size.h)
      let sphePos = pointAndOffsetToLatandLong(sphericalPoint: sphPoint, offset: point)
      return [sphePos.lat, sphePos.long, uV.x, uV.y]
    }
    // Load into a buffer object!
    
    
  }
  
  func generateTextureForNavBall() {
    let buffer = drawing.createTextureFramebuffer(Size2D(w: 4096, h: 2048), depth: false, stencil: false)
    drawing.bind(buffer)
    drawing.program.projection = GLKMatrix4MakeOrtho(-180, 180, -90, 90, -10, 10)
    let text = drawing.textRenderer("Menlo")
    // 20 degrees, 10 to 80
    var textures : [Int : Texture] = [:]
    // Draw all the textures first
    for var angle = -80; angle <= 80; angle += 10 {
      let str = angle == 0 ? "N" : String(angle)
      textures[angle] = text.drawToTexture(str, size: 45)
    }
    for var angle = 45; angle <= 270; angle += 45 {
      textures[angle] = text.drawToTexture(String(angle), size: 45)
    }
    // Draw the vertical bands
    for var midAngle = 0; midAngle <= 270; midAngle += 90 {
      for var angle = -80; angle <= 80; angle += 10 {
        
      }
    }
  }
}