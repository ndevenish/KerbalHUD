//
//  Bounds.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 28/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

protocol Bounds {
  var left   : Float { get }
  var bottom : Float { get }
  var right  : Float { get }
  var top    : Float { get }
  var height : Float { get }
  var width  : Float { get }
}

struct ErrorBounds : Bounds {
  var left : Float { fatalError() }
  var right : Float { fatalError() }
  var bottom : Float { fatalError() }
  var top : Float { fatalError() }
  var width : Float { fatalError() }
  var height : Float { fatalError() }
}
struct FixedBounds : Bounds {
  var left : Float
  var right : Float
  var top : Float
  var bottom : Float
  
  var width : Float { return abs(right-left) }
  var height : Float { return abs(top-bottom) }
  
  init(left: Float, bottom: Float, right: Float, top: Float) {
    self.left = left
    self.bottom = bottom
    self.right = right
    self.top = top
  }
  
}
