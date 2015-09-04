//
//  RPMTextFile.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 03/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

struct TextDrawInfo {
  var position : Point2D
  var color : Color4
  var size : Float
  var string : String
}

protocol PageEntry {
  /// Is this entry dynamic, or can it's behaviour change?
  var isDynamic : Bool { get }
  /// Is this entry always the same length?
  var isFixedLength : Bool { get }
  /// Can, or does this entry, affect state?
  var affectsState : Bool { get }
  var affectsOffset : Bool { get }
  var affectsTextScale : Bool { get }
  var affectsColor : Bool { get }
  var affectsFont : Bool { get }
  
  /// What is the length, or at least, current length
  var length : Int { get }
  var state : FormatState? { get set }
  // Position, in lines, where we would expect to start
  var position : Point2D? { get set }
  
  func process(data : IKerbalDataStore) -> TextDrawInfo
}

class FixedLengthEntry : PageEntry {
  private(set) var length : Int
  
  init(length : Int) {
    self.length = length
  }
  
  var isDynamic : Bool { return false }
  var isFixedLength : Bool { return true }
  
  var affectsState : Bool { return false }
  var affectsOffset : Bool { return false }
  var affectsTextScale : Bool { return false }
  var affectsColor : Bool { return false }
  var affectsFont : Bool { return false }

  var state : FormatState?
  var position : Point2D? = nil
  
  func process(data : IKerbalDataStore) -> TextDrawInfo {
    fatalError()
  }

}

class EmptyString : FixedLengthEntry {

}

class FixedString : FixedLengthEntry {
  private(set) var text : String

  init(text: String) {
    self.text = text
    super.init(length: text.characters.count)
  }
  
  override func process(data : IKerbalDataStore) -> TextDrawInfo {
    return TextDrawInfo(position: position!+state!.offset, color: state!.color, size: 1, string: text)
  }
}

class FormatEntry : PageEntry {
  var variable : String
  var alignment : Int
  var format : String
  
  private(set) var length : Int
  var isDynamic : Bool { return true }
  var isFixedLength : Bool { return stringFormatter.fixedLength }
  
  var affectsState : Bool { return affectsOffset || affectsTextScale || affectsColor || affectsFont }
  private(set) var affectsOffset : Bool
  private(set) var affectsTextScale : Bool
  private(set) var affectsColor : Bool
  private(set) var affectsFont : Bool
  
  var state : FormatState?
  var position : Point2D? = nil
  
  var stringFormatter : StringFormatter
  
  init(variable: String, alignment: Int, format: String) {
    self.variable = variable
    self.alignment = alignment
    self.format = format
    self.length = 0
    stringFormatter = getFormatterForString(format)
    if (stringFormatter.fixedLength) {
      self.length = stringFormatter.length
    }
    affectsColor = false
    affectsTextScale = false
    affectsFont = false
    affectsOffset = false
  }
  
  func process(data : IKerbalDataStore) -> TextDrawInfo {
    let dataVar = "rpm." + variable
    return TextDrawInfo(position: position!+state!.offset, color: state!.color, size: 1,
      string: stringFormatter.format(data[dataVar]))
  }
}

class Tag : FixedLengthEntry {
  func changeState(from: FormatState) -> FormatState {
    fatalError()
  }
  
//  var affectsOffset : Bool { return false }
//  var affectsTextScale : Bool { return false }
//  var affectsColor : Bool { return false }
//  var affectsFont : Bool { return false }
//  
  override var affectsState : Bool { return true }
  
  init() {
    super.init(length: 0)
  }
}

class ColorTag : Tag {
  var text : String
  
  override var affectsColor : Bool { return true }
  
  init(value : String) {
    text = value
  }
  
  override func changeState(from: FormatState) -> FormatState {
    fatalError()
  }
}

class NudgeTag : Tag {
  var value : Float
  var x : Bool
  init(value : Float, x : Bool) {
    self.value = value
    self.x = x
  }
  
  override var affectsOffset : Bool { return true }
  
  override func changeState(from: FormatState) -> FormatState {
    if x {
      return FormatState(prior: from, offset: Point2D(value, from.offset.y))
    } else {
      return FormatState(prior: from, offset: Point2D(from.offset.x, value))
    }
  }
}

class WidthTag : Tag {
  enum WidthType {
    case Normal
    case Half
    case Double
  }
  var type : WidthType = .Normal
  
  init(type : WidthType) {
    self.type = type
  }
  
  override var affectsTextScale : Bool { return true }
  
  override func changeState(from: FormatState) -> FormatState {
    return FormatState(prior: from, textSize: type)
  }
}

struct FormatState {
  var offset : Point2D
  var textSize : WidthTag.WidthType
  var color : Color4
  var font : String
  
  init(prior: FormatState) {
    self.offset = prior.offset
    self.textSize = prior.textSize
    self.color = prior.color
    self.font = prior.font
  }
  init(prior: FormatState, offset: Point2D) {
    self.init(prior: prior)
    self.offset = offset
  }
  init(prior: FormatState, textSize: WidthTag.WidthType) {
    self.init(prior: prior)
    self.textSize = textSize
  }
  init() {
    self.offset = Point2D(0,0)
    self.textSize = .Normal
    self.color = Color4.White
    self.font = ""
  }
}

class RPMTextFile {
  private(set) var lineHeight : Float = 0
  private(set) var screenHeight : Float = 0
  
  var fixedEntries : [PageEntry] = []
  var dynamicEntries : [PageEntry] = []
  var dynamicLines : [[PageEntry]] = []
  
  let textFileData : String
  var text : TextRenderer? = nil
  var drawing : DrawingTools? = nil
  
  convenience init(file : NSURL) {
    let data = NSData(contentsOfURL: file)
    let s = NSString(bytes: data!.bytes, length: data!.length, encoding: NSUTF8StringEncoding)! as String
    self.init(data: s)
  }
  
  
  init(data : String) {
    textFileData = data
  }
  
  func prepareTextFor(lineHeight : Float, screenHeight : Float, font : TextRenderer, tools: DrawingTools) {
    self.lineHeight = lineHeight
    self.screenHeight = screenHeight
    let fW : Float = 16//lineHeight * font.aspect * 0.5
    text = font
    drawing = tools
    
    let reSplit = try! NSRegularExpression(pattern: "^(.+?)(?:\\$&\\$\\s*(.+))?$", options: NSRegularExpressionOptions())
    
    var allLines : [[PageEntry]] = []
    //    for line in data.s
    let lines = textFileData.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
    for (i, line) in lines.enumerate() {
      var lineEntries : [PageEntry] = []
      if let match = reSplit.firstMatchInString(line, options: NSMatchingOptions(), range: NSRange(location: 0, length: line.characters.count)) {
        let nss = line as NSString
        let formatString = nss.substringWithRange(match.rangeAtIndex(1))
        let variables : [String]
        if match.rangeAtIndex(2).location != NSNotFound {
          variables = nss.substringWithRange(match.rangeAtIndex(2))
            .componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        } else {
          variables = []
        }
        print ("\(i) Vars: ", variables)
        lineEntries.appendContentsOf(parseWholeFormattingLine(formatString, variables: variables))
        //      } else {
        //        // No formatting variables. pass the whole thing
        //        lineEntries.appendContentsOf(parseWholeFormattingLine(line, variables: []))
      }
      print ("Processed line: ", lineEntries)
      allLines.append(lineEntries)
    }
    print("Done")
    
    // Now, go over each line, and reduce down to dynamic entries only
    var fixedEntries : [PageEntry] = []
    // Lines with only dynamic entries remaining
    var dynamicLines : [[PageEntry]] = []
    // Dynamic entries that do not affect state
    var dynamicEntries : [PageEntry] = []
    //    var dynamicEntries : [PageEntry] = []
    
    for (lineNum, entries) in allLines.enumerate() {
      var state : FormatState = FormatState()
      var position : Point2D = Point2D(0,Float(lineNum))
      var lineDynamics : [PageEntry] = []
      
      for (j, var entry) in entries.enumerate() {
        // Assign the current position and state
//        entry.position = position
        entry.state = state
        entry.position = Point2D(x: position.x*fW, y: screenHeight-(0.5+Float(lineNum))*lineHeight) + state.offset
        // If we have a text scale, calculate this now for width calculations
        let scale : Float = state.textSize == .Normal ? 1 : (state.textSize == .Half ? 0.5 : 2.0)
        position.x += Float(entry.length) * scale
        if entry is EmptyString {
//          position.x += Float(entry.length) * scale
        } else if entry is Tag {
          // We have something that can change state
          state = (entry as! Tag).changeState(state)
        } else if !entry.isDynamic && entry.isFixedLength {
          fixedEntries.append(entry)
        } else if entry.isFixedLength && !entry.affectsState {
          // We are dynamic, but not in a way that affects other items.
          dynamicEntries.append(entry)
//          position.x += Float(entry.length) * scale
        } else {
          // We are dynamic, or not fixed length. Skip the rest
          for iEntry in j..<entries.count {
            lineDynamics.append(entries[iEntry])
          }
          break
        }
      }
      if !lineDynamics.isEmpty {
        // Strip any empty strings off of the end
        while lineDynamics.last is EmptyString {
          lineDynamics.removeLast()
        }
        // If a single entry, just shove onto the dynamic pile
        if lineDynamics.count == 1 {
          dynamicEntries.append(lineDynamics.first!)
        } else {
          dynamicLines.append(lineDynamics)
        }
      }
    }
    self.fixedEntries = fixedEntries
    self.dynamicEntries = dynamicEntries
    self.dynamicLines = dynamicLines
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
    let fmtRE = Regex(pattern: "(\\d+)(?:,(\\d+))?(?::(.+))?")
    let info = fmtRE.firstMatchInString(fragment)!.groups
    let variable = variables[Int(info[0])!]
    let alignment = Int(info[1] ?? "0") ?? 0
    let format = info[2] ?? ""
    
    return FormatEntry(variable: variable, alignment: alignment, format: format)
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
  func processTag(fragment : String) -> Tag {
    let offsetRE = Regex(pattern: "@([xy])(-?\\d+)")
    if let nudge = offsetRE.firstMatchInString(fragment) {
      let res = nudge.groups
      return NudgeTag(value: Float(res[1])!, x: res[0] == "x")
    } else if fragment == "hw" {
      return WidthTag(type: .Half)
    } else if fragment == "/hw" || fragment == "/dw"{
      return WidthTag(type: .Normal)
    } else if fragment == "dw" {
      return WidthTag(type: .Double)
    }
    fatalError()
  }
  
  func draw(data : IKerbalDataStore) {
    // Draw all the fixed positions
    for entry in fixedEntries {
      let txt = entry.process(data)
      drawing!.program.setColor(txt.color)
      text?.draw(txt.string, size: lineHeight*txt.size, position: txt.position)
    }
  }
}

extension String {
  func isWhitespace() -> Bool {
    let trim = self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    return trim.characters.count == 0
  }
}

private let sipRE = Regex(pattern: "SIP(_?)(0?)(\\d+)(?:\\.(\\d+))?")

protocol StringFormatter {
  func format<T>(item : T) -> String
  var fixedLength : Bool { get }
  var length : Int { get }
}

class SIFormatter : StringFormatter {
  var spaced : Bool
  var zeroPadded : Bool
  var length : Int
  var precision : Int?
  
  var fixedLength : Bool { return true }
  
  init(format: String) {
    guard let match = sipRE.firstMatchInString(format) else {
      fatalError()
    }
    // We have an SI processing entry.
    var parts = match.groups
    spaced = parts[0] != ""
    zeroPadded = parts[1] == "0"
    length = Int(parts[2])!
    precision = parts[3] == "" ? nil : Int(parts[3])!
  }
  
//  var length : Int { return length }
  
  func format<T>(item : T) -> String {
    fatalError()
  }
}

class DefaultStringFormatter : StringFormatter {
  var fixedLength : Bool { return false }
  var length : Int { return 0 }
  func format<T>(item: T) -> String {
    return String(item)
  }
}

func getFormatterForString(format: String) -> StringFormatter {
  if let _ = sipRE.firstMatchInString(format) {
    return SIFormatter(format: format)
  }
  return DefaultStringFormatter()
}