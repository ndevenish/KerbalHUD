//
//  SimpleStructures.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 27/08/2015.
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

struct Size2D<T where T : FloatConvertible> {
  var w : T
  var h : T
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
}


//  func scaleForFitInto(maxSize : Size2D) -> Float {
//    if w is Float {
//      if maxSize.h is Float {
//        
//      } else {
//        
//      }
//      return (w as! Float) / (h as! Float)
//    } else if w is Int {
//      return Float(w as! Int) / Float(h as! Int)
//    }
//    fatalError()
//  }
//  func scaleForFitInto<U>(maxSize : Size2D<U>) -> Float {
//    if w is Float {
//      let W = w as! Float
//      let H = h as! Float
//      return min(maxSize.w/W, maxSize.h/H)
//    } else if w is Int {
//      return Float(w as! Int) / Float(h as! Int)
//    }
//    fatalError()
//  }
//}

//
//extension Size2D where T == Float {
//  var aspect : Float { return w/h }
//  func scaleForFitInto(maxSize : Size2D<Float>) -> Float {
//    return min(maxSize.w/w, maxSize.h/h)
//  }
//  func scaleForFitInto(maxSize : Size2D<Int>) -> Float {
//    return min(Float(maxSize.w)/w, Float(maxSize.h)/h)
//  }
//}
//
//extension Size2D where T == Int {
//  var aspect : Float { return Float(w)/Float(h) }
//  func scaleForFitInto(maxSize : Size2D<Float>) -> Float {
//    return min(maxSize.w/Float(w), maxSize.h/Float(h))
//  }
//  func scaleForFitInto(maxSize : Size2D<Int>) -> Float {
//    return min(Float(maxSize.w)/Float(w), Float(maxSize.h)/Float(h))
//  }
//}