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
  var size : Int
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
  let allVariables : Set<String>
  var varValues : [String : AnyObject] = [:]

  
  init(tools : DrawingTools, config : InstrumentConfiguration) {
    drawing = tools
    self.defaultText = drawing.textRenderer("Menlo")
    self.config = config
    self.screenSize = config.size
    
    // Render the overlays to a texture
    let svg = SVGImage(withContentsOfFile: (config.overlay as! SVGOverlay).url)
    let minScreenSize = Float(min(tools.screenSize))
    overlayTexture = svg.renderToTexture(Size2D(w: minScreenSize*self.screenSize.aspect, h: minScreenSize))
    
    // Gather all of the variable names for subscription
    allVariables = Set(config.text.flatMap { $0.variables })
  }
  
  func connect(to : IKerbalDataStore) {
    dataStore = to
    to.subscribe(Array(allVariables))
//    let x = to["some"].
    
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
//      if let data = data[varname]?.type
      if let val = data[varname] {
        switch val.type {
        case .String:
          varValues[varname] = val.stringValue
        case .Number:
          varValues[varname] = NSNumber(double: val.doubleValue)
//          if Double(val.intValue) == val.doubleValue {
//            varValues[varname] = val.intValue
//          } else {
//            varValues[varname] = val.doubleValue
//          }
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
//      public enum Type :Int{
//        
//        case Number
//        case String
//        case Bool
//        case Array
//        case Dictionary
//        case Null
//        case Unknown
//      }
//      switch data[varname]?.type {
//      }
//      varValues[varname] = data[varname]?.rawValue
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

private func t(string : String, x: Float, y: Float) -> TextEntry {
  return TextEntry(string: string, size: 15, position: Point2D(x,y), align: .Center, variables: [], font: "")
}

private func t(string : String, _ variable : String, x: Float, y: Float) -> TextEntry {
  return TextEntry(string: string, size: 32, position: Point2D(x,640-y), align: .Center, variables: [variable], font: "")
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
    
    config.text = [
      t("Altitude",     x: 83,     y: 591),
      t("SRF.SPEED",    x: 640-83, y: 591),
      t("ORB.VELOCITY", x: 83,     y: 554),
      t("ACCEL.",       x: 640-83, y: 554),
      t("MODE",         x: 54,     y: 489),
      t("ROLL",         x: 36,     y: 434),
      t("PITCH",        x: 599,    y: 434),
      t("RADAR ALTITUDE", x: 104,  y: 47 ),
      t("HOR.SPEED",    x: 320,    y: 47 ),
      t("VERT.SPEED",   x: 534,    y: 47 ),
    ]
    config.text.appendContentsOf([
      t("%03.1f°", Vars.Flight.Roll, x: 67, y: 240),
      t("%03.1f°", Vars.Flight.Pitch, x: 573, y: 240),
      t("%03.1f°", Vars.Flight.Heading, x: 320, y: 80),
      
      t("{0:SIP_6.1}m", Vars.Vessel.Altitude, x: 83.5, y: 22),
      t("{0,4:SIP4}m/s", "v.surfaceSpeed", x: 556.5, y: 22),
      
      t("{0:SIP_6.1}m", "v.orbitalVelocity", x: 83.5, y: 115),
      t("{0:SIP4}m/s", "rpm.ACCEL", x: 556.5, y: 115),
  //    drawText(data.SpeedDisplay.rawValue, x: 55, y: 177),
      
      t("{0:SIP_6.3}m", "rpm.RADARALTOCEAN", x: 95, y: 623),
      t("{0:SIP_6.3}m", "rpm.HORZVELOCITY", x: 320, y: 623),
      t("{0:SIP_6.3}m", "v.verticalSpeed", x: 640-95, y: 623)
    ])

    
    super.init(tools: tools, config: config)
  }
}