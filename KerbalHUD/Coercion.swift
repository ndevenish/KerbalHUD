//
//  Coercion.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 07/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

// Allows introspection to discover what the 
// natural form of a coercible is
enum NaturalType {
  case Boolean
  case Integer
  case Floating
  case String
}

protocol Coercible {
  var naturalType : NaturalType { get }
  static func coerceTo(from : Any) -> Self?
}

protocol BoolCoercible : Coercible {
  var asBoolValue : Bool { get }
}

protocol DoubleCoercible : Coercible {
  var asDoubleValue : Double { get }
}

protocol IntCoercible : Coercible {
  var asIntValue : Int { get }
}

extension Bool : BoolCoercible {
  var asBoolValue : Bool { return self }
  var naturalType : NaturalType { return .Boolean }
  static func coerceTo(from : Any) -> Bool? {
    return (from as? BoolCoercible)?.asBoolValue
  }
}

extension Float : DoubleCoercible {
  var asDoubleValue : Double { return Double(self) }
  var naturalType : NaturalType { return .Floating }
  static func coerceTo(from : Any) -> Float? {
    if let dbl = (from as? DoubleCoercible)?.asDoubleValue {
      return Float(dbl)
    }
    return nil
  }
}

extension Double : DoubleCoercible {
  var asDoubleValue : Double { return self }
  var naturalType : NaturalType { return .Floating }
  static func coerceTo(from : Any) -> Double? {
    return (from as? DoubleCoercible)?.asDoubleValue
  }
}

extension Int : DoubleCoercible, BoolCoercible {
  var asDoubleValue : Double { return Double(self) }
  var asBoolValue : Bool { return self != 0 }
  var naturalType : NaturalType { return .Integer }
  static func coerceTo(from : Any) -> Int? {
    return (from as? IntCoercible)?.asIntValue
  }
}

extension NSNumber : DoubleCoercible, BoolCoercible, IntCoercible {
  var asDoubleValue : Double { return self.doubleValue }
  var asIntValue : Int { return self.integerValue }
  var asBoolValue : Bool { return self.boolValue }
  var naturalType : NaturalType { return .Floating }
  static func coerceTo(from : Any) -> Self? {
    fatalError()
  }
}

extension String : Coercible {
  var naturalType : NaturalType { return .String }
  static func coerceTo(from: Any) -> String? {
    return String(from)
  }
}

extension JSON : Coercible, IntCoercible, DoubleCoercible, BoolCoercible {
  var naturalType : NaturalType {
    switch self.type {
    case .String:
      return .String
    case .Bool:
      return .Boolean
    case .Number:
      return .Floating
    default:
      return .String
    }
  }
  static func coerceTo(from: Any) -> JSON? {
    fatalError()
  }
  var asDoubleValue : Double { return self.doubleValue }
  var asIntValue : Int { return self.intValue }
  var asBoolValue : Bool { return self.boolValue }
}