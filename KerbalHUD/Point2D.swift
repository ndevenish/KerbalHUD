//
//  Point2D.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 28/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import CoreGraphics

public protocol Point {
  func +(lhs: Self, rhs: Self) -> Self
  func flatten() -> [Float]
}
//protocol Summable { }
public struct Point2D : Point, NilLiteralConvertible {
  var x : Float
  var y : Float
  
  public init(fromCGPoint: CGPoint) {
    x = Float(fromCGPoint.x)
    y = Float(fromCGPoint.y)
  }

  init(_ x: Float, _ y: Float) {
    self.x = x
    self.y = y
  }

  public init(x: Float, y: Float) {
    self.x = x
    self.y = y
  }
  
  public init(nilLiteral: ()) {
    x = 0
    y = 0
  }
  public func flatten() -> [Float] {
    return [x, y]
  }
}

public struct TexturedPoint2D : Point {
  var x : Float
  var y : Float
  var u : Float
  var v : Float
  
  public init(_ x: Float, _ y: Float, u: Float, v: Float) {
    self.x = x
    self.y = y
    self.u = u
    self.v = v
  }
  public func flatten() -> [Float] {
    return []
  }
}
public func +(left: Point2D, right: Point2D) -> Point2D {
  return Point2D(x: left.x+right.x, y: left.y+right.y)
}

public func +(left: TexturedPoint2D, right: TexturedPoint2D) -> TexturedPoint2D {
  return TexturedPoint2D(left.x+right.x, left.y+right.y, u: left.u+right.u, v: left.v+right.v)
}


func ShiftTriangle<T : Point>(base : Triangle<T>, shift : T) -> Triangle<T> {
  return Triangle(base.p1 + shift, base.p2 + shift, base.p3 + shift)
}
func ShiftTriangles<T : Point>(base : [Triangle<T>], shift : T) -> [Triangle<T>] {
  return base.map({ ShiftTriangle($0, shift: shift) });
}

