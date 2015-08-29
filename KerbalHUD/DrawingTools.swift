//
//  DrawingKit.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

let π : GLfloat = GLfloat(M_PI)

protocol Drawable2D {
  
}

func BUFFER_OFFSET(i: Int) -> UnsafePointer<Void> {
  let p: UnsafePointer<Void> = nil
  return p.advancedBy(i)
}

private struct Mesh : Drawable2D {
  // Need array here? Probably not, as anything in the same buffer
  // should match formats
  //  var vertexArray  : GLuint = 0
//  var vertexArray : GLuint = 0
  var vertexBuffer : GLuint = 0
  var bufferOffset : GLuint = 0
  var bufferCount  : GLuint = 0
  var vertexType : GLenum = GLenum(GL_INVALID_ENUM)
}
enum VertexRepresentation : GLenum {
  case Points
  case Line_Strip
  case Line_Loop
  case Lines
  case Triangle_Strip
  case Triangle_Fan
  case Triangles
}

extension VertexRepresentation {
  var GLenum : GLKit.GLenum {
    switch self {
    case .Points:
      return GLKit.GLenum(GL_POINTS)
    case Line_Strip:
      return GLKit.GLenum(GL_LINE_STRIP)
    case Line_Loop:
      return GLKit.GLenum(GL_LINE_LOOP)
    case Lines:
      return GLKit.GLenum(GL_LINES)
    case Triangle_Strip:
      return GLKit.GLenum(GL_TRIANGLE_STRIP)
    case Triangle_Fan:
      return GLKit.GLenum(GL_TRIANGLE_FAN)
    case Triangles:
      return GLKit.GLenum(GL_TRIANGLES)
    }
  }
}

//typealias Point2D = (x: Float, y: Float)

typealias Triangle = (Point2D, Point2D, Point2D)
typealias Color4 = (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)


func ShiftPoint2D(base : Point2D, shift : Point2D) -> Point2D {
  return Point2D(x: base.x + shift.x, y: base.y + shift.y)
}
func ShiftTriangle(base : Triangle, shift : Point2D) -> Triangle {
  return Triangle(
    ShiftPoint2D(base.0, shift: shift),
    ShiftPoint2D(base.1, shift: shift),
    ShiftPoint2D(base.2, shift: shift))
}
func ShiftTriangles(base : [Triangle], shift : Point2D) -> [Triangle] {
  return base.map({ ShiftTriangle($0, shift: shift) });
}

/// A real, cyclic mod
private func mod(x : Int, m : Int) -> Int {
  let rem = x % m
  return rem < 0 ? rem + m : rem
}
public func cyc_mod(x: Float, m : Float) -> Float {
  let rem = x % m;
  return rem < 0 ? rem + m : rem
}
public func cyc_mod(x: Double, m : Double) -> Double {
  let rem = x % m;
  return rem < 0 ? rem + m : rem
}

/// Use barycentric coordinates to determine if a point is inside a triangle
func isPointInside(p : Point2D, x : (a: Point2D, b: Point2D, c: Point2D)) -> Bool {
  let area = 0.5 * (-x.b.y*x.c.x  + x.a.y*(x.c.x-x.b.x) + x.a.x*(x.b.y - x.c.y) + x.b.x*x.c.y)
  
  let s = (x.a.y*x.c.x - x.a.x*x.c.y + (x.c.y - x.a.y)*p.x + (x.a.x - x.c.x)*p.y) / (2*area)
  let t = (x.a.x*x.b.y - x.a.y*x.b.x + (x.a.y - x.b.y)*p.x + (x.b.x - x.a.x)*p.y) / (2*area)
  let u = 1-s-t
  // Inside the triangle, OR, on the edge, but not a shared vertex
  return s>0 && t>0 && u>0 || (s>=0 && t>=0 && u>=0 && s < 1 && t < 1 && u < 1)
}

enum TriangleClassification {
  case Closed
  case Open
  case Degenerate
}
private func isPointConvex(let points : [Point2D], index : Int) -> TriangleClassification
{
  let indices = (mod(index-1, m: points.count), index, mod(index+1, m: points.count))
  let x = (a: points[indices.0], b: points[indices.1], c: points[indices.2])
  let area = 0.5 * (-x.b.y*x.c.x  + x.a.y*(x.c.x-x.b.x) + x.a.x*(x.b.y - x.c.y) + x.b.x*x.c.y)
  return area < 0 ? .Closed : (area > 0 ? .Open : .Degenerate)
}

private func isPolygonEar(let points : [Point2D], index : Int) -> Bool {
  let indices = (mod(index-1, m: points.count), index, mod(index+1, m: points.count))
  let triangle = (points[indices.0], points[indices.1], points[indices.2])
  
  let classify = isPointConvex(points, index: index)
  if classify == .Open {
//    print ("   Is Open - not an ear.")
    return false
  } else if classify == .Degenerate {
    // for now, treat them as a valid triangle
//    print ("   Is Degenerate - counts as an ear.")
    return true
  }
  
  // This vertex, v, is an ear if v-1, v, v contains no other points
  for p in 0..<points.count {
    // Skip testing points that form part of this triangle
    if p == indices.0 || p == indices.1 || p == indices.2 {
      continue
    }
    if isPointInside(points[p], x: triangle) {
      // Not an ear, as another point is inside
//      print ("   Contains point \(p).")
      return false
    }
  }
  // If here, no other points are inside
  return true
}

/// Contains tools for drawing simple objects
class DrawingTools
{
  // State storing
  private var lastArray : GLuint = 0
  private var lastFramebuffer : GLuint = 0
  private var lastTexture : GLuint = 0

  
  var program : ShaderProgram

  var defaultFramebuffer : GLuint = 0
  var screenAspect : Float { return Float(screenSize.w) / Float(screenSize.h) }
  /// The size, in pixels, of the entire screen.
  var screenSize : Size2D = Size2D(w: 0,h: 0)
  
  // For textured squares
  var vertexArrayTextured : GLuint = 0
  var vertexBufferTextured : GLuint = 0

  private var buffers : [GLuint : BufferInfo] = [:]
  private var textRenderers : [String : TextRenderer] = [:]
  
  /// Scale for turning point values into current projection
  var pointsToScreenScale : GLfloat = 1
  
  private var meshSquare : Mesh?
  
  var time : (total: Double, frame: Double) = (0,0)
  
  private struct BufferInfo {
    let array : GLuint
    let name : GLuint
    let size : GLsizeiptr
    var offset : GLintptr = 0
    var spaceFree : GLsizeiptr {
      return size-offset
    }
    mutating func write(size : GLsizeiptr, data : UnsafePointer<Void>) {
      assert(spaceFree >= size)
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), name)
      glBufferSubData(GLenum(GL_ARRAY_BUFFER), offset, size, data)
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
      offset += size
    }
  }
  
  /// Clear memory that is no longer used
  func flush() {
    for txt in textRenderers.values {
      txt.flush()
    }
  }
  
  init(shaderProgram : ShaderProgram) {
    program = shaderProgram

    screenSize = Size2D(
      w: Int(UIScreen.mainScreen().bounds.width),
      h: Int(UIScreen.mainScreen().bounds.height))
    
    // Create an initial buffer
    generate_buffer()
    
    // Load a basic set of square vertices
    let sqVpoints : [Point2D] = [
      (0,0),(0,1),(1,0),(1,1)
    ].map { Point2D(x: $0.0, y: $0.1) }
    meshSquare = LoadVertices(VertexRepresentation.Triangle_Strip, vertices: sqVpoints) as? Mesh

    // Load the vertex information for a textured square
    glGenVertexArrays(1, &vertexArrayTextured)
    glBindVertexArray(vertexArrayTextured)
    glGenBuffers(1, &vertexBufferTextured)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBufferTextured)
    // Set up the vertex array information
    glEnableVertexAttribArray(program.attributes.position)
    glEnableVertexAttribArray(program.attributes.texture)
    glVertexAttribPointer(program.attributes.position, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)*4), BUFFER_OFFSET(0))
    glVertexAttribPointer(program.attributes.texture, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)*4), BUFFER_OFFSET(8))
    // Now copy the data into the buffer
    var texturedSquare : [GLfloat] = [
      0,0,0,1,
      0,1,0,0,
      1,0,1,1,
      1,1,1,0
    ]
    glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*texturedSquare.count, &texturedSquare, GLenum(GL_STATIC_DRAW))
    glBindVertexArray(0)
    
  }

//  private var current_buffer : GLuint
  private func generate_buffer(size : GLsizeiptr = 1024*sizeof(GLfloat)) -> BufferInfo {
    var buffer : GLuint = 0
    var array : GLuint = 0
    glGenVertexArrays(1, &array)
    glBindVertexArray(array)
    glGenBuffers(1, &buffer)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
    glBufferData(GLenum(GL_ARRAY_BUFFER), size, nil, GLenum(GL_STATIC_DRAW))
    buffers[buffer] = BufferInfo(array: array, name: buffer, size: Int(size), offset: 0)

    // Now create the vertex array settings
    glEnableVertexAttribArray(program.attributes.position)
    glVertexAttribPointer(program.attributes.position, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)*2), BUFFER_OFFSET(0))

    glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
    glBindVertexArray(0);
    
    return buffers[buffer]!
  }

  func bind(buffer : Framebuffer) {
    if lastFramebuffer == buffer.name {
      return
    }
    let name = buffer.name == 0 ? defaultFramebuffer : buffer.name
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), name)
    lastFramebuffer = name
    let size = name == defaultFramebuffer ? screenSize : buffer.size
    glViewport(0, 0, GLsizei(size.w), GLsizei(size.h))
//    glClearColor(0,0,0,1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_STENCIL_BUFFER_BIT))

  }
  
  func forceBind(buffer : Framebuffer) {
    let name = buffer.name == 0 ? defaultFramebuffer : buffer.name
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), name)
    lastFramebuffer = name
  }
  
  private func bufferWithSpace(space : GLsizeiptr) -> BufferInfo
  {
    for buffer in buffers.values {
      if buffer.spaceFree >= space {
        return buffer
      }
    }
    print ("Cannot find space, generating new buffer")
    // If it's greater than 3/4 the size of a full buffer, create one just for it
    if space > 1024*sizeof(GLfloat)*3/4 {
      return generate_buffer(space)
    } else {
      return generate_buffer()
    }
  }
  
  // Takes a list of 2D vertices and converts them into a drawable representation
  func LoadVertices(form : VertexRepresentation, vertices : [Point2D]) -> Drawable2D? {
    // Turn the vertices into a flat GLfloat array
    var asFloat : [GLfloat] = []
    for vertex in vertices {
      asFloat.append(vertex.x)
      asFloat.append(vertex.y)
    }
    assert(vertices.count < 1024)

    let buffer = bufferWithSpace(sizeof(GLfloat)*asFloat.count)
    let offset = GLuint(buffer.offset) / GLuint(sizeof(GLfloat)) / 2
    buffers[buffer.name]!.write(sizeof(GLfloat)*asFloat.count, data: &asFloat)
    
    return Mesh(vertexBuffer: buffer.name, bufferOffset: offset, bufferCount: GLuint(vertices.count), vertexType: form.GLenum)
  }
  
  // Converts a polygon into triangles
  var decomposeLog : [Triangle] = []
  
  func DecomposePolygon(points : [Point2D]) -> [Triangle]
  {
    // Calculate the signed area of this polygon
    var area : Float = 0.0
    for i in 0..<points.count {
      let iPlus = (i + 1) % points.count
      area += (points[iPlus].x-points[i].x) * (points[iPlus].y + points[i].y)
    }
    let CW = area > 0
    
    var triangles : [Triangle] = []
    
    // Continue until only three points remaing
    var remaining : [Point2D]
    // Always iterate clockwise over the polygon
    if CW {
      remaining = points
    } else {
      remaining = points.reverse()
    }
    
    var lastRemaining = 0
    
    decomposeLog.removeAll()
    
    while remaining.count > 3 {
      if lastRemaining == remaining.count {
        print ("Didn't remove any ears!!!! Error!!!!")
        break
      }
      lastRemaining = remaining.count
      // Step over every vertex, and check to see if it is an ear
      for v in 0..<remaining.count {
        let indices = (mod(v-1, m: remaining.count), v, mod(v+1, m: remaining.count))
        let triangle = Triangle(remaining[indices.0], remaining[indices.1], remaining[indices.2])
//        print("Examining \(triangle.0), \(triangle.1), \(triangle.2)")
        if isPolygonEar(remaining, index: v) {
//          print("   Is Ear number \(triangles.count+1)!")
          triangles.append(triangle)
//          decomposeLog.append(triangle)
          remaining.removeAtIndex(v)
          // Now go back to the beginning
          break
        } else {
//          print("   Not Ear.")
        }
      }
    }
    // Add the remaining triangle
    triangles.append((remaining[0], remaining[1], remaining[2]))
    return triangles
  }
  
  /// Convert a series of polygon points into a metadata object for drawing.
  ///
  /// It first reduces the polygon to triangles by using ear clipping.
  ///
  func Load2DPolygon(points : [Point2D]) -> Drawable2D? {
    return LoadTriangles(DecomposePolygon(points))
  }
  
  func LoadTriangles(triangles : [Triangle]) -> Drawable2D?
  {
    var vertexList : [Point2D] = []
    for tri in triangles {
      vertexList.append(tri.0)
      vertexList.append(tri.1)
      vertexList.append(tri.2)
    }
    return LoadVertices(.Triangles, vertices: vertexList)
  }
  
  /// Binds a vertex array, with caching
  func bindArray(array : GLuint) {
    if array != lastArray {
      glBindVertexArray(array)
      lastArray = array
    }
  }
  
  func Draw(item : Drawable2D) {
    let mesh = item as! Mesh
    bindArray(buffers[mesh.vertexBuffer]!.array)
    glDrawArrays(mesh.vertexType, GLint(mesh.bufferOffset), GLint(mesh.bufferCount))
  }
  
  func DrawLine(  from  : (x: GLfloat, y: GLfloat),
                      to: (x: GLfloat, y: GLfloat),
                  width : GLfloat,
             transform  : GLKMatrix4 = GLKMatrix4Identity) {
    // Calculate the rotation for this vector
    let rotation_angle = atan2(to.y-from.y, to.x-from.x)

    let length = sqrt(pow(to.y-from.y, 2) + pow(to.x-from.x, 2))
    var baseMatrix = transform
    baseMatrix = GLKMatrix4Translate(baseMatrix, from.x, from.y, 0.1)
    baseMatrix = GLKMatrix4Rotate(baseMatrix, (0.5*3.1415926)-rotation_angle, 0, 0, -1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, width, length, 1)
    baseMatrix = GLKMatrix4Translate(baseMatrix, -0.5, 0, 0)
    let mvp = GLKMatrix4Multiply(program.projection, baseMatrix)
    program.setModelViewProjection(mvp)
    
    Draw(meshSquare!)
  }
  
  func DrawSquare(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat)
  {
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, left, bottom, 0.1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, right-left, top-bottom, 1)
    let mvp = GLKMatrix4Multiply(program.projection, baseMatrix)
    program.setModelViewProjection(mvp)
    Draw(meshSquare!)
  }

  func DrawTexturedSquare(bounds : Bounds) {
    DrawTexturedSquare(bounds.left, bottom: bounds.bottom, right: bounds.right, top: bounds.top)
  }
  func DrawTexturedSquare(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat)
  {
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, left, bottom, 0.1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, right-left, top-bottom, 1)
    let mvp = GLKMatrix4Multiply(program.projection, baseMatrix)
    program.setModelViewProjection(mvp)
    bindArray(vertexArrayTextured)
    program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
  }

  
  func textRenderer(fontName : String) -> TextRenderer {
    if let existing = textRenderers[fontName] {
      return existing
    } else {
      let new = TextRenderer(tool: self, font: fontName)
      textRenderers[fontName] = new
      return new
    }
  }
  
  /// A convenience text renderer that avoids having to grab a font named explicitly
  func drawText(text: String, size : GLfloat, position : Point2D, align : NSTextAlignment = .Left, rotation : GLfloat = 0) {
    textRenderer("Menlo").draw(text, size: size, position: position, align: align, rotation: rotation)
  }
  
  private func startWritingStencilBuffer() {
    glEnable(GLenum(GL_STENCIL_TEST))
    glStencilFunc(GLenum(GL_ALWAYS), 1, 0xFF)
    glStencilOp(GLenum(GL_KEEP), GLenum(GL_KEEP), GLenum(GL_REPLACE))
    glColorMask(GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE))
    glStencilMask(0xFF)
    glClear(GLenum(GL_STENCIL_BUFFER_BIT))
  }
  private func stopWritingStencilBuffer() {
    glColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
    glStencilFunc(GLenum(GL_EQUAL), 1, 0xFF)
    // Prevent further writing to the stencil from this point
    glStencilMask(0x00);
  }
  
  func ConstrainDrawing(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat) {
    startWritingStencilBuffer()
    DrawSquare(left, bottom: bottom, right: right, top: top)
    stopWritingStencilBuffer()
  }
  func ConstrainDrawing(bounds : Bounds) {
    startWritingStencilBuffer()
    DrawSquare(bounds.left, bottom: bounds.bottom, right: bounds.right, top: bounds.top)
    stopWritingStencilBuffer()
  }

  func UnconstrainDrawing() {
    glDisable(GLenum(GL_STENCIL_TEST))
  }
  
  
  func bind(texture : Texture) {
    let name = texture.name
    if name != lastTexture {
      glBindTexture(texture.target, name)
    }
  }
  
}

private let _glErrors = [
  GLenum(GL_NO_ERROR) : "",
  GLenum(GL_INVALID_ENUM): "GL_INVALID_ENUM",
  GLenum(GL_INVALID_VALUE): "GL_INVALID_VALUE",
  GLenum(GL_INVALID_OPERATION): "GL_INVALID_OPERATION",
  GLenum(GL_INVALID_FRAMEBUFFER_OPERATION): "GL_INVALID_FRAMEBUFFER_OPERATION",
  GLenum(GL_OUT_OF_MEMORY): "GL_OUT_OF_MEMORY"
]
func processGLErrors() {
  var error = glGetError()
  while error != 0 {
    print("OpenGL Error: " + _glErrors[error]!)
    error = glGetError()
  }
}


/// Generates a series of triangles for an open circle
func GenerateCircleTriangles(r : GLfloat, w : GLfloat) -> [Triangle]
{
  var tris : [Triangle] = []
  let Csteps = 20
  let innerR = r - w/2
  let outerR = r + w/2
  
  for step in 0..<Csteps {
    let theta = Float(2*M_PI*(Double(step)/Double(Csteps)))
    let nextTheta = Float(2*M_PI*(Double(step+1)/Double(Csteps)))
    tris.append((
      Point2D(x: innerR*sin(theta), y: innerR*cos(theta)),
      Point2D(x: outerR*sin(theta), y: outerR*cos(theta)),
      Point2D(x: innerR*sin(nextTheta), y: innerR*cos(nextTheta))
    ))
    tris.append((
      Point2D(x: innerR*sin(nextTheta), y: innerR*cos(nextTheta)),
      Point2D(x: outerR*sin(theta), y: outerR*cos(theta)),
      Point2D(x: outerR*sin(nextTheta), y: outerR*cos(nextTheta))
    ))
  }
  return tris
}

func GenerateBoxTriangles(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat) -> [Triangle] {
  return [
    Triangle(Point2D(x: left, y: bottom), Point2D(x: left, y: top), Point2D(x: right, y: top)),
    Triangle(Point2D(x: right, y: top), Point2D(x: right, y: bottom), Point2D(x: left, y: bottom))
  ]
}

func GenerateRoundedBoxPoints(
  left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat, radius: GLfloat) -> [Point2D]
{
  // How many steps to do in a corner
  let STEPS = 5
  let STEP_ANGLE = π/2.0/Float(STEPS+2)
  // Start before the top-left circle
  var points : [(Float, Float)] = [(left, top-radius)]
  // Do the inner circle points
  for step in 1...STEPS {
    let x = -cos(STEP_ANGLE*Float(step))*radius
    let y = sin(STEP_ANGLE*Float(step))*radius
    points.append((left+radius+x, top-radius+y))
  }
  points.append((left+radius, top))
  points.append((right-radius, top))
  // Do the inner circle points
  for step in 1...STEPS {
    let x = sin(STEP_ANGLE*Float(step))*radius
    let y = cos(STEP_ANGLE*Float(step))*radius
    points.append((right-radius+x, top-radius+y))
  }
  points.append((right, top-radius))
  points.append((right, bottom+radius))
  for step in 1...STEPS {
    let x = cos(STEP_ANGLE*Float(step))*radius
    let y = -sin(STEP_ANGLE*Float(step))*radius
    points.append((right-radius+x, bottom+radius+y))
  }
  points.append((right-radius, bottom))
  points.append((left+radius, bottom))
  for step in 1...STEPS {
    let x = -sin(STEP_ANGLE*Float(step))*radius
    let y = -cos(STEP_ANGLE*Float(step))*radius
    points.append((left+radius+x, bottom+radius+y))
  }
  points.append((left, bottom+radius))
  
//  return 
  return points.map({Point2D(x: $0.0, y: $0.1)})
}
