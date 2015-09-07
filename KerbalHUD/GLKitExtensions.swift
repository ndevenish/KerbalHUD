//
//  GLKitExtensions.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

infix operator • {}
infix operator ± {}

prefix func -(of: GLKVector3) -> GLKVector3 {
  return GLKVector3MultiplyScalar(of, -1)
}

func +(left: GLKVector3, right: GLKVector3) -> GLKVector3 {
  return GLKVector3Add(left, right)
}

func -(left: GLKVector3, right: GLKVector3) -> GLKVector3 {
  return GLKVector3Subtract(left, right)
}
func *(left: GLKVector3, right: GLfloat) -> GLKVector3 {
  return GLKVector3MultiplyScalar(left, right)
}
func *(left: GLfloat, right: GLKVector3) -> GLKVector3 {
  return GLKVector3MultiplyScalar(right, left)
}

func •(left: GLKVector3, right: GLKVector3) -> GLfloat {
  return GLKVector3DotProduct(left, right)
}

func ±(left: GLfloat, right: GLfloat) -> (GLfloat, GLfloat) {
  return (left + right, left - right)
}

func *(left: GLKMatrix4, right: GLKVector3) -> GLKVector3 {
  return GLKMatrix4MultiplyVector3(left, right)
}

func *(left: GLKMatrix4, right: GLKMatrix4) -> GLKMatrix4 {
  return GLKMatrix4Multiply(left, right)
}


extension GLKVector3 {
  var length : GLfloat {
    return GLKVector3Length(self)
  }
  static var eX : GLKVector3 { return GLKVector3Make(1, 0, 0) }
  static var eY : GLKVector3 { return GLKVector3Make(0, 1, 0) }
  static var eZ : GLKVector3 { return GLKVector3Make(0, 0, 1) }
}

extension GLKVector3 : CustomStringConvertible {
  public var description : String {
    return NSStringFromGLKVector3(self)
  }
}
