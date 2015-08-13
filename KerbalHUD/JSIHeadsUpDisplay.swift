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
    
  }
}