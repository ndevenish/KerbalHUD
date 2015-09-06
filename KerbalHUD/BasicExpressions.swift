//
//  BasicExpressions.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 06/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation


enum ExpressionError : ErrorType {
  case MissingVariable(varname : String)
  case CannotCoerce(from : String, to : NaturalType)
}

protocol BooleanExpression {
  /// Uses a data dictionary to evaluate the provided expression
  var variables : [String]  { get }
  func evaluate(data : [String : Any]) throws -> Bool
}

//enum LexicalTokens {
//  case Identifier(String)
//  case Negation
//}

//private func parseString(string : String) -> [LexicalTokens] {
// return []
//}

private struct TrueExpression : BooleanExpression {
  let variables : [String] = []
  func evaluate(data: [String : Any]) -> Bool {
    return true
  }
}

private struct SimpleBooleanExpression : BooleanExpression {
  var negated : Bool
  var variable : String
  var variables : [String] { return [variable] }
  
  func evaluate(data : [String : Any]) throws -> Bool {
    guard let val = data[variable] as? BoolCoercible else {
      if let badData = data[variable] {
        throw ExpressionError.CannotCoerce(from: String(badData), to: .Boolean)
      }
      throw ExpressionError.MissingVariable(varname: variable)
    }
    if negated {
      return !val.asBoolValue
    } else {
      return val.asBoolValue
    }
  }
}

class ExpressionParser {
  static func parseBooleanExpression(expression string: String) throws -> BooleanExpression {
    if string == "true" {
      return TrueExpression()
    }
    let invert = string.hasPrefix("!")
    let varname = !invert ? string : string.substringFromIndex(string.startIndex.advancedBy(1))
    return SimpleBooleanExpression(negated: invert, variable: varname)
  }
}