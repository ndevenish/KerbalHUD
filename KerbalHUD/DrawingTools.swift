//
//  DrawingKit.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

protocol Drawable {
  
}

/// Contains tools for drawing simple objects
class DrawingTools
{
  private struct DrawingToolState {
    var array : GLuint = 0
    var framebuffer : Framebuffer = Framebuffer.Default
    var texture : GLuint = 0
    var vertexArray : VertexArray = VertexArray.Empty
    var usingColorAttrib : Bool = true
    var stencilTesting : Bool = false
    var program : ShaderState?
    var scaleToPoints = Point2D(1,1)
  }
  
  // State storing
  private var currentState = DrawingToolState()
  private var stateStack : [DrawingToolState] = []
  
  var program : ShaderProgram

  /// The default framebuffer
  var defaultFramebuffer : GLuint = 0
  
  /// The size, in pixels, of the entire hardware screen, in current orientation
  var screenSizePhysical : Size2D<Int>
  /// The multiplier to convert the current rendering target to pixels
  var scaleToPoints : Point2D { return currentState.scaleToPoints }
  /// The physical size (in pixels) of the currently bound render target
  var renderTargetPixels : Size2D<Int>
  
  var images : ImageLibrary { return _images! }
  private var _images : ImageLibrary? = nil
  
  // For textured squares, offset and centered
  private(set) var texturedSquare : Drawable? = nil
  private(set) var texturedCenterSquare : Drawable? = nil
  /// An untextured square
  private var meshSquare : Mesh?
  /// A blank 1x1 white texture
  private let blankTexture : Texture
  
  /// Tracks buffer objects for loading shared
  private var buffers : [GLuint : BufferInfo] = [:]
  /// Tracks every text renderer we have created
  private var textRenderers : [String : TextRenderer] = [:]
  
  /// Scale for turning point values into current projection
  var pointsToScreenScale : GLfloat = 1
  
  private struct BufferInfo {
    let array : VertexArray
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
    currentState.scaleToPoints = Point2D(pointSize.w/abs(right-left), pointSize.h/abs(top-bottom))
  }
  
  func saveState() {
    currentState.program = program.state
    stateStack.append(currentState)
    glPushGroupMarkerEXT(0, "Entering State Group " + String(stateStack.count))
  }
  func restoreState() {
    guard let state = stateStack.popLast() else {
      fatalError("Run out of states")
    }
    glPushGroupMarkerEXT(0, "Restoring previous state's state")
    if currentState.array != state.array {
      glBindVertexArray(state.array)
    }
    if currentState.framebuffer != state.framebuffer {
      bind(state.framebuffer, clear: false)
//      if state.framebuffer.name == 0 {
//        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), defaultFramebuffer)
//      } else {
//        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), state.framebuffer.name)
//      }
    }
    if currentState.texture != state.texture {
//      bind(state.texture)
      glBindTexture(GLenum(GL_TEXTURE_2D), state.texture)
    }
    if currentState.vertexArray != state.vertexArray {
      //glBindBuffer(GLenum(GL_ARRAY_BUFFER), state.vertexArray.name)
      bind(state.vertexArray)
    }

    if currentState.stencilTesting != state.stencilTesting {
      if state.stencilTesting {
        glEnable(GLenum(GL_STENCIL_TEST))
      } else {
        glDisable(GLenum(GL_STENCIL_TEST))
      }
    }
    if let ps = state.program {
      program.state = ps
    }
    currentState = state
    currentState.program = nil
    glPopGroupMarkerEXT()
    glPopGroupMarkerEXT()
  }
  
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
    if currentState.array == array.name {
      return
    }
    // If we are moving away from a color array, then enable the default
    if currentState.usingColorAttrib && !array.usesColor {
      glVertexAttrib3f(program.attributes.color, 1, 1, 1)
    }

    glBindVertexArray(array.name)
    currentState.array = array.name
  }
  
  
  func bind(buffer : Framebuffer, clear : Bool = true) {
    if currentState.framebuffer.name == buffer.name {
      return
    }
    let name = buffer.name == 0 ? defaultFramebuffer : buffer.name
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), name)
    currentState.framebuffer = buffer
    let size = name == defaultFramebuffer ? screenSizePhysical : buffer.size
    glViewport(0, 0, GLsizei(size.w), GLsizei(size.h))
    renderTargetPixels = size
    
    // Clear the framebuffer, unless we are asked not to
    if clear {
      glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_STENCIL_BUFFER_BIT))
    }
    // If we have no stencil buffer, ensure we don't stencil test
    if buffer.stencil == 0 && buffer.name != 0 {
      UnconstrainDrawing()
    }

  }
  
  func bind(texture : Texture) {
    if texture.name == 0 {
      bind(blankTexture)
      return
    }
    let name = texture.name
    if name != currentState.texture {
      glBindTexture(texture.target, name)
      program.setUVProperties()
    }
  }
  

  func forceBind(buffer : Framebuffer) {
    let name = buffer.name == 0 ? defaultFramebuffer : buffer.name
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), name)
    currentState.framebuffer = buffer
  }
  
  func getCurrentFramebuffer() -> Framebuffer {
    return currentState.framebuffer
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
        let indices = (cyc_mod(v-1, m: remaining.count), v, cyc_mod(v+1, m: remaining.count))
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
  
//  func LoadTriangles(triangles : [Triangle<Point2D>]) -> Drawable
//  {
//    var vertexList : [Point2D] = []
//    for tri in triangles {
//      vertexList.append(tri.p1)
//      vertexList.append(tri.p2)
//      vertexList.append(tri.p3)
//    }
//    return LoadVertices(.Triangles, vertices: vertexList)
//  }

  func LoadTriangles<T : Point>(triangles : [Triangle<T>], texture: Texture? = nil) -> Drawable
  {
    var vertexList : [T] = []
    for tri in triangles {
      vertexList.append(tri.p1)
      vertexList.append(tri.p2)
      vertexList.append(tri.p3)
    }
    var data = vertexList.flatMap({$0.flatten()})
    let array = createVertexArray(positions: T.vertexAttributes.pts, textures: T.vertexAttributes.tex, color: T.vertexAttributes.col)
    glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*data.count, &data, GLenum(GL_STREAM_DRAW))
    return SimpleMesh(array: array, texture: texture, vertexType: .Triangles, bufferOffset: 0, bufferCount: GLuint(vertexList.count), color: nil)
  }

//  func LoadTriangles(triangles : [Triangle<TexturedPoint3D>], texture: Texture, color: Color4? = nil) -> Drawable
//  {
//    var data = triangles.flatMap { (tri) -> [GLfloat] in
//      var flat : [Float] = []
//      flat.appendContentsOf(tri.p1.flatten())
//      flat.appendContentsOf(tri.p2.flatten())
//      flat.appendContentsOf(tri.p3.flatten())
//      return flat.map({ GLfloat($0) })
//    }
//    let array = createVertexArray(positions: 3, textures: 2)
//    glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*data.count, &data, GLenum(GL_STATIC_DRAW))
//    return SimpleMesh(array: array, texture: texture, vertexType: .Triangles, bufferOffset: 0, bufferCount: GLuint(triangles.count*3), color:color)
//  }

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
    currentState.stencilTesting = true
  }
  func ConstrainDrawing(bounds : Bounds) {
    startWritingStencilBuffer()
    DrawSquare(bounds.left, bottom: bounds.bottom, right: bounds.right, top: bounds.top)
    stopWritingStencilBuffer()
    currentState.stencilTesting = true
  }

  func UnconstrainDrawing() {
    currentState.stencilTesting = false
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
