//
//  NavUtilities.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 15/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

class HSIIndicator {
  var variables : [String] = []
  
  var screenWidth : Float = 1
  var screenHeight : Float = 1
  
  let drawing : DrawingTools
  
  init(tools : DrawingTools) {
    drawing = tools
  }
  
  func update(variables : [String: JSON]) {
  
  }
  
  func draw() {
  
  }
}