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

private class Mesh : Drawable2D {
  // Need array here? Probably not, as anything in the same buffer
  // should match formats
  //  var vertexArray  : GLuint = 0
  var vertexBuffer : GLuint = 0
  var buffferIndex : GLuint = 0
  var bufferCount  : GLuint = 0
  var vertexType : GLenum = GLenum(GL_INVALID_ENUM)
}

enum VertexRepresentation {
  case Points
  case Line_Strip
  case Line_Loop
  case Lines
  case Triangle_Strip
  case Triangle_Fan
  case Triangles
}

typealias Point2D = (x: Float, y: Float)


/// Contains tools for drawing simple objects
class DrawingTools
{
  private let meshes : [Mesh] = []
  
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
  
  // Takes a list of 2D vertices and converts them into a drawable representation
  func LoadVertices(form : VertexRepresentation, vertices : [Point2D]) -> Drawable2D? {
    return nil
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
  
}