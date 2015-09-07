//
//  LadderHorizonWidget.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

private struct LadderHorizonSettings {
  /// Use a 180 or 360 degree horizon
  var use360Horizon : Bool = true
  /// The vertical angle of view for the horizon
  var verticalAngleView : Float = 90
}
private struct FlightData {
  var Pitch   : Float = 0
  var Roll    : Float = 0
//  var Heading : Float = 0
}

class LadderHorizonWidget : Widget {
  private(set) var bounds : Bounds
  private(set) var variables : [String] = [
    Vars.Flight.Pitch, Vars.Flight.Roll
  ]
  
  private let drawing : DrawingTools

  private var data : FlightData?
  private let settings = LadderHorizonSettings()
  
  init(tools : DrawingTools, bounds : Bounds) {
    self.drawing = tools
    self.bounds = bounds
  }
  
  func update(data : [String : JSON]) {
    if let pitch = data[Vars.Flight.Pitch]?.float,
      let roll = data[Vars.Flight.Roll]?.float {
      self.data = FlightData(Pitch: pitch, Roll: roll)
    } else {
      self.data = nil
    }
  }
  
  func draw() {
    guard let data = self.data else {
      return
    }
    
    // Constrain drawing to the bounds
    drawing.ConstrainDrawing(bounds)
    
    drawing.program.setColor(Color4.Red)
    drawing.DrawSquare(bounds.left, bottom: bounds.bottom, right: bounds.right, top: bounds.top)
    drawing.UnconstrainDrawing()
  }
}
//
//private func drawHorizonView() {
//  let pitch : GLfloat = latestData?.Pitch ?? 0
//  let roll : GLfloat = latestData?.Roll ?? 0
//  
//  drawing.program.setColor(foregroundColor)
//  
//  // Because of roll corners, effective size is increased according to aspect
//  let hScale = horizonScale*sqrt(pow(horizonSize.width/horizonSize.height, 2)+1)
//  
//  var angleRange = (min: Int(floor((pitch - hScale/2)/10)*10),
//    max: Int(ceil( (pitch + hScale/2)/10)*10))
//  // Apply the constrained horizon, if turned on
//  if use360horizon == false {
//    angleRange = (max(angleRange.min, -90), min(angleRange.max, 90))
//  }
//  // Build a transform to apply to all drawing to put us in horizon frame
//  var horzFrame = GLKMatrix4Identity
//  // Put us in the center of the screen
//  horzFrame = GLKMatrix4Translate(horzFrame, page.screenSize.w/2, page.screenSize.h/2, 0)
//  // Rotate according to the roll
//  horzFrame = GLKMatrix4Rotate(horzFrame, roll*π/180, 0, 0, -1)
//  // And translate for pitch in the center
//  horzFrame = GLKMatrix4Translate(horzFrame, 0, (-pitch/horizonScale)*horizonSize.height, 0)
//  
//  
//  for var angle = angleRange.min; angle <= angleRange.max; angle += 5 {
//    // How wide do we draw this bar?
//    let width : GLfloat = angle % 20 == 0 ? 128 : (angle % 10 == 0 ? 74 : 23)
//    let y = horizonSize.height * GLfloat(angle)/horizonScale
//    drawing.DrawLine((-width/2, y), to: (width/2, y), width: (angle % 20 == 0 ? 2 : 1), transform: horzFrame)
//  }
//  // Do the text labels
//  for var angle = angleRange.min; angle <= angleRange.max; angle += 10 {
//    if angle % 20 != 0 {
//      continue
//    }
//    let y = horizonSize.height * GLfloat(angle)/horizonScale
//    text.draw(String(format: "%d", angle), size: (angle == 0 ? 16 : 10),
//      position: (-64-8, y), align: .Left, rotation: π, transform: horzFrame)
//    text.draw(String(format: "%d", angle), size: (angle == 0 ? 16 : 10),
//      position: (64+8, y), align: .Left, rotation: 0, transform: horzFrame)
//  }
//  
//  // Do the prograde marker - position
//  //    horzFrame = GLKMatrix4Translate(horzFrame, 0, latestData?.AngleOfAttack ?? 0, 0)
//  if let data = latestData {
//    horzFrame = GLKMatrix4Translate(horzFrame, 0, horizonSize.height*((data.Pitch-data.AngleOfAttack ?? 0) / horizonScale), 0)
//    // And roll backwards...
//    horzFrame = GLKMatrix4Rotate(horzFrame, -roll*π/180, 0, 0, -1)
//    
//    drawing.program.setModelView(horzFrame)
//    drawing.program.setColor(progradeColor)
//    drawing.Draw(prograde!)
//  }
//}
