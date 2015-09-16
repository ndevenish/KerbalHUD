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
  var condition : String? = nil
  var color : Color4? = nil
}

struct InstrumentConfiguration {
  var size : Size2D<Float> = Size2D(w: 640, h: 640)
  var overlay : InstrumentOverlay? = nil
  var text : [TextEntry] = []
  var textColor : Color4 = Color4.White
}


class LayeredInstrument : Instrument {
  var screenSize : Size2D<Float>
  let drawing : DrawingTools
  let config : InstrumentConfiguration
  let defaultText : TextRenderer
  
  var dataStore : IKerbalDataStore? = nil
  let overlayTexture : Texture?
  var allVariables : Set<String> = Set()
  var varValues : [String : Any] = [:]

  var widgets : [Widget] = []
  
  struct ProcessedText {
    let entry : TextEntry
    let expression : BooleanExpression?
  }
  var textEntries : [ProcessedText]
  
  init(tools : DrawingTools, config : InstrumentConfiguration) {
    drawing = tools
    self.defaultText = drawing.textRenderer("Menlo")
    self.config = config
    self.screenSize = config.size
    
    // Build the text expressions
    var parsedText : [ProcessedText] = []
    for entry in config.text {
      if let condition = entry.condition {
        try! parsedText.append(ProcessedText(entry: entry,
          expression: ExpressionParser.parseBooleanExpression(
            expression: condition)))
      } else {
        parsedText.append(ProcessedText(entry: entry, expression: nil))
      }
    }
    textEntries = parsedText
    
    // Render the overlays to a texture
    if let overlayFile = config.overlay as? SVGOverlay {
      let svg = SVGImage(withContentsOfFile: overlayFile.url)
      let minScreenSize = Float(min(tools.screenSizePhysical))
      overlayTexture = svg.renderToTexture(Size2D(w: minScreenSize*self.screenSize.aspect, h: minScreenSize))
    } else {
      overlayTexture = nil
    }
  }
  
  func connect(to : IKerbalDataStore) {
    allVariables = Set(config.text.flatMap { $0.variables })
      .union(widgets.flatMap({$0.variables}))
      .union(textEntries.flatMap({$0.entry.variables}))
      .union(textEntries.flatMap({$0.expression?.variables ?? []}))
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
    guard let texture = overlayTexture else {
      return
    }
    drawing.bind(texture)
    drawing.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    drawing.DrawTexturedSquare(0, bottom: 0, right: screenSize.w, top: screenSize.h)
  }
  
  func drawText() {
    let dr = (defaultText as! AtlasTextRenderer).createDeferredRenderer()
    
    for fullEntry in self.textEntries {
      if let condition = fullEntry.expression {
        do {
          if !(try condition.evaluate(varValues)) {
            continue
          }
        } catch {
          continue
        }
      }
      let entry = fullEntry.entry
      let varEntries = entry.variables.map { (varValues[$0] ?? 0) as Any }
      let str = try! String.Format(entry.string, argList: varEntries)
//      drawing.program.setColor(entry.color ?? config.textColor)
      dr.draw(str, size: GLfloat(entry.size), position: entry.position, align: entry.align)
    }
    let drawable = dr.generateDrawable()!
    drawing.program.setModelView(GLKMatrix4Identity)
    //print("Drawing text into screensize \(screenSize)")
    drawing.draw(drawable)
  }
}
