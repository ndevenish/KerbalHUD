//
//  FlapsIndicator.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

private func generateFoil(drawing : DrawingTools) -> Drawable {
  let c : Float = 1
  let t : Float = 0.15
  
  let numSteps = 20
  var points : [Point2D] = []
  
  for xStep in 0...numSteps {
    let x = 1-cos(Float(xStep)/Float(numSteps) * π/2)
    var y = 0.2969*sqrt(x/c)
    y += (-0.1260)*(x/c)
    y += (-0.3516)*pow(x/c, 2)
    y += 0.2843*pow(x/c, 3)
    y += (-0.1015)*pow(x/c, 4)
    y *= 5 * t * c
    points.append(Point2D(x: x-t, y: xStep == numSteps ? 0 : y))
  }
  // go back around
  points.appendContentsOf(points.dropLast().dropFirst().reverse().map {Point2D(x: $0.x, y: $0.y * -1)})
  return drawing.Load2DPolygon(points)
}

class FlapsIndicatorWidget : Widget {
  var bounds : Bounds
  private(set) var variables : [String] = []
  private var config : [String : Any] = [:]
  private var drawing : DrawingTools
  
  private var flapSetting : Int?
  
  private var text : TextRenderer
  private var fontSize : Float
  private var fontColor : Color4
  
  private var foil : Drawable
  
  init(tools : DrawingTools, bounds : Bounds, configuration : [String : Any])
  {
    self.drawing = tools
    self.bounds = bounds
    self.variables = [Vars.FAR.Flaps]
    self.config = configuration
    
    self.foil = generateFoil(tools)
    if let font = configuration["font"] as? String {
      text = drawing.textRenderer(font)
    } else {
      text = drawing.defaultTextRenderer
    }
    if let fontSize = (configuration["fontsize"] as? DoubleCoercible)?.asDoubleValue {
      self.fontSize = Float(fontSize)
    } else {
      // Work out from the bounds to fill the width
      let numChars = Float(" FLP: X ".characters.count)
      self.fontSize = (self.bounds.width / numChars) / text.aspect
    }

    fontColor = Color4.coerceTo(configuration["fontcolor"]) ?? Color4.White
  }
  
  func update(data  : [String : JSON]) {
    flapSetting = (data[variables.first!] as? IntCoercible)?.asIntValue
  }
  
  func draw() {
    guard let flaps = flapSetting else {
      return
    }
    
    // length 1, 20° == height = 0.35*width
    let foilSweepSize = Size2D<Float>(w: bounds.width, h: bounds.width * 0.35)
    
    let foilPosition = Point2D(
      x: bounds.center.x - foilSweepSize.w/2,
      y: bounds.top - fontSize - 1.25 * foilSweepSize.h/2)
    
    var foilMV = GLKMatrix4MakeTranslation(foilPosition.x, foilPosition.y, 0)
    foilMV = GLKMatrix4Scale(foilMV, foilSweepSize.w, foilSweepSize.h, 0)
    foilMV = GLKMatrix4Translate(foilMV, 0.15-0.5 , 0, 0)
    
    if flaps > 0 {
      drawing.program.setModelView(foilMV)
      drawing.program.setColor(red: 0, green: 0.1, blue: 0)
      drawing.Draw(foil)
    }
    
    foilMV = GLKMatrix4Rotate(foilMV, 20*(GLfloat(flaps)/4) * π/180 , 0, 0, -1)
    drawing.program.setModelView(foilMV)
    if flaps == 0 || flaps == 1 {
      drawing.program.setColor(red: 0, green: 1, blue: 0)
    } else if flaps == 2 {
      drawing.program.setColor(red: 1, green: 1, blue: 0)
    } else {
      drawing.program.setColor(red: 1, green: 0, blue: 0)
    }
    drawing.Draw(foil)
    
    if flaps == 0 {
      foilMV = GLKMatrix4Scale(foilMV, 0.90, 0.90, 0)
      drawing.program.setModelView(foilMV)
      drawing.program.setColor(red: 0, green: 0, blue: 0)
      drawing.Draw(foil)
    }
    
    drawing.program.setColor(fontColor)
    text.draw("FLP: " + (flaps == 0 ? "-" : String(flaps)),
      size: fontSize, position: Point2D(
        x: bounds.left,
        y: bounds.top-fontSize/2), align: .Center)
  }
}