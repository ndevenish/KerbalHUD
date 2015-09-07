//
//  Colors.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 03/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit
//typealias Color4 = (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)

//protocol Color {
//  var r : GLfloat { get }
//  
//}

struct Color4 {
  var r : GLfloat
  var g : GLfloat
  var b : GLfloat
  var a : GLfloat
  
  init(r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat = 1) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }
  init(_ r: GLfloat, _ g: GLfloat, _ b: GLfloat, _ a: GLfloat = 1) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }
  init(fromByteR: UInt, g: UInt, b: UInt) {
    self.r = Float(fromByteR)/255.0
    self.g = Float(g)/255.0
    self.b = Float(b)/255.0
    self.a = 1
  }
  
}

extension Color4 {
  static var White : Color4 { return Color4(r: 1, g: 1, b: 1, a: 1) }
  static var Black : Color4 { return Color4(r: 0, g: 0, b: 0, a: 1) }
  static var Green : Color4 { return Color4(r: 0, g: 1, b: 0, a: 1) }
  static var Red : Color4 { return Color4(r: 1, g: 0, b: 0, a: 1) }
}

extension Color4 : Coercible {
  var naturalType : NaturalType { return .String }
  static func coerceTo(from: Any) -> Color4? {
    if from is Color4 {
      return from as? Color4
    } else if from is String {
      // We will handle this, but not yet
      fatalError()
    }
    return nil
  }
}