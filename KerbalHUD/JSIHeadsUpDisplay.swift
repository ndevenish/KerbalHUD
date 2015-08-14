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
  
  private var latestData : HUDFlightData?
  private var drawing : DrawingTools
  
  private var overlay : Drawable2D?
  private var prograde : Drawable2D?
  
  required init(tools : DrawingTools) {
      drawing = tools
    overlay  = GenerateHUDoverlay()
    prograde = GenerateProgradeMarker()
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
    drawing.program.setModelViewProjection(GLKMatrix4Multiply(drawing.program.projection, GLKMatrix4MakeTranslation(0.5, 0.5, 0)))
    drawing.Draw(overlay!)
    drawing.program.setColor(red: 1, green: 1, blue: 0)
    drawing.Draw(prograde!)
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
      // Back to base
//      (w/2, -H-J)
    ]
    let ptScaled = points.map { Point2D($0.x/640.0, $0.y/640.0) }
    
    var triangles = drawing.DecomposePolygon(ptScaled)
    
    // Add the crosshair lines and triangles
    let cxW : GLfloat = 1.0
    let cxTw : GLfloat = 15.0
    let cxTh : GLfloat = 20.0
    let crossHairPoints : [Point2D] = [
      (-160, -cxW/2), (-160-cxTw, -cxTh/2), (-160-cxTw, cxTh/2), (-160, cxW/2),
      (-W-w, cxW/2), (-W-w, -cxW/2)
    ]
    triangles.extend(drawing.DecomposePolygon(crossHairPoints.map { Point2D($0.x/640.0, $0.y/640.0) }))
    triangles.extend(drawing.DecomposePolygon(crossHairPoints.map { Point2D(-$0.x/640.0, $0.y/640.0) }))
    
    // Top Triangle
    let topTriangle : [Point2D] = [(0,160), (-cxTh/2, 160+cxTw), (cxTh/2, 160+cxTw)]
    triangles.extend(drawing.DecomposePolygon(topTriangle.map { Point2D($0.x/640.0, $0.y/640.0) }))
    
    // Upper target line
    let upperTarget : [Point2D] = [(-w/2, H), (-w/2, H+J), (w/2, H+J), (w/2, H)]
    triangles.extend(drawing.DecomposePolygon(upperTarget.map { Point2D($0.x/640.0, $0.y/640.0) }))
    
    // Finally, an open circle
    triangles.extend(GenerateCircleTriangles(5/640.0, w: 2.5/640.0))
    
    return drawing.LoadTriangles(triangles)!
  }
  
  func GenerateProgradeMarker() -> Drawable2D {
    var tris = GenerateCircleTriangles(12.0/640.0, w: 3.0/640.0)
    tris.extend(GenerateBoxTriangles(-30/640.0, bottom: -1/640.0, right: -14/640.0, top: 1/640.0))
    tris.extend(GenerateBoxTriangles(-1/640.0, bottom: 14/640.0, right: 1/640.0, top: 30/640.0))
    tris.extend(GenerateBoxTriangles(14/640.0, bottom: -1/640.0, right: 30/640.0, top: 1/640.0))
    
    return drawing.LoadTriangles(tris)!
  }
}

/// Generates a series of triangles for an open circle
func GenerateCircleTriangles(r : GLfloat, w : GLfloat) -> [Triangle]
{
  var tris : [Triangle] = []
  let Csteps = 20
  let innerR = r - w/2
  let outerR = r + w/2
  
  for step in 0..<Csteps {
    let theta = Float(2*M_PI*(Double(step)/Double(Csteps)))
    let nextTheta = Float(2*M_PI*(Double(step+1)/Double(Csteps)))
    tris.append((
      Point2D(innerR*sin(theta), innerR*cos(theta)),
      Point2D(outerR*sin(theta), outerR*cos(theta)),
      Point2D(innerR*sin(nextTheta), innerR*cos(nextTheta))
    ))
    tris.append((
      Point2D(innerR*sin(nextTheta), innerR*cos(nextTheta)),
      Point2D(outerR*sin(theta), outerR*cos(theta)),
      Point2D(outerR*sin(nextTheta), outerR*cos(nextTheta))
    ))
  }
  return tris
}

func GenerateBoxTriangles(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat) -> [Triangle] {
  return [
    Triangle((left, bottom), (left, top), (right, top)),
    Triangle((right, top), (right, bottom), (left, bottom))
  ]
}

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