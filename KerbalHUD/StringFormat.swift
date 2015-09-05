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

  if !value.isFinite {
    return String(value)
  }
  // Handle degenerate values (NaN, INF)
  // We should return the string of requested length if we can even then.
  // Which is why we parse the format string first.
//  if (double.IsInfinity(inputValue) || double.IsNaN(inputValue))
//  {
//    int blankLength;
//    if (formatData.IndexOf('.') > 0)
//    {
//      string[] tokens = formatData.Split('.');
//      Int32.TryParse(tokens[0], out blankLength);
//    }
//    else
//    {
//      Int32.TryParse(formatData, out blankLength);
//    }
//    return (inputValue + " ").PadLeft(blankLength);
//  }
//  
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
  static func Format(formatString : String, _ args: Any...) throws -> String {
    return try Format(formatString, argList: args)
  }
  static func Format(formatString : String, argList args: [Any]) throws -> String {
    var returnString = ""
    let nsS = formatString as NSString
    var position = 0
    
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

      var postFormat : String
      if format.hasPrefix("SIP") {
        let val = downcastToDouble(args[index])
        postFormat = processSIPFormat(val, formatString: format)
      } else if format.hasPrefix("DMS") {
        print("Warning: DMS not handled")
        postFormat = String(args[index])
      } else if format.hasPrefix("KDT") || format.hasPrefix("MET") {
        print("Warning: KDT/MET not handled")
        postFormat = String(args[index])
      } else {
        fatalError()
      }
      
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