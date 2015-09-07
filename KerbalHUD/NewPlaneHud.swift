//
//  NewPlaneHud.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import UIKit

private func t(format : String, _ variable : String, x: Float, y: Float, align: NSTextAlignment = .Center,
  condition: String? = nil, size: Float = 1) -> TextEntry {
      let rX = x * 1.0/40
      let rY = 1 - ((y+0.5) * 1.0/20)
    return t(format, [variable], exactX: rX, exactY: rY, align: align, condition: condition, size: size)
}

private func t(format : String, _ variable : [String], exactX: Float, exactY: Float, align: NSTextAlignment = .Center,
  condition: String? = nil, size: Float = 1) -> TextEntry {
    let lineHeight : Float = size * 1.0/20
    return TextEntry(string: format, size: lineHeight, position: Point2D(exactX,exactY), align: align, variables: variable, font: "", condition: condition, color: Color4.Green)
}

private func t(format : String, x: Float, y: Float, align: NSTextAlignment = .Center,
  condition: String? = nil, size: Float = 1) -> TextEntry {
    let rX = x * 1.0/40
    let rY = 1 - ((y+0.5) * 1.0/20)
    let lineHeight : Float = size * 1.0/20
    return TextEntry(string: format, size: lineHeight, position: Point2D(rX,rY), align: align, variables: [], font: "", condition: condition, color: Color4.Green)
}

class NewPlaneHud : LayeredInstrument {
  init(tools : DrawingTools) {
    var config = InstrumentConfiguration()
    config.size = Size2D(w: 1, h: 1)
    
    // Now do the text
    config.text.appendContentsOf([
      t("PRS: %7.3f Pa",  "v.dynamicPressure", x: 1, y: 1, align: .Left),
      t("ATM: {0,5:00.0%}",  "rpm.ATMOSPHEREDEPTH", x: 1, y: 2, align: .Left),
      
      t("ASL: {0:SIP6}m", "v.altitude", x:39, y: 1, align: .Right),
      t("TER: {0:SIP6}m", "rpm.TERRAINHEIGHT", x:39, y: 2, align: .Right),
      t("%03.1f°", Vars.Flight.Heading, x:20, y: 3, align: .Center),
      t("{0:SIP6}m/s", ["v.verticalSpeed"], exactX: 0.25, exactY: 0.75+0.7/2/20, align: .Right, condition: nil, size: 0.7),
      t("{0:SIP6}m", ["rpm.RADARALTOCEAN"], exactX: 0.75, exactY: 0.75+0.7/2/20, align: .Left, condition: nil, size: 0.7),
      t("SAS",   x: 2, y: 5.5, align: .Left, condition: Vars.Vessel.SAS),
      t("GEAR",  x: 2, y: 7.5, align: .Left, condition: Vars.Vessel.Gear),
      t("BRAKE", x: 2, y: 9.5, align: .Left, condition: Vars.Vessel.Brakes),
      t("LIGHT", x: 2, y: 11.5, align: .Left, condition: Vars.Vessel.Lights),
      t("HEAT!", x: 39, y: 5.5, align: .Right, condition: "rpm.ENGINEOVERHEATALARM"),
      t("GEAR!", x: 39, y: 7.5, align: .Right, condition: "rpm.GROUNDPROXIMITYALARM"),
      t("SLOPE!",x: 39, y: 9.5, align: .Right, condition: "rpm.SLOPEALARM"),
      
      t("SPD: {0:SIP6}m/s", "rpm.SURFSPEED", x: 1, y: 16, align: .Left),
      t("EAS: {0:SIP6}m/s", "rpm.EASPEED", x: 1, y: 17, align: .Left),
      t("HRZ: {0:SIP6}m/s", "rpm.HORZVELOCITY", x: 1, y: 18, align: .Left),
      t("THR: {0,6:00.0%} ({1,6:00.0%})", ["rpm.THROTTLE", "rpm.EFFECTIVETHROTTLE"], exactX: 1.0/40, exactY: 1 - (19.5*1.0/20), align: .Left),
      
      t("P: {0,6:000.0}° R: {1,6:000.0}°", [Vars.Flight.Pitch, Vars.Flight.Roll], exactX: 0.5, exactY: 0.25-0.5/2/20, align: .Center, condition: nil, size: 0.5)
      ])
    
    //
    //      text.draw(String(format:"SPD: %6.0fm/s", data.Speed), size: lineHeight, position: (16, lineY[16]))
    //      text.draw(String(format:"HRZ: %6.0fm/s", data.HrzSpeed), size: lineHeight, position: (16, lineY[18]))
    //
    //      text.draw(String(format:"P:  %05.1f˚ R:  %05.1f˚", data.Pitch, -data.Roll), size: 16,
    //        position:(screenSize.w/2, screenSize.h*0.25-8), align: .Center)
    //
    //      text.draw(String(format:"%6.0fm/s", (data.DeltaH > -0.5 ? abs(data.DeltaH) : data.DeltaH)),
    //        size: 18, position: (screenSize.w*0.25, screenSize.h*0.75+8), align: .Right)
    //      text.draw(String(format:"%6.0fm", data.RadarHeight),
    //        size: 18, position: (screenSize.w*0.75, screenSize.h*0.75+8), align: .Left)
    //
    //      if data.SAS {
    //        text.draw(" SAS", size: lineHeight, position: (8, lineY[5]))
    //      }
    //      if data.Gear {
    //        text.draw(" GEAR", size: lineHeight, position: (8, lineY[6]))
    //      }
    //      if data.Brake {
    //        text.draw(" BRAKE", size: lineHeight, position: (8, lineY[7]))
    //      }
    //      if data.Lights {
    //        text.draw(" LIGHT", size: lineHeight, position: (8, lineY[8]))
    //      }
    //
    //      if data.RPMVariablesAvailable {
    //        text.draw(String(format:"ATM: %5.1f%%", data.AtmPercent*100.0), size: lineHeight, position: (16, lineY[2]))
    //        text.draw(String(format:"EAS: %6.0fm/s", data.EASpeed), size: lineHeight, position: (16, lineY[17]))
    //
    //        text.draw(String(format:"THR: %5.1f%% [%5.1f%%]", data.ThrottleSet*100, data.ThrottleActual*100.0),
    //          size: lineHeight, position: (16, lineY[19]))
    //
    //        if data.HeatAlarm {
    //          text.draw("HEAT! ", size: lineHeight, position: (screenSize.w-8, lineY[5]), align: .Right)
    //        }
    //        if data.GroundAlarm {
    //          text.draw("GEAR! ", size: lineHeight, position: (screenSize.w-8, lineY[6]), align: .Right)
    //        }
    //        if data.SlopeAlarm {
    //          text.draw("SLOPE!", size: lineHeight, position: (screenSize.w-8, lineY[7]), align: .Right)
    //        }
    //      } else {
    //        // Only display partial throttle without RPM
    //        text.draw(String(format:"THR: %5.1f%%", data.ThrottleSet*100), size: lineHeight, position: (16, lineY[19]))
    //
    //      }

    
    super.init(tools: tools, config: config)
    
    // Set up the indicator bars
    let deltaVzSettings = ScaledBarSettings(
      variable: "v.verticalSpeed", scale: .PseudoLogarithmic, ticks: .Left,
      range: 10000, maxValue: 10000, minValue: -10000, color: Color4.Green,
      markerLine: 2)
    let altSettings = ScaledBarSettings(
      variable: "rpm.RADARALTOCEAN", scale: .PseudoLogarithmic, ticks: .Right,
      range: InversePseudoLog10(4.6), maxValue: 10000, minValue: 0, color: Color4.Green,
      markerLine: 1)
    let headingSettings = ScaledBarSettings(
      variable: Vars.Flight.Heading, scale: .LinearWrapped, ticks: .Up,
      range: 90, maxValue: 360, minValue: 0, color: Color4.Green)
//    let headingSettings2 = ScaledBarSettings(
//      variable: Vars.Flight.Heading, scale: .LinearWrapped, ticks: .Down,
//      range: 90, maxValue: 360, minValue: 0, color: Color4.Green,
//      markerLine: 5)

    widgets.append(LadderHorizonWidget(tools: tools,
      bounds: FixedBounds(left: 0.25, bottom: 0.25, right: 0.75, top: 0.75)))
    
    widgets.append(ScaledBarWidget(tools: tools,
      bounds: FixedBounds(left: 0, bottom: 0.25, right: 0.25, top: 0.75),
      config: deltaVzSettings ))
    widgets.append(ScaledBarWidget(tools: tools,
      bounds: FixedBounds(left: 0.75, bottom: 0.25, right: 1, top: 0.75),
      config: altSettings ))
    widgets.append(ScaledBarWidget(tools: tools,
      bounds: FixedBounds(left: 0.25, bottom: 0.75, right: 0.75, top: 1.0),
      config: headingSettings ))
    
    widgets.append(FlapsIndicatorWidget(tools: tools,
      bounds: FixedBounds(centerX: 7/8, centerY: 1/8,
        width: 0.2, height: 0.15),
      configuration: [:]))
    
//    widgets.append(RPMTextFileWidget(tools: tools, bounds: FixedBounds(left: 0, bottom: 0, right: 1, top: 1)))

  }
}

//
//class NavBall : LayeredInstrument {
//  init(tools : DrawingTools) {
//    var config = InstrumentConfiguration()
//    config.overlay = SVGOverlay(url: NSBundle.mainBundle().URLForResource("RPM_NavBall_Overlay", withExtension: "svg")!)
//    
//    // Fixed text labels
//    config.text = [
//      t("Altitude",     x: 83,     y: 49, size: 15),
//      t("SRF.SPEED",    x: 640-83, y: 49, size: 15),
//      t("ORB.VELOCITY", x: 83,     y: 640-554, size: 15),
//      t("ACCEL.",       x: 640-83, y: 640-554, size: 15),
//      t("MODE",         x: 54,     y: 640-489, size: 15),
//      t("ROLL",         x: 36,     y: 640-434, size: 15),
//      t("PITCH",        x: 599,    y: 640-434, size: 15),
//      t("RADAR ALTITUDE", x: 104,  y: 640-47 , size: 15),
//      t("HOR.SPEED",    x: 320,    y: 640-47 , size: 15),
//      t("VERT.SPEED",   x: 534,    y: 640-47 , size: 15),
//    ]
//    
//    // Simple display text
//    config.text.appendContentsOf([
//      t("%03.1f°", Vars.Flight.Roll, x: 67, y: 240),
//      t("%03.1f°", Vars.Flight.Pitch, x: 573, y: 240),
//      t("%03.1f°", Vars.Flight.Heading, x: 320, y: 80),
//      
//      t("{0:SIP_6.1}m", Vars.Vessel.Altitude, x: 83.5, y: 22),
//      t("{0,4:SIP4}m/s", "v.surfaceSpeed", x: 556.5, y: 22),
//      
//      t("{0:SIP_6.1}m", "v.orbitalVelocity", x: 83.5, y: 115),
//      t("{0:SIP4}m/s", "rpm.ACCEL", x: 556.5, y: 115),
//      t("{0:ORB;TGT;SRF}", "rpm.SPEEDDISPLAYMODE", x: 55, y: 177),
//      
//      
//      t("{0:SIP_6.3}m", "rpm.RADARALTOCEAN", x: 95, y: 623),
//      t("{0:SIP_6.3}m", "rpm.HORZVELOCITY", x: 320, y: 623),
//      t("{0:SIP_6.3}m", "v.verticalSpeed", x: 640-95, y: 623)
//      ])
//    
//    // Various control Status displays
//    config.text.appendContentsOf([
//      t("SAS:", x: 10, y: 280, align: .Left, size: 20),
//      t("RCS:", x: 10, y: 344, align: .Left, size: 20),
//      t("Throttle:", x: 10, y: 408, align: .Left, size: 20),
//      t("{0:P0}", Vars.Vessel.Throttle, x: 90, y: 440, align: .Right),
//      t("Gear:", x: 635, y: 290, align: .Right, size: 20),
//      t("Brakes:", x: 635, y: 344, align: .Right, size: 20),
//      t("Lights:", x: 635, y: 408, align: .Right, size: 20),
//      ])
//    
//    // Conditional text entries collections for the status displays
//    config.text.appendContentsOf([
//      tOnOff(Vars.Vessel.SAS, x: 43, y: 640-312),
//      tOnOff(Vars.Vessel.RCS, x: 43, y: 640-376),
//      tOnOff(Vars.Vessel.Brakes, x: 640-43, y: 640-(344+32)),
//      tOnOff(Vars.Vessel.Lights, x: 640-43, y: 640-(408+32)),
//      tOnOff(Vars.Vessel.Gear, x: 640-43, y: 640-312, onText: "Down", offText: "Up"),
//      ].flatMap({$0}))
//    
//    // Time to node text
//    config.text.appendContentsOf([
//      t("Burn T:", x: 10, y: 472, size: 20, align: .Left,
//        color: nil,
//        condition: Vars.RPM.Node.Exists),
//      t("{0:METS.f}s", Vars.RPM.Node.BurnTime, x: 10, y: 408+64+32, align: .Left,
//        color: nil,
//        condition: Vars.RPM.Node.Exists),
//      t("Node in T", x: 10, y: 408+64+64, align: .Left, size: 20,
//        color: nil,
//        condition: Vars.RPM.Node.Exists),
//      t("{0,17:MET+yy:ddd:hh:mm:ss.f}", Vars.RPM.Node.TimeTo, x: 10, y: 408+64+64+32, align: .Left,
//        color: nil,
//        condition: Vars.RPM.Node.Exists),
//      t("ΔV", x: 640-10, y: 408+64+64, align: .Right, size: 20,
//        color: nil,
//        condition: Vars.RPM.Node.Exists),
//      t("{0:SIP_6.3}m/s", Vars.RPM.Node.DeltaV, x: 630, y: 408+64+64+32, align: .Right,
//        color: nil,
//        condition: Vars.RPM.Node.Exists)
//      ])
//    
//    super.init(tools: tools, config: config)
//    
//    // Add the navball
//    widgets.append(NavBallWidget(tools: tools,
//      bounds: FixedBounds(centerX: 320, centerY: 338, width: 430, height: 430)))
//    //    widgets.append(FlapsIndicatorWidget(tools: tools,
//    //      bounds: FixedBounds(centerX: 640*13/16, centerY: 640*3/16,
//    //        width: 640*1/8, height: 640*1/8),
//    //      configuration: [:]))
//  }
//}
//

//private func t(string : String, x: Float, y: Float, size: Float = 32, align: NSTextAlignment = .Center, color: Color4? = nil, condition: String? = nil) -> TextEntry {
//  return TextEntry(string: string, size: size, position: Point2D(x,640-y), align: align, variables: [], font: "", condition : condition, color: color)
//}
//
//private func t(string : String, _ variable : String,
//  x: Float, y: Float, size: Float = 32, align: NSTextAlignment = .Center, color: Color4? = nil, condition: String? = nil) -> TextEntry {
//    return TextEntry(string: string, size: size, position: Point2D(x,640-y), align: align, variables: [variable], font: "", condition : condition, color: color)
//    
//}
//
//private func tOnOff(condition: String, x: Float, y: Float, onText: String = "On", offText: String = "Off") -> [TextEntry] {
//  return [
//    TextEntry(string: onText, size: 32, position: Point2D(x, y),
//      align: .Center, variables: [], font: "",
//      condition: condition, color: Color4.Green),
//    TextEntry(string: offText, size: 32, position: Point2D(x, y),
//      align: .Center, variables: [], font: "",
//      condition: "!" + condition, color: nil)
//  ]
//}
