//
//  StringFormat.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 03/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

private let formatRegex = Regex(pattern: "{(\\d+)(?:,(\\d+))?(?::(.+?))?}")
private let sipRegex = Regex(pattern: "SIP(_?)(0?)(\\d+)(?:\\.(\\d+))?")

enum StringFormatError : ErrorType {
  case InvalidIndex
  case InvalidAlignment
}

private func downcastToDouble(val : Any) -> Double {
  let db : Double
  if val is Float {
    db = Double(val as! Float)
  } else if val is Double {
    db = val as! Double
  } else if val is Int {
    db = Double(val as! Int)
  } else {
    fatalError()
  }
  return db
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
  
  let leadingExponent = max(0, Int(floor(log10(abs(value)))))
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
//  let requiredIncludingDecimal = requiredCharacters + (precision > 0 ? precision + 1 : 0)
//  double scaledInputValue = Math.Round(inputValue / Math.Pow(10.0, siExponent), postDecimal);
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
  if length > currentLength && zeros {
    let insertPoint = value < 0 ? 1 : 0
    let fillString = String(count: length-currentLength, repeatedValue: Character("0"))
    parts.insert(fillString, atIndex: insertPoint)
  }
  return parts.joinWithSeparator("")
}

extension String {
  func Format(formatString : String, _ args: Any...) throws -> String {
    var returnString = ""
    
    // Compose the string with the regex formatting
    for match in formatRegex.matchesInString(formatString) {
      guard let index = Int(match.groups[0]) else {
        throw StringFormatError.InvalidIndex
      }
      guard let alignment = Int(match.groups[1]) else {
        throw StringFormatError.InvalidAlignment
      }
      let format = match.groups[2]

      let postFormat : String
      if format.hasPrefix("SIP") {
        let val = downcastToDouble(args[index])
        postFormat = processSIPFormat(val, formatString: format)
      }
      
      // Pad with alignment!
      
    }
    return ""
  }
}