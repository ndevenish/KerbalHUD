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
  
  private init() {
    
  }
}

}