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

private func isPolygonEar(let points : [Point2D], index : Int) -> Bool {
  let indices = (mod(index-1, m: points.count), index, mod(index+1, m: points.count))
  let triangle = (points[indices.0], points[indices.1], points[indices.2])
  
  // This vertex, v, is an ear if v-1, v, v contains no other points
  for p in 0..<points.count {
    // Skip testing points that form part of this triangle
    if p == indices.0 || p == indices.1 || p == indices.2 {
      continue
    }
    if isPointInside(points[p], x: triangle) {
      // Not an ear, as another point is inside
      return false;
    }
  }
  // If here, no other points are inside
  return true
}

/// Contains tools for drawing simple objects
class DrawingTools
{
  var program : ShaderProgram
  private var vertexArray2D : GLuint
//  private var meshes : [Mesh] = []
  private var buffers : [GLuint : BufferInfo] = [:]
  
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
      glBufferSubData(GLenum(GL_ARRAY_BUFFER), offset, size, data)
      offset += size
    }
  }
  
  init(shaderProgram : ShaderProgram) {
    program = shaderProgram
    vertexArray2D = 0
    glGenVertexArrays(1, &vertexArray2D)
    glEnableVertexAttribArray(program.attributes.position)
    glVertexAttribPointer(program.attributes.position, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)*2), BUFFER_OFFSET(0))
    glBindVertexArray(0);
  }

//  private var current_buffer : GLuint
  private func generate_buffer(size : GLsizeiptr = 1024*sizeof(GLfloat)) -> GLuint {
    var buffer : GLuint = 0
    glGenBuffers(1, &buffer)
    glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*Int(size), nil, GLenum(GL_STATIC_DRAW))
    buffers[buffer] = BufferInfo(array: vertexArray2D, index: buffer, size: sizeof(GLfloat)*Int(size), offset: 0)
    return buffer
  }
  
  private func bufferWithSpace(space : GLsizeiptr) -> GLuint
  {
    for buffer in buffers.values {
      if buffer.spaceFree >= space {
        return buffer.index
      }
    }
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
    let offset = GLuint(buffers[buffer]!.offset)
    buffers[buffer]?.write(sizeof(GLfloat)*asFloat.count, data: &asFloat)
    
    return Mesh(vertexBuffer: buffer, bufferOffset: offset, bufferCount: GLuint(vertices.count), vertexType: form.GLenum)
  }
  
  /// Convert a series of polygon points into a metadata object for drawing.
  ///
  /// It first reduces the polygon to triangles by using ear clipping.
  ///
  func Load2DPolygon(points : [Point2D]) -> Drawable2D? {
    // Calculate the signed area of this polygon
    var area : Float = 0.0
    for i in 0..<points.count {
      let iPlus = (i + 1) % points.count
      area += (points[iPlus].x-points[i].x) * (points[iPlus].y + points[i].y)
    }
    let CW = area > 0
    
    var triangles : [(Point2D,Point2D,Point2D)] = []

    // Continue until only three points remaing
    var remaining = points
    while remaining.count > 3 {
      // Step over every vertex, and check to see if it is an ear
      for v in 0..<remaining.count {
        if isPolygonEar(remaining, index: v) {
          let indices = (mod(v-1, m: points.count), v, mod(v+1, m: points.count))
          triangles.append((remaining[indices.0], remaining[indices.1], remaining[indices.2]))
          remaining.removeAtIndex(v)
          // Now go back to the beginning
          break
        }
      }
    }
    // Add the remaining triangle
    triangles.append((remaining[0], remaining[1], remaining[2]))
    
    // Now, step over each and build the GLfloat data array, in clockwise format
    var vertexList : [Point2D] = []
    for tri in triangles {
      if CW {
        vertexList.append(tri.0)
        vertexList.append(tri.1)
        vertexList.append(tri.2)
      } else {
        vertexList.append(tri.0)
        vertexList.append(tri.2)
        vertexList.append(tri.1)
      }
    }
    
    return LoadVertices(.Triangles, vertices: vertexList)
  }
  
  func Draw(item : Drawable2D) {
    let mesh = item as! Mesh
    glBindVertexArray(buffers[mesh.vertexBuffer]!.array)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), mesh.vertexBuffer)
    glDrawArrays(mesh.vertexType, GLint(mesh.bufferOffset), GLint(mesh.bufferCount))
  }
  
}