//
//  NavBall.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

private enum SpeedDisplayMode : String {
  case Surface = "SRF"
  case Orbit   = "ORB"
  case Target  = "TGT"
}

private struct FlightData {
  var Altitude : Float = 0
  var SurfaceSpeed : Float = 0
  var OrbitalVelocity : Float = 0
  var Acceleration : Float = 0
  var Roll : Float = 0
  var Pitch : Float = 0
  var Heading : Float = 0
  var RadarAltitude : Float = 0
  var HorizontalSpeed : Float = 0
  var VerticalSpeed : Float = 0
  var SAS : Bool = false
  var RCS : Bool = false
  var Gear : Bool = false
  var Brakes : Bool = false
  var Lights : Bool = false
  var Throttle : Float = 0
  var SpeedDisplay : SpeedDisplayMode = .Surface

  var NodeExists : Bool = false
  var NodeBurnTime : Float = 0
  var NodeTime : Float = 0
  var NodeDv : Float = 0
}

class NavBall : Instrument {
  /// The INTERNAL screen size e.g. the coordinate system this expects to draw on
  var screenSize : Size2D<Float>
  
  var dataProvider : IKerbalDataStore? = nil
  var drawing : DrawingTools
  var text : TextRenderer
  var navBall : Texture
  var sphere : Drawable
//  var outline : Drawable
//  var triPoints : Drawable
//  var roundBox : (inner: Drawable, outer: Drawable)
//  var lesserRoundBox : (inner: Drawable, outer: Drawable)

  private var data : FlightData? = nil
  
  var overlayTexture : Texture
  
//  var rpmText : RPMTextFile
  
  /// Initialise with a toolset to draw with
  required init(tools : DrawingTools) {
    drawing = tools
    text = drawing.textRenderer("Menlo-Bold")
    sphere = drawing.LoadTriangles(generateSphereTriangles(215, latSteps: 50, longSteps: 100))
//    outline = drawing.LoadTriangles(GenerateCircleTriangles(230, w: 8, steps: 100))
    navBall = NavBallTextureRendering(tools: drawing).generate()
    screenSize = Size2D(w: 640, h: 640)
//    rpmText = RPMTextFile(file: NSBundle.mainBundle().URLForResource("RPMHUD", withExtension: "txt")!)
//    rpmText.prepareTextFor(640/20, screenHeight: 640, font: text, tools: drawing)
  
    
//    let inBox = GenerateRoundedBoxPoints(-60, bottom: -22, right: 60, top: 22, radius: 4)
//    let outBox = GenerateRoundedBoxPoints(-64, bottom: -26, right: 64, top: 26, radius: 8)
//    roundBox = (drawing.Load2DPolygon(inBox), drawing.Load2DPolygon(outBox))
//    
//    let lInBox = GenerateRoundedBoxPoints(-83, bottom: -27, right: 83, top: 27, radius: 4, topLeft: false, topRight: false)
//    let lOutBox = GenerateRoundedBoxPoints(-86, bottom: -30, right: 86, top: 30, radius: 8, topLeft: false, topRight: false)
//    lesserRoundBox = (drawing.Load2DPolygon(lInBox), drawing.Load2DPolygon(lOutBox))
//    
//    let w : Float = 9.093
//    var triList : [Triangle<Point2D>] = [
//      Triangle(Point2D(0, -230+w), Point2D(w, -230-w), Point2D(-w, -230-w)),
//      Triangle(Point2D(-230+w, 0), Point2D(-230-w, -w), Point2D(-230-w, w)),
//      Triangle(Point2D( 230-w, 0), Point2D(230+w, w), Point2D(230+w, -w)),
//      Triangle(Point2D(-w, 302), Point2D(w, 302), Point2D(0, 302-w-w))
//      ]
//    triList.appendContentsOf(GenerateCircleTriangles(4.5, w: 3))
//    triPoints = drawing.LoadTriangles(triList)
//    
    
    // Generate the overlay texture
    let svgFile = NSBundle.mainBundle().URLForResource("RPM_NavBall_Overlay", withExtension: "svg")!
    let svg = SVGImage(withContentsOfFile: svgFile)
    overlayTexture = svg.renderToTexture(Size2D(w: Float(drawing.screenSize.w), h: Float(drawing.screenSize.h)))
    
  }
  
  let variables =   ["rpm.SPEEDDISPLAYMODE",
    "v.altitude", "n.roll", "n.pitch", "n.heading",
    "rpm.RADARALTOCEAN", "v.surfaceSpeed", "v.verticalSpeed",
    "v.orbitalVelocity", "rpm.HORZVELOCITY", "v.sasValue", "v.rcsValue", "v.lightValue", "v.brakeValue", "v.gearValue", "f.throttle",
    "rpm.SPEEDDISPLAYMODE", "rpm.MNODEEXISTS", "rpm.MNODEBURNTIMESECS", "rpm.MNODETIMESECS", "rpm.MNODEDV"]
  
  /// Start communicating with the kerbal data store
  func connect(to : IKerbalDataStore){
    dataProvider = to
    to.subscribe(variables)
  }
  /// Stop communicating with the kerbal data store
  func disconnect(from : IKerbalDataStore) {
    
  }
  
  /// Update this instrument
  func update() {
    guard let v = dataProvider else {
      return
    }
    var data = FlightData()
    data.Altitude = v["v.altitude"]?.floatValue ?? 0
    data.Acceleration = v["rpm.ACCEL"]?.floatValue ?? 0
    data.Roll = v["n.roll"]?.floatValue ?? 0
    data.Pitch = v["n.pitch"]?.floatValue ?? 0
    data.Heading = v["n.heading"]?.floatValue ?? 0
    data.RadarAltitude = v["rpm.RADARALTOCEAN"]?.floatValue ?? 0
    data.SurfaceSpeed = v["v.surfaceSpeed"]?.floatValue ?? 0
    data.VerticalSpeed = v["v.verticalSpeed"]?.floatValue ?? 0
    data.OrbitalVelocity = v["v.orbitalVelocity"]?.floatValue ?? 0
    data.HorizontalSpeed = v["rpm.HORZVELOCITY"]?.floatValue ?? 0
    data.SAS = v["v.sasValue"]?.boolValue ?? false
    data.RCS = v["v.rcsValue"]?.boolValue ?? false
    data.Lights = v["v.lightValue"]?.boolValue ?? false
    data.Brakes = v["v.brakeValue"]?.boolValue ?? false
    data.Gear = v["v.gearValue"]?.boolValue ?? false
    data.Throttle = v["f.throttle"]?.floatValue ?? 0

    let sdm = v["rpm.SPEEDDISPLAYMODE"]?.intValue ?? 0
    if sdm < 0 {
      data.SpeedDisplay = .Target
    } else if sdm > 0 {
      data.SpeedDisplay = .Orbit
    } else {
      data.SpeedDisplay = .Surface
    }
    //  ORB;TGT;SRF + , - , 0
// tr.draw("MODE", size: 15, position: (x: 54, y: 489), align: .Center)

    self.data = data
  }

  let timer = Clock.createTimer()

  func draw() {
    drawing.bind(navBall)
    drawing.program.setColor(red: 1, green: 1, blue: 1)

    var sphMat = GLKMatrix4Identity
    sphMat = GLKMatrix4Translate(sphMat, 320, 338, 0)

    // Roll
    sphMat = GLKMatrix4Rotate(sphMat, (data!.Roll) * π/180, 0, 0, 1)
    // Pitch?
    sphMat = GLKMatrix4Rotate(sphMat, (data!.Pitch) * π/180, 1, 0, 0)
    // Heading
    sphMat = GLKMatrix4Rotate(sphMat, data!.Heading * π/180, 0, -1, 0)

    // Proper orientation to start from. Heading 0, pitch 0, roll 0.
    sphMat = GLKMatrix4Rotate(sphMat, π/2, 0, 0, 1)
    sphMat = GLKMatrix4Rotate(sphMat, π/2, 0, 1, 0)
    drawing.program.setModelView(sphMat)
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.Draw(sphere)

    drawOverlay()
    drawText()

  }
  
//  func drawRoundBox(box : (inner: Drawable, outer: Drawable),
//    position: Point2D, color: Color4) {
//      drawing.program.setModelView(GLKMatrix4MakeTranslation(position.x, position.y, 0))
//      drawing.program.setColor(color)
//      drawing.Draw(box.outer)
//      drawing.program.setColor(red: 0, green: 0, blue: 0)
//      drawing.Draw(box.inner)
//  }
  
  func drawOverlay() {
    // Draw the overlay texture now
    drawing.bind(overlayTexture)
    drawing.program.setUseTexture(true)
    drawing.DrawTexturedSquare(0, bottom: 0, right: 640, top: 640)

    // Overlay text
    let tr = text
    drawing.program.setColor(Color4.White)
    tr.draw("ALTITUDE", size: 15, position: (x: 83, y: 591), align: .Center)
    tr.draw("SRF.SPEED",size: 15, position: (x: 640-83, y: 591), align: .Center)
    tr.draw("ORB.VELOCITY", size: 15, position: (x: 83, y: 554), align: .Center)
    tr.draw("ACCEL.", size: 15, position: (x: 640-83, y: 554), align: .Center)
    
    tr.draw("MODE", size: 15, position: (x: 54, y: 489), align: .Center)
    tr.draw("ROLL", size: 15, position: (x: 36, y: 434), align: .Center)
    tr.draw("PITCH", size: 15, position: (x: 599, y: 434), align: .Center)

    tr.draw("RADAR ALTITUDE", size: 15, position: (x: 104, y: 47), align: .Center)
    tr.draw("HOR.SPEED", size: 15, position: (x: 320, y: 47), align: .Center)
    tr.draw("VERT.SPEED", size: 15, position: (x: 534, y: 47), align: .Center)
    
  }
  
  func drawText() {
    guard let data = data else {
      return
    }

    drawText("%03.1f°", data.Roll, x: 64, y: 240)
    drawText("%03.1f°", data.Pitch, x: 640-64, y: 240)
    drawText("%03.1f°", data.Heading, x: 320, y: 88)

    drawText("{0:SIP_6.1}m", data.Altitude, x: 75, y: 22)
    drawText("{0,4:SIP4}m/s", data.SurfaceSpeed, x: 558, y: 22)
    
    drawText("{0:SIP_6.1}m", data.OrbitalVelocity, x: 77, y: 115)
    drawText("{0:SIP4}m/s", data.Acceleration, x: 558, y: 115)
    drawText(data.SpeedDisplay.rawValue, x: 55, y: 177)
   
    drawText("{0:SIP_6.3}m", data.RadarAltitude, x: 95, y: 623)
    drawText("{0:SIP_6.3}m", data.HorizontalSpeed, x: 320, y: 623)
    drawText("{0:SIP_6.3}m", data.VerticalSpeed, x: 640-95, y: 623)
    
    // 10, 300
    drawText("SAS:", x: 10, y: 280, align: .Left, size: 20)
    drawOnOff(data.SAS, x: 43, y: 312)
    drawText("RCS:", x: 10, y: 344, align: .Left, size: 20)
    drawOnOff(data.RCS, x: 43, y: 344+32)
    drawText("Throttle:", x: 10, y: 408, align: .Left, size: 20)
    
    drawText("Gear:", x: 630, y: 290, align: .Right, size: 20)
    drawOnOff(data.Gear, x: 640-43, y: 312, onText: "Down", offText: "Up")
    drawText("Brakes:", x: 630, y: 344, align: .Right, size: 20)
    drawOnOff(data.Brakes, x: 640-43, y: 344+32)
    drawText("Lights:", x: 630, y: 408, align: .Right, size: 20)
    drawOnOff(data.Lights, x: 640-43, y: 408+32)
    drawText("%.0f%%", data.Throttle*100, x: 90, y: 408+32, align: .Right)

    
    if data.NodeExists {
      drawText("Burn T:", x: 10, y: 408+64, align: .Left, size: 20)
      drawText("{0:METS.f}s", data.NodeBurnTime, x: 10, y: 408+64+32, align: .Left)
      drawText("Node in T", x: 10, y: 408+64+64, align: .Left, size: 20)
      drawText("{0,17:MET+yy:ddd:hh:mm:ss.f}", data.NodeTime, x: 10, y: 408+64+64+32, align: .Left)
      drawText("ΔV", x: 640-10, y: 408+64+64, align: .Right, size: 20)
      drawText("{0:SIP_6.3}m/s", data.NodeDv, x: 630, y: 408+64+64+32, align: .Right)
    }
  }

  func drawOnOff(value : Bool, x : Float, y: Float, onText: String = "On", offText : String = "Off") {
    if value {
      drawText(onText, 0, x: x, y: y, align: .Center, color: Color4.Green)
    } else {
      drawText(offText, 0, x: x, y: y, align: .Center)
    }
    drawing.program.setColor(Color4.White)
  }
  
  func drawText(format : String, x: Float, y: Float, align: NSTextAlignment = .Center, size : Float = 32) {
    drawText(format, 0, x: x, y: y, align: align, color: nil, size: size)
  }

  func drawText(format : String, _ value : Float, x: Float, y: Float, align: NSTextAlignment = .Center, color : Color4? = nil, size : Float = 32) {
    let realPos = Point2D(x, screenSize.h - y)
    if let c = color {
      drawing.program.setColor(c)
    }
    // Format the text.
    let formatted : String
    if format.containsString("{") {
      formatted = try! String.Format(format, value)
    } else {
      formatted = String(format: format, value)
    }
    text.draw(formatted, size: size, position: realPos, align: align)
    
  }
  
//  func generateCrosshairs(
  // Build it out of triangles - trace the edge
//  let points : [Point2D] = [
//    (w/2, -H-J), (-w/2, -H-J),
//    // Left spur
//    (-w/2,m*w/2 - H - w/cos(theta)), (-m*(H+w/cos(theta)-w/2),-w/2),
//    // Outside of box
//    (-W, -w/2), (-W, -Bh/2), (-W-B, -Bh/2), (-W-B, Bh/2), (-W, Bh/2),
//    // Inside of box
//    (-W-w, BiY), (-W-B+w, BiY), (-W-B+w, -BiY), (-W-w, -BiY), (-W-w, BiY), (-W, Bh/2),
//    // Spur top
//    (-W, w/2), (-m*(H+w/2),w/2), (0, -H),
//    (m*(H+w/2),w/2), (W, w/2),
//    // Inside of right box
//    (W, Bh/2), (W+w, BiY), (W+w, -BiY), (W+B-w, -BiY), (W+B-w, BiY), (W+w, BiY),
//    // Outside of right box
//    (W, Bh/2), (W+B, Bh/2), (W+B, -Bh/2), (W, -Bh/2), (W, -w/2),
//    // Right under spur
//    (m*(H+w/cos(theta)-w/2),-w/2), (w/2,m*w/2 - H - w/cos(theta)),
//    ].map { Point2D(x: $0.0, y: $0.1) }
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