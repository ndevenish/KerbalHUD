//
//  NavUtilities.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 15/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

class HSIIndicator : RPMInstrument {
  
  struct FlightData {
    var Heading : GLfloat = 0
  }
  
  var overlay : Drawable2D?
  var overlayBackground : Drawable2D?
  var data : FlightData = FlightData()
  
  required init(tools: DrawingTools) {
    let set = RPMPageSettings(textSize: (40,23), screenSize: (640,640),
      backgroundColor: Color4(0,0,0,1), fontName: "Menlo", fontColor: Color4(1,1,1,1))
    super.init(tools: tools, settings: set)
    variables = ["n.heading"]
    
    let d : GLfloat = 0.8284271247461902
    // Inner loop
    let overlayBase : [Point2D] = [(128,70), (128,113), (50, 191), (50, 452), (128, 530), (128, 574),
      (306, 574), (319, 561), (319, 471), (321, 471), (321, 561), (334,574),
      (510, 574), (510, 530), (588, 452), (588, 70),
      (336, 70), (320, 86), (304, 70), (128,70),
      // move to outer edge (rem (590, 191+d),  from second to last on next line)
      (128,68), (640, 68), (640, 70), (590, 70), (590, 452+d),
      (512, 530+d), (512, 574), (640, 574), (640, 576), (0, 576), (0, 574),
      (126, 574), (126, 530+d), (48, 452+d), (48, 191-d), (126, 113-d), (126, 70),
      (0, 70), (0, 68), (128, 68)]
    overlay = tools.Load2DPolygon(overlayBase)

    // Do the overlay background separately
    let overlayBackgroundPts : [Point2D] = [
      (128,70), (128,113), (50, 191), (50, 452), (128, 530), (128, 574),
      (510, 574), (510, 530), (588, 452), (588, 70), (128,70),
      (0,0), (640,0), (640,640), (0, 640), (0,0) ]
    overlayBackground = tools.Load2DPolygon(overlayBackgroundPts)
  }
  
  override func update(variables: [String : JSON]) {
    var newData = FlightData()
    newData.Heading = variables["n.heading"]?.floatValue ?? 0
    data = newData
  }
  
  override func draw() {
    drawing.program.setColor(red: 1,green: 1,blue: 1)
    drawCompass(data.Heading)
    
    drawing.program.setModelView(GLKMatrix4Identity)
    drawing.program.setColor(red: 16.0/255,green: 16.0/255,blue: 16.0/255)
    drawing.Draw(overlayBackground!)
    drawing.program.setColor(red: 1,green: 1,blue: 1)
    drawing.Draw(overlay!)
  }
  
  func drawCompass(heading : GLfloat) {
    let inner : GLfloat = 356.0/2
    var offset = GLKMatrix4Identity
    offset = GLKMatrix4Translate(offset, 320, 320, 0)
    offset = GLKMatrix4Rotate(offset, heading*π/180, 0, 0, 1)

    for var angle = 0; angle < 360; angle += 5 {
      let rad = GLfloat(angle) * π/180
      let length : GLfloat = angle % 90 == 0 ? 16 : (angle % 10 == 0 ? 25 : 20)
      let width : GLfloat = angle % 30 == 0 ? 4 : 3
      let outer = inner+length
      drawing.DrawLine((inner*sin(rad), inner*cos(rad)) , to: (outer*sin(rad), outer*cos(rad)), width: width, transform: offset)
    }
    
    // Draw text
    for var angle = 0; angle < 36; angle += 3 {
      let txt : String
      switch (angle) {
      case 0:
        txt = "N"
      case 9:
        txt = "E"
      case 18:
        txt = "S"
      case 27:
        txt = "W"
      default:
        txt = String(angle)
      }
      let rad = GLfloat(angle)*10*π/180
      let transform = GLKMatrix4Rotate(offset, rad, 0, 0, -1)
      text.draw(txt, size: 32, position: (0, inner + 25 + 16), align: .Center, rotation: 0, transform: transform)
    }
  }
}