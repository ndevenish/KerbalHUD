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

  var overlay : Drawable2D?
  
  required init(tools: DrawingTools) {
    let set = RPMPageSettings(textSize: (40,23), screenSize: (640,640),
      backgroundColor: Color4(0,0,0,1), fontName: "Menlo", fontColor: Color4(1,1,1,1))
    super.init(tools: tools, settings: set)
    
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

    
    tris = drawing.decomposeLog.map { drawing.LoadTriangles([$0])! }
    
  }
  
  var tris : [Drawable2D] = []
  var frameStep = 0
  var interm = 0
  
  override func draw() {
    drawing.program.setColor(red: 1,green: 1,blue: 1)
    drawing.program.setModelView(GLKMatrix4Identity)
    drawing.Draw(overlay!)
//    interm += 1
//    if interm % 10 == 0 {
//      frameStep += 1
//      print ("Showing step \(frameStep%drawing.decomposeLog.count)")
//    }
//    for i in 0...(frameStep%drawing.decomposeLog.count) {
//      drawing.Draw(tris[i])
//    }
//    drawing.drawText(String(frameStep%drawing.decomposeLog.count), size: 30, position: (0, 680))
    
    
  }
}