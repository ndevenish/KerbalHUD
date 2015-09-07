//
//  LadderHorizonWidget.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import UIKit
import GLKit

private struct LadderHorizonSettings {
  /// Use a 180 or 360 degree horizon
  var use360Horizon : Bool = true
  /// The vertical angle of view for the horizon
  var verticalAngleView : Float = 90
  /// The color of the ladder lines
  var foregroundColor : Color4 = Color4.Green
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
  private let text : TextRenderer
  
  private var data : FlightData?
  private let settings = LadderHorizonSettings()
  
  init(tools : DrawingTools, bounds : Bounds) {
    self.drawing = tools
    self.text = tools.textRenderer("Menlo")
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
    
    // Draw a background
    drawing.program.setModelView(GLKMatrix4Identity)
    
    // Set the drawing color
    drawing.program.setColor(settings.foregroundColor)
    // Because of roll corners, effective size is increased according to aspect
    let pitchHeight = settings.verticalAngleView * sqrt(pow(bounds.size.aspect, 2)+1)
    // Calculate the angle range to draw lines and text for
    let angleRangeFor360 = (min: Int(floor((data.Pitch - pitchHeight/2)/10)*10),
                            max: Int(ceil( (data.Pitch + pitchHeight/2)/10)*10))
    let angleRange = settings.use360Horizon
      ? angleRangeFor360
      : (min: max(angleRangeFor360.min, -90), max: min(angleRangeFor360.max, 90))

    // Build a transform to apply to all drawing to put us in horizon frame
    var frame = GLKMatrix4Identity
    // Put us in the center of the bounds
    frame = GLKMatrix4Translate(frame, bounds.center.x, bounds.center.y, 0)
    // Rotate according to the roll
    frame = GLKMatrix4Rotate(frame, data.Roll*π/180, 0, 0, -1)
    // And translate for pitch in the center
    frame = GLKMatrix4Translate(frame, 0, (-data.Pitch/settings.verticalAngleView)*bounds.height, 0)
    // And scale so the height = vertical view
    let heightScale = settings.verticalAngleView / bounds.height
    frame = GLKMatrix4Scale(frame, bounds.width, 1/heightScale, 1)
    
    // Draw bars every 5 degrees
    let maxBarWidth : Float = 0.4
    for var angle = angleRange.min; angle <= angleRange.max; angle += 5 {
      let width : GLfloat
      if angle % 20 == 0 {
        width = 0.4
      } else if angle % 10 == 0 {
        width = 0.6*0.4
      } else {
        width = 0.2*0.4
      }
      let thickness : GLfloat = angle % 20 == 0 ? 1 : 0.5
      let y = GLfloat(angle)
      drawing.DrawLine(
        from: (-width/2, y), to: (width/2, y),
        width: thickness, transform: frame)
    }

    // Do the text labels
    // Additionally transform the frame so that the axis are equal aspect
//    frame = GLKMatrix4Scale(frame, 1, heightScale*bounds.height, 1)
    let textOffset = (maxBarWidth + 0.05) / 2
    let baseFontSize : Float = 5 // / heightScale
    for var angle = angleRange.min; angle <= angleRange.max; angle += 10 {
      if angle % 20 != 0 {
        continue
      }
      let y = GLfloat(angle)///heightScale
      text.draw(String(format: "%d", angle), size: (angle == 0 ? baseFontSize*1.6 : baseFontSize),
        position: (-textOffset, y), align: .Left, rotation: π, transform: frame)
      text.draw(String(format: "%d", angle), size: (angle == 0 ? baseFontSize*1.6 : baseFontSize),
        position: (textOffset, y), align: .Left, rotation: 0, transform: frame)
    }

    
    
    drawing.UnconstrainDrawing()
  }
}

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
