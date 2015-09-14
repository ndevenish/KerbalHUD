//
//  DrawingKit.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

public let π : GLfloat = GLfloat(M_PI)

protocol Drawable {
  
}

func BUFFER_OFFSET(i: Int) -> UnsafePointer<Void> {
  let p: UnsafePointer<Void> = nil
  return p.advancedBy(i)
}

//private struct Mesh : Drawable {
//  // Need array here? Probably not, as anything in the same buffer
//  // should match formats
//  //  var vertexArray  : GLuint = 0
////  var vertexArray : GLuint = 0
//  var vertexBuffer : GLuint = 0
//  var bufferOffset : GLuint = 0
//  var bufferCount  : GLuint = 0
//  var vertexType : GLenum = GLenum(GL_INVALID_ENUM)
//}

/// Builds a 1X1 white texture to use for non-texture drawing
func generate1X1Texture() -> Texture {
  var tex : GLuint = 0
  glGenTextures(1, &tex)
  glBindTexture(GLenum(GL_TEXTURE_2D), tex)
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT);
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT);
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR);
  glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR);
  var data : [GLubyte] = [255]
  glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_LUMINANCE, 1, 1, 0, GLenum(GL_LUMINANCE), GLenum(GL_UNSIGNED_BYTE), &data)
  glBindTexture(GLenum(GL_TEXTURE_2D), 0)
  return Texture(name: tex, width: 1, height: 1)
}

func generateCenteredTextureSquare(tools: DrawingTools) -> Drawable {
  let centerTA = tools.createVertexArray(positions: 2, textures: 2)
  var texturedSquareO : [GLfloat] = [
    -0.5,-0.5,0,0,
    -0.5, 0.5,0,1,
    0.5,-0.5,1,0,
    0.5, 0.5,1,1
  ]
  glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*texturedSquareO.count, &texturedSquareO, GLenum(GL_STATIC_DRAW))
  tools.bind(VertexArray.Empty)
  return SimpleMesh(array: centerTA, texture: nil, vertexType: .TriangleStrip, bufferOffset: 0, bufferCount: 4, color: nil)
}

func generateOriginTextureSquare(tools: DrawingTools) -> Drawable {
  let texturedArray = tools.createVertexArray(positions: 2, textures: 2)
  // Now copy the data into the buffer
  var texturedSquare : [GLfloat] = [
    0,0,0,0,
    0,1,0,1,
    1,0,1,0,
    1,1,1,1
  ]
  glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*texturedSquare.count, &texturedSquare, GLenum(GL_STATIC_DRAW))
  tools.bind(VertexArray.Empty)
  return SimpleMesh(array: texturedArray, texture: nil, vertexType: .TriangleStrip, bufferOffset: 0, bufferCount: 4, color: nil)
}
protocol Mesh : Drawable {
  
}

private struct SimpleMesh : Mesh {
  var array : VertexArray
  var texture : Texture?
  var vertexType : VertexRepresentation
  var bufferOffset : GLuint
  var bufferCount : GLuint
  var color : Color4?
}

struct MultiDrawable : Drawable {
  let drawables : [Drawable]
}

enum VertexRepresentation : GLenum {
  case Points
  case LineStrip
  case LineLoop
  case Lines
  case TriangleStrip
  case TriangleFan
  case Triangles
}

extension VertexRepresentation {
  var GLenum : GLKit.GLenum {
    switch self {
    case .Points:
      return GLKit.GLenum(GL_POINTS)
    case LineStrip:
      return GLKit.GLenum(GL_LINE_STRIP)
    case LineLoop:
      return GLKit.GLenum(GL_LINE_LOOP)
    case Lines:
      return GLKit.GLenum(GL_LINES)
    case TriangleStrip:
      return GLKit.GLenum(GL_TRIANGLE_STRIP)
    case TriangleFan:
      return GLKit.GLenum(GL_TRIANGLE_FAN)
    case Triangles:
      return GLKit.GLenum(GL_TRIANGLES)
    }
  }
}

//typealias Point2D = (x: Float, y: Float)

//typealias Triangle = (Point2D, Point2D, Point2D)


func ShiftPoint2D(base : Point2D, shift : Point2D) -> Point2D {
  return Point2D(x: base.x + shift.x, y: base.y + shift.y)
}
func ShiftTriangle<T : Point>(base : Triangle<T>, shift : T) -> Triangle<T> {
  return Triangle(base.p1 + shift, base.p2 + shift, base.p3 + shift)
}
func ShiftTriangles<T : Point>(base : [Triangle<T>], shift : T) -> [Triangle<T>] {
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
  private var lastFramebuffer : Framebuffer = Framebuffer.Default
  private var lastTexture : GLuint = 0
  private var lastVertexBuffer : GLuint = 0
  
  var program : ShaderProgram

  var defaultFramebuffer : GLuint = 0
  
  /// The size, in pixels, of the entire hardware screen, in current orientation
  var screenSizePhysical : Size2D<Int>
  /// The multiplier to convert the current rendering target to pixels
  var scaleToPoints = Point2D(0,0)
  /// The physical size (in pixels) of the currently bound render target
  var renderTargetPixels : Size2D<Int>
  
  var images : ImageLibrary { return _images! }
  private var _images : ImageLibrary? = nil
  
  // For textured squares
  var texturedSquare : Drawable? = nil

  private(set) var texturedCenterSquare : Drawable? = nil
  
  private var buffers : [GLuint : BufferInfo] = [:]
  private var textRenderers : [String : TextRenderer] = [:]
  
  /// Scale for turning point values into current projection
  var pointsToScreenScale : GLfloat = 1
  
  private var meshSquare : Mesh?
  
  private let blankTexture : Texture
  
  private struct BufferInfo {
    let array : VertexArray
//    let array : GLuint
//    let name : GLuint
    let size : GLsizeiptr
    var offset : GLintptr = 0
    var spaceFree : GLsizeiptr {
      return size-offset
    }
    mutating func write(size : GLsizeiptr, data : UnsafePointer<Void>) {
      assert(spaceFree >= size)
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), array.buffer_name)
      glBufferSubData(GLenum(GL_ARRAY_BUFFER), offset, size, data)
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
      offset += size
    }
  }
  
  /// Clear memory that is no longer used
  func flush() {
    for txt in textRenderers.values {
      (txt as? AtlasTextRenderer)?.flush()
    }
  }
  
  init(shaderProgram : ShaderProgram) {
    program = shaderProgram

    screenSizePhysical = Size2D(
      w: Int(UIScreen.mainScreen().bounds.width),
      h: Int(UIScreen.mainScreen().bounds.height))
    renderTargetPixels = screenSizePhysical
    
    blankTexture = generate1X1Texture()
    
    _images = ImageLibrary(tools: self)
    
    // Create an initial buffer
    generate_buffer()
    
    // Load a basic set of square vertices
    let sqVpoints : [Point2D] = [
      (0,0),(0,1),(1,0),(1,1)
    ].map { Point2D(x: $0.0, y: $0.1) }
    meshSquare = LoadVertices(VertexRepresentation.TriangleStrip, vertices: sqVpoints) as! SimpleMesh
    bind(VertexArray.Empty)
    
    
    texturedSquare =       generateOriginTextureSquare(self)
    texturedCenterSquare = generateCenteredTextureSquare(self)
  }
  
  func setOrthProjection(left left: Float, right: Float, bottom: Float, top: Float) {
    program.setProjection(GLKMatrix4MakeOrtho(left, right, bottom, top, -abs(top-bottom)/2, abs(top-bottom)))
    let mss = Float(UIScreen.mainScreen().scale)
    let pointSize = Size2D(w: Float(renderTargetPixels.w)/mss, h: Float(renderTargetPixels.h)/mss)
    scaleToPoints = Point2D(pointSize.w/abs(right-left), pointSize.h/abs(top-bottom))
  }
  
//  private var current_buffer : GLuint
  private func generate_buffer(size : GLsizeiptr = 1024*sizeof(GLfloat)) -> BufferInfo {
    
    let array = createVertexArray(positions: 2, textures: 0)
    let buffer = array.buffer_name
    
    // Preallocate the data
    glBufferData(GLenum(GL_ARRAY_BUFFER), size, nil, GLenum(GL_STATIC_DRAW))
    buffers[buffer] = BufferInfo(array: array, size: Int(size), offset: 0)

    bind(VertexArray.Empty)
    return buffers[buffer]!
  }

  func bind(array : VertexArray) {
    if lastArray == array.name {
      return
    }
    glBindVertexArray(array.name)
    lastArray = array.name
  }
  
  
  func bind(buffer : Framebuffer) {
    if lastFramebuffer.name == buffer.name {
      return
    }
    let name = buffer.name == 0 ? defaultFramebuffer : buffer.name
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), name)
    lastFramebuffer = buffer
    let size = name == defaultFramebuffer ? screenSizePhysical : buffer.size
    glViewport(0, 0, GLsizei(size.w), GLsizei(size.h))
    renderTargetPixels = size
    
//    glClearColor(0,0,0,1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_STENCIL_BUFFER_BIT))

  }
  
  func bind(texture : Texture) {
    if texture.name == 0 {
      bind(blankTexture)
      return
    }
    let name = texture.name
    if name != lastTexture {
      glBindTexture(texture.target, name)
      program.setUVProperties()
    }
  }
  

  func forceBind(buffer : Framebuffer) {
    let name = buffer.name == 0 ? defaultFramebuffer : buffer.name
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), name)
    lastFramebuffer = buffer
  }
  
  func getCurrentFramebuffer() -> Framebuffer {
    return lastFramebuffer
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
  func LoadVertices(form : VertexRepresentation, vertices : [Point2D], color: Color4? = nil) -> Drawable {
    // Turn the vertices into a flat GLfloat array
    var asFloat : [GLfloat] = []
    for vertex in vertices {
      asFloat.append(vertex.x)
      asFloat.append(vertex.y)
    }
    assert(vertices.count < 1024)

    let buffer = bufferWithSpace(sizeof(GLfloat)*asFloat.count)
    let offset = GLuint(buffer.offset) / GLuint(sizeof(GLfloat)) / 2
    buffers[buffer.array.buffer_name]!.write(sizeof(GLfloat)*asFloat.count, data: &asFloat)
    
    return SimpleMesh(
      array: buffer.array,
      texture: blankTexture,
      vertexType: form, bufferOffset: offset, bufferCount: GLuint(vertices.count),
      color: color)
//    
//      vertexBuffer: buffer.name, bufferOffset: offset, bufferCount: GLuint(vertices.count), vertexType: form.GLenum)
  }
  
  func DecomposePolygon(points : [Point2D]) -> [Triangle<Point2D>]
  {
    // Calculate the signed area of this polygon
    var area : Float = 0.0
    for i in 0..<points.count {
      let iPlus = (i + 1) % points.count
      area += (points[iPlus].x-points[i].x) * (points[iPlus].y + points[i].y)
    }
    let CW = area > 0
    
    var triangles : [Triangle<Point2D>] = []
    
    // Continue until only three points remaing
    var remaining : [Point2D]
    // Always iterate clockwise over the polygon
    if CW {
      remaining = points
    } else {
      remaining = points.reverse()
    }
    
    var lastRemaining = 0
    
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
    triangles.append(Triangle(remaining[0], remaining[1], remaining[2]))
    return triangles
  }
  
  /// Convert a series of polygon points into a metadata object for drawing.
  ///
  /// It first reduces the polygon to triangles by using ear clipping.
  ///
  func Load2DPolygon(points : [Point2D]) -> Drawable {
    return LoadTriangles(DecomposePolygon(points))
  }
  
  func LoadTriangles(triangles : [Triangle<Point2D>]) -> Drawable
  {
    var vertexList : [Point2D] = []
    for tri in triangles {
      vertexList.append(tri.p1)
      vertexList.append(tri.p2)
      vertexList.append(tri.p3)
    }
    return LoadVertices(.Triangles, vertices: vertexList)
  }

  func LoadTriangles(triangles : [Triangle<TexturedPoint3D>], texture: Texture, color: Color4? = nil) -> Drawable
  {
    var data = triangles.flatMap { (tri) -> [GLfloat] in
      var flat : [Float] = []
      flat.appendContentsOf(tri.p1.flatten())
      flat.appendContentsOf(tri.p2.flatten())
      flat.appendContentsOf(tri.p3.flatten())
      return flat.map({ GLfloat($0) })
    }
    let array = createVertexArray(positions: 3, textures: 2)
    glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*data.count, &data, GLenum(GL_STATIC_DRAW))
    return SimpleMesh(array: array, texture: texture, vertexType: .Triangles, bufferOffset: 0, bufferCount: GLuint(triangles.count*3), color:color)
  }

  func Draw(item : Drawable) {
    draw(item)
  }
  
  func draw(item : Drawable) {
    if let mesh = item as? SimpleMesh {
      bind(mesh.array)
      if let texture = mesh.texture {
        bind(texture)
      }
      if let color = mesh.color {
        program.setColor(color)
      }
      glDrawArrays(mesh.vertexType.GLenum, GLint(mesh.bufferOffset), GLsizei(mesh.bufferCount))
    } else if let mesh = item as? MultiDrawable {
      for drawable in mesh.drawables {
        Draw(drawable)
      }
    } else {
      fatalError("Unrecognised mesh type!")
    }
  }
  
  func DrawLine( from from  : (x: GLfloat, y: GLfloat),
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
    program.setModelView(baseMatrix)
    bind(blankTexture)
    Draw(meshSquare!)
  }
  
  func DrawSquare(bounds : Bounds)
  {
    DrawSquare(bounds.left, bottom: bounds.bottom, right: bounds.right, top: bounds.top)
  }
  func DrawSquare(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat)
  {
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, left, bottom, 0.1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, right-left, top-bottom, 1)
    let mvp = GLKMatrix4Multiply(program.projection, baseMatrix)
    program.setModelViewProjection(mvp)
    bind(blankTexture)
    Draw(meshSquare!)
  }

  func DrawTexturedSquare(bounds : Bounds) {
    DrawTexturedSquare(bounds.left, bottom: bounds.bottom, right: bounds.right, top: bounds.top)
  }
  func DrawTexturedSquare(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat, rotation: GLfloat = 0)
  {
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, left, bottom, 0.1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, right-left, top-bottom, 1)
    if rotation != 0 {
      baseMatrix = GLKMatrix4Translate(baseMatrix, 0.5, 0.5, 0.1)
      baseMatrix = GLKMatrix4Rotate(baseMatrix, rotation, 0, 0, 1)
      baseMatrix = GLKMatrix4Translate(baseMatrix, -0.5, -0.5, 0)
    }
    let mvp = GLKMatrix4Multiply(program.projection, baseMatrix)
    program.setModelViewProjection(mvp)
    program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    draw(texturedSquare!)
  }

  
  func textRenderer(fontName : String) -> TextRenderer {
    if let existing = textRenderers[fontName] {
      return existing
    } else {
      let new = AtlasTextRenderer(tool: self, font: fontName)
      textRenderers[fontName] = new
      return new
    }
  }
  
  /// A convenience text renderer that avoids having to grab a font named explicitly
  func drawText(text: String, size : GLfloat, position : Point2D, align : NSTextAlignment = .Left, rotation : GLfloat = 0) {
    textRenderer("Menlo").draw(text, size: size, position: position, align: align, rotation: rotation)
  }
  var defaultTextRenderer : TextRenderer { return textRenderer("Menlo") }
  
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
