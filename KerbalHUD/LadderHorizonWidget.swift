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
  /// Show the prograde marker?
  var progradeMarker : Bool = true
  var progradeColor : Color4 = Color4(0.84, 0.98, 0, 1)
}

private struct FlightData {
  var Pitch   : Float = 0
  var Roll    : Float = 0
  var AngleOfAttack : Float?
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
  private let progradeMarker : Drawable?
  
  init(tools : DrawingTools, bounds : Bounds) {
    self.drawing = tools
    self.text = tools.textRenderer("Menlo")
    self.bounds = bounds
    
    // Generate a prograde marker if we want one
    if settings.progradeMarker {
      variables.append(Vars.RPM.AngleOfAttack)
      // Construct the prograde marker
      progradeMarker = GenerateProgradeMarker(tools)
    } else {
      progradeMarker = nil
    }
  }
  
  func update(data : [String : JSON]) {
    if let pitch = data[Vars.Flight.Pitch]?.float,
      let roll = data[Vars.Flight.Roll]?.float {
        let aOa = data[Vars.RPM.AngleOfAttack]?.float
        self.data = FlightData(Pitch: pitch, Roll: roll, AngleOfAttack: aOa)
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
    let preScaleFrame = GLKMatrix4Translate(frame, 0, (-data.Pitch/settings.verticalAngleView)*bounds.height, 0)
    // And scale so the height = vertical view
    let heightScale = settings.verticalAngleView / bounds.height
    frame = GLKMatrix4Scale(preScaleFrame, bounds.width, 1/heightScale, 1)
    
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

    // Prograde marker
    if let aoa = data.AngleOfAttack,
       let pgm = progradeMarker
    {
      // Set the color and start building the transformation
      drawing.program.setColor(settings.progradeColor)
      var progradeFrame = preScaleFrame
      // Re-apply the scaling, but in an equal-aspect way
      progradeFrame = GLKMatrix4Scale(progradeFrame, 1/heightScale, 1/heightScale, 1)
      // Move it, in the frame of reference of the angles
      progradeFrame = GLKMatrix4Translate(progradeFrame, 0, data.Pitch-aoa, 0)
      // Scale this to match the frame scale
      // Scale to the right size e.g. 10 degrees tall
      progradeFrame = GLKMatrix4Scale(progradeFrame, 20, 20, 1)
      // And roll backwards...
      progradeFrame = GLKMatrix4Rotate(progradeFrame, -data.Roll*π/180, 0, 0, -1)
      
      drawing.program.setModelView(progradeFrame)
      drawing.Draw(pgm)
    }
    
    // Remove the stencil constraints
    drawing.UnconstrainDrawing()
  }
}


private func GenerateProgradeMarker(tools: DrawingTools, size : GLfloat = 1) -> Drawable {
  let scale = size / 64.0
  var tris = GenerateCircleTriangles(11.0 * scale, w: 4.0*scale)
  tris.appendContentsOf(GenerateBoxTriangles(-30*scale, bottom: -1*scale, right: -14*scale, top: 1*scale))
  tris.appendContentsOf(GenerateBoxTriangles(-1*scale, bottom: 14*scale, right: 1*scale, top: 30*scale))
  tris.appendContentsOf(GenerateBoxTriangles(14*scale, bottom: -1*scale, right: 30*scale, top: 1*scale))
  
  return tools.LoadTriangles(tris)
}