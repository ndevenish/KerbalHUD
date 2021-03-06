//
//  NavBall.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

private prefix func -(dir : NavBallWidget.FlightData.Direction) -> NavBallWidget.FlightData.Direction {
  return NavBallWidget.FlightData.Direction(p: -dir.Pitch, y: dir.Yaw+180)
}

class NavBallWidget : Widget {
  private struct FlightData {
    var Roll : Float = 0
    var Pitch : Float = 0
    var Heading : Float = 0
    
    var speedDisplay : SpeedDisplay = .Orbit
    
    private struct Ends {
      var Pro : Direction
      var Retro : Direction
      
      init(data : [String:JSON], pro: String, ret: String) {
        Pro = Direction(data: data, name: pro)
        Retro = Direction(data: data, name: ret)
      }
      init(data : [String:JSON], pro: String) {
        Pro = Direction(data: data, name: pro)
        Retro = -Pro
      }
    }
    private struct Direction {
      var Pitch : Float
      var Yaw : Float
      init(data : [String:JSON], name: String) {
        Pitch = data["rpm.PITCH" + name]?.floatValue ?? 0
        Yaw = data["rpm.YAW" + name]?.floatValue ?? 0
      }
      init(p: Float, y: Float) {
        Pitch = p
        Yaw = y
      }
    }
    
    var markers : [String:Direction] = [:]
  }
  
  private(set) var bounds : Bounds
  let variables : [String]
  private(set) var configuration : [String : Any] = [:]
  
  private let drawing : DrawingTools
  
  private let sphere : Drawable
  private let sphereTexture : Texture
  private var data = FlightData()
  
  init(tools : DrawingTools, bounds : Bounds) {
    drawing = tools

    var varList = [Vars.Flight.Roll,
                   Vars.Flight.Pitch,
                   Vars.Flight.Heading,
                   Vars.Node.Exists,
                   Vars.Target.Exists,
                   Vars.Aero.AngleOfAttack,
                   Vars.Aero.Sideslip,
                   Vars.Vessel.SpeedDisplay]
    
    varList.appendContentsOf(Vars.RPM.Direction.allCardinal)
    varList.appendContentsOf(Vars.RPM.Direction.Node.all)
    varList.appendContentsOf(Vars.RPM.Direction.Target.all)
    
    variables = varList
    
    self.bounds = bounds
    glPushGroupMarkerEXT(0, "Navball Texture Generation")
    sphereTexture = NavBallTextureRendering(tools: drawing).generate()
    glPopGroupMarkerEXT()
    sphere = tools.LoadTriangles(generateSphereTriangles(1, latSteps: 50, longSteps: 100), texture: sphereTexture)
  }
  
  func update(data : [String : JSON]) {
    var out = FlightData()
    out.Roll = (data[Vars.Flight.Roll]?.floatValue ?? 0)
    out.Pitch = data[Vars.Flight.Pitch]?.floatValue ?? 0
    out.Heading = data[Vars.Flight.Heading]?.floatValue ?? 0
    out.speedDisplay = SpeedDisplay(rawValue: data[Vars.Vessel.SpeedDisplay]?.intValue ?? 1) ?? .Orbit
    
    var markers : [String:FlightData.Direction] = [:]
    
    switch out.speedDisplay {
    case .Orbit:
      let primary = FlightData.Ends(data: data, pro: "PROGRADE")
      let normal =  FlightData.Ends(data: data, pro: "NORMALPLUS")
      let radial =  FlightData.Ends(data: data, pro: "RADIALIN")

      markers = [
        "Prograde": primary.Pro,
        "Retrograde": primary.Retro,
        "RadialIn": radial.Pro,
        "RadialOut": radial.Retro,
        "Normal": normal.Pro,
        "AntiNormal": normal.Retro
      ]
      if data[Vars.Node.Exists]?.boolValue ?? false {
        markers["Maneuver"] = FlightData.Direction(data: data, name: "NODE")
      }
      if data[Vars.Target.Exists]?.boolValue ?? false {
        markers["TargetPrograde"] = FlightData.Direction(data: data, name: "TARGET")
      }
    case .Surface:
      if let pitch = data[Vars.Aero.AngleOfAttack]?.floatValue,
              let yaw   = data[Vars.Aero.Sideslip]?.floatValue
      {
        markers["Prograde"] = FlightData.Direction(p: pitch, y: yaw)
      }
    case .Target:
      break
    }
    out.markers = markers
    self.data = out
  }
  
  /// Draw something
  func draw() {
    drawing.bind(sphereTexture)
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    
    var sphMat = GLKMatrix4Identity
    //    sphMat = GLKMatrix4Translate(sphMat, 320, 338, 0)
    sphMat = GLKMatrix4Translate(sphMat,
      bounds.left+bounds.width/2, bounds.bottom+bounds.height/2, 0)
    sphMat = GLKMatrix4Scale(sphMat, bounds.width/2, bounds.height/2, 1)
    // Roll
    sphMat = GLKMatrix4Rotate(sphMat, -(data.Roll) * π/180, 0, 0, 1)
    // Pitch?
    sphMat = GLKMatrix4Rotate(sphMat, (data.Pitch) * π/180, 1, 0, 0)
    // Heading
    sphMat = GLKMatrix4Rotate(sphMat, data.Heading * π/180, 0, -1, 0)
    
    // Proper orientation to start from. Heading 0, pitch 0, roll 0.
    sphMat = GLKMatrix4Rotate(sphMat, π/2, 0, 0, 1)
    sphMat = GLKMatrix4Rotate(sphMat, π/2, 0, 1, 0)
    drawing.program.setModelView(sphMat)
    drawing.draw(sphere)
    
    var mkMat = GLKMatrix4Identity
    // Middle of the screen, forwards
    mkMat = GLKMatrix4Translate(mkMat, bounds.center.x, bounds.center.y, 1)
    mkMat = GLKMatrix4Scale(mkMat, bounds.width/2, bounds.height/2, 1)
//    sphMat = GLKMatrix4Scale(sphMat, bounds.width/2, bounds.height/2, 1)
    glPushGroupMarkerEXT(0, "Drawing NavBall Markers")
    defer {
      glPopGroupMarkerEXT()
    }
    drawing.program.setModelView(mkMat)
    // Draw all the nav markers
    for (name, dir) in data.markers {
      guard let tex = drawing.images[name] else {
        continue
      }
      drawing.bind(tex)
      // Work out where to draw this....
      var spec = mkMat
      // Now rotate off-center
      spec = GLKMatrix4Rotate(spec, (dir.Pitch) * π/180, 1, 0, 0)
      spec = GLKMatrix4Rotate(spec, (-dir.Yaw  ) * π/180, 0, -1, 0)
      spec = GLKMatrix4Translate(spec, 0,0,1)
      spec = GLKMatrix4Rotate(spec, (-dir.Pitch) * π/180, 1, 0, 0)
      spec = GLKMatrix4Rotate(spec, (dir.Yaw  ) * π/180, 0, -1, 0)
      spec = GLKMatrix4Scale(spec, 0.3, 0.3, 1)
      drawing.program.setModelView(spec)
      
      // What colour? White, other than the transparency...
      let zPosition = cos(dir.Yaw * π/180)*cos(dir.Pitch * π/180)
      drawing.program.setColor(Color4(r: 1, g: 1, b: 1, a: min(1,2*(zPosition+0.5))))
      drawing.draw(drawing.texturedCenterSquare!)
    }
    drawing.program.setColor(Color4.White)
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
  }
  
  func generateTextTextures() {
    processGLErrors()
    let text = drawing.textRenderer("Menlo-Bold") as! AtlasTextRenderer
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
  }

  func generate() -> Texture {
    let texture = drawing.createTextureFramebuffer(Size2D(w: 2048, h: 1024), depth: false, stencil: false)
    drawing.bind(texture)
    drawing.setOrthProjection(left: -180, right: 180, bottom: -90, top: 90)
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
    tex.debugName("NavBall")
    return tex
  }
  
  func drawText(angle : Int, size : Float, position : SphericalPoint,
    fillBackground : Color4? = nil, foregroundColor: Color4? = nil)
  {
    let tex = textures[angle]!

    let size = Size2D(w: tex.size!.aspect*size, h: size)
    if let color = fillBackground {
      drawing.program.setColor(color)
      drawing.bind(Texture.None)
      drawing.drawProjectedGridOntoSphere(
        position: position,
        left: -size.w/2, bottom: -size.h/2,
        right: size.w/2, top: size.h/2,
        xSteps: 10, ySteps: 5, slicePoint: 0)
      drawing.program.setColor(foregroundColor!)
    }
    
    drawing.bind(tex)
    drawing.drawProjectedGridOntoSphere(
      position: position,
      left: -size.w/2, bottom: -size.h/2,
      right: size.w/2, top: size.h/2,
      xSteps: 10, ySteps: 5, slicePoint: 0)
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
    drawing.bind(Texture.None)
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
