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
      varValues[varname] = data[varname]?.rawValue
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
      let varEntries = entry.variables.map { varValues[$0] as Any }
      let str = try! String.Format(entry.string, argList: varEntries)
      defaultText.draw(str, size: GLfloat(entry.size), position: entry.position, align: entry.align)
    }
  }
}

class NewNavBall : LayeredInstrument {
  init(tools : DrawingTools) {
    var config = InstrumentConfiguration()
    config.overlay = SVGOverlay(url: NSBundle.mainBundle().URLForResource("RPM_NavBall_Overlay", withExtension: "svg")!)
    
    super.init(tools: tools, config: config)
  }
}