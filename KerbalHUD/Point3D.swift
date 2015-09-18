//
//  Point3D.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 02/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
//import CoreGraphics

public struct Point3D : Point, NilLiteralConvertible {
  var x : Float
  var y : Float
  var z : Float
  
  init(_ x: Float, _ y: Float, _ z : Float) {
    self.x = x
    self.y = y
    self.z = z
  }
  
  public init(x: Float, y: Float, z: Float) {
    self.x = x
    self.y = y
    self.z = z
  }
  
  public init(nilLiteral: ()) {
    x = 0
    y = 0
    z = 0
  }
  public func flatten() -> [Float] {
    return [x, y, z]
  }
  
  public static var vertexAttributes = VertexAttributes(pts: 3, tex: 0, col: false)
}

public struct TexturedPoint3D : Point {
  var x : Float
  var y : Float
  var z : Float
  var u : Float
  var v : Float

  public init(x: Float, y: Float, z: Float, u: Float, v: Float) {
    self.x = x
    self.y = y
    self.z = z
    self.u = u
    self.v = v
  }

  public init(_ point: Point3D, u: Float, v: Float) {
    x = point.x
    y = point.y
    z = point.z
    self.u = u
    self.v = v
  }
  public init(_ point: SphericalPoint, u: Float, v: Float) {
    let c = GLKVector3Make(fromSpherical: point)
    x = c.x
    y = c.y
    z = c.z
    self.u = u
    self.v = v
  }
  public func flatten() -> [Float] {
    return [x, y, z, u, v]
  }
  public static var vertexAttributes = VertexAttributes(pts: 3, tex: 2, col: false)
}


public func +(left: Point3D, right: Point3D) -> Point3D {
  return Point3D(x: left.x+right.x, y: left.y+right.y, z: left.z+right.z)
}

public func +(left: TexturedPoint3D, right: TexturedPoint3D) -> TexturedPoint3D {
  return TexturedPoint3D(x: left.x+right.x, y: left.y+right.y, z: left.z+right.z, u: left.u+right.u, v: left.v+right.v)
}
