//
//  TelemachusVariables.swift
//  KerbalHUD
//
//  Helper structs to access the Telemachus API string variables without
//  explicitly hardcoding them. Helps ensure that the correct name is
//  used throughout the code, and allows e.g. compound variables at some
//  point in the future.
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

/// Top level variable name structure. Intended to be referenced as a static
/// global reference source.

struct Vars {
  static let Flight = FlightDataVarNames()
  static let Vessel = VesselDataVarNames()
  static let RPM = RasterPropMonitorVarNames()
  static let FAR = FARVarNames()
  static let Aero = AeroNames()
  static let Target = TargetNames()
  static let Node = NodeNames()
  
  private init() {
    
  }
  
}

// All the secondary level access structures. Inside an extension so as not
// to pollute the general namespace.
extension Vars {
  struct FlightDataVarNames {
    let Roll = "n.roll"
    let Pitch = "n.pitch"
    let Heading = "n.heading"

    private init() {
      
    }
  }

  struct VesselDataVarNames {
    let SAS    = "v.sasValue"
    let RCS    = "v.rcsValue"
    let Lights = "v.lightValue"
    let Brakes = "v.brakeValue"
    let Gear   = "v.gearValue"
    
    let Altitude = "v.altitude"
    let Throttle = "f.throttle"
    
    private init() {
      
    }
  }

  struct RasterPropMonitorVarNames {
    struct RPMNode {
      let Exists = "rpm.MNODEEXISTS"
      let BurnTime = "rpm.MNODEBURNTIMESECS"
      let TimeTo = "rpm.MNODETIMESECS"
      let DeltaV = "rpm.MNODEDV"
    }
    
    let Node = RPMNode()
    let Direction = Vars.Direction()

    private init() {
      
    }
  }
  
  
  struct FARVarNames {
    let Flaps = "rpm.PLUGIN_JSIFAR:GetFlapSetting"
  }

  struct AeroNames {
    let Sideslip      = "rpm.SIDESLIP"
    let AngleOfAttack = "rpm.ANGLEOFATTACK"
    let DynamicPressure = "v.dynamicPressure"
  }
  
  struct RelativeOrientation {
    let Pitch : String
    let Yaw : String
    var all : [String] { return [Pitch, Yaw] }
  }
  
  struct Direction {
    let Prograde = RelativeOrientation(  Pitch: "rpm.PITCHPROGRADE",
                                           Yaw: "rpm.YAWPROGRADE")
    let Retrograde = RelativeOrientation(Pitch: "rpm.PITCHRETROGRADE",
                                           Yaw: "rpm.YAWRETROGRADE")
    let RadialIn = RelativeOrientation(  Pitch: "rpm.PITCHRADIALIN",
                                           Yaw: "rpm.YAWRADIALIN")
    let RadialOut = RelativeOrientation( Pitch: "rpm.PITCHRADIALOUT",
                                           Yaw: "rpm.YAWRADIALOUT")
    let NormalPlus = RelativeOrientation(Pitch: "rpm.PITCHNORMALPLUS",
                                           Yaw: "rpm.YAWNORMALPLUS")
    let NormalMinus = RelativeOrientation(Pitch: "rpm.PITCHNORMALMINUS",
                                            Yaw: "rpm.YAWNORMALMINUS")
    let Node = RelativeOrientation(      Pitch: "rpm.PITCHNODE",
                                           Yaw: "rpm.YAWNODE")
    let Target = RelativeOrientation(    Pitch: "rpm.PITCHTARGET",
                                           Yaw: "rpm.YAWTARGET")
    var allRadial : [String] { return Array([RadialIn.all, RadialOut.all].flatten()) }
    var allNormal : [String] { return Array([NormalPlus.all, NormalMinus.all].flatten()) }
    var allProAxis : [String] { return Array([Prograde.all, Retrograde.all].flatten()) }
    var allCardinal : [String] { return Array([allRadial, allNormal, allProAxis].flatten()) }
  }
  
  struct TargetNames {
    let Exists = "rpm.TARGETEXISTS"
  }
  
  struct NodeNames {
    let Exists = "rpm.MNODEEXISTS"
  }
}

func coerceTelemachusVariable(api: String, value: JSON) -> JSON
{
  let badBooleans = [
    Vars.Node.Exists, Vars.Target.Exists]
  if badBooleans.contains(api) {
    return JSON(value.int ?? -1 == 1)
  }
  return value
}