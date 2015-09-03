//
//  RPMTextFile.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 03/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

protocol PageEntry {
  
}

struct EmptyString : PageEntry {
  var length : Int
}

struct FixedString : PageEntry {
  var text : String
}
struct FormatEntry : PageEntry {
  var text : String
}

struct UnprocessedStringEntry : PageEntry {
  var text : String
}

struct ColorTag : PageEntry {
  var text : String
}
struct NudgeTag : PageEntry {
  var value : Point2D
}

class RPMTextFile {
  convenience init(file : NSURL) {
    let data = NSData(contentsOfURL: file)
    let s = NSString(bytes: data!.bytes, length: data!.length, encoding: NSUTF8StringEncoding)! as String
    self.init(data: s)
  }
  
  
  init(data : String) {
    // old : ^(.+)\\$&\\$\\s*(.+)$
    //^(.+?)(?:\$&\$\s*(.+))?$
    let reSplit = try! NSRegularExpression(pattern: "^(.+?)(?:\\$&\\$\\s*(.+))?$", options: NSRegularExpressionOptions())
    
//    for line in data.s
    let lines = data.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
    for line in lines {
      var lineEntries : [PageEntry] = []
      if let match = reSplit.firstMatchInString(line, options: NSMatchingOptions(), range: NSRange(location: 0, length: line.characters.count)) {
        let nss = line as NSString
        let variables = nss.substringWithRange(match.rangeAtIndex(2))
          .componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let formatString = nss.substringWithRange(match.rangeAtIndex(1))
        lineEntries.appendContentsOf(parseWholeFormattingLine(formatString, variables: variables))
      } else {
        // No formatting variables. pass the whole thing
        lineEntries.appendContentsOf(parseWholeFormattingLine(line, variables: []))
      }
      print ("Processed line: ", lineEntries)
    }
  }
  
  func parseWholeFormattingLine(line : String, variables : [String]) -> [PageEntry] {
    let nss = line as NSString
    var entries : [PageEntry] = []
    let formatRE = try! NSRegularExpression(pattern: "\\{([^\\}]+)\\}", options: NSRegularExpressionOptions())
    // Split all formatting out of this, iteratively
    var position = 0
    for match in
      formatRE.matchesInString(line, options: NSMatchingOptions(), range: NSRange(location: 0, length: nss.length))
    {
      if match.range.location > position {
        let s = nss.substringWithRange(NSRange(location: position, length: match.range.location-position))
        // Process anything between the position and this match
        entries.appendContentsOf(parsePotentiallyTaggedString(s as String))
        position = match.range.location
      }
      // Append an entry for this variable
      entries.append(parseFormatString(nss.substringWithRange(match.rangeAtIndex(1)), variables: variables))
      position = match.range.location + match.range.length
    }
    if position != nss.length {
      let remaining = nss.substringFromIndex(position)
      entries.appendContentsOf(parsePotentiallyTaggedString(remaining))
    }

    return entries
  }
  
  func parseFormatString(fragment : String, variables : [String]) -> PageEntry {
    return FormatEntry(text: fragment)
  }
  
  /// Parse a string that contains no variables {} but may contain tags
  func parsePotentiallyTaggedString(fragment : String) -> [PageEntry] {
    var entries : [PageEntry] = []
    // Handle square bracket escaping
    let fragment = fragment.stringByReplacingOccurrencesOfString("[[", withString: "[")
    let tagRE = try! NSRegularExpression(pattern: "\\[([@\\#hs\\/].+?)\\]", options: NSRegularExpressionOptions())
    let matches = tagRE.matchesInString(fragment,
      options: NSMatchingOptions(), range: NSRange(location: 0, length: fragment.characters.count))
    var position = 0
    for match in matches
    {
      // Handle any intermediate text
      if match.range.location > position {
        let subS = (fragment as NSString).substringWithRange(NSRange(location: position, length: match.range.location-position))
        entries.appendContentsOf(processStringEntry(subS))
        position = match.range.location
      }
      // Handle the tag type
      entries.append(processTag((fragment as NSString).substringWithRange(match.rangeAtIndex(1))))
      position += match.range.length
    }
    if position < fragment.characters.count {
      let subS = (fragment as NSString).substringFromIndex(position)
      entries.appendContentsOf(processStringEntry(subS))
    }
    
    return entries
  }

  func lengthOfSpacesAtFrontOf(string : String) -> UInt {
    var charCount : UInt = 0
    var idx = string.startIndex
    while string[idx] == " " as Character {
      charCount += 1
      if idx == string.endIndex {
        break
      }
      idx = idx.advancedBy(1)
    }
    return charCount
  }
  
  /// Takes a plain string entry, and splits into an array of potential
  /// [Whitespace] [String] [Whitespace] entries
  func processStringEntry(var fragment : String) -> [PageEntry] {
    if fragment.isWhitespace() {
      return [EmptyString(length: fragment.characters.count)]
    }
    
    var entries : [PageEntry] = []
    let startWhite = lengthOfSpacesAtFrontOf(fragment)
    if startWhite > 0 {
      entries.append(EmptyString(length: Int(startWhite)))
      fragment = fragment.substringFromIndex(fragment.startIndex.advancedBy(Int(startWhite)))
    }
    let reversed = fragment.characters.reverse().reduce("", combine: { (str : String, ch : Character) -> String in
      var news = str
      news.append(ch)
      return news
    })
    let endWhite = lengthOfSpacesAtFrontOf(reversed)
    if endWhite > 0 {
      fragment = fragment.substringToIndex(fragment.endIndex.advancedBy(-Int(endWhite)))
    }
    
    entries.append(FixedString(text: fragment))
    if endWhite > 0 {
      entries.append(EmptyString(length: Int(endWhite)))
    }
    return entries
  }
  
  /// Processes the inner contents of a tag, and returns the page entry
  func processTag(fragment : String) -> PageEntry {
    let offsetRE = Regex(pattern: "@([xy])(-?\\d+)")
    if let nudge = offsetRE.firstMatchInString(fragment) {
      let res = nudge.getGroups(fragment)
      let pt : Point2D
      if res[0] == "x" {
        pt = Point2D(Float(res[1])!, 0)
      } else {
        pt = Point2D(0, Float(res[1])!)
      }
      return NudgeTag(value: pt)
    }
    fatalError()
  }
}

extension String {
  func isWhitespace() -> Bool {
    let trim = self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    return trim.characters.count == 0
  }
  func substringWithRange(range : NSRange) -> String {
    let nss = self as NSString
    return nss.substringWithRange(range)
  }
}

class Regex {
  let re : NSRegularExpression
  init(pattern: String) {
    re = try! NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions())
  }
  func firstMatchInString(string : String) -> NSTextCheckingResult? {
    let nss = string as NSString
    return re.firstMatchInString(string, options: NSMatchingOptions(), range: NSRange(location: 0, length: nss.length))
  }
}

extension NSTextCheckingResult {
  func getGroups(string : String) -> [String] {
    return (1..<self.numberOfRanges).map { string.substringWithRange(rangeAtIndex($0)) }
//    for 1..<self.numberOfRanges {
  }
}