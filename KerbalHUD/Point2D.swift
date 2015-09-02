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

public func +(left: Point2D, right: Point2D) -> Point2D {
  return Point2D(x: left.x+right.x, y: left.y+right.y)
}
