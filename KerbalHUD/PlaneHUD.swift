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
    glPushGroupMarkerEXT(0, "Creating Instrument: Plane HUD")
    defer { glPopGroupMarkerEXT() }
    
    var config = InstrumentConfiguration()
    config.size = Size2D(w: 1, h: 1)
    config.overlay = SVGOverlay(url: NSBundle.mainBundle().URLForResource("PlaneHUD_Overlay", withExtension: "svg")!)
    config.textColor = Color4.Green
    // Now do the text
    config.text.appendContentsOf([
      t("PRS: {0,7:0,.000}kPa",  "v.dynamicPressure", x: 1, y: 1, align: .Left),
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
      t("THR: {0,6:00.0%} [{1,6:00.0%}]", [Vars.Vessel.Throttle, "rpm.EFFECTIVETHROTTLE"], exactX: 1.0/40, exactY: 1 - (19.5*1.0/20), align: .Left),
      
      t("P: {0,6:00.0}° R: {1,6:000.0}°", [Vars.Flight.Pitch, Vars.Flight.Roll], exactX: 0.5, exactY: 0.25-0.5/2/20, align: .Center, condition: nil, size: 0.5)
      ])
    
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

    widgets.append(LadderHorizonWidget(tools: tools,
      bounds: FixedBounds(left: 0.25, bottom: 0.25, right: 0.75, top: 0.75)))
    
    widgets.append(ScaledBarWidget(tools: tools,
      bounds: FixedBounds(left: 0, bottom: 0.25, right: 0.25, top: 0.75),
      config: deltaVzSettings ))
    widgets.append(ScaledBarWidget(tools: tools,
      bounds: FixedBounds(left: 0.75, bottom: 0.25, right: 1, top: 0.75),
      config: altSettings ))
    widgets.append(HeadingBarWidget(tools: tools,
      bounds: FixedBounds(left: 0.25, bottom: 0.75, right: 0.75, top: 1.0),
      config: headingSettings ))
    
    widgets.append(FlapsIndicatorWidget(tools: tools,
      bounds: FixedBounds(centerX: 7/8, centerY: 1/8,
        width: 0.2, height: 0.15),
      configuration: ["fontcolor": Color4.Green]))
  }
}
