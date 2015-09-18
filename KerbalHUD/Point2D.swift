//
//  Point2D.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 28/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import CoreGraphics
import GLKit

public protocol Point {
  func flatten() -> [Float]
  static var vertexAttributes : VertexAttributes { get }
}

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
  
  public static var vertexAttributes = VertexAttributes(pts: 2, tex: 0, col: false)
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
    return [x, y, u, v]
  }

  public static var vertexAttributes = VertexAttributes(pts: 2, tex: 2, col: false)
}

public struct TexturedColoredPoint2D : Point {
  var x : Float
  var y : Float
  var u : Float
  var v : Float
  var color : Color4
  
  init(_ x: Float, _ y: Float, u: Float, v: Float, color: Color4) {
    self.x = x
    self.y = y
    self.u = u
    self.v = v
    self.color = color
  }
  
  public func flatten() -> [Float] {
    // Convert the rgba to a single float
    let r = UInt8(color.r * 255)
    let g = UInt8(color.g * 255)
    let b = UInt8(color.b * 255)
    let a = UInt8(color.a * 255)
    let bytes:[UInt8] = [r, g, b, a]
    let f32 = UnsafePointer<Float>(bytes).memory
    // Flattened!
    return [x, y, u, v, f32]
  }
  
  public static var vertexAttributes = VertexAttributes(pts: 2, tex: 2, col: true)
}

public func +(left: Point2D, right: Point2D) -> Point2D {
  return Point2D(x: left.x+right.x, y: left.y+right.y)
}