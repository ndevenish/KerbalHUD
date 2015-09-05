//
//  Size2D.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 28/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//


import Foundation

protocol FloatConvertible {
  var asFloat : Float { get }
}

extension Int : FloatConvertible {
  var asFloat : Float { return Float(self) }
}
extension Double : FloatConvertible {
  var asFloat : Float { return Float(self) }
}
extension Float : FloatConvertible {
  var asFloat : Float { return self }
}

struct Size2D<T where T : FloatConvertible, T: Equatable> {
  var w : T
  var h : T
}

func ==<T>(first: Size2D<T>, second: Size2D<T>) -> Bool {
  return first.w == second.w && first.h == second.h
}
  
enum SizeDimension {
  case Width
  case Height
}

extension Size2D {
  var aspect : Float {
    return w.asFloat / h.asFloat
  }
  func scaleForFitInto<U>(maxSize : Size2D<U>) -> Float {
    return min(maxSize.w.asFloat/w.asFloat, maxSize.h.asFloat/h.asFloat)
  }
  func constrainingSide<U>(maxSize : Size2D<U>) -> SizeDimension {
    if maxSize.w.asFloat/w.asFloat < maxSize.h.asFloat/h.asFloat {
      return .Width
    } else {
      return .Height
    }
  }
  var flipped : Size2D {
    
    return Size2D(w: h, h: w)
  }
  
  func map<U>(meth: (T -> U)) -> Size2D<U> {
    return Size2D<U>(w: meth(w), h: meth(h))
  }
}

func *(size: Size2D<Float>, scale: Float) -> Size2D<Float>{
  return Size2D(w: size.w*scale, h: size.h*scale)
}
func *(scale: Float, size: Size2D<Float>) -> Size2D<Float>{
  return Size2D(w: size.w*scale, h: size.h*scale)
}
func min<T : Comparable>(size : Size2D<T>) -> T {
  return min(size.w, size.h)
}

