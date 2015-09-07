//
//  NavBall.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit



class NavBall : LayeredInstrument {
  init(tools : DrawingTools) {
    var config = InstrumentConfiguration()
    config.overlay = SVGOverlay(url: NSBundle.mainBundle().URLForResource("RPM_NavBall_Overlay", withExtension: "svg")!)
    
    // Fixed text labels
    config.text = [
      t("Altitude",     x: 83,     y: 49, size: 15),
      t("SRF.SPEED",    x: 640-83, y: 49, size: 15),
      t("ORB.VELOCITY", x: 83,     y: 640-554, size: 15),
      t("ACCEL.",       x: 640-83, y: 640-554, size: 15),
      t("MODE",         x: 54,     y: 640-489, size: 15),
      t("ROLL",         x: 36,     y: 640-434, size: 15),
      t("PITCH",        x: 599,    y: 640-434, size: 15),
      t("RADAR ALTITUDE", x: 104,  y: 640-47 , size: 15),
      t("HOR.SPEED",    x: 320,    y: 640-47 , size: 15),
      t("VERT.SPEED",   x: 534,    y: 640-47 , size: 15),
    ]
    
    // Simple display text
    config.text.appendContentsOf([
      t("%03.1f°", Vars.Flight.Roll, x: 67, y: 240),
      t("%03.1f°", Vars.Flight.Pitch, x: 573, y: 240),
      t("%03.1f°", Vars.Flight.Heading, x: 320, y: 80),
      
      t("{0:SIP_6.1}m", Vars.Vessel.Altitude, x: 83.5, y: 22),
      t("{0,4:SIP4}m/s", "v.surfaceSpeed", x: 556.5, y: 22),
      
      t("{0:SIP_6.1}m", "v.orbitalVelocity", x: 83.5, y: 115),
      t("{0:SIP4}m/s", "rpm.ACCEL", x: 556.5, y: 115),
      t("{0:ORB;TGT;SRF}", "rpm.SPEEDDISPLAYMODE", x: 55, y: 177),
      
      
      t("{0:SIP_6.3}m", "rpm.RADARALTOCEAN", x: 95, y: 623),
      t("{0:SIP_6.3}m", "rpm.HORZVELOCITY", x: 320, y: 623),
      t("{0:SIP_6.3}m", "v.verticalSpeed", x: 640-95, y: 623)
      ])
    
    // Various control Status displays
    config.text.appendContentsOf([
      t("SAS:", x: 10, y: 280, align: .Left, size: 20),
      t("RCS:", x: 10, y: 344, align: .Left, size: 20),
      t("Throttle:", x: 10, y: 408, align: .Left, size: 20),
      t("{0:P0}", Vars.Vessel.Throttle, x: 90, y: 440, align: .Right),
      t("Gear:", x: 635, y: 290, align: .Right, size: 20),
      t("Brakes:", x: 635, y: 344, align: .Right, size: 20),
      t("Lights:", x: 635, y: 408, align: .Right, size: 20),
      ])
    
    // Conditional text entries collections for the status displays
    config.text.appendContentsOf([
      tOnOff(Vars.Vessel.SAS, x: 43, y: 640-312),
      tOnOff(Vars.Vessel.RCS, x: 43, y: 640-376),
      tOnOff(Vars.Vessel.Brakes, x: 640-43, y: 640-(344+32)),
      tOnOff(Vars.Vessel.Lights, x: 640-43, y: 640-(408+32)),
      tOnOff(Vars.Vessel.Gear, x: 640-43, y: 640-312, onText: "Down", offText: "Up"),
      ].flatMap({$0}))
    
    // Time to node text
    config.text.appendContentsOf([
      t("Burn T:", x: 10, y: 472, size: 20, align: .Left,
        color: nil,
        condition: Vars.RPM.Node.Exists),
      t("{0:METS.f}s", Vars.RPM.Node.BurnTime, x: 10, y: 408+64+32, align: .Left,
        color: nil,
        condition: Vars.RPM.Node.Exists),
      t("Node in T", x: 10, y: 408+64+64, align: .Left, size: 20,
        color: nil,
        condition: Vars.RPM.Node.Exists),
      t("{0,17:MET+yy:ddd:hh:mm:ss.f}", Vars.RPM.Node.TimeTo, x: 10, y: 408+64+64+32, align: .Left,
        color: nil,
        condition: Vars.RPM.Node.Exists),
      t("ΔV", x: 640-10, y: 408+64+64, align: .Right, size: 20,
        color: nil,
        condition: Vars.RPM.Node.Exists),
      t("{0:SIP_6.3}m/s", Vars.RPM.Node.DeltaV, x: 630, y: 408+64+64+32, align: .Right,
        color: nil,
        condition: Vars.RPM.Node.Exists)
      ])
    
    super.init(tools: tools, config: config)
    
    // Add the navball
    widgets.append(NavBallWidget(tools: tools,
      bounds: FixedBounds(centerX: 320, centerY: 338, width: 430, height: 430)))
  }
}


private func t(string : String, x: Float, y: Float, size: Float = 32, align: NSTextAlignment = .Center, color: Color4? = nil, condition: String? = nil) -> TextEntry {
  return TextEntry(string: string, size: size, position: Point2D(x,640-y), align: align, variables: [], font: "", condition : condition, color: color)
}

private func t(string : String, _ variable : String,
  x: Float, y: Float, size: Float = 32, align: NSTextAlignment = .Center, color: Color4? = nil, condition: String? = nil) -> TextEntry {
    return TextEntry(string: string, size: size, position: Point2D(x,640-y), align: align, variables: [variable], font: "", condition : condition, color: color)
    
}

private func tOnOff(condition: String, x: Float, y: Float, onText: String = "On", offText: String = "Off") -> [TextEntry] {
  return [
    TextEntry(string: onText, size: 32, position: Point2D(x, y),
      align: .Center, variables: [], font: "",
      condition: condition, color: Color4.Green),
    TextEntry(string: offText, size: 32, position: Point2D(x, y),
      align: .Center, variables: [], font: "",
      condition: "!" + condition, color: nil)
  ]
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
      let size : Size2D<Float>
      if angle == 80 || angle == -80 {
        size = Size2D(w: tex.size!.aspect*textHeight*0.7, h: textHeight*0.7)
      } else {
        size = Size2D(w: tex.size!.aspect*textHeight, h: textHeight)
      }
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
//    drawing.program.setColor(red: 33.0/255, green: 48.0/255, blue: 82.0/255)
    drawing.program.setColor(upperBlue)
    for longitude in thetaSet {
      drawTextStrip(Float(longitude), upper: true)
    }

    drawing.program.setColor(white)
    for longitude in thetaSet {
      drawTextStrip(Float(longitude), upper: false)
    }

    drawing.program.setModelView(GLKMatrix4Identity)
    
    // Cross-bars locations

    // Blue uppers
    drawing.program.setColor(upperBlue)
    drawVerticalBand(90, width: 1.5, upper: true)
    drawVerticalBand(-90, width: 1.5, upper: true)
    drawVerticalBand(180, width: 1.5, upper: true)
    drawVerticalBand(-180, width: 1.5, upper: true)

    // Cross-bars
    for longitude in [225, 315, 45, 135] {
      drawVerticalBand(Float(longitude), width: 1, upper: true)
    }
    drawing.DrawSquare(-180, bottom: 44.5, right: 180, top: 45.5)
    drawing.DrawSquare(-180, bottom: 84.75, right: 180, top: 85.25)
    // Fill in the anti-color on the top
    drawing.DrawSquare(-180, bottom: 89.5, right: 180, top: 90)
    drawing.program.setModelView(GLKMatrix4Identity)
    drawSpurs(upper: true)

    // Really thin top spur that is a circle
//    drawing.DrawSquare(-180, bottom: 84.75, right: 180, top: 85.25)
    
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
    drawing.program.setModelView(GLKMatrix4Identity)
    
    // Lower middle text
    for longitude in [-180, 0, 45, 135, 180, 225, 315] {
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
    for longitude in [-180, 0, 45, 90, 135, 180, 225, 270, 315] {
      let size = longitude == 0 ? 9 : 7
      drawText(longitude, size : Float(size), position : SphericalPoint(lat: 45, long: Float(longitude), r: 0),
        fillBackground: upperBackground, foregroundColor: upperBlue)
    }
    // White across top and bottom
    drawing.program.setColor(white)
    drawing.DrawSquare(-180, bottom:  88.5, right: 180, top:  89.5)
    drawing.DrawSquare(-180, bottom: -89.5, right: 180, top: -88.5)
    
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
    
    if angle == -180 {
      print ("Handling")
    }
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
    // Work out the maximum projection for this width
    let maxDisplacement = (width/2) / tan(sin(width/2/59)) - 0.01
    
    let points : ((GLfloat, GLfloat), (GLfloat, GLfloat))
    if upper {
      points = ((0, 50),(50, maxDisplacement))
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


//var bounds : Bounds { get }
//var variables : [String] { get }
//
//func update(data : [String : JSON])
//
//func draw()

class NavBallWidget : Widget {
  private struct FlightData {
    var Roll : Float = 0
    var Pitch : Float = 0
    var Heading : Float = 0
  }
  private(set) var bounds : Bounds
  let variables : [String]
  private let drawing : DrawingTools
  
  private let sphere : Drawable
  private let sphereTexture : Texture
  private var data = FlightData()
  
  init(tools : DrawingTools, bounds : Bounds) {
    drawing = tools
    variables = [Vars.Flight.Roll,
                 Vars.Flight.Pitch,
                 Vars.Flight.Heading]
    self.bounds = bounds
    
    sphere = tools.LoadTriangles(generateSphereTriangles(1, latSteps: 50, longSteps: 100))
    sphereTexture = NavBallTextureRendering(tools: drawing).generate()
  }
  
  func update(data : [String : JSON]) {
    self.data = FlightData(
      Roll: data[Vars.Flight.Roll]?.floatValue ?? 0,
      Pitch: data[Vars.Flight.Pitch]?.floatValue ?? 0,
      Heading: data[Vars.Flight.Heading]?.floatValue ?? 0)
  }
  
  func draw() {
    drawing.bind(sphereTexture)
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    
    var sphMat = GLKMatrix4Identity
//    sphMat = GLKMatrix4Translate(sphMat, 320, 338, 0)
    sphMat = GLKMatrix4Translate(sphMat,
      bounds.left+bounds.width/2, bounds.bottom+bounds.height/2, 0)
    sphMat = GLKMatrix4Scale(sphMat, bounds.width/2, bounds.height/2, 1)
    // Roll
    sphMat = GLKMatrix4Rotate(sphMat, (data.Roll) * π/180, 0, 0, 1)
    // Pitch?
    sphMat = GLKMatrix4Rotate(sphMat, (data.Pitch) * π/180, 1, 0, 0)
    // Heading
    sphMat = GLKMatrix4Rotate(sphMat, data.Heading * π/180, 0, -1, 0)
    
    // Proper orientation to start from. Heading 0, pitch 0, roll 0.
    sphMat = GLKMatrix4Rotate(sphMat, π/2, 0, 0, 1)
    sphMat = GLKMatrix4Rotate(sphMat, π/2, 0, 1, 0)
    drawing.program.setModelView(sphMat)
    
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.Draw(sphere)
  }
}