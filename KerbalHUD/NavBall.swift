//
//  NavBall.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import UIKit

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
      t("{0:ORB;TGT;SRF}", Vars.Vessel.SpeedDisplay, x: 55, y: 177),
      
      
//      t("{0:SIP_6.3}m", "rpm.RADARALTOCEAN", x: 95, y: 623),
//      t("{0:SIP_6.3}m", "rpm.HORZVELOCITY", x: 320, y: 623),
//      t("{0:SIP_6.3}m", "v.verticalSpeed", x: 640-95, y: 623)
        t("%.3f°", "rpm.YAWPROGRADE", x: 95, y: 623),
        t("%.3f°", "rpm.YAWRETROGRADE", x: 320, y: 623),
      //      t("{0:SIP_6.3}m", "v.verticalSpeed", x: 640-95, y: 623)

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
    
    // 167 - 473 x 50
    let s = ScaledBarSettings(variable: Vars.Flight.Heading, scale: .LinearWrapped, ticks: .Up, range: 90)
    widgets.append(ScaledBarWidget(tools: tools, bounds: FixedBounds(left: 167, bottom: 590, right: 473, top: 640), config: s))
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
