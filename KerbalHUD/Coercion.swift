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
}

extension Float : DoubleCoercible {
  var asDoubleValue : Double { return Double(self) }
  var naturalType : NaturalType { return .Floating }
}

extension Double : DoubleCoercible {
  var asDoubleValue : Double { return self }
  var naturalType : NaturalType { return .Floating }
}

extension Int : DoubleCoercible, BoolCoercible {
  var asDoubleValue : Double { return Double(self) }
  var asBoolValue : Bool { return self != 0 }
  var naturalType : NaturalType { return .Integer }
}

extension NSNumber : DoubleCoercible, BoolCoercible, IntCoercible {
  var asDoubleValue : Double { return self.doubleValue }
  var asIntValue : Int { return self.integerValue }
  var asBoolValue : Bool { return self.boolValue }
  var naturalType : NaturalType { return .Floating }
}

extension String : Coercible {
  var naturalType : NaturalType { return .String }
}