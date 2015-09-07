//
//  VerticalScaleBar.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

struct ScaledBarSettings {
  /// What variable is being tracked
  var variable : String
  /// Is the bar a pseudo-logarithmic display?
  var type : ScaledBarScale
  /// Which direction the ticks for the display are heading
  var direction : TickDirection
  /// How much of the range should be visible at once?
  var visibleRange : Float = 100
  /// The maximum value to display on the scale
  var maxValue : Float?
  /// The minimum value to display on the scale
  var minValue : Float?
  /// The primary display color
  var foregroundColor : Color4?
  
  init(variable: String, scale: ScaledBarScale, ticks: TickDirection, range: Float,
    maxValue: Float? = nil, minValue: Float? = nil, color: Color4? = nil)
  {
    self.variable = variable
    self.type = scale
    self.direction = ticks
    self.visibleRange = range
    self.maxValue = maxValue
    self.minValue = minValue
    self.foregroundColor = color
  }
  
  /// Which orientation the bar is drawn in
  enum TickDirection {
    case Left
    case Right
    case Up
    case Down
  }
  // The scale type
  enum ScaledBarScale {
    case Linear
    case LinearWrapped
    case PseudoLogarithmic
  }
}

class ScaledBarWidget : Widget {
  private(set) var bounds : Bounds
  private(set) var variables : [String]
  
  private let drawing : DrawingTools
  private let config : ScaledBarSettings
  private let text : TextRenderer
  
  private var data : Float?
  
  init(tools : DrawingTools, bounds : Bounds, config : ScaledBarSettings) {
    self.drawing = tools
    self.bounds = bounds
    self.config = config
    self.text = tools.defaultTextRenderer
    
    self.variables = [config.variable]
  }
  
  func update(data : [String : JSON]) {
    if let varn = data[config.variable]?.float {
      self.data = varn
    } else {
      self.data = nil
    }
  }
  
  func draw() {
    guard let data = self.data else {
      return
    }
    drawing.ConstrainDrawing(bounds)
    
    let isLog = config.type == .PseudoLogarithmic
    let toLin : (Float) -> Float = isLog ? { PseudoLog10($0) } : { $0 }
    let fromLin : (Float) -> Float = isLog ? { InversePseudoLog10($0) } : { $0 }
      
    if let color = config.foregroundColor {
      drawing.program.setColor(color)
    }
    
    // Do as many calculations independent of orientation as we can
    
    // Calculate the visible range in linear space, relative to the data point
    let linearRange : (min: Float, max: Float)
        = (toLin(data)-toLin(config.visibleRange)/2, toLin(data)+toLin(config.visibleRange)/2)

    
    // And now, calculate the range in data-space
    let valueRange : (min: Float, max: Float) =
      (fromLin(linearRange.min), fromLin(linearRange.max))

    // Work out the marker-delimited major marker ranges.
    // Marker placement happens in linear space, at all times.
    // If log,    markers at 1, 2, 3,...
    // If linear, markers at 20, 40, ... minor at 10
    let majorMarkerStep = isLog ? 1 : 20
    let minorMarkerStep : Float = 0.5
    
    let fullMarkerRange = (
      min: Int(floor(toLin(valueRange.min)/Float(majorMarkerStep)))*majorMarkerStep,
      max: Int(ceil(toLin(valueRange.max)/Float(majorMarkerStep)))*majorMarkerStep)

    // Calculate the marker range, taking into account constraints
    let markerRange : (min: Int, max: Int)
    if config.type == .LinearWrapped {
      // If linear wrapped, then we have no constraints for markers, only for
      // what they are labelled with
      markerRange = fullMarkerRange
    } else {
      let linMin = config.minValue == nil ? fullMarkerRange.min : Int(floor(toLin(config.minValue!)))
      let linMax = config.maxValue == nil ? fullMarkerRange.max : Int(ceil(toLin(config.maxValue!)))
      markerRange = (min: max(fullMarkerRange.min, linMin),
                     max: min(fullMarkerRange.max, linMax))
    }
    
    // Now, draw the markers
    for var value = markerRange.min; value <= markerRange.max; value += majorMarkerStep {
      // Now, can draw a major marker at value, with text fromLin(value)
      let linPos = (Float(value)-linearRange.min)/(linearRange.max-linearRange.min)
      drawMajorMarker(fromLin(Float(value)), linearPosition: linPos)
//      print("Major marker at ", fromLin(Float(value)))
      // Do minor markers, only for the but-final entries
      if value < markerRange.max {
        let minorValue : Float
        if isLog {
          minorValue = toLin(fromLin(Float(value+(value < 0 ? 0 : majorMarkerStep))) * minorMarkerStep)
        } else {
          minorValue = Float(value) + Float(majorMarkerStep) * minorMarkerStep
        }
        // Now, can draw a minor marker at minorValue, with text fromLin(minorValue)
        
//        print("Minor marker at ", fromLin(minorValue))
      }
    }
    drawing.UnconstrainDrawing()
  }
  
  /// Abstracts out the concept of bar direction
  func drawMajorMarker(dataValue : Float, linearPosition : Float) {
    let pAP : GLfloat
    let horizontal = (config.direction == .Left || config.direction == .Right)
    // Calculate the position along the primary axis
    if horizontal {
      pAP = bounds.bottom + bounds.height*linearPosition
    } else {
      pAP = bounds.left + bounds.width*linearPosition
    }
    let mL : Float = 16 / drawing.scaleToPoints.x // MarkerLength
    let mW : Float = 2 / drawing.scaleToPoints.x
    let textSize : Float = 16 / drawing.scaleToPoints.y
    let str = String(format: "%.0f", dataValue)
    switch config.direction {
    case .Left:
      drawing.DrawLine(from: (bounds.right, pAP), to: (bounds.right-mL, pAP), width: mW)
      text.draw(str, size: textSize, position: (x: bounds.right-mL*1.5, y: pAP), align: .Right)
    case .Right:
      drawing.DrawLine(from: (bounds.right, pAP), to: (bounds.right+mL, pAP), width: mW)
    case .Up:
      drawing.DrawLine(from: (pAP, bounds.bottom), to: (pAP, bounds.bottom+mL), width: mW)
      text.draw(str, size: textSize, position: (x: pAP, y: bounds.bottom+mL+textSize/2), align: .Center)
    case .Down:
      drawing.DrawLine(from: (pAP, bounds.bottom), to: (pAP, bounds.bottom-mL), width: mW)
    }
  }
  
  func drawMinorMarker(dataValue : Float, linearPosition : Float) {
    
  }

}


func PseudoLog10(x : Float) -> Float
{
  if abs(x) <= 1.0 {
    return x
  }
  return (1.0 + log10(abs(x))) * sign(x)
}

func InversePseudoLog10(x : Float) -> Float
{
  if abs(x) <= 1.0 {
    return x
  }
  return pow(10, abs(x)-1)*sign(x)
}