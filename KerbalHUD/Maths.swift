//
//  Maths.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 18/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

public let π : GLfloat = GLfloat(M_PI)

func BUFFER_OFFSET(i: Int) -> UnsafePointer<Void> {
  let p: UnsafePointer<Void> = nil
  return p.advancedBy(i)
}

/// A real, cyclic mod
public func cyc_mod(x: Int, m : Int) -> Int {
  let rem = x % m;
  return rem < 0 ? rem + m : rem
}
public func cyc_mod(x: Float, m : Float) -> Float {
  let rem = x % m;
  return rem < 0 ? rem + m : rem
}
public func cyc_mod(x: Double, m : Double) -> Double {
  let rem = x % m;
  return rem < 0 ? rem + m : rem
}

