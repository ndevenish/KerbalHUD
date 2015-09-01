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
  var navBall : NavBallTextureRendering
  
  /// Initialise with a toolset to draw with
  required init(tools : DrawingTools) {
    drawing = tools
    navBall = NavBallTextureRendering(tools: drawing)
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
    navBall.generate()
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
    let text = drawing.textRenderer("Menlo-Bold")
    for var angle = -80; angle <= 80; angle += 10 {
      let str = angle == 0 ? "N" : String(angle)
      textures[angle] = text.drawToTexture(str, size: 45)
    }
    for var angle = 45; angle <= 270; angle += 45 {
      textures[angle] = text.drawToTexture(String(angle), size: 45)
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

  func generate() {
    //    let texture = drawing.createTextureFramebuffer(Size2D(w: 4096, h: 2048), depth: false, stencil: false)
    //    drawing.bind(texture)
    drawing.program.projection = GLKMatrix4MakeOrtho(-180, 180, -90, 90, -10, 10)
    drawing.program.setModelView(GLKMatrix4Identity)
    
    // Upper and lower halves
    drawing.program.setColor(red: 93.0/255, green: 177.0/255, blue: 228.0/225)
    drawing.DrawSquare(-180, bottom: 0, right: 180, top: 90)
    drawing.program.setColor(red: 4.0/255, green: 80.0/255, blue: 117.0/255)
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
    
    // Blue uppers
    drawing.program.setColor(red: 4.0/255, green: 80.0/255, blue: 117.0/255)
    drawVerticalBand(90, width: 1.5, upper: true)
    drawVerticalBand(-90, width: 1.5, upper: true)
    drawVerticalBand(180, width: 1.5, upper: true)
    drawVerticalBand(-180, width: 1.5, upper: true)

    // White lowers
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    drawVerticalBand(90, width: 1.5, upper: false)
    drawVerticalBand(-90, width: 1.5, upper: false)
    drawVerticalBand(180, width: 1.5, upper: false)
    drawVerticalBand(-180, width: 1.5, upper: false)

    // Orange bands
    drawing.program.setColor(red: 247.0/255, green: 101.0/255, blue: 3.0/255)
    drawVerticalBand(0, width: 2.5, upper: true)
    drawVerticalBand(0, width: 2.5, upper: false)
    drawing.DrawSquare(-180, bottom: -1, right: 180, top: 1)
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
}
