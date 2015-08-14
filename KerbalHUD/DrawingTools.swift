//
//  DrawingKit.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

protocol Drawable2D {
  
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

typealias Point2D = (x: Float, y: Float)
typealias Triangle = (Point2D, Point2D, Point2D)

/// A real, cyclic mod
private func mod(x : Int, m : Int) -> Int {
  let rem = x % m
  return rem < 0 ? rem + m : rem
}

/// Use barycentric coordinates to determine if a point is inside a triangle
func isPointInside(p : Point2D, x : (a: Point2D, b: Point2D, c: Point2D)) -> Bool {
  let area = 0.5 * (-x.b.y*x.c.x  + x.a.y*(x.c.x-x.b.x) + x.a.x*(x.b.y - x.c.y) + x.b.x*x.c.y)
  
  let s = (x.a.y*x.c.x - x.a.x*x.c.y + (x.c.y - x.a.y)*p.x + (x.a.x - x.c.x)*p.y) / (2*area)
  let t = (x.a.x*x.b.y - x.a.y*x.b.x + (x.a.y - x.b.y)*p.x + (x.b.x - x.a.x)*p.y) / (2*area)
  let u = 1-s-t
  
  return s>0 && t>0 && u>0
}

private func isPointConvex(let points : [Point2D], index : Int) -> Bool
{
  let indices = (mod(index-1, m: points.count), index, mod(index+1, m: points.count))
  let x = (a: points[indices.0], b: points[indices.1], c: points[indices.2])
  let area = 0.5 * (-x.b.y*x.c.x  + x.a.y*(x.c.x-x.b.x) + x.a.x*(x.b.y - x.c.y) + x.b.x*x.c.y)
  return area < 0
}

private func isPolygonEar(let points : [Point2D], index : Int) -> Bool {
  let indices = (mod(index-1, m: points.count), index, mod(index+1, m: points.count))
  let triangle = (points[indices.0], points[indices.1], points[indices.2])
  
  if !isPointConvex(points, index: index) {
    return false
  }
  
  // This vertex, v, is an ear if v-1, v, v contains no other points
  for p in 0..<points.count {
    // Skip testing points that form part of this triangle
    if p == indices.0 || p == indices.1 || p == indices.2 {
      continue
    }
    if isPointInside(points[p], x: triangle) {
      // Not an ear, as another point is inside
      return false
    }
  }
  // If here, no other points are inside
  return true
}

/// Contains tools for drawing simple objects
class DrawingTools
{
  var program : ShaderProgram
  var vertexArray2D : GLuint = 0
//  private var meshes : [Mesh] = []
  private var buffers : [GLuint : BufferInfo] = [:]
  
  private var meshSquare : Mesh?
  
  private struct BufferInfo {
    let array : GLuint
    let index : GLuint
    let size : GLsizeiptr
    var offset : GLintptr = 0
    var spaceFree : GLsizeiptr {
      return size-offset
    }
    mutating func write(size : GLsizeiptr, data : UnsafePointer<Void>) {
      assert(spaceFree >= size)
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), index)
      glBufferSubData(GLenum(GL_ARRAY_BUFFER), offset, size, data)
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
      offset += size
    }
  }
  init(shaderProgram : ShaderProgram) {
    program = shaderProgram
    
    // Generate the array, but wait for a buffer to set it up
    vertexArray2D = 0
    glGenVertexArrays(1, &vertexArray2D)
    glBindVertexArray(vertexArray2D);

    // Create an initial buffer
    let buffer = generate_buffer()
    
    // Now create the vertex array
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
    glEnableVertexAttribArray(program.attributes.position)
    glVertexAttribPointer(program.attributes.position, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)*2), BUFFER_OFFSET(0))
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
    glBindVertexArray(0);
    
    // Load a basic set of square vertices
    let sqVpoints : [Point2D] = [
      (0,0),(0,1),(1,0),(1,1)
    ]
    meshSquare = LoadVertices(VertexRepresentation.Triangle_Strip, vertices: sqVpoints) as? Mesh

  }

//  private var current_buffer : GLuint
  private func generate_buffer(size : GLsizeiptr = 1024*sizeof(GLfloat)) -> GLuint {
    var buffer : GLuint = 0
//    glBindVertexArray(vertexArray2D)
    glGenBuffers(1, &buffer)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
    glBufferData(GLenum(GL_ARRAY_BUFFER), size, nil, GLenum(GL_STATIC_DRAW))
    buffers[buffer] = BufferInfo(array: vertexArray2D, index: buffer, size: sizeof(GLfloat)*Int(size), offset: 0)
//    glBindVertexArray(0)
    return buffer
  }
  
  private func bufferWithSpace(space : GLsizeiptr) -> GLuint
  {
    for buffer in buffers.values {
      if buffer.spaceFree >= space {
        return buffer.index
      }
    }
    print ("Cannot find space, generating new buffer")
//    return generate_buffer(space)
    if space > 1024*sizeof(GLfloat) {
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
    let offset = GLuint(buffers[buffer]!.offset) / GLuint(sizeof(GLfloat)) / 2
    buffers[buffer]!.write(sizeof(GLfloat)*asFloat.count, data: &asFloat)
    
    return Mesh(vertexBuffer: buffer, bufferOffset: offset, bufferCount: GLuint(vertices.count), vertexType: form.GLenum)
  }
  
  // Converts a polygon into triangles
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
    
    while remaining.count > 3 {
      if lastRemaining == remaining.count {
        print ("Didn't remove any ears!!!! Error!!!!")
        break
      }
      lastRemaining = remaining.count
      // Step over every vertex, and check to see if it is an ear
      for v in 0..<remaining.count {
        if isPolygonEar(remaining, index: v) {
          let indices = (mod(v-1, m: remaining.count), v, mod(v+1, m: remaining.count))
          triangles.append(Triangle(remaining[indices.0], remaining[indices.1], remaining[indices.2]))
          remaining.removeAtIndex(v)
          // Now go back to the beginning
          break
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
  
  func Draw(item : Drawable2D) {
    let mesh = item as! Mesh
    glBindVertexArray(buffers[mesh.vertexBuffer]!.array)
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
  
  
  //    withUnsafePointer(&mvp, {
  //      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
  //    })
  //    let mesh = meshes[MESH_SQUARE]
  //    glDrawArrays(GLenum(GL_TRIANGLES), mesh.offset, mesh.size)
  //  }
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
