//
//  Meshes.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 15/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit


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

struct SimpleMesh : Mesh {
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
func isPointConvex(let points : [Point2D], index : Int) -> TriangleClassification
{
  let indices = (cyc_mod(index-1, m: points.count), index, cyc_mod(index+1, m: points.count))
  let x = (a: points[indices.0], b: points[indices.1], c: points[indices.2])
  let area = 0.5 * (-x.b.y*x.c.x  + x.a.y*(x.c.x-x.b.x) + x.a.x*(x.b.y - x.c.y) + x.b.x*x.c.y)
  return area < 0 ? .Closed : (area > 0 ? .Open : .Degenerate)
}

func isPolygonEar(let points : [Point2D], index : Int) -> Bool {
  let indices = (cyc_mod(index-1, m: points.count), index, cyc_mod(index+1, m: points.count))
  let triangle = (points[indices.0], points[indices.1], points[indices.2])
  
  let classify = isPointConvex(points, index: index)
  if classify == .Open {
    return false
  } else if classify == .Degenerate {
    return true
  }
  
  // This vertex, v, is an ear if v-1, v, v contains no other points
  for p in 0..<points.count {
    // Skip testing points that form part of this triangle
    if p == indices.0 || p == indices.1 || p == indices.2 {
      continue
    }
    if isPointInside(points[p], x: triangle) {
      return false
    }
  }
  // If here, no other points are inside
  return true
}


