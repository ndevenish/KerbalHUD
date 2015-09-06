//
//  LayeredInstrument.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 05/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import UIKit
import GLKit

protocol InstrumentOverlay {
  
}

struct SVGOverlay : InstrumentOverlay {
  var url : NSURL
}

struct TextEntry {
  var string : String
  var size : Float
  var position : Point2D
  var align : NSTextAlignment
  var variables : [String]
  var font : String
}

struct InstrumentConfiguration {
  var size : Size2D<Float> = Size2D(w: 640, h: 640)
  var overlay : InstrumentOverlay? = nil
  var text : [TextEntry] = []
}


class LayeredInstrument : Instrument {
  var screenSize : Size2D<Float>
  let drawing : DrawingTools
  let config : InstrumentConfiguration
  let defaultText : TextRenderer
  
  var dataStore : IKerbalDataStore? = nil
  let overlayTexture : Texture
  var allVariables : Set<String> = Set()
  var varValues : [String : AnyObject] = [:]

  var widgets : [Widget] = []
  
  init(tools : DrawingTools, config : InstrumentConfiguration) {
    drawing = tools
    self.defaultText = drawing.textRenderer("Menlo")
    self.config = config
    self.screenSize = config.size
    
    // Render the overlays to a texture
    let svg = SVGImage(withContentsOfFile: (config.overlay as! SVGOverlay).url)
    let minScreenSize = Float(min(tools.screenSize))
    overlayTexture = svg.renderToTexture(Size2D(w: minScreenSize*self.screenSize.aspect, h: minScreenSize))
  }
  
  func connect(to : IKerbalDataStore) {
    allVariables = Set(config.text.flatMap { $0.variables })
      .union(widgets.flatMap({$0.variables}))
    dataStore = to
    to.subscribe(Array(allVariables))
  }
  
  func disconnect(from : IKerbalDataStore) {
    from.unsubscribe(Array(allVariables))
  }
  
  func update() {
    guard let data = dataStore else {
      return
    }
    // Read all the required variables out of the
    for varname in allVariables {
      // Read the "Most natural" form out of the JSON
      if let val = data[varname] {
        switch val.type {
        case .String:
          varValues[varname] = val.stringValue
        case .Number:
          varValues[varname] = NSNumber(double: val.doubleValue)
        case .Bool:
          varValues[varname] = val.boolValue
        case .Null:
          varValues[varname] = nil
        default:
          fatalError()
        }
      } else {
        varValues[varname] = nil
      }
    }
    // Read the variables for each widget
    for widget in widgets {
      var wVars : [String : JSON] = [:]
      for varname in widget.variables {
        if let res = data[varname] {
          wVars[varname] = res
        }
      }
      widget.update(wVars)
    }
  }
  
  func draw() {
//    drawing.bind(VertexArray.Empty)
    
    drawing.program.setColor(Color4.White)
    drawing.program.setModelView(GLKMatrix4Identity)
    drawWidgets()
    drawOverlay()
    drawText()
  }
  
  func drawWidgets() {
    for widget in widgets {
      widget.draw()
    }
  }
  
  func drawOverlay() {
    drawing.bind(overlayTexture)
    drawing.program.setUseTexture(true)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.DrawTexturedSquare(0, bottom: 0, right: screenSize.w, top: screenSize.h)
  }
  
  func drawText() {
    for entry in self.config.text {
      let varEntries = entry.variables.map { (varValues[$0] ?? 0) as Any }
      let str = try! String.Format(entry.string, argList: varEntries)
      defaultText.draw(str, size: GLfloat(entry.size), position: entry.position, align: entry.align)
    }
  }
}

private func t(string : String, x: Float, y: Float, size: Float = 32, align: NSTextAlignment = .Center) -> TextEntry {
  return TextEntry(string: string, size: size, position: Point2D(x,640-y), align: align, variables: [], font: "")
}

private func t(string : String, _ variable : String,
  x: Float, y: Float, size: Float = 32, align: NSTextAlignment = .Center) -> TextEntry {
  return TextEntry(string: string, size: size, position: Point2D(x,640-y), align: align, variables: [variable], font: "")
}


struct FlightDataVarNames {
  let Roll = "n.roll"
  let Pitch = "n.pitch"
  let Heading = "n.heading"
}

struct VesselDataVarNames {
  let SAS    = "v.sasValue"
  let RCS    = "v.rcsValue"
  let Lights = "v.lightValue"
  let Brakes = "v.brakeValue"
  let Gear   = "v.gearValue"
  
  let Altitude = "v.altitude"
  let Throttle = "f.throttle"
}

struct Vars {
  static let Flight = FlightDataVarNames()
  static let Vessel = VesselDataVarNames()
}


class NewNavBall : LayeredInstrument {
  init(tools : DrawingTools) {
    var config = InstrumentConfiguration()
    config.overlay = SVGOverlay(url: NSBundle.mainBundle().URLForResource("RPM_NavBall_Overlay", withExtension: "svg")!)
    
    // Fixed text
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
      t("{0:ORB;TGT;SRF}", "rpm.SPEEDDISPLAYMODE", x: 55, y: 177),
      
      
      t("{0:SIP_6.3}m", "rpm.RADARALTOCEAN", x: 95, y: 623),
      t("{0:SIP_6.3}m", "rpm.HORZVELOCITY", x: 320, y: 623),
      t("{0:SIP_6.3}m", "v.verticalSpeed", x: 640-95, y: 623)
    ])
    
    config.text.appendContentsOf([
      t("SAS:", x: 10, y: 280, align: .Left, size: 20),
      t("RCS:", x: 10, y: 344, align: .Left, size: 20),
      t("Throttle:", x: 10, y: 408, align: .Left, size: 20),
      t("{0:P0}", Vars.Vessel.Throttle, x: 90, y: 440, align: .Right),
      t("Gear:", x: 635, y: 290, align: .Right, size: 20),
      t("Brakes:", x: 635, y: 344, align: .Right, size: 20),
      t("Lights:", x: 635, y: 408, align: .Right, size: 20),
    ])
    
//    drawOnOff(data.SAS, x: 43, y: 312)
//    drawOnOff(data.RCS, x: 43, y: 344+32)
//    drawOnOff(data.Gear, x: 640-43, y: 312, onText: "Down", offText: "Up")
//    drawOnOff(data.Brakes, x: 640-43, y: 344+32)
//    drawOnOff(data.Lights, x: 640-43, y: 408+32)


//    if data.NodeExists {
//      drawText("Burn T:", x: 10, y: 408+64, align: .Left, size: 20)
//      drawText("{0:METS.f}s", data.NodeBurnTime, x: 10, y: 408+64+32, align: .Left)
//      drawText("Node in T", x: 10, y: 408+64+64, align: .Left, size: 20)
//      drawText("{0,17:MET+yy:ddd:hh:mm:ss.f}", data.NodeTime, x: 10, y: 408+64+64+32, align: .Left)
//      drawText("ΔV", x: 640-10, y: 408+64+64, align: .Right, size: 20)
//      drawText("{0:SIP_6.3}m/s", data.NodeDv, x: 630, y: 408+64+64+32, align: .Right)
//    }

    
    super.init(tools: tools, config: config)
    
    // Add the navball
    widgets.append(NavBallWidget(tools: tools,
      bounds: FixedBounds(centerX: 320, centerY: 338, width: 430, height: 430)))
  }
}