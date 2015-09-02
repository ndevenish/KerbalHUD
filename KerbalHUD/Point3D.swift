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
}

public func +(left: Point3D, right: Point3D) -> Point3D {
  return Point3D(x: left.x+right.x, y: left.y+right.y, z: left.z+right.z)
}
