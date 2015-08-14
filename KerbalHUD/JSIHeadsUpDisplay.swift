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
  
  private var latestData : HUDFlightData?
  private var drawing : DrawingTools
  private var hud : JSIHeadsUpDisplay?
  
  required init(tools : DrawingTools) {
      drawing = tools
    hud = JSIHeadsUpDisplay(tools: tools, page: self)
  }
  
  func update(vars : [String: JSON]) {
    var data = HUDFlightData()
    data.AtmHeight = vars["v.altitude"]!.floatValue ?? 0
    data.TerrHeight = vars["v.terrainHeight"]!.floatValue
    data.RadarHeight = min(data.AtmHeight, data.AtmHeight - data.TerrHeight)
    data.Pitch = vars["n.pitch"]!.floatValue
    data.Heading = vars["n.heading"]!.floatValue
    data.Roll = vars["n.roll"]!.floatValue
    data.DynPressure = vars["v.dynamicPressure"]!.floatValue
    data.ThrottleSet = vars["f.throttle"]!.floatValue
    data.SAS = vars["v.sasValue"]!.stringValue == "True"
    data.Brake = vars["v.brakeValue"]!.stringValue == "True"
    data.Lights = vars["v.lightValue"]!.stringValue == "True"
    data.Gear = vars["v.gearValue"]!.stringValue == "True"
    data.Speed = vars["v.surfaceSpeed"]!.floatValue
    data.DeltaH = vars["v.verticalSpeed"]!.floatValue
    let sqHzSpeed = data.Speed*data.Speed - data.DeltaH*data.DeltaH
    data.HrzSpeed = sqHzSpeed < 0 ? 0 : sqrt(sqHzSpeed)
    data.AtmDensity = vars["v.atmosphericDensity"]!.floatValue
    data.SurfaceVelocity = (vars["v.surfaceVelocityx"]!.floatValue, vars["v.surfaceVelocityy"]!.floatValue, vars["v.surfaceVelocityz"]!.floatValue)
    data.RPMVariablesAvailable = vars["rpm.available"]!.stringValue.uppercaseString == "TRUE"
    if data.RPMVariablesAvailable {
      data.AtmPercent = vars["rpm.ATMOSPHEREDEPTH"]!.floatValue
      data.EASpeed = vars["rpm.EASPEED"]!.floatValue
      data.ThrottleActual = vars["rpm.EFFECTIVETHROTTLE"]!.floatValue
      
      data.HeatAlarm = vars["rpm.ENGINEOVERHEATALARM"]!.intValue != 0
      data.GroundAlarm = vars["rpm.GROUNDPROXIMITYALARM"]!.intValue != 0
      data.SlopeAlarm = vars["rpm.SLOPEALARM"]!.intValue != 0
      data.RadarHeight = vars["rpm.RADARALTOCEAN"]!.floatValue
    }
    latestData = data
  }
  
  func draw() {
    hud?.RenderHUD()
  }
}

class JSIHeadsUpDisplay {
  /// Is the heading bar displayed?
  var headingBar : Bool = true
  /// The position of the heading bar
  var headingBarPosition : (position: Point2D, size: Size2D) = ((160, 640-122-38), (320,38))
  /// The visible width of the heading bar, in degrees
  var headingBarScale : GLfloat = 58.0
  
  /// The colour the prograde icon is drawn in
  var progradeColor : (GLfloat, GLfloat, GLfloat, GLfloat) = (0.84, 0.98, 0.0, 1.0)
  /// The colour the rest of the HUD is drawn in
  var foregroundColor : (GLfloat, GLfloat, GLfloat, GLfloat) = (0.0, 1.0, 0.0, 1.0)

  private(set) var drawing : DrawingTools
  private var overlay : Drawable2D?
  private var prograde : Drawable2D?
  private var page : Instrument

  private var verticalBars : [JSIHudVerticalBar] = []
  
  init(tools : DrawingTools, page : Instrument) {
    self.page = page
    drawing = tools
    overlay = GenerateHUDoverlay()
    prograde = GenerateProgradeMarker()
    
    let deltaH = JSIHudVerticalBar(tools: tools, useLog: true, direction: .Left, position: (160, 160, 64, 320), limits: (-10000,10000), verticalScale: 10000)
    verticalBars.append(deltaH)
    let radarAlt = JSIHudVerticalBar(tools: tools, useLog: true, direction: .Right, position: (640-160, 160, 64, 320), limits: (0,10000), verticalScale: InversePseudoLog10(4.6))
    verticalBars.append(radarAlt)
    
  }
  
  func RenderHUD() {
    // Draw the vertical bars
    for bar in self.verticalBars {
      bar.draw()
    }
    // Draw the heading indicator bar
    
    // Draw the prograde icon
    drawing.program.setColor(progradeColor)
    drawing.Draw(prograde!)
    
    // Draw the overlay, centered
    drawing.program.setModelView(GLKMatrix4MakeTranslation(page.screenWidth/2, page.screenHeight/2, 0))
    drawing.program.setColor(foregroundColor)
    drawing.Draw(overlay!)
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
  var position : (x: GLfloat, y: GLfloat, width: GLfloat, height: GLfloat) = (0,0,1,1)
  /// What are the upper and lower display limits?
  var limits : (min: GLfloat, max: GLfloat)?
  /// How much should we display in one vertical sweep?
  var verticalScale : GLfloat = 100
  
  var drawing : DrawingTools
  
  var variable : GLfloat = 0
  
  init(tools : DrawingTools, useLog : Bool, direction: VerticalScaleDirection,
    position: (x: GLfloat, y: GLfloat, width: GLfloat, height: GLfloat), limits: (min: GLfloat, max: GLfloat),
    verticalScale : GLfloat) {
    drawing = tools
      self.useLog = useLog
      self.direction = direction
      self.position = position
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
    
    drawing.DrawLine((position.x, position.y), to: (position.x, position.y+position.height), width: 1)
    
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
      let y : GLfloat = position.y + position.height * ((GLfloat(value)-range.min) / (2*rangeOffset))
      drawing.DrawLine((position.x, y), to: (position.x+lgeTickSize, y), width: 1)
      
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
        let halfwayY : GLfloat = position.y + position.height * ((GLfloat(halfValue)-range.min) / (2*rangeOffset))
        drawing.DrawLine((position.x, halfwayY), to: (position.x+medTickSize, halfwayY), width: 1)
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