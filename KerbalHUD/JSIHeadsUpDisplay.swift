//
//  JSIHeadsUpDisplay.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

import GLKit

private struct HUDFlightData {
  var Pitch   : GLfloat = 0
  var Roll    : GLfloat = 0
  var Heading : GLfloat = 0
  
  var DeltaH  : GLfloat = 0
  var AtmHeight : GLfloat = 0
  var TerrHeight : GLfloat = 0
  var RadarHeight : GLfloat = 0
  var DynPressure : GLfloat = 0
  var AtmPercent : GLfloat = 0
  var AtmDensity : GLfloat = 0
  var ThrottleSet : GLfloat = 0
  var ThrottleActual : GLfloat = 0
  var Speed : GLfloat = 0
  var EASpeed : GLfloat = 0
  var HrzSpeed : GLfloat = 0
  var SurfaceVelocity : (x: GLfloat, y: GLfloat, z: GLfloat) = (0,0,0)
  var SAS : Bool = false
  var Gear : Bool = false
  var Lights : Bool = false
  var Brake : Bool = false
  var RCS : Bool = false
  
  var HeatAlarm : Bool = false
  var GroundAlarm : Bool = false
  var SlopeAlarm : Bool = false
  
  var RPMVariablesAvailable : Bool = false
  
  func DataNamed<T>(name : String) -> T? {
    switch name {
      case "v.verticalSpeed":
        return DeltaH as? T
      case "rpm.RADARALTOCEAN":
        return RadarHeight as? T
    default:
      fatalError("Unknown variable " + name)
    }
  }
}

class RPMPlaneHUD : Instrument
{
  let variables = [
    "v.atmosphericDensity", "v.dynamicPressure",
    "v.altitude", "v.heightFromTerrain", "v.terrainHeight",
    "n.pitch", "n.heading", "n.roll",
    "f.throttle",
    "v.sasValue", "v.lightValue", "v.brakeValue", "v.gearValue",
    "v.surfaceSpeed", "v.verticalSpeed",
    "v.surfaceVelocityx", "v.surfaceVelocityy", "v.surfaceVelocityz",
    // RPM Variables
    "rpm.available",
    "rpm.ATMOSPHEREDEPTH","rpm.EASPEED","rpm.EFFECTIVETHROTTLE",
    "rpm.ENGINEOVERHEATALARM", "rpm.GROUNDPROXIMITYALARM", "rpm.SLOPEALARM",
    "rpm.RADARALTOCEAN"
    ]
  
  var screenWidth : Float = 640.0
  var screenHeight : Float = 640.0
  
  var screenTextSize : (w: GLfloat, h: GLfloat) = (40, 20)
  
  private var latestData : HUDFlightData?
  private var drawing : DrawingTools
  private var hud : JSIHeadsUpDisplay?
  private var text : TextRenderer
  
  required init(tools : DrawingTools) {
      drawing = tools
    text = drawing.textRenderer("Menlo")
    hud = JSIHeadsUpDisplay(tools: tools, page: self)
  }
  
  func update(vars : [String: JSON]) {
    var data = HUDFlightData()
    data.AtmHeight = vars["v.altitude"]?.floatValue ?? 0
    data.TerrHeight = vars["v.terrainHeight"]?.floatValue ?? 0
    data.RadarHeight = min(data.AtmHeight, data.AtmHeight - data.TerrHeight)
    data.Pitch = vars["n.pitch"]?.floatValue ?? 0
    data.Heading = vars["n.heading"]?.floatValue ?? 0
    data.Roll = vars["n.roll"]?.floatValue ?? 0
    data.DynPressure = vars["v.dynamicPressure"]?.floatValue ?? 0
    data.ThrottleSet = vars["f.throttle"]?.floatValue ?? 0
    data.SAS = vars["v.sasValue"]?.boolValue ?? false
    data.Brake = vars["v.brakeValue"]?.boolValue ?? false
    data.Lights = vars["v.lightValue"]?.boolValue ?? false
    data.Gear = vars["v.gearValue"]?.boolValue ?? false
    data.Speed = vars["v.surfaceSpeed"]?.floatValue ?? 0
    data.DeltaH = vars["v.verticalSpeed"]?.floatValue ?? 0
    let sqHzSpeed = data.Speed*data.Speed - data.DeltaH*data.DeltaH
    data.HrzSpeed = sqHzSpeed < 0 ? 0 : sqrt(sqHzSpeed)
    data.AtmDensity = vars["v.atmosphericDensity"]?.floatValue ?? 0
    data.SurfaceVelocity = (vars["v.surfaceVelocityx"]?.floatValue ?? 0,
                            vars["v.surfaceVelocityy"]?.floatValue ?? 0,
                            vars["v.surfaceVelocityz"]?.floatValue ?? 0)
    data.RPMVariablesAvailable = vars["rpm.available"]?.boolValue ?? false
    if data.RPMVariablesAvailable {
      data.AtmPercent = vars["rpm.ATMOSPHEREDEPTH"]?.floatValue ?? 0
      data.EASpeed = vars["rpm.EASPEED"]?.floatValue ?? 0
      data.ThrottleActual = vars["rpm.EFFECTIVETHROTTLE"]?.floatValue ?? 0
      
      data.HeatAlarm = vars["rpm.ENGINEOVERHEATALARM"]?.boolValue ?? false
      data.GroundAlarm = vars["rpm.GROUNDPROXIMITYALARM"]?.boolValue ?? false
      data.SlopeAlarm = vars["rpm.SLOPEALARM"]?.boolValue ?? false
      data.RadarHeight = vars["rpm.RADARALTOCEAN"]?.floatValue ?? 0
    }
    latestData = data
    
    hud?.update(latestData!)
  }
  
  func draw() {
    hud?.RenderHUD()
    
    if let data = latestData {
      let lineHeight = floor(screenHeight / screenTextSize.h)
      // 16, 48
      //16, 80
      let lineY = (0...19).map { (line : Int) -> Float in screenHeight-lineHeight*(Float(line) + 0.5)}
      
      // Render the text!
      text.draw(String(format:"PRS: %7.3fkPa", data.DynPressure/1000),
        size: lineHeight, position: (16, lineY[1]))
      
      text.draw(String(format:"ASL: %6.0fm", data.AtmHeight),
        size: lineHeight, position: (screenWidth-16, lineY[1]), align: .Right)
      text.draw(String(format:"TER: %6.0fm", data.TerrHeight), size: lineHeight,
        position: (screenWidth-16, lineY[2]), align: .Right)
      
      // Heading note
      text.draw(String(format:"%05.1f˚", data.Heading), size: lineHeight,
        position: (screenWidth/2, lineY[3]), align: .Center)

      text.draw(String(format:"SPD: %6.0fm/s", data.Speed), size: lineHeight, position: (16, lineY[16]))
      text.draw(String(format:"HRZ: %6.0fm/s", data.HrzSpeed), size: lineHeight, position: (16, lineY[18]))
      
      text.draw(String(format:"P:  %05.1f˚ R:  %05.1f˚", data.Pitch, -data.Roll), size: 16,
        position:(screenWidth/2, screenHeight*0.25-8), align: .Center)

      text.draw(String(format:"%6.0fm/s", (data.DeltaH > -0.5 ? abs(data.DeltaH) : data.DeltaH)),
        size: 18, position: (screenWidth*0.25, screenHeight*0.75+8), align: .Right)
      text.draw(String(format:"%6.0fm", data.RadarHeight),
        size: 18, position: (screenWidth*0.75, screenHeight*0.75+8), align: .Left)
  
      if data.SAS {
        text.draw(" SAS", size: lineHeight, position: (8, lineY[5]))
      }
      if data.Gear {
        text.draw(" GEAR", size: lineHeight, position: (8, lineY[6]))
      }
      if data.Brake {
        text.draw(" BRAKE", size: lineHeight, position: (8, lineY[7]))
      }
      if data.Lights {
        text.draw(" LIGHT", size: lineHeight, position: (8, lineY[8]))
      }

      if data.RPMVariablesAvailable {
        text.draw(String(format:"ATM: %5.1f%%", data.AtmPercent*100.0), size: lineHeight, position: (16, lineY[2]))
        text.draw(String(format:"EAS: %6.0fm/s", data.EASpeed), size: lineHeight, position: (16, lineY[17]))

        text.draw(String(format:"THR: %5.1f%% [%5.1f%%]", data.ThrottleSet*100, data.ThrottleActual*100.0),
          size: lineHeight, position: (16, lineY[19]))

        if data.HeatAlarm {
          text.draw("HEAT! ", size: lineHeight, position: (screenWidth-8, lineY[5]), align: .Right)
        }
        if data.GroundAlarm {
          text.draw("GEAR! ", size: lineHeight, position: (screenWidth-8, lineY[6]), align: .Right)
        }
        if data.SlopeAlarm {
          text.draw("SLOPE!", size: lineHeight, position: (screenWidth-8, lineY[7]), align: .Right)
        }
      } else {
        // Only display partial throttle without RPM
        text.draw(String(format:"THR: %5.1f%%", data.ThrottleSet*100), size: lineHeight, position: (16, lineY[19]))

      }
    }
  }
}

class JSIHeadsUpDisplay {
  /// Is the heading bar displayed?
  var headingBar : Bool = true
  /// The position of the heading bar
  var headingBarBounds : Bounds = Bounds(left: 160, bottom: 640-122-38, right: 160+320,top: 640-122)
  /// The visible width of the heading bar, in degrees
  var headingBarScale : GLfloat = 58.0
  
  /// The colour the prograde icon is drawn in
  var progradeColor : (GLfloat, GLfloat, GLfloat, GLfloat) = (0.84, 0.98, 0.0, 1.0)
  /// The colour the rest of the HUD is drawn in
  var foregroundColor : (GLfloat, GLfloat, GLfloat, GLfloat) = (0.0, 1.0, 0.0, 1.0)

  /// Use a 180 or 360 degree horizon
  var use360horizon : Bool = true
  /// The physical size of the horizon box
  var horizonSize : (width: GLfloat, height: GLfloat) = (320, 320)
  /// The vertical scale for the view box e.g. how many degrees it covers
  var horizonScale : GLfloat = 90

  private(set) var drawing : DrawingTools
  private var overlay : Drawable2D?
  private var prograde : Drawable2D?
  private var page : Instrument
  private var text : TextRenderer
  private var verticalBars : [String: JSIHudVerticalBar] = [:]
  private var latestData : HUDFlightData?
  
  init(tools : DrawingTools, page : Instrument) {
    self.page = page
    drawing = tools
    text = tools.textRenderer("Menlo")
    overlay = GenerateHUDoverlay()
    prograde = GenerateProgradeMarker()
    
    let deltaH = JSIHudVerticalBar(tools: tools, useLog: true, direction: .Left, position: (160, 160, 64, 320), limits: (-10000,10000), verticalScale: 10000)
    verticalBars["v.verticalSpeed"] = deltaH
    let radarAlt = JSIHudVerticalBar(tools: tools, useLog: true, direction: .Right, position: (640-160, 160, 64, 320), limits: (0,10000), verticalScale: InversePseudoLog10(4.6))
    verticalBars["rpm.RADARALTOCEAN"] = radarAlt
  }
  
  private func update(data : HUDFlightData) {
    latestData = data
    for barvar in self.verticalBars.keys {
      self.verticalBars[barvar]!.update(latestData!.DataNamed(barvar)!)
    }
  }
  
  func RenderHUD() {
    // Draw the vertical bars
    for bar in self.verticalBars.values {
      drawing.ConstrainDrawing(bar.bounds)
      bar.draw()
    }
    
    // Draw the heading indicator bar
    if headingBar {
      drawing.ConstrainDrawing(headingBarBounds)
      drawHeadingDisplay()
    }
    
  
    // Draw the main pitch view
    drawing.ConstrainDrawing(page.screenWidth/2-horizonSize.width/2,
                              bottom: page.screenHeight/2-horizonSize.height/2,
                              right: page.screenWidth/2+horizonSize.width/2,
                              top: page.screenHeight/2+horizonSize.height/2)
    drawHorizonView()
    drawing.UnconstrainDrawing()
    
    
    // Draw the prograde icon
//    drawing.program.setColor(progradeColor)
//    drawing.Draw(prograde!)
    
    // Draw the overlay, centered
    drawing.program.setModelView(GLKMatrix4MakeTranslation(page.screenWidth/2, page.screenHeight/2, 0))
    drawing.program.setColor(foregroundColor)
    drawing.Draw(overlay!)
  }
  
  private func drawHorizonView() {
    let pitch : GLfloat = latestData?.Pitch ?? 0
    let roll : GLfloat = latestData?.Roll ?? 0
    
    // Because of roll corners, effective size is increased according to aspect
    let hScale = horizonScale*sqrt(pow(horizonSize.width/horizonSize.height, 2)+1)
    
    var angleRange = (min: Int(floor((pitch - hScale/2)/10)*10),
                      max: Int(ceil( (pitch + hScale/2)/10)*10))
    // Apply the constrained horizon, if turned on
    if use360horizon == false {
      angleRange = (max(angleRange.min, -90), min(angleRange.max, 90))
    }
    // Build a transform to apply to all drawing to put us in horizon frame
    var horzFrame = GLKMatrix4Identity
    // Put us in the center of the screen
    horzFrame = GLKMatrix4Translate(horzFrame, page.screenWidth/2, page.screenHeight/2, 0)
    // Rotate according to the roll
    horzFrame = GLKMatrix4Rotate(horzFrame, roll*π/180, 0, 0, -1)
    // And translate for pitch in the center
    horzFrame = GLKMatrix4Translate(horzFrame, 0, (-pitch/horizonScale)*horizonSize.height, 0)
    
    
    for var angle = angleRange.min; angle <= angleRange.max; angle += 5 {
      // How wide do we draw this bar?
      let width : GLfloat = angle % 20 == 0 ? 128 : (angle % 10 == 0 ? 74 : 23)
      let y = horizonSize.height * GLfloat(angle)/horizonScale
      drawing.DrawLine((-width/2, y), to: (width/2, y), width: 1, transform: horzFrame)
    }
    // Do the text labels
    for var angle = angleRange.min; angle <= angleRange.max; angle += 10 {
      if angle % 20 != 0 {
        continue
      }
      let y = horizonSize.height * GLfloat(angle)/horizonScale
      text.draw(String(format: "%d", angle), size: (angle == 0 ? 16 : 10),
        position: (-64-8, y), align: .Left, rotation: π, transform: horzFrame)
      text.draw(String(format: "%d", angle), size: (angle == 0 ? 16 : 10),
        position: (64+8, y), align: .Left, rotation: 0, transform: horzFrame)
    }
  }
  
  private func drawHeadingDisplay() {
    let heading : GLfloat = latestData?.Heading ?? 0
    let halfScale = headingBarScale/2
    let minAngle = Int(floor((heading - halfScale)/10))*10
    let maxAngle = Int(ceil( (heading + halfScale)/10))*10
    let lowAngle = heading-halfScale
    
    for var angle = minAngle; angle <= maxAngle; angle += 10 {
      let x = headingBarBounds.left + headingBarBounds.width*((Float(angle)-lowAngle)/headingBarScale)
      let height = angle % 20 == 0 ? 19 : 11
      drawing.DrawLine((x, headingBarBounds.bottom), to: (x, headingBarBounds.bottom+GLfloat(height)), width: 1)
    }
    
    for var angle = minAngle; angle <= maxAngle; angle += 10 {
      if angle % 20 != 0 {
        continue
      }
      let x = headingBarBounds.left + headingBarBounds.width*((Float(angle)-lowAngle)/headingBarScale)
      
      text.draw(String(format: "%d", angle), size: 15, position: (x, headingBarBounds.bottom+19+9), align: .Center)
    }
  }

  private func GenerateHUDoverlay(H : GLfloat = 16, J : GLfloat = 68, w : GLfloat = 5, theta : GLfloat = 0.7243116395776468) -> Drawable2D
  {
    let m = sin(theta)/cos(theta)
    let W : GLfloat = 41.0
    let B : GLfloat = 70
    let Bh : GLfloat = 17
    let BiY = (Bh-2*w)*0.5
    
    // Build it out of triangles - trace the edge
    let points : [Point2D] = [
      (w/2, -H-J), (-w/2, -H-J),
      // Left spur
      (-w/2,m*w/2 - H - w/cos(theta)), (-m*(H+w/cos(theta)-w/2),-w/2),
      // Outside of box
      (-W, -w/2), (-W, -Bh/2), (-W-B, -Bh/2), (-W-B, Bh/2), (-W, Bh/2),
      // Inside of box
      (-W-w, BiY), (-W-B+w, BiY), (-W-B+w, -BiY), (-W-w, -BiY), (-W-w, BiY), (-W, Bh/2),
      // Spur top
      (-W, w/2), (-m*(H+w/2),w/2), (0, -H),
      (m*(H+w/2),w/2), (W, w/2),
      // Inside of right box
      (W, Bh/2), (W+w, BiY), (W+w, -BiY), (W+B-w, -BiY), (W+B-w, BiY), (W+w, BiY),
      // Outside of right box
      (W, Bh/2), (W+B, Bh/2), (W+B, -Bh/2), (W, -Bh/2), (W, -w/2),
      // Right under spur
      (m*(H+w/cos(theta)-w/2),-w/2), (w/2,m*w/2 - H - w/cos(theta)),
    ]
    
    var triangles = drawing.DecomposePolygon(points)
    
    // Add the crosshair lines and triangles
    let cxW : GLfloat = 1.0
    let cxTw : GLfloat = 15.0
    let cxTh : GLfloat = 20.0
    let crossHairPoints : [Point2D] = [
      (-160, -cxW/2), (-160-cxTw, -cxTh/2), (-160-cxTw, cxTh/2), (-160, cxW/2),
      (-W-w, cxW/2), (-W-w, -cxW/2)
    ]
    triangles.extend(drawing.DecomposePolygon(crossHairPoints))
    triangles.extend(drawing.DecomposePolygon(crossHairPoints.map { Point2D(-$0.x, $0.y) }))

    // Top Triangle
    let topTriangle : [Point2D] = [(0,160), (-cxTh/2, 160+cxTw), (cxTh/2, 160+cxTw)]
    triangles.extend(drawing.DecomposePolygon(topTriangle))
    
    // Upper target line
    let upperTarget : [Point2D] = [(-w/2, H), (-w/2, H+J), (w/2, H+J), (w/2, H)]
    triangles.extend(drawing.DecomposePolygon(upperTarget))
    
    // Finally, an open circle
    triangles.extend(GenerateCircleTriangles(5, w: 2.5))
    
    return drawing.LoadTriangles(triangles)!
  }
  
  func GenerateProgradeMarker(size : GLfloat = 64) -> Drawable2D {
    let scale = size / 64.0
    var tris = GenerateCircleTriangles(12.0 * scale, w: 3.0*scale)
    tris.extend(GenerateBoxTriangles(-30*scale, bottom: -1*scale, right: -14*scale, top: 1*scale))
    tris.extend(GenerateBoxTriangles(-1*scale, bottom: 14*scale, right: 1*scale, top: 30*scale))
    tris.extend(GenerateBoxTriangles(14*scale, bottom: -1*scale, right: 30*scale, top: 1*scale))
    
    return drawing.LoadTriangles(tris)!
  }
}

class JSIHudVerticalBar {
  enum VerticalScaleDirection {
    case Left
    case Right
  }
  /// Use the Log10 function for scaling the axis
  var useLog : Bool = true
  /// Which direction is the axis drawn in
  var direction : VerticalScaleDirection = .Left
  /// Where is this scale positioned
//  var position : (x: GLfloat, y: GLfloat, width: GLfloat, height: GLfloat) = (0,0,1,1)
  var bounds : Bounds
  
  /// What are the upper and lower display limits?
  var limits : (min: GLfloat, max: GLfloat)?
  /// How much should we display in one vertical sweep?
  var verticalScale : GLfloat = 100
  
  
  var drawing : DrawingTools
  private var text : TextRenderer
  
  var variable : GLfloat = 0
  
  init(tools : DrawingTools, useLog : Bool, direction: VerticalScaleDirection,
    position: (x: GLfloat, y: GLfloat, width: GLfloat, height: GLfloat), limits: (min: GLfloat, max: GLfloat),
    verticalScale : GLfloat) {
      drawing = tools
      text = drawing.textRenderer("Menlo")
      self.useLog = useLog
      self.direction = direction
      if self.direction == .Left {
        self.bounds = Bounds(left: position.x-position.width, bottom: position.y, right: position.x, top: position.y+position.height)
      } else {
        self.bounds = Bounds(left: position.x, bottom: position.y, right: position.x+position.width, top: position.y+position.height)
      }
      self.limits = limits
      self.verticalScale = verticalScale
  }
  
  func update(value : GLfloat) {
    variable = value
  }
  
  func draw() {
    let lgeTickSize : GLfloat = 14 * (direction == .Left ? -1 : 1)
    let medTickSize = lgeTickSize / 2
//    let smlTickSize = medTickSize / 2
    let axisLinePos = direction == .Left ? bounds.right : bounds.left
    let lineOffset : GLfloat = direction == .Left ? -0.5 : 0.5
    drawing.DrawLine((axisLinePos+lineOffset, bounds.bottom), to: (axisLinePos+lineOffset, bounds.top), width: 1)
    
    // Calculate the visible range of markers
    let center = useLog ? PseudoLog10(variable) : variable
    let rangeOffset = (useLog ? PseudoLog10(verticalScale) : verticalScale) / 2
    let range = (min: center - rangeOffset, max: center + rangeOffset)
    var markerRange = (min: Int(floor(range.min)), max: Int(ceil(range.max)))

    // If we are limited, then constrain these
    if let limit = limits {
      let lower = Int(floor(useLog ? PseudoLog10(limit.min) : limit.min))
      let upper = Int(ceil(useLog ? PseudoLog10(limit.max) : limit.max))
      // Calculate the minimum and maximum of the log range to draw
      markerRange = (min: max(markerRange.min, lower), max: min(markerRange.max, upper))
    }

    // Draw the major marks now
    for value in markerRange.min...markerRange.max {
      let y : GLfloat = bounds.bottom + bounds.height * ((GLfloat(value)-range.min) / (2*rangeOffset))
      drawing.DrawLine((axisLinePos, y), to: (axisLinePos+lgeTickSize, y), width: 1)
      
      // Now, draw the intermediate markers
      if !(value == markerRange.max) {
        let halfValue : GLfloat
        if useLog {
          // Work out the next power
          let nextPower = value >= 0 ? value + 1 : value
          halfValue = PseudoLog10(InversePseudoLog10(Float(nextPower))*0.5)
        } else {
          halfValue = Float(value) + 0.5
        }
        let halfwayY : GLfloat = bounds.bottom + bounds.height * ((GLfloat(halfValue)-range.min) / (2*rangeOffset))
        drawing.DrawLine((axisLinePos, halfwayY), to: (axisLinePos+medTickSize, halfwayY), width: 1)
      }
    }
    
    // Now, draw text in a separate pass
    let textAlign = direction == .Left ? NSTextAlignment.Right : NSTextAlignment.Left
    for value in markerRange.min...markerRange.max {
      let y : GLfloat = bounds.bottom + bounds.height * ((GLfloat(value)-range.min) / (2*rangeOffset))
      let realVal = useLog ? InversePseudoLog10(Float(value)) : Float(value)
      text.draw(String(format: "%.0f", realVal), size: 16, position: (GLfloat(axisLinePos + lgeTickSize + 2), y), align: (direction == .Left ? NSTextAlignment.Right : NSTextAlignment.Left))
      if !(value == markerRange.max) {
        let halfValue : GLfloat
        let halfPosition : GLfloat
        if useLog {
          // Work out the next power
          let nextPower = value >= 0 ? value + 1 : value
          halfValue = InversePseudoLog10(Float(nextPower))*0.5
          halfPosition = PseudoLog10(halfValue)
        } else {
          halfValue = Float(value) + 0.5
          halfPosition = halfValue
        }
        let halfwayY : GLfloat = bounds.bottom + bounds.height * ((GLfloat(halfPosition)-range.min) / (2*rangeOffset))
        let halfFormat = value == -1 || value == 0 ? "%.1f" : "%.0f"
        text.draw(String(format: halfFormat, halfValue), size: 10, position: (GLfloat(axisLinePos + lgeTickSize + 2), halfwayY), align: textAlign)
      }
    }
  }
}

//    // Draw the major marks
//    for power in logMin...logMax {
//      var y : GLfloat = 0.25 + 0.5 * GLfloat((Double(power)-bottom)/logRange)
//      drawLine((xPos,y), to: (xPos+GLfloat(lgeTickSize), y), width: 1)
//
//
//      if !(power == logMax) {
//        var nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
//        let halfPoint = PseudoLog10(nextPow*0.5)
//        y = 0.25 + GLfloat((halfPoint-bottom)/logRange * 0.5)
//        drawLine((xPos,y), to: (xPos+GLfloat(medTickSize), y), width: 1)
//
//        nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
//        let doubPoint = PseudoLog10(nextPow*0.1*2)
//        y = 0.25 + 0.5 * GLfloat((doubPoint-bottom)/logRange)
//        drawLine((xPos,y), to: (xPos+GLfloat(smlTickSize), y), width: 1)
//      }
//    }
//    // Draw text in a separate pass
//    for power in logMin...logMax {
//      var y : GLfloat = 0.25 + 0.5 * GLfloat((Double(power)-bottom)/logRange)
//      var txt = NSString(format: "%.0f", abs(InversePseudoLog10(Double(power))))
//      drawText(txt as String, align: left ? .Right : .Left, position: (xPos + lgeTickSize * 1.25, y), fontSize: 12)
//
//      if !(power == logMax) {
//        let nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
//        let halfPoint = PseudoLog10(nextPow*0.5)
//        y = 0.25 + GLfloat((halfPoint-bottom)/logRange * 0.5)
//        if abs(nextPow) == 1 {
//          txt = NSString(format: "%.1f", abs(nextPow*0.5))
//        } else {
//          txt = NSString(format: "%.0f", abs(nextPow*0.5))
//        }
//        drawText(txt as String, align: left ? .Right : .Left, position: (xPos + medTickSize * 1.25, y), fontSize: 9)
//      }
//    }
//
//  }






//PAGE
//{
//  name = aviapfd
//  default = yes
//  text = JSI/RPMPodPatches/BasicMFD/pa_HUDPFD.txt
//  defaultFontTint = 0,255,0,255
//  button = HUDScreenObj
//  BACKGROUNDHANDLER
//  {
//    name = JSIHeadsUpDisplay
//    method = RenderHUD
//    backgroundColor = 0,255,0,20
//
//    horizonTexture = JSI/RasterPropMonitor/Library/Components/HUD/ladder
//    use360horizon = true
//    horizonSize = 320,320
//    horizonTextureSize = 480,480
//
//    headingBar = JSI/RasterPropMonitor/Library/Components/HUD/heading
//    headingBarPosition = 160,122,320,38
//    headingBarWidth = 320
//
//    verticalBar = RadarAltOceanBar;VSIBar
//
//    staticOverlay = JSI/RasterPropMonitor/Library/Components/HUD/hud-overlay
//  }
//}
//  
//JSIHUD_VERTICAL_BAR
//{
//  name = RadarAltOceanBar
//  texture = JSI/RasterPropMonitor/Library/Components/HUD/rightscale
//  useLog10 = true
//  variableName = RADARALTOCEAN
//  position = 480,160,64,320
//  scale = 0, 10000
//  textureLimit = 855,170
//  textureSize = 640
//}
//
//JSIHUD_VERTICAL_BAR
//{
//  name = VSIBar
//  texture = JSI/RasterPropMonitor/Library/Components/HUD/leftscale
//  useLog10 = true
//  variableName = VERTSPEED
//  position = 96,160,64,320
//  scale = -10000, 10000
//  textureLimit = 1845, 208
//  textureSize = 640
//}


func PseudoLog10(x : Float) -> Float
{

  if abs(x) <= 1.0 {
    return x
  }
  return (1.0 + log10(abs(x))) * sign(x)
}

func InversePseudoLog10(x : Float) -> Float
{
  if abs(x) <= 1.0 {
    return x
  }
  return pow(10, abs(x)-1)*sign(x)
}