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
  
  var size : Size2D<Float> { get }
}

struct ErrorBounds : Bounds {
  var left : Float { fatalError() }
  var right : Float { fatalError() }
  var bottom : Float { fatalError() }
  var top : Float { fatalError() }
  var width : Float { fatalError() }
  var height : Float { fatalError() }
  
  var size : Size2D<Float> { fatalError() }
}
struct FixedBounds : Bounds, Equatable {
  var left : Float
  var right : Float
  var top : Float
  var bottom : Float
  
  var width : Float { return abs(right-left) }
  var height : Float { return abs(top-bottom) }
  
  var size : Size2D<Float> { return Size2D(w: width, h: height) }
  
  init(left: Float, bottom: Float, right: Float, top: Float) {
    self.left = left
    self.bottom = bottom
    self.right = right
    self.top = top
  }
  init(left: Float, bottom: Float, width: Float, height: Float) {
    self.left = left
    self.bottom = bottom
    self.right = left+width
    self.top = bottom+height
  }
  
  init(bounds : Bounds) {
    left = bounds.left
    right = bounds.right
    top = bounds.top
    bottom = bounds.bottom
  }
}

func ==(first : FixedBounds, second: FixedBounds) -> Bool {
  return first.left == second.left && first.right == second.right
    && first.bottom == second.bottom && first.top == second.top
}


struct BoundsInterpolator : Bounds {
  var left : Float { return start.left + (end.left-start.left)*Float(clock.fraction) }
  var right : Float { return start.right + (end.right-start.right)*Float(clock.fraction) }
  var top : Float { return start.top + (end.top-start.top)*Float(clock.fraction) }
  var bottom : Float { return start.bottom + (end.bottom-start.bottom)*Float(clock.fraction) }
  
  var width : Float { return abs(right-left) }
  var height : Float { return abs(top-bottom) }
  var size : Size2D<Float> { return Size2D(w: width, h: height) }
  
  var start : Bounds
  var end : Bounds
  var clock : Timer
  
  init(from: Bounds, to: Bounds, seconds: Double) {
    start = FixedBounds(bounds: from)
    end = FixedBounds(bounds: to)
    clock = Clock.createTimer(.Animation, duration: seconds)
  }
}

extension Bounds {
  func contains(point: Point2D) -> Bool {
    return left <= point.x && right >= point.x && top >= point.y && bottom <= point.y
  }
}