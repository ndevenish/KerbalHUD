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
  /// Draw a line with thickness on the metered edge...
  var markerEdgeLineThickness : Float = 0
  
  init(variable: String, scale: ScaledBarScale, ticks: TickDirection, range: Float,
    maxValue: Float? = nil, minValue: Float? = nil, color: Color4? = nil, markerLine : Float = 0)
  {
    self.variable = variable
    self.type = scale
    self.direction = ticks
    self.visibleRange = range
    self.maxValue = maxValue
    self.minValue = minValue
    self.foregroundColor = color
    self.markerEdgeLineThickness = markerLine
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
  
  /// Where the axis line begins
  private(set) var axisOrigin : GLKVector2
  /// The direction of the axis line, increasing. Length of the axis.
  private(set) var axisVec : GLKVector2
  /// The pointing direction of the ticks
  private(set) var tickVec : GLKVector2
  
  init(tools : DrawingTools, bounds : Bounds, config : ScaledBarSettings) {
    self.drawing = tools
    self.bounds = bounds
    self.config = config
    self.text = tools.defaultTextRenderer
    self.variables = [config.variable]
    
    // Handle the vector calculations now
    switch config.direction {
    case .Left:
      axisOrigin = GLKVector2(x: bounds.right, y: bounds.bottom)
      axisVec    = GLKVector2(x: 0, y: bounds.height)
      tickVec    = GLKVector2(x: -1, y: 0)
    case .Right:
      axisOrigin = GLKVector2(x: bounds.left, y: bounds.bottom)
      axisVec    = GLKVector2(x: 0, y: bounds.height)
      tickVec    = GLKVector2(x: 1, y: 0)
    case .Up:
      axisOrigin = GLKVector2(x: bounds.left, y: bounds.bottom)
      axisVec    = GLKVector2(x: bounds.width, y: 0)
      tickVec    = GLKVector2(x: 0, y: 1)
    case .Down:
      axisOrigin = GLKVector2(x: bounds.left, y: bounds.top)
      axisVec    = GLKVector2(x: bounds.width, y: 0)
      tickVec    = GLKVector2(x: 0, y: -1)
    }
  }
  
  func update(data : [String : JSON]) {
    if let varn = data[config.variable]?.float {
      self.data = varn
    } else {
      self.data = nil
    }
  }
  
  func drawDecorations(transform : (Float) -> Float) {
    
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
      let realVal = wrapToValueRange(fromLin(Float(value)))
      drawMajorMarker(realVal, linearPosition: linPos)
      
      // Do minor markers, only for the but-final entries
      if value < markerRange.max {
        let minorValue : Float
        if isLog {
          minorValue = toLin(fromLin(Float(value+(value < 0 ? 0 : majorMarkerStep))) * minorMarkerStep)
        } else {
          minorValue = Float(value) + Float(majorMarkerStep) * minorMarkerStep
        }
        // Now, can draw a minor marker at minorValue, with text fromLin(minorValue)
        let minorRealVal = wrapToValueRange(fromLin(Float(minorValue)))

        let minorLinPos = (Float(minorValue)-linearRange.min)/(linearRange.max-linearRange.min)
        drawMinorMarker(minorRealVal, linearPosition: minorLinPos)
//        print("Minor marker at ", fromLin(minorValue))
      }
    }
    
    // Do any subclass entries
    // Build a function to convert a data value into a linear position
    let dataToDisplayFraction = { (val : Float) -> Float in
      return (toLin(val)-linearRange.min)/(linearRange.max-linearRange.min)
    }
    drawDecorations(dataToDisplayFraction)
    
    
    // Draw the marker edge
    if config.markerEdgeLineThickness > 0 {
      let scale = config.direction == .Left || config.direction == .Right ? drawing.scaleToPoints.x : drawing.scaleToPoints.y
      let w = config.markerEdgeLineThickness / scale

      let start = axisOrigin + tickVec*w/2
      let end = axisOrigin + axisVec + tickVec*w/2
      drawing.DrawLine(from: (x: start.x, y: start.y),
                         to: (x: end.x, y: end.y),
                      width: w)
    }
    
    drawing.UnconstrainDrawing()
  }
  
  private func wrapToValueRange(var value : Float) -> Float {
    guard let minV = config.minValue,
          let maxV = config.maxValue
          where config.type == .LinearWrapped else {
        return value
    }
    // If wrapping, then handle this
    while value < minV {
      value += maxV-minV
    }
    while value >= maxV {
      value -= maxV-minV
    }
    return value
  }
  
  func drawMinorMarker(dataValue : Float, linearPosition : Float) {
    let mL : Float = 8 / drawing.scaleToPoints.x // MarkerLength
    var str = ""
    if config.type == .PseudoLogarithmic {
      if abs(dataValue) < 1 {
        str = String(format: "%.1f", dataValue)
      } else {
        str = String(format: "%.0f", dataValue)
      }
    }
    drawMarker(linearPosition, length: mL, markText: str)
  }
  func drawMajorMarker(dataValue : Float, linearPosition : Float) {
    let mL : Float = 16 / drawing.scaleToPoints.x // MarkerLength
    let str = String(format: "%.0f", dataValue)
    drawMarker(linearPosition, length: mL, markText: str)
  }

  
  /// Abstracts out the concept of bar direction
  func drawMarker(linearPosition : Float, length : Float, markText : String) {
    let pAP : GLfloat
    let horizontal = (config.direction == .Left || config.direction == .Right)
    // Calculate the position along the primary axis
    if horizontal {
      pAP = bounds.bottom + bounds.height*linearPosition
    } else {
      pAP = bounds.left + bounds.width*linearPosition
    }
    let mL = length
    let mW : Float = 2 / drawing.scaleToPoints.x
    let textSize : Float = 16 / drawing.scaleToPoints.y
    let textOffset : Float = length + 2/drawing.scaleToPoints.x
//    let str = String(format: "%.0f", dataValue)
    switch config.direction {
    case .Left:
      drawing.DrawLine(from: (bounds.right, pAP), to: (bounds.right-mL, pAP), width: mW)
      text.draw(markText, size: textSize, position: (x: bounds.right-textOffset, y: pAP), align: .Right)
    case .Right:
      drawing.DrawLine(from: (bounds.left, pAP), to: (bounds.left+mL, pAP), width: mW)
      text.draw(markText, size: textSize, position: (x: bounds.left+textOffset, y: pAP), align: .Left)
    case .Up:
      drawing.DrawLine(from: (pAP, bounds.bottom), to: (pAP, bounds.bottom+mL), width: mW)
      text.draw(markText, size: textSize, position: (x: pAP, y: bounds.bottom+textOffset+textSize/2), align: .Center)
    case .Down:
      drawing.DrawLine(from: (pAP, bounds.top), to: (pAP, bounds.top-mL), width: mW)
      text.draw(markText, size: textSize, position: (x: pAP, y: bounds.top-textOffset-textSize/2), align: .Center)
    }
  }
}

/// A specialised subclass of ScaledBar that shows heading and sideslip
class HeadingBarWidget : ScaledBarWidget {
  
  private(set) var sideSlip : Float? = nil
  private var prograde : Drawable?
  
  override init(tools: DrawingTools, bounds: Bounds, var config: ScaledBarSettings) {
    config.variable = Vars.Flight.Heading
    super.init(tools: tools, bounds: bounds, config: config)
    self.variables = [Vars.Flight.Heading, Vars.Aero.Sideslip]
  }
  
  override func update(data: [String : JSON]) {
    super.update(data)
    if let ss = data[Vars.Aero.Sideslip]?.float {
      sideSlip = ss
    }
  }
  
  override func drawDecorations(transform: (Float) -> Float) {
    if let heading = data,
       let slip = sideSlip {
        let progradeSize = 32/drawing.scaleToPoints.x
        if prograde == nil {
          prograde = GenerateProgradeMarker(drawing, size: progradeSize)
        }
        let angle = heading - slip
        let position = transform(angle)
        let point = axisOrigin + position * axisVec
                               + progradeSize/2 * tickVec * 0.8
        drawing.program.setModelView(GLKMatrix4MakeTranslation(point.x, point.y, 0))
        drawing.program.setColor(Color4(0.84, 0.98, 0, 1))
        drawing.Draw(prograde!)
    }
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