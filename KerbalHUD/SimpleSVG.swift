// SimpleSVG Copyright (c) 2015 Nicholas Devenish
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import CoreGraphics
import GLKit

typealias SVGMatrix = GLKMatrix3

enum SVGErrors : ErrorType {
  case NoSuchElement
}

/// The public face of the module. Loads an SVGFile and has options for rendering
public class SVGImage {
  private let svg : SVGContainer
  
  public init(withContentsOfFile file : NSURL) {
    // Read the file
    let data = NSData(contentsOfURL: file)!
    let parser = SVGParser(data: data)
    svg = parser.parse() as! SVGContainer
  }
  
  public func drawToContext(context : CGContextRef, subId: String = "") throws {
    let drawingElement : SVGDrawable
    if subId.isEmpty {
      drawingElement = svg
    } else if let subElem = svg.findWithID(subId) {
      drawingElement = subElem
    } else {
      throw SVGErrors.NoSuchElement
    }
    drawingElement.drawToContext(context)
  }
  
  private func getElement(id: String) throws -> SVGDrawable {
    let drawingElement : SVGDrawable
    if id.isEmpty {
      drawingElement = svg
    } else if let subElem = svg.findWithID(id) {
      drawingElement = subElem
    } else {
      throw SVGErrors.NoSuchElement
    }
    return drawingElement
  }
  
  // Draw an element with a specific ID, aligned and sized to fit a specific context
  public func drawToContextRect(context : CGContextRef, rect: CGRect, subId: String = "") throws {
    let drawingElement = try getElement(subId)

    if rect.minX != 0 || rect.minY != 0 {
      fatalError("Currently incorrect transform with nonzero mins")
    }
    let bounds = drawingElement.boundingBox!
    // Work out position and scale to fit this bounding box inside the specified
    let scale = min(rect.width/bounds.width, rect.height/bounds.height)
    CGContextSaveGState(context)
    CGContextScaleCTM(context, scale, scale)
    let offset = CGPointMake(rect.minX-bounds.minX, rect.minY-bounds.minY)
    CGContextTranslateCTM(context, offset.x, offset.y)
    drawingElement.drawToContext(context)
    CGContextRestoreGState(context)
  }
  
  public func bounds(subId: String = "") throws -> CGRect {
    let drawingElement = try getElement(subId)
    return drawingElement.boundingBox ?? CGRectMake(0, 0, 0, 0)
  }
}

// MARK: Parser Configuration and which entities are handled

/// Which parsers handle different data types
private typealias Converter = (String) -> Any
private let parserMap : [String : Converter] = [
  "<length>": parseLength,
  "<coord>":  parseLength,
  "<paint>":  parsePaint,
  "<path-data>": parsePath,
  "<list-of-points>": parseListOfPoints,
  "<transform>": parseTransform,
]

/// Which attribute names hold which different data types
private let dataTypesForAttributeNames : [String:[String]] = [
  "<paint>":  ["fill", "stroke"],
  "<length>": ["width", "height", "rx", "ry", "r", "stroke-width"],
  "<coord>":  ["x", "y", "cx", "cy", "x1", "y1", "x2", "y2"],
  "<path-data>": ["d"],
  "<transform>": ["transform"],
  "<list-of-points>": ["points"],
]

/// Which SVG entity to create for a particular XML tag name
private let tagCreationMap : [String : () -> SVGElement] = [
  "svg":    { SVGContainer() as SVGElement},
  "g"  :    { SVGGroup() as SVGElement},
  "circle": { Circle() as SVGElement },
  "line":   { Line() as SVGElement },
  "polygon":{ Polygon() as SVGElement },
  "ellipse":{ Ellipse() as SVGElement },
  "rect":   { Rect() as SVGElement },
  "polyline": { PolyLine() as SVGElement },
  "path":   { Path() as SVGElement },
]

/// Get the parser conversion function for a particular element and attribute
private func getParserFor(elem: String, attr : String) -> Converter? {
  for (parsetype, names) in dataTypesForAttributeNames {
    if names.contains(attr) {
      if let fn = parserMap[parsetype] {
        return fn
      }
    }
  }
  return nil
}

// SVG Color names
private let svgColorNames = [
  "red":       "rgb(255, 0, 0)",     "lightgray":            "rgb(211, 211, 211)",
  "tan":       "rgb(210, 180, 140)", "lightgrey":            "rgb(211, 211, 211)",
  "aqua":      "rgb( 0, 255, 255)",  "lightpink":            "rgb(255, 182, 193)",
  "blue":      "rgb( 0, 0, 255)",    "limegreen":            "rgb( 50, 205, 50)",
  "cyan":      "rgb( 0, 255, 255)",  "mintcream":            "rgb(245, 255, 250)",
  "gold":      "rgb(255, 215, 0)",   "mistyrose":            "rgb(255, 228, 225)",
  "gray":      "rgb(128, 128, 128)", "olivedrab":            "rgb(107, 142, 35)",
  "grey":      "rgb(128, 128, 128)", "orangered":            "rgb(255, 69, 0)",
  "lime":      "rgb( 0, 255, 0)",    "palegreen":            "rgb(152, 251, 152)",
  "navy":      "rgb( 0, 0, 128)",    "peachpuff":            "rgb(255, 218, 185)",
  "peru":      "rgb(205, 133, 63)",  "rosybrown":            "rgb(188, 143, 143)",
  "pink":      "rgb(255, 192, 203)", "royalblue":            "rgb( 65, 105, 225)",
  "plum":      "rgb(221, 160, 221)", "slateblue":            "rgb(106, 90, 205)",
  "snow":      "rgb(255, 250, 250)", "slategray":            "rgb(112, 128, 144)",
  "teal":      "rgb( 0, 128, 128)",  "slategrey":            "rgb(112, 128, 144)",
  "azure":     "rgb(240, 255, 255)", "steelblue":            "rgb( 70, 130, 180)",
  "beige":     "rgb(245, 245, 220)", "turquoise":            "rgb( 64, 224, 208)",
  "black":     "rgb( 0, 0, 0)",      "aquamarine":           "rgb(127, 255, 212)",
  "brown":     "rgb(165, 42, 42)",   "blueviolet":           "rgb(138, 43, 226)",
  "coral":     "rgb(255, 127, 80)",  "chartreuse":           "rgb(127, 255, 0)",
  "green":     "rgb( 0, 128, 0)",    "darkorange":           "rgb(255, 140, 0)",
  "ivory":     "rgb(255, 255, 240)", "darkorchid":           "rgb(153, 50, 204)",
  "khaki":     "rgb(240, 230, 140)", "darksalmon":           "rgb(233, 150, 122)",
  "linen":     "rgb(250, 240, 230)", "darkviolet":           "rgb(148, 0, 211)",
  "olive":     "rgb(128, 128, 0)",   "dodgerblue":           "rgb( 30, 144, 255)",
  "wheat":     "rgb(245, 222, 179)", "ghostwhite":           "rgb(248, 248, 255)",
  "white":     "rgb(255, 255, 255)", "lightcoral":           "rgb(240, 128, 128)",
  "bisque":    "rgb(255, 228, 196)", "lightgreen":           "rgb(144, 238, 144)",
  "indigo":    "rgb( 75, 0, 130)",   "mediumblue":           "rgb( 0, 0, 205)",
  "maroon":    "rgb(128, 0, 0)",     "papayawhip":           "rgb(255, 239, 213)",
  "orange":    "rgb(255, 165, 0)",   "powderblue":           "rgb(176, 224, 230)",
  "orchid":    "rgb(218, 112, 214)", "sandybrown":           "rgb(244, 164, 96)",
  "purple":    "rgb(128, 0, 128)",   "whitesmoke":           "rgb(245, 245, 245)",
  "salmon":    "rgb(250, 128, 114)", "darkmagenta":          "rgb(139, 0, 139)",
  "sienna":    "rgb(160, 82, 45)",   "deepskyblue":          "rgb( 0, 191, 255)",
  "silver":    "rgb(192, 192, 192)", "floralwhite":          "rgb(255, 250, 240)",
  "tomato":    "rgb(255, 99, 71)",   "forestgreen":          "rgb( 34, 139, 34)",
  "violet":    "rgb(238, 130, 238)", "greenyellow":          "rgb(173, 255, 47)",
  "yellow":    "rgb(255, 255, 0)",   "lightsalmon":          "rgb(255, 160, 122)",
  "crimson":   "rgb(220, 20, 60)",   "lightyellow":          "rgb(255, 255, 224)",
  "darkred":   "rgb(139, 0, 0)",     "navajowhite":          "rgb(255, 222, 173)",
  "dimgray":   "rgb(105, 105, 105)", "saddlebrown":          "rgb(139, 69, 19)",
  "dimgrey":   "rgb(105, 105, 105)", "springgreen":          "rgb( 0, 255, 127)",
  "fuchsia":   "rgb(255, 0, 255)",   "yellowgreen":          "rgb(154, 205, 50)",
  "hotpink":   "rgb(255, 105, 180)", "antiquewhite":         "rgb(250, 235, 215)",
  "magenta":   "rgb(255, 0, 255)",   "darkseagreen":         "rgb(143, 188, 143)",
  "oldlace":   "rgb(253, 245, 230)", "lemonchiffon":         "rgb(255, 250, 205)",
  "skyblue":   "rgb(135, 206, 235)", "lightskyblue":         "rgb(135, 206, 250)",
  "thistle":   "rgb(216, 191, 216)", "mediumorchid":         "rgb(186, 85, 211)",
  "cornsilk":  "rgb(255, 248, 220)", "mediumpurple":         "rgb(147, 112, 219)",
  "darkblue":  "rgb( 0, 0, 139)",    "midnightblue":         "rgb( 25, 25, 112)",
  "darkcyan":  "rgb( 0, 139, 139)",  "darkgoldenrod":        "rgb(184, 134, 11)",
  "darkgray":  "rgb(169, 169, 169)", "darkslateblue":        "rgb( 72, 61, 139)",
  "darkgrey":  "rgb(169, 169, 169)", "darkslategray":        "rgb( 47, 79, 79)",
  "deeppink":  "rgb(255, 20, 147)",  "darkslategrey":        "rgb( 47, 79, 79)",
  "honeydew":  "rgb(240, 255, 240)", "darkturquoise":        "rgb( 0, 206, 209)",
  "lavender":  "rgb(230, 230, 250)", "lavenderblush":        "rgb(255, 240, 245)",
  "moccasin":  "rgb(255, 228, 181)", "lightseagreen":        "rgb( 32, 178, 170)",
  "seagreen":  "rgb( 46, 139, 87)",  "palegoldenrod":        "rgb(238, 232, 170)",
  "seashell":  "rgb(255, 245, 238)", "paleturquoise":        "rgb(175, 238, 238)",
  "aliceblue": "rgb(240, 248, 255)", "palevioletred":        "rgb(219, 112, 147)",
  "burlywood": "rgb(222, 184, 135)", "blanchedalmond":       "rgb(255, 235, 205)",
  "cadetblue": "rgb( 95, 158, 160)", "cornflowerblue":       "rgb(100, 149, 237)",
  "chocolate": "rgb(210, 105, 30)",  "darkolivegreen":       "rgb( 85, 107, 47)",
  "darkgreen": "rgb( 0, 100, 0)",    "lightslategray":       "rgb(119, 136, 153)",
  "darkkhaki": "rgb(189, 183, 107)", "lightslategrey":       "rgb(119, 136, 153)",
  "firebrick": "rgb(178, 34, 34)",   "lightsteelblue":       "rgb(176, 196, 222)",
  "gainsboro": "rgb(220, 220, 220)", "mediumseagreen":       "rgb( 60, 179, 113)",
  "goldenrod": "rgb(218, 165, 32)",  "mediumslateblue":      "rgb(123, 104, 238)",
  "indianred": "rgb(205, 92, 92)",   "mediumturquoise":      "rgb( 72, 209, 204)",
  "lawngreen": "rgb(124, 252, 0)",   "mediumvioletred":      "rgb(199, 21, 133)",
  "lightblue": "rgb(173, 216, 230)", "mediumaquamarine":     "rgb(102, 205, 170)",
  "lightcyan": "rgb(224, 255, 255)", "mediumspringgreen":    "rgb( 0, 250, 154)",
  "lightgoldenrodyellow": "rgb(250, 250, 210)"
]

/// Converts a string in CSS2 form to a CGColor. See
/// http://www.w3.org/TR/SVG/types.html#DataTypeColor
private func CGColorCreateFromString(string : String) -> CGColor? {     
  // Look in the color string table for an entry for this
  let colorString = svgColorNames[string] == nil ? string : svgColorNames[string]!
  // Handle either "rgb(..." or "#XXX..." strings
  if colorString.substringToIndex(colorString.startIndex.advancedBy(3)) == "rgb" {
    // Remove the prefix and whitespace and brackets
    let dataRange = Range(start: colorString.startIndex.advancedBy(4), end: colorString.endIndex.advancedBy(-1))
    let digits = colorString.substringWithRange(dataRange)
      .componentsSeparatedByString(",")
      .map { Int($0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()))! }
      .map { CGFloat($0) }
    return CGColorCreate(CGColorSpaceCreateDeviceRGB(), digits)
  } else if colorString.characters.first == "#" {
    let hexString = colorString.substringFromIndex(colorString.startIndex.advancedBy(1))
    let hex : CUnsignedLongLong = CUnsignedLongLong(hexString, radix: 16)!
    switch hexString.characters.count {
    case 3:
      let r = CGFloat((hex >> 8) & 0xF)
      let g = CGFloat((hex >> 4) & 0xF)
      let b = CGFloat((hex) & 0xF)
      return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [r/16, g/16, b/16, 1])!
    case 6:
      let r = CGFloat((hex >> 16) & 0xFF)
      let g = CGFloat((hex >> 8) & 0xFF)
      let b = CGFloat((hex) & 0xFF)
      return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [r/255, g/255, b/255, 1])!
    default:
      fatalError()
    }
  }
  return nil
}

// MARK: SVG Element protocols

protocol SVGElement {
  var id : String? { get }
  var attributes : [String : Any] { get }
  var sourceLine : UInt { get }
}

private protocol SVGTransformable : SVGElement {
  var transform : SVGMatrix { get }
}

private protocol SVGDrawable : SVGElement, SVGTransformable {
  func drawToContext(context : CGContextRef)
  var boundingBox : CGRect? { get }
}

private protocol SVGContainerElement : SVGDrawable {
  var children : [SVGElement] { get mutating set }
}

private protocol SVGPresentationElement : SVGElement {
  // All elements are:
  //‘alignment-baseline’, ‘baseline-shift’, ‘clip’, ‘clip-path’, ‘clip-rule’, ‘color’, ‘color-interpolation’, ‘color-interpolation-filters’, ‘color-profile’, ‘color-rendering’, ‘cursor’, ‘direction’, ‘display’, ‘dominant-baseline’, ‘enable-background’, ‘fill’, ‘fill-opacity’, ‘fill-rule’, ‘filter’, ‘flood-color’, ‘flood-opacity’, ‘font-family’, ‘font-size’, ‘font-size-adjust’, ‘font-stretch’, ‘font-style’, ‘font-variant’, ‘font-weight’, ‘glyph-orientation-horizontal’, ‘glyph-orientation-vertical’, ‘image-rendering’, ‘kerning’, ‘letter-spacing’, ‘lighting-color’, ‘marker-end’, ‘marker-mid’, ‘marker-start’, ‘mask’, ‘opacity’, ‘overflow’, ‘pointer-events’, ‘shape-rendering’, ‘stop-color’, ‘stop-opacity’, ‘stroke’, ‘stroke-dasharray’, ‘stroke-dashoffset’, ‘stroke-linecap’, ‘stroke-linejoin’, ‘stroke-miterlimit’, ‘stroke-opacity’, ‘stroke-width’, ‘text-anchor’, ‘text-decoration’, ‘text-rendering’, ‘unicode-bidi’, ‘visibility’, ‘word-spacing’, ‘writing-mode’
  var fill : Paint? { get }
  var stroke : Paint? { get }
  var strokeWidth : Length { get }
  var miterLimit : Float { get }
  var display : String { get }
}

// MARK: SVG protocol implementation extensions

private extension SVGPresentationElement {
  var display : String {
    return (attributes["display"] ?? "") as? String ?? "inline"
  }
  var fill : Paint? { return attributes["fill"] as? Paint }
  var stroke : Paint? { return attributes["stroke"] as? Paint }
  var strokeWidth : Length { return attributes["stroke-width"] as? Length ?? 1}
  var miterLimit : Float { return Float(attributes["stroke-miterlimit"] as? String ?? "4")! }
}

private extension SVGContainerElement {
  var boundingBox : CGRect? {
    // Unify all the child bounding boxes
    var boundingBox : CGRect? = nil
    for child in children.filter({ $0 is SVGDrawable }).map({ $0 as! SVGDrawable }) {
      guard let childBox = child.boundingBox else {
        continue
      }
      // Transform the bounding box
      boundingBox = boundingBox ∪? childBox.transformedBoundingBox(child.transform)
    }
    return boundingBox
  }
  
  func drawToContext(context: CGContextRef) {
    if let drawable = self as? SVGPresentationElement where drawable.display == "none" {
      return
    }
    // Loop over all children and draw
    for child in children.filter({ $0 is SVGDrawable }).map({ $0 as! SVGDrawable }) {
      if let pres = child as? SVGPresentationElement {
        if pres.isInvisible() { continue }
      }
      CGContextSaveGState(context)
      CGContextConcatCTM(context, child.transform.affine)

      // Draw the child
      child.drawToContext(context)
      CGContextRestoreGState(context)
    }
  }
}

private extension SVGTransformable {
  var transform : SVGMatrix { return attributes["transform"] as? SVGMatrix ?? SVGMatrix.Identity }
}
// Transformable: √ ‘circle’ ‘ellipse’,‘line’, ‘path’, ‘polygon’, ‘polyline’, ‘rect’, ‘g’,
//‘a’, ‘clipPath’, ‘defs’, ‘foreignObject’, ‘image’,  ‘switch’, ‘text’, ‘use’

// MARK: SVG Class implementations

// The base class for any physical elements
private class SVGElementBase : SVGElement {
  var id : String? { return attributes["id"] as? String }
  var attributes : [String : Any] = [:]
  var sourceLine : UInt = 0
}

/// Used for unknown elements encountered whilst parsing
private class SVGUnknownElement : SVGElementBase {
  var tag : String
  init(name : String) {
    tag = name
  }
}

/// An SVG element that can contain other SVG elements. For e.g. svg, g, defs
private class SVGGroup : SVGElementBase, SVGContainerElement, SVGDrawable, SVGTransformable {
  var children : [SVGElement] = []
}

/// The root element of any SVG file
private class SVGContainer : SVGElementBase, SVGContainerElement {
  var children : [SVGElement] = []
  private var idMap : [String : SVGElement] = [:]
  
  var width : Length {  return attributes["width"] as! Length }
  var height : Length { return attributes["height"] as! Length }
  
  override init() {
    super.init()
    attributes["width"]  = Length(value: 100, unit: .pc)
    attributes["height"] = Length(value: 100, unit: .pc)
  }
  
  func findWithID(id : String) -> SVGDrawable? {
    return idMap[id] as? SVGDrawable
  }
}

/// Generic base class for handling path objects
private class Path : SVGElementBase, SVGDrawable, SVGPresentationElement, SVGTransformable {
  var d : [PathInstruction] {
    return attributes["d"] as? [PathInstruction] ?? []
  }
  
  func drawToContext(context : CGContextRef)
  {
    guard d.count > 0 else {
      print("Warning: Path with no data from line \(sourceLine)")
      return
    }
    
    for command in d {
      switch command {
      case .MoveTo(let to):
        CGContextMoveToPoint(context, to.x, to.y)
      case .LineTo(let to):
        CGContextAddLineToPoint(context, to.x, to.y)
      case .CurveTo(let to, let controlStart, let controlEnd):
        CGContextAddCurveToPoint(context, controlStart.x, controlStart.y,
          controlEnd.x, controlEnd.y, to.x, to.y)
      case .ClosePath:
        CGContextClosePath(context)
      default:
        fatalError("Unrecognised path instruction: \(command)")
      }
    }
    handleStrokeAndFill(context)
  }
  
  var boundingBox : CGRect? {
    var box : CGRect? = nil
    for command in d {
      switch command {
      case .MoveTo(let to):
        box = box ∪? to
      case .LineTo(let to):
        box = box ∪? to
      case .CurveTo(let to, let controlStart, let controlEnd):
        box = box ∪? to ∪? controlStart ∪? controlEnd
      case .EllipticalArc(let data):
        box = box ∪? data.to
      case .ClosePath:
        break
      default:
        fatalError()
      }
    }
    return hasStroke ? box?.inset(CGFloat(-strokeWidth.value/2)) : box
  }
}

/// Represents a circle element in the SVG file
private class Circle : Path {
  var radius : CGFloat { return CGFloat((attributes["r"] as? Length)?.value ?? 0) }
  var center : CGPoint {
    let x = attributes["cx"] as? Length
    let y = attributes["cy"] as? Length
    return CGPointMake(CGFloat(x?.value ?? 0), CGFloat(y?.value ?? 0))
  }
  
  override func drawToContext(context: CGContextRef) {
    CGContextAddEllipseInRect(context,
      CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
    handleStrokeAndFill(context)
  }
  
  override var boundingBox : CGRect? {
    let s = CGFloat(hasStroke ? strokeWidth.value : 0)
    return CGRectMake(center.x-radius-s/2, center.y-radius-s/2, 2*radius+s, 2*radius+s)
  }
}

private class Line : Path {
  var start : CGPoint {
    let x = attributes["x1"] as? Length
    let y = attributes["y1"] as? Length
    return CGPoint(x: x?.value ?? 0, y: y?.value ?? 0)
  }
  var end : CGPoint {
    let x = attributes["x2"] as? Length
    let y = attributes["y2"] as? Length
    return CGPoint(x: x?.value ?? 0, y: y?.value ?? 0)
  }
  
  override func drawToContext(context: CGContextRef) {
    var points = [start, end]
    CGContextAddLines(context, &points, 2)
    handleStrokeAndFill(context)
  }
  
  override var boundingBox : CGRect? {
    let s = CGFloat(hasStroke ? strokeWidth.value/2 : 0)
    return (CGRectMake(start.x, start.y, 0, 0) ∪ end).inset(-s)
  }
}

private class Polygon : Path {
  var points : [CGPoint] {
    return attributes["points"] as? [CGPoint] ?? []
  }
  override func drawToContext(context: CGContextRef) {
    var pts = points
    CGContextAddLines(context, &pts, pts.count)
    CGContextClosePath(context)
    handleStrokeAndFill(context)
  }
  
  override var boundingBox : CGRect? {
    // Make a list of lines
    var maxMiter = strokeWidth.value
    // Only calculate miter if we have a stroke
    if hasStroke {
      for i in 0..<points.count {
        let lineA = (points[i], points[(i+1) % points.count])
        let lineB = (points[(i+1) % points.count], points[(i+2) % points.count])
        let vecA = lineA.1 - lineA.0
        let vecB = lineB.1 - lineB.0
        let cosTheta = (vecA • vecB) /
          (CGPointAsVectorLength(vecA) * CGPointAsVectorLength(vecB))
        let theta = acos(cosTheta)
        let miterDistance = Float(1 / sin(theta/2)) * strokeWidth.value
        // If this is a valid miter, then
        if miterDistance < miterLimit {
          maxMiter = max(miterDistance, maxMiter)
        }
      }
    }
    
    let s = CGFloat(hasStroke ? maxMiter : 0)
    let start = CGRectMake(points[0].x, points[0].y, 0, 0)
    return points.reduce(start, combine: { $0 ∪ $1 })
      .inset(-s)
  }
}

private class Rect : Path {
  var rect : CGRect {
    let x = attributes["x"] as? Length
    let y = attributes["y"] as? Length
    let width = attributes["width"] as? Length
    let height = attributes["height"] as? Length
    return CGRect(x: x?.value ?? 0, y: y?.value ?? 0, width: width?.value ?? 0, height: height?.value ?? 0)
  }
  
  override func drawToContext(context: CGContextRef) {
    CGContextAddRect(context, rect)
    handleStrokeAndFill(context)
  }

  override var boundingBox : CGRect? {
    let s = CGFloat(hasStroke ? strokeWidth.value/2 : 0)
    return rect.inset(-s)
  }
}

private class Ellipse : Path {
  override func drawToContext(context: CGContextRef) {
    fatalError()
  }
  override var boundingBox : CGRect? {
    fatalError()
  }
}

private class PolyLine : Path {
  var points : [CGPoint] {
    return attributes["points"] as? [CGPoint] ?? []
  }
  override func drawToContext(context: CGContextRef) {
    var pts = points
    CGContextAddLines(context, &pts, pts.count)
    handleStrokeAndFill(context)
  }

  override var boundingBox : CGRect? {
    let s = CGFloat(hasStroke ? strokeWidth.value/2 : 0)
    let start = CGRectMake(points[0].x, points[0].y, 0, 0)
    return points.reduce(start, combine: { $0 ∪ $1 }).inset(-s)
  }
}

/// Extension to handle stroke and fill for any SVGPresentationElement objects
private extension SVGPresentationElement {
  var hasStroke : Bool {
    return (stroke ?? .None)  != .None && strokeWidth.value != 0
  }
  var hasFill : Bool {
    return (fill ?? .Inherit) != .None
  }
  
  func isInvisible() -> Bool {
    if hasStroke || hasFill {
      return false
    }
    return true
  }
  
  /// Handles generic stroke and fill for this element
  func handleStrokeAndFill(context : CGContextRef) {
    var mode : CGPathDrawingMode? = nil
    // Handle stroke
    if strokeWidth.value > 0 {
      CGContextSetLineWidth(context, CGFloat(strokeWidth.value))
      switch stroke ?? .None {
      case .None:
        break
      case .Color(let color):
        CGContextSetStrokeColorWithColor(context, color)
        mode = .Stroke
      default:
        fatalError()
      }
    }
    // And, handle fill
    switch fill ?? .Color(CGColor.Black) {
    case .None:
      break
    case .Color(let color):
      CGContextSetFillColorWithColor(context, color)
      mode = (mode == .Stroke ? .FillStroke : .Fill)
    default:
      fatalError()
    }
    if let m = mode {
      CGContextDrawPath(context, m)
    }
  }
}

// MARK: General XML parsing functions

/// Handles information about an SVG length elements
private struct Length : FloatLiteralConvertible, IntegerLiteralConvertible {
  enum LengthUnit : String {
    case Unspecified
    case em = "em"
    case ex = "ex"
    case px = "px"
    case inches = "in"
    case cm = "cm"
    case mm = "mm"
    case pt = "pt"
    case pc = "pc"
  }
  var value : Float
  var unit : LengthUnit = .Unspecified
  
  init(value: Float, unit: LengthUnit) {
    self.value = value
    self.unit = unit
  }
  init(floatLiteral value: FloatLiteralType) {
    self.value = Float(value)
  }
  init(integerLiteral value: IntegerLiteralType) {
    self.value = Float(value)
  }
}

/// Handles entries for a painting entry type
private enum Paint : Equatable {
  case None
  case CurrentColor
  case Color(CGColor)
  case Inherit
}

private func ==(a : Paint, b : Paint) -> Bool {
  switch (a, b) {
  case (.None, .None):
    return true
  case (.CurrentColor, .CurrentColor):
    return true
  case (.Inherit, .Inherit):
    return true
  case (.Color(let a), .Color(let b)):
    return CGColorEqualToColor(a, b)
  default: return false
  }
}

/// Parse a <length> entry
private func parseLength(entry : String) -> Any {
  if entry.startIndex.distanceTo(entry.endIndex) >= 2 {
    let unitPos = entry.endIndex.advancedBy(-2)
    if let unit = Length.LengthUnit(rawValue: entry.substringFromIndex(unitPos)) {
      return Length(value: Float(entry.substringToIndex(unitPos))!, unit: unit)
    }
  }
  return Length(value: Float(entry)!, unit: .Unspecified)
}

// Parse an SVG <paint> type
private func parsePaint(entry : String) -> Any {
  switch entry {
  case "none":
    return Paint.None
  case "currentColor":
    return Paint.CurrentColor
  case "inherit":
    return Paint.Inherit
  default:
    // No simple implementation. Must be a color!
    return Paint.Color(CGColorCreateFromString(entry)!)
  }
}

/// Parse the list of points from a polygon/polyline entry
private func parseListOfPoints(entry : String) -> Any {
  // Split by all commas and whitespace, then group into coords of two floats
  let entry = entry.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
  let separating = NSMutableCharacterSet.whitespaceAndNewlineCharacterSet()
  separating.addCharactersInString(",")
  let parts = entry.componentsSeparatedByCharactersInSet(separating).filter { !$0.isEmpty }
  return floatsToPoints(parts.map({Float($0)!}))
}


private let transformFunction = SVGRegex(pattern: "\\s*(\\w+)\\s*\\(([^)]*)\\)\\s*,?\\s*")
private let transformArgumentSplitter = SVGRegex(pattern: "\\s*([^\\s),]+)")

private func parseTransform(entry: String) -> Any {
  if entry.isEmpty {
    return SVGMatrix.Identity
  }
  var current = SVGMatrix.Identity
  
  for match in transformFunction.matchesInString(entry) {
    let function = match.groups[0]
    let args = transformArgumentSplitter.matchesInString(match.groups[1]).map({Float($0.groups[0])!})
    switch function {
    case "matrix":
      guard args.count == 6 else {
        fatalError()
      }
      current *= SVGMatrix(data: args)
    case "translate":
      guard args.count == 1 || args.count == 2 else {
        fatalError()
      }
      let tx = CGPointMake(CGFloat(args[0]), args.count == 2 ? CGFloat(args[1]) : 0)
      current *= SVGMatrix(translation: tx)
    case "scale":
      guard args.count == 1 || args.count == 2 else {
        fatalError()
      }
      let sc = CGPointMake(CGFloat(args[0]), args.count == 2 ? CGFloat(args[1]) : 0)
      current *= SVGMatrix(scale: sc)
    case "rotate":
      guard args.count == 1 || args.count == 3 else {
        fatalError()
      }
      let offset = args.count == 3
        ? CGPointMake(CGFloat(args[1]), CGFloat(args[2]))
        : CGPointMake(0, 0)
      current *= SVGMatrix(translation: offset)
        * SVGMatrix(rotation: args[0])
        * SVGMatrix(translation: CGPointMake(-offset.x, -offset.y))
    case "skewX":
      guard args.count == 1 else {
        fatalError()
      }
      current *= SVGMatrix(skewX: args[0])
    case "skewY":
      guard args.count == 1 else {
        fatalError()
      }
      current *= SVGMatrix(skewY: args[0])
    default:
      fatalError()
    }
  }
  return current
}

/// Main XML Parser
internal class SVGParser : NSObject, NSXMLParserDelegate {
  
  var parser : NSXMLParser
  var elements : [SVGElement] = []
  private var idObjects : [String : SVGElement] = [:]
  
  init(data : NSData) {
    parser = NSXMLParser(data: data)
    super.init()
    parser.delegate = self
  }
  
  func parse() -> SVGElement {
    idObjects = [:]
    parser.parse()
    if let elem = lastElementToRemove as? SVGContainer {
      elem.idMap = idObjects
    }
    return lastElementToRemove!
  }
  
  var lastElementToRemove : SVGElement?
  
  func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String])
  {
    let element : SVGElementBase
    if let creator = tagCreationMap[elementName] {
      element = creator() as! SVGElementBase
    } else {
      element = SVGUnknownElement(name: elementName)
    }
    element.sourceLine = UInt(parser.lineNumber)
    
    for (key, value) in attributeDict {
      if let parser = getParserFor(elementName, attr: key) {
        element.attributes[key] = parser(value)
      } else {
        element.attributes[key] = value
      }
    }
    if var ce = elements.last as? SVGContainerElement {
      ce.children.append(element)
    }
    
    if let id = element.id {
      idObjects[id] = element
    }
    elements.append(element)
  }
  
  func parser(parser: NSXMLParser, didEndElement elementName: String,
    namespaceURI: String?, qualifiedName qName: String?)
  {
    let removed = elements.removeLast()

    // Remember the last element we removed, so we don't discard the end result
    lastElementToRemove = removed
  }
}

// MARK: Path parsing

private let pathSplitter = SVGRegex(pattern: "([a-zA-z])([^a-df-zA-DF-Z]*)")
private let pathArgSplitter = SVGRegex(pattern: "([+-]?\\d*\\.?\\d*(?:[eE][+-]?\\d+)?)\\s*,?\\s*")

private enum PathInstruction {
  case ClosePath
  case MoveTo(CGPoint)
  case LineTo(CGPoint)
  case HLineTo(CGFloat)
  case VLineTo(CGFloat)
  case CurveTo(to: CGPoint, controlStart: CGPoint, controlEnd: CGPoint)
  case SmoothCurveTo(to: CGPoint, controlEnd: CGPoint)
  case QuadraticBezier(to: CGPoint, control: CGPoint)
  case SmoothQuadraticBezier(to: CGPoint)
  case EllipticalArc(to: CGPoint, radius: CGPoint, xAxisRotation: Float, largeArc: Bool, sweep: Bool)
}

/// Convert an even list of floats to CGPoints
private func floatsToPoints(data: [Float]) -> [CGPoint] {
  guard data.count % 2 == 0 else {
    fatalError()
  }
  var out : [CGPoint] = []
  for var i = 0; i < data.count-1; i += 2 {
    out.append(CGPointMake(CGFloat(data[i]), CGFloat(data[i+1])))
  }
  return out
}

private func parsePath(data: String) -> Any { // -> [PathInstruction]
  var commands : [PathInstruction] = []
  // The point for the start of the current subpath
  var currentSubpathStart : CGPoint = CGPoint(x: 0, y: 0)
  // The current working point
  var currentPoint : CGPoint = CGPoint(x: 0, y: 0)
  // Now process the path
  for match in pathSplitter.matchesInString(data) {
    let command = match.groups[0]
    // Split the arguments, if we have any
    let args = pathArgSplitter.matchesInString(match.groups[1])
      .filter({ !$0.groups[0].isEmpty })
      .map { Float($0.groups[0])! }
    // Absolute or relative?
    let relative = command == command.lowercaseString
    // Handle the commands
    switch command.lowercaseString {
    case "m":
      for (i, point) in floatsToPoints(args).enumerate() {
        currentPoint = relative ? currentPoint + point : point
        if i == 0 {
          currentSubpathStart = currentPoint
          commands.append(.MoveTo(currentPoint))
        } else {
          commands.append(.LineTo(currentPoint))
        }
      }
    case "l":
      for point in floatsToPoints(args) {
        currentPoint = relative ? currentPoint + point : point
        commands.append(.LineTo(currentPoint))
      }
    case "h":
      for point in args {
        currentPoint = CGPointMake((relative ? currentPoint.x : 0) + CGFloat(point), currentPoint.y)
        commands.append(.LineTo(currentPoint))
      }
    case "v":
      for point in args {
        currentPoint = CGPointMake(currentPoint.x, (relative ? currentPoint.y : 0) + CGFloat(point))
        commands.append(.LineTo(currentPoint))
      }
    case "c":
      for args in floatsToPoints(args).groupByStride(3) {
        let controlA = relative ? currentPoint + args[0] : args[0]
        let controlB = relative ? currentPoint + args[1] : args[1]
        currentPoint = relative ? currentPoint + args[2] : args[2]
        commands.append(.CurveTo(to: currentPoint, controlStart: controlA, controlEnd: controlB))
      }
    case "z":
      commands.append(.ClosePath)
      currentPoint = currentSubpathStart
    case "a":
      for args in args.groupByStride(7) {
        let plainTo = CGPointMake(CGFloat(args[5]), CGFloat(args[6]))
        let to = relative ? currentPoint + plainTo : plainTo
        let radius = CGPointMake(CGFloat(args[0]), CGFloat(args[1]))
        let largeArcFlag = args[3] != 0
        let sweepFlag = args[4] != 0
        commands.append(.EllipticalArc(to: to, radius: radius, xAxisRotation: args[2], largeArc: largeArcFlag, sweep: sweepFlag))
      }
      
      //      (rx ry x-axis-rotation large-arc-flag sweep-flag x y)+
    default:
      fatalError()
    }
  }
  return commands
}


// MARK: Various Errata and extensions

private extension Array {
  func groupByStride(stride : Int) -> [[Generator.Element]] {
    var grouped : [[Generator.Element]] = []
    for var i = 0; i <= self.count-stride; i += stride {
      grouped.append(Array(self[i...i+stride-1]))
    }
    return grouped
  }
}

// Easy references to common colors
private extension CGColor {
  static var Black : CGColor { return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [0,0,0,1])! }
  static var Red : CGColor { return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [1,0,0,1])! }
  
}

private extension CGRect {
  init(x : Float, y: Float, width: Float, height: Float) {
    self.init(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
  }
  func inset(amount: CGFloat) -> CGRect {
    return CGRectInset(self, CGFloat(amount), CGFloat(amount))
  }
}

infix operator ∪ { associativity left }
infix operator ∪? { associativity left }

private func ∪(left: CGRect, right: CGRect) -> CGRect {
  return CGRectUnion(left, right)
}
private func ∪(left: CGRect, right: CGPoint) -> CGRect {
  return CGRectUnion(left, CGRectMake(right.x, right.y, 0, 0))
}
private func ∪(right: CGPoint, left: CGRect) -> CGRect {
  return CGRectUnion(left, CGRectMake(right.x, right.y, 0, 0))
}
private func ∪?(left: CGRect?, right: CGRect?) -> CGRect? {
  guard left != nil || right != nil else {
    return nil
  }
  return CGRectUnion(left ?? right!, right ?? left!)
}
private func ∪?(left: CGRect?, right: CGPoint) -> CGRect? {
  let rRect = CGRectMake(right.x, right.y, 0, 0)
  guard let l = left else {
    return rRect
  }
  return CGRectUnion(l, rRect)
}
private func ∪?(right: CGPoint, left: CGRect?) -> CGRect? {
  let rRect = CGRectMake(right.x, right.y, 0, 0)
  guard let l = left else {
    return rRect
  }
  return CGRectUnion(l, rRect)
}

private extension CGPoint {
  init(x: Float, y: Float) {
    self.init(x: CGFloat(x), y: CGFloat(y))
  }
}

private func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPointMake(left.x + right.x, left.y + right.y)
}

private struct SVGRegexMatch {
  var groups : [String]
  var result : NSTextCheckingResult
  
  init(string: String, result : NSTextCheckingResult) {
    self.result = result
    var groups : [String] = []
    for i in 1..<result.numberOfRanges {
      let range = result.rangeAtIndex(i)
      if range.location == NSNotFound {
        groups.append("")
      } else {
        groups.append((string as NSString).substringWithRange(range))
      }
    }
    self.groups = groups
  }
  
  var range : NSRange { return result.range }
}

private class SVGRegex {
  let re : NSRegularExpression
  init(pattern: String) {
    re = try! NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions())
  }
  func firstMatchInString(string : String) -> SVGRegexMatch? {
    let nss = string as NSString
    if let tr = re.firstMatchInString(string, options: NSMatchingOptions(), range: NSRange(location: 0, length: nss.length)) {
      return SVGRegexMatch(string: string, result: tr)
    }
    return nil
  }
  func matchesInString(string : String) -> [SVGRegexMatch] {
    let nsS = string as NSString
    return re.matchesInString(string, options: NSMatchingOptions(), range: NSRange(location: 0, length: nsS.length)).map { SVGRegexMatch(string: string, result: $0) }
  }
}

extension GLKMatrix3 : CustomStringConvertible, CustomDebugStringConvertible {
  public var description : String { return NSStringFromGLKMatrix3(self) }
  public var debugDescription : String { return description }
}

private extension SVGMatrix {
  static var Identity : SVGMatrix { return GLKMatrix3Identity }
  
  init(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float) {
    self = GLKMatrix3Make(a, b, 0, c, d, 0, e, f, 1)
  }
  init(data : [Float]) {
    self = GLKMatrix3Make(data[0], data[1], 0, data[2], data[3], 0, data[4], data[5], 1)
  }
  init(translation : CGPoint) {
    ///  [1 0 0 1 tx ty]
    self.init(a: 1, b: 0, c: 0, d: 1, e: Float(translation.x), f: Float(translation.y))
  }
  init(scale: CGPoint) {
    self.init(a: Float(scale.x), b: 0, c: 0, d: Float(scale.y), e: 0, f: 0)
  }
  init(rotation r: Float) {
    self.init(a: cos(r), b: sin(r), c: -sin(r), d: cos(r), e: 0, f: 0)
  }
  init(skewX s : Float) {
    self.init(a: 1, b: 0, c: tan(s), d: 1, e: 0, f: 0)
  }
  init(skewY s : Float) {
    self.init(a: 1, b: tan(s), c: 0, d: 1, e: 0, f: 0)
  }
  var affine : CGAffineTransform {
    return CGAffineTransformMake(CGFloat(m00), CGFloat(m01), CGFloat(m10), CGFloat(m11), CGFloat(m20), CGFloat(m21))
  }
}
private func *(left: SVGMatrix, right: SVGMatrix) -> SVGMatrix {
  return GLKMatrix3Multiply(left, right)
}
private func *(left: SVGMatrix, right: GLKVector3) -> GLKVector3 {
  return GLKMatrix3MultiplyVector3(left, right)
}
private func *(left: SVGMatrix, right: CGPoint) -> CGPoint {
  let v3 = GLKVector3Make(Float(right.x), Float(right.y), 1)
  let tx = GLKMatrix3MultiplyVector3(left, v3)
  return CGPointMake(CGFloat(tx.x), CGFloat(tx.y))
}
private func *=(inout left: SVGMatrix, right: SVGMatrix) {
  left = left * right
}

private extension CGRect {
  func transformedBoundingBox(transform: SVGMatrix) -> CGRect {
    let points = [
      CGPointMake(minX, minY),
      CGPointMake(minX, maxY),
      CGPointMake(maxX, minY),
      CGPointMake(maxX, maxY)
    ]
    let transformed = points.map({transform * $0})
    let newRect = transformed.reduce(nil, combine: {$0 ∪? $1})
    return newRect!
  }
}

private func *(left: CGPoint, right: CGFloat) -> CGPoint {
  return CGPointMake(left.x*right, left.y*right)
}
private func -(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPointMake(left.x-right.x, left.y-right.y)
}
private func CGPointAsVectorLength(pt: CGPoint) -> CGFloat {
  return sqrt(pt.x*pt.x + pt.y*pt.y)
}

infix operator • {associativity left precedence 140}
postfix operator ⟂ {}

private func •(left: CGPoint, right: CGPoint) -> CGFloat {
  return left.x*right.x + left.y*right.y
}

private func CGPointPerpendicular(of: CGPoint) -> CGPoint {
  return CGPointMake(of.y, -of.x)
}

private postfix func ⟂(of: CGPoint) -> CGPoint {
  return CGPointMake(of.y, -of.x)
}

private func CGPointNormalize(pt: CGPoint) -> CGPoint {
  return CGPointMake(pt.x / sqrt(pt•pt), pt.y / sqrt(pt•pt))
}
