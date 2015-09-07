//
//  StringFormat.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 03/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

private let formatRegex = Regex(pattern: "\\{(\\d+)(?:,(\\d+))?(?::(.+?))?\\}")
private let sipRegex    = Regex(pattern: "SIP(_?)(0?)(\\d+)(?:\\.(\\d+))?")

enum StringFormatError : ErrorType {
  case InvalidIndex
  case InvalidAlignment
  case CannotCastToDouble
}

func downcastToDouble(val : Any) throws -> Double {
  guard let dbl = val as? DoubleCoercible else {
    fatalError()
  }
  return dbl.asDoubleValue

//  let db : Double
//  if val is Float {
//    db = Double(val as! Float)
//  } else if val is Double {
//    db = val as! Double
//  } else if val is Int {
//    db = Double(val as! Int)
//  } else if val is NSNumber {
//    db = (val as! NSNumber).doubleValue
//  } else {
//    print("Couldn't parse")
//    throw StringFormatError.CannotCastToDouble
//    return 0
////    fatalError()
//  }
//  return db
}

private func getSIPrefix(exponent : Int) -> String {
  let units = ["y", "z", "a", "f", "p", "n", "μ", "m",
    "",
    "k", "M", "G", "T", "P", "E", "Z", "Y"]
  let unitOffset = 8
  let index = min(max(exponent / 3 + unitOffset, 0), units.count-1)
  return units[index]
}

func processSIPFormat(value : Double, formatString : String) -> String {
  let matchParts = sipRegex.firstMatchInString(formatString)!
  let space = matchParts.groups[0] == "_"
  let zeros = matchParts.groups[1] == "0"
  let length = Int(matchParts.groups[2])!

  if !value.isFinite {
    return String(value)
  }
  let leadingExponent = value == 0.0 ? 0 : max(0, Int(floor(log10(abs(value)))))
  let siExponent = Int(floor(Float(leadingExponent) / 3.0))*3
  // If no precision specified, use the SI exponent
  var precision : Int = Int(matchParts.groups[3]) ?? max(0, siExponent)

  // Calculate the bare minimum characters required
  let requiredCharacters = 1 + (leadingExponent-siExponent)
    + (value < 0 ? 1 : 0) + (siExponent != 0 ? 1 : 0) + (space ? 1 : 0)

  if requiredCharacters >= length {
    // Drop decimal values since we are already over budget
    precision = 0
  } else if (precision > 0) {
    // See how many we can fit.
    precision = min(precision, (length-requiredCharacters-1))
  }
  // Scale the value to it's SI prefix
  let scaledValue = abs(value / pow(10, Double(siExponent)))
  
  var parts : [String] = []
  if value < 0 {
    parts.append("-")
  }
  parts.append(String(format: "%.\(precision)f", scaledValue))
  if space {
    parts.append(" ")
  }
  parts.append(getSIPrefix(siExponent))
  // Handle undersized
  let currentLength = parts.reduce(0, combine: {$0 + $1.characters.count })
  if length > currentLength {
    let fillCharacter = zeros ? Character("0") : Character(" ")
    let insertPoint = value < 0 && zeros ? 1 : 0
    let fillString = String(count: length-currentLength, repeatedValue: fillCharacter)
    parts.insert(fillString, atIndex: insertPoint)
  }
  return parts.joinWithSeparator("")
}

extension String {
  static func Format(formatString : String, _ args: Any...) throws -> String {
    return try Format(formatString, argList: args)
  }
  
  static func Format(var formatString : String, argList args: [Any]) throws -> String {
    var returnString = ""
    var position = 0
    // Attempt to use the built in formatting
    if formatString.containsString("%") {
      let argList = args.map { $0 is CVarArgType ? try! downcastToDouble($0) as CVarArgType : 0 }
      formatString = String(format: formatString, arguments: argList)
    }
    let nsS = formatString as NSString
    // Compose the string with the regex formatting
    for match in formatRegex.matchesInString(formatString) {
      if match.range.location > position {
        let intermediateRange = NSRange(location: position, length: match.range.location-position)
        returnString += formatString.substringWithRange(intermediateRange)
      }
      guard let index = Int(match.groups[0]) else {
        throw StringFormatError.InvalidIndex
      }
      guard index < args.count else {
        throw StringFormatError.InvalidIndex
      }
      let alignment = Int(match.groups[1])
      if !match.groups[1].isEmpty && alignment == nil {
        throw StringFormatError.InvalidAlignment
      }
      let format = match.groups[2]
      let formatValue = args[index]
      
      var postFormat = ExpandSingleFormat(format, arg: formatValue)
      
      // Pad with alignment!
      if let align = alignment where postFormat.characters.count < abs(align) {
        let difference =  abs(align) - postFormat.characters.count
        let fillString = String(count: difference, repeatedValue: Character(" "))
        if align < 0 {
          postFormat = postFormat + fillString
        } else {
          postFormat = fillString + postFormat
        }
      }
      // Append this new entry to our total string
      returnString += postFormat
      position = match.range.location + match.range.length
    }
    if position < nsS.length {
      returnString += nsS.substringFromIndex(position)
    }
    return returnString
  }
}

enum NumericFormatSpecifier : String {
  case Currency = "C"
  case Decimal = "D"
  case Exponential = "E"
  case FixedPoint = "F"
  case General = "G"
  case Number = "N"
  case Percent = "P"
  case RoundTrip = "R"
  case Hexadecimal = "X"
}

let numericPrefix = Regex(pattern: "^([CDEFGNPRX])(\\d{0,2})$")
let conditionalSeparator = Regex(pattern: "(?<!\\\\);")

private var formatComplaints = Set<String>()

private func ExpandSingleFormat(format : String, arg: Any) -> String {
  // If not format, use whatever default.
  if format.isEmpty {
    return String(arg)
  }
  // Attempt to split the format string on ; - conditionals
  let parts = conditionalSeparator.splitString(format)
  switch parts.count {
  case 1:
    // Just one entry - no splitting
    break
  case 2:
    // 0 : positive and zero, negative
    let val = try! downcastToDouble(arg)
    if val >= 0 {
      return ExpandSingleFormat(parts[0], arg: arg)
    } else {
      return ExpandSingleFormat(parts[1], arg: abs(val))
    }
  case 3:
//The first section applies to positive values, the second section applies to negative values, and the third section applies to zeros.
    let val = try! downcastToDouble(arg)
    if val == 0 {
      return ExpandSingleFormat(parts[2], arg: arg)
    } else {
      return ExpandSingleFormat(
        parts[(val > 0 || parts[1].isEmpty) ? 0 : 1],
        arg: abs(val))
    }
  default:
    // More than three. This is an error.
    fatalError()
  }
  //Axx
  let postFormat : String
  
  // Look for form AXX e.g. standard numeric formats
  if let match = numericPrefix.firstMatchInString(format.uppercaseString) {
    let formatType = NumericFormatSpecifier(rawValue: match.groups[0])!
    let precision = match.groups[1].isEmpty ? 2 : Int(match.groups[1].isEmpty)
    let value = try! downcastToDouble(arg)
    switch formatType {
    case .Percent:
      return String(format: "%.\(precision)f%%", value*100)
    default:
      fatalError()
    }
  } else if format.hasPrefix("SIP") {
    let val = try! downcastToDouble(arg)
    postFormat = processSIPFormat(val, formatString: format)
  } else if format.hasPrefix("DMS") {
    print("Warning: DMS not handled")
    postFormat = String(arg)
  } else if format.hasPrefix("KDT") || format.hasPrefix("MET") {
    if !formatComplaints.contains(format) {
      print("Warning: KDT/MET not handled: ", format)
      formatComplaints.insert(format)
    }
    postFormat = String(arg)
  } else {
    // Else, not a format we recognised. Until we are sure we
    // have complete formatting, warn about this
    if !formatComplaints.contains(format) {
      print("Unrecognised string format: ", format)
      formatComplaints.insert(format)
    }
    return format
  }
  return postFormat
}
