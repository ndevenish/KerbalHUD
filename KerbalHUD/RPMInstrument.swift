//
//  RPMPage.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 28/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

struct RPMPageSettings
{
  var textSize : (width: GLfloat, height: GLfloat) = (32, 8)
  var screenSize = Size2D<Float>(w: 512, h: 256)
  
  var backgroundColor : Color4 = Color4.Black
  var fontName : String = "Menlo"
  var fontColor : Color4 = Color4.White
}

class RPMInstrument : Instrument
{
  var drawing : DrawingTools
  var text : TextRenderer
  
  var dataProvider : IKerbalDataStore? = nil
  var screenSize : Size2D<Float> { return settings.screenSize }

  private var _settings : RPMPageSettings
  
  var settings : RPMPageSettings {
    get { return _settings }
    set {
      _settings = newValue
      // If the font changed, reload the font object
      if _settings.fontName != text.fontName {
        text = drawing.textRenderer(_settings.fontName)
      }
    }
  }

  
  /// Start communicating with the kerbal data store
  func connect(to : IKerbalDataStore) {
    dataProvider = to
  }
  /// Stop communicating with the kerbal data store
  func disconnect(from : IKerbalDataStore) {
    dataProvider = nil
  }

  
  convenience required init(tools: DrawingTools) {
    self.init(tools: tools, settings: RPMPageSettings())
  }
  
  init(tools : DrawingTools, settings: RPMPageSettings)
  {
    self.drawing = tools
    self._settings = settings
    self.text = tools.textRenderer(_settings.fontName)
  }
  
  func update() {
    
  }
  
  func draw() {
    
  }
}


