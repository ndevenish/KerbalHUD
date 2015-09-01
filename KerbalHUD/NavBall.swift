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
  var navBall : Texture
  
  /// Initialise with a toolset to draw with
  required init(tools : DrawingTools) {
    drawing = tools
    navBall = NavBallTextureRendering(tools: drawing).generate()
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
    drawing.bind(navBall)
    drawing.program.setUseTexture(true)
    drawing.DrawTexturedSquare(FixedBounds(left: 0.1, bottom: 0.1, width: 0.8, height: 0.8))
  }
  
}

class NavBallTextureRendering {
  
  var drawing : DrawingTools
  var textures : [Int : Texture] = [:]
  
  init(tools : DrawingTools) {
    drawing = tools
    generateTextTextures()
  }
  
  deinit {
    // Delete all text textures
    for t in textures.values {
      drawing.deleteTexture(t)
    }
    textures.removeAll()
//    drawing.program.setUseTexture(false)
  }
  
  func generateTextTextures() {
    processGLErrors()
    let text = drawing.textRenderer("Menlo-Bold")
    processGLErrors()
    for var angle = -80; angle <= 80; angle += 10 {
      let str = angle == 0 ? "N" : String(angle)
      textures[angle] = text.drawToTexture(str, size: 45)
    }
    for var angle = 45; angle <= 360; angle += 45 {
      textures[angle] = text.drawToTexture(String(angle), size: 45)
      textures[-angle] = textures[angle]!
    }
  }
  
  func drawTextStrip(longitude: Float, upper : Bool) {
    drawing.program.setUseTexture(true)
    
    let range : (Int, Int) = upper ? (10, 80) : (-80, -10)
    for var angle = range.0; angle <= range.1; angle += 10 {
      // Don't render the central signs
      if angle == 0 {
        continue
      }
      
      // Bind the texture and calculate the size
      let tex = textures[angle]!
      let textHeight : Float = 4
      let textOffset : Float = 5
      let size = Size2D(w: tex.size!.aspect*textHeight, h: textHeight)
      drawing.bind(tex)
      
      drawing.drawProjectedGridOntoSphere(
        position: SphericalPoint(lat: Float(angle), long: longitude, r: 0),
        left: textOffset, bottom: -size.h/2,
        right: textOffset+size.w, top: size.h/2,
        xSteps: 10, ySteps: 5, slicePoint: 0)
      
      drawing.drawProjectedGridOntoSphere(
        position: SphericalPoint(lat: Float(angle), long: longitude, r: 0),
        left: -textOffset-size.w, bottom: -size.h/2, right: -textOffset, top: size.h/2,
        xSteps: 10, ySteps: 5, slicePoint: 0)
    }
    drawing.program.setUseTexture(false)
  }

  func generate() -> Texture {
    let texture = drawing.createTextureFramebuffer(Size2D(w: 2048, h: 1024), depth: false, stencil: false)
    drawing.bind(texture)
    drawing.program.projection = GLKMatrix4MakeOrtho(-180, 180, -90, 90, -10, 10)
    drawing.program.setModelView(GLKMatrix4Identity)
    
    let upperBackground = Color4(r: 93.0/255, g: 177.0/255, b: 228.0/225, a: 1)
    let lowerBackground = Color4(r: 4.0/255, g: 80.0/255, b: 117.0/255, a: 1)
    let white = Color4(r: 1, g: 1, b: 1, a: 1)
    let upperBlue = Color4(r: 4.0/255, g: 80.0/255, b: 117.0/255, a: 1)
    
    // Upper and lower halves
    drawing.program.setColor(upperBackground)
    drawing.DrawSquare(-180, bottom: 0, right: 180, top: 90)
    drawing.program.setColor(lowerBackground)
    drawing.DrawSquare(-180, bottom: -90, right: 180, top: 0)
    drawing.program.setModelView(GLKMatrix4Identity)
    

    let thetaSet = [-180, -90, 0, 90, 180]
    
    // Draw the vertical bands of text
    // Angles to draw:
    drawing.program.setColor(red: 33.0/255, green: 48.0/255, blue: 82.0/255)
    for longitude in thetaSet {
      drawTextStrip(Float(longitude), upper: true)
    }

    drawing.program.setColor(red: 1, green: 1, blue: 1)
    for longitude in thetaSet {
      drawTextStrip(Float(longitude), upper: false)
    }

    drawing.program.setModelView(GLKMatrix4Identity)
    
    // Cross-bars locations

    // Blue uppers
    drawing.program.setColor(red: 4.0/255, green: 80.0/255, blue: 117.0/255)
    drawVerticalBand(90, width: 1.5, upper: true)
    drawVerticalBand(-90, width: 1.5, upper: true)
    drawVerticalBand(180, width: 1.5, upper: true)
    drawVerticalBand(-180, width: 1.5, upper: true)

    // Cross-bars
    for longitude in [225, 315, 45, 135] {
      drawVerticalBand(Float(longitude), width: 1, upper: true)
    }
    drawing.DrawSquare(-180, bottom: 44.5, right: 180, top: 45.5)
    drawing.program.setModelView(GLKMatrix4Identity)
    drawSpurs(upper: true)
    
    // White lowers
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    drawVerticalBand(90, width: 1.5, upper: false)
    drawVerticalBand(-90, width: 1.5, upper: false)
    drawVerticalBand(180, width: 1.5, upper: false)
    drawVerticalBand(-180, width: 1.5, upper: false)

    // Cross-bars
    for longitude in [225, 315, 45, 135] {
      drawVerticalBand(Float(longitude), width: 1, upper: false)
    }
    drawing.DrawSquare(-180, bottom: -45.5, right: 180, top: -44.5)
    drawing.program.setModelView(GLKMatrix4Identity)
    drawSpurs(upper: false)
    
    // Orange bands
    drawing.program.setColor(red: 247.0/255, green: 101.0/255, blue: 3.0/255)
    drawVerticalBand(0, width: 2.5, upper: true)
    drawVerticalBand(0, width: 2.5, upper: false)
    drawing.DrawSquare(-180, bottom: -1, right: 180, top: 1)
    // middles: [0, 45, 90, 135, 225, 315]
    // upper middles: [0, 45, 90, 135, 180, 225, 270, 315]
    
    drawing.program.setModelView(GLKMatrix4Identity)
    // Lower middle text
    for longitude in [0, 45, 135, 180, 225, 315] {
      let size = longitude == 0 ? 9 : 7
      drawText(longitude, size : Float(size), position : SphericalPoint(lat: -45, long: Float(longitude), r: 0),
        fillBackground: lowerBackground, foregroundColor: white)
    }
    // Upper text
    for longitude in [0, 45, 90, 135, 225, 315] {
      let size = longitude == 0 ? 9 : 7
      drawText(longitude, size : Float(size), position : SphericalPoint(lat: 5, long: Float(longitude), r: 0),
        fillBackground: upperBackground, foregroundColor: upperBlue)
    }
    for longitude in [0, 45, 90, 135, 180, 225, 270, 315] {
      let size = longitude == 0 ? 9 : 7
      drawText(longitude, size : Float(size), position : SphericalPoint(lat: 45, long: Float(longitude), r: 0),
        fillBackground: upperBackground, foregroundColor: upperBlue)
    }
    // White across top and bototm
    drawing.program.setColor(white)
    drawing.DrawSquare(-180, bottom: 87-0.5, right: 180, top: 87+0.5)
    drawing.DrawSquare(-180, bottom: -87-0.5, right: 180, top: -87+0.5)
    
    drawing.bind(Framebuffer.Default)
    let tex = texture.texture
    drawing.deleteFramebuffer(texture, texture: false)
    return tex
  }
  
  func drawText(angle : Int, size : Float, position : SphericalPoint,
    fillBackground : Color4? = nil, foregroundColor: Color4? = nil)
  {
    let tex = textures[angle]!
    drawing.bind(tex)
    
    let size = Size2D(w: tex.size!.aspect*size, h: size)
    if let color = fillBackground {
      drawing.program.setColor(color)
      drawing.drawProjectedGridOntoSphere(
        position: position,
        left: -size.w/2, bottom: -size.h/2,
        right: size.w/2, top: size.h/2,
        xSteps: 10, ySteps: 5, slicePoint: 0)
      drawing.program.setColor(foregroundColor!)
    }
    
    drawing.program.setUseTexture(true)
    drawing.drawProjectedGridOntoSphere(
      position: position,
      left: -size.w/2, bottom: -size.h/2,
      right: size.w/2, top: size.h/2,
      xSteps: 10, ySteps: 5, slicePoint: 0)
    drawing.program.setUseTexture(false)
  }
  
  private enum BulkSpherePosition {
    case Left
    case Right
    case Middle
  }
  
  func drawVerticalBand(longitude: Float, width : Float, upper: Bool = true)
  {
    let points : ((GLfloat, GLfloat), (GLfloat, GLfloat))
    if upper {
      points = ((0, 50),(50, 58.9))
    } else {
      points = ((-50, 0), (-58.9, -50))
    }
    // Draw in two portions as it stretches out at high points
    drawing.drawProjectedGridOntoSphere(
      position: SphericalPoint(lat: 0, long: longitude, r: 0),
      left: -width/2, bottom: points.0.0, right: width/2, top: points.0.1,
      xSteps: 1, ySteps: 10, slicePoint: 0)
    
    drawing.drawProjectedGridOntoSphere(
      position: SphericalPoint(lat: 0, long: longitude, r: 0),
      left: -width/2, bottom: points.1.0, right: width/2, top: points.1.1,
      xSteps: 1, ySteps: 100, slicePoint: 0)
  }
  
  func drawSpurs(upper upper : Bool) {
    // Spurs!
    for longitude in [-180, -90, 0, 90, 180] {
      let offset : Float = 1.5
      let h : Float = 0.5 * (upper ? 1 : -1)
      for var lat = 5; lat <= 80; lat += 5 {
        if lat == 45 {
          continue
        }
        let latitude = lat * (upper ? 1 : -1)
        let w : Float = latitude % 10 == 0 ? 3 : 2
        drawing.drawProjectedGridOntoSphere(
          position: SphericalPoint(lat: Float(latitude), long: Float(longitude), r: 0),
          left: -offset-w, bottom: -h/2, right: -offset, top: h/2,
          xSteps: 1, ySteps: 1,
          slicePoint: 0)
        drawing.drawProjectedGridOntoSphere(
          position: SphericalPoint(lat: Float(latitude), long: Float(longitude), r: 0),
          left: offset, bottom: -h/2, right: w+offset, top: h/2,
          xSteps: 1, ySteps: 1,
          slicePoint: 0)
      }
    }
  }
}
