//
//  KerbalConfigFile.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 18/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

func ==(left: KerbalConfigLexer.Token.TokenType, right: KerbalConfigLexer.Token.TokenType) -> Bool {
  switch (left, right) {
  case (.OpenBrace, .OpenBrace):
    return true
  case (.CloseBrace, .CloseBrace):
    return true
  case (.Equals, .Equals):
    return true
  case (.Identifier(let a), .Identifier(let b)):
    return a == b
  case (.Value(let a), .Value(let b)):
    return a == b
  default:
    return false
  }
}
class KerbalConfigLexer : SequenceType {
  
  struct Token {
    enum TokenType : Equatable {
      case OpenBrace
      case CloseBrace
      case Identifier(value:String)
      case Value(contents:String)
      case Equals
    }
    var type : TokenType
    var length : String.Index.Distance
    var position : String.Index
  }
  
  typealias Generator = AnyGenerator<Token>

  /// The entire set of data
  private let data : String
  
  init(data: String) {
    self.data = data
  }
  
  func generate() -> Generator {
    var position = data.startIndex
    var prevToken : Token.TokenType? = nil
    return anyGenerator {
      if let tok = self.tokenFromPosition(position, prevToken: prevToken) {
        position = tok.position.advancedBy(tok.length)
        prevToken = tok.type
        return tok
      }
      return nil
    }
  }
  
  let identifierRegex = Regex(pattern: "^[a-zA-Z][a-zA-Z0-9_]*")
  private func tokenFromPosition(var index: String.Index, prevToken: Token.TokenType? = nil) -> Token? {
    guard index != data.endIndex else {
      return nil
    }
    // Scan from the position to get the next token.
    // Start by skipping any whitespace at our current position
    index = skipWhitespaceAndComments(index)
    
    // What is the next character?
    switch String(data[index]) {
    case "{":
      return Token(type: .OpenBrace, length: 1, position: index)
    case "}":
      return Token(type: .CloseBrace, length: 1, position: index)
    case "=":
      return Token(type: .Equals, length: 1, position: index)
    default:
      if let tok = prevToken where tok == .Equals {
        // Read the rest of the line as a single value
        let val = readToEndOfLineOrComment(index)
        return Token(type: .Value(contents: val), length: val.characters.count, position: index)
      }
      // Must be an identifier...
      guard let ident = readIdentifier(index) else {
        fatalError("Could not read identifier!")
      }
      return Token(type: .Identifier(value: ident), length: ident.characters.count, position: index)
    }
  }
  
  private func skipWhitespaceAndComments(var index: String.Index) -> String.Index {
    var wsIndex = index
    var cmIndex = index
    repeat {
      index = max(wsIndex, cmIndex)
      wsIndex = skipWhitespace(index)
      cmIndex = skipComment(index)
      if cmIndex > index {
        print("Read comment: ", data.substringWithRange(Range(start: index, end: cmIndex)))
      }
    } while (wsIndex != index || cmIndex != index) && index != data.endIndex
    // Can return either, as they are the same when the loop ends
    return wsIndex
  }
  
  private func skipComment(start: String.Index) -> String.Index {
    guard start != data.endIndex && start.advancedBy(1) != data.endIndex else {
      return start
    }
    guard data[start] == "/" && data[start.advancedBy(1)] == "/" else {
      return start
    }
    return skipToCharacterSet(NSCharacterSet.newlineCharacterSet(), start: start)
  }
  
  private func readToEndOfLineOrComment(start: String.Index) -> String {
    let lineEnd = skipToCharacterSet(NSCharacterSet.newlineCharacterSet(), start: start)
    // Is there a comment between here and there?
    let lineString = data.substringWithRange(Range(start:start,end:lineEnd))
    if let comment = lineString.rangeOfString("//") {
      return lineString.substringToIndex(comment.startIndex)
    }
    return lineString
  }
  
  private func readIdentifier(start: String.Index) -> String? {
    guard let match = identifierRegex.firstMatchInString(data.substringFromIndex(start)) else {
      return nil
    }
    return data.substringWithRange(Range(start: start, end: start.advancedBy(match.range.length)))
  }
  
  /// Skips whitespace, and returns the index of the next non-whitespace value
  private func skipWhitespace(start: String.Index) -> String.Index {
    return skipCharacterSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), start: start)
  }
  
  /// Skip characters until we have a match from a particular set
  private func skipToCharacterSet(set: NSCharacterSet, start: String.Index) -> String.Index {
    return skipCharacterSet(set.invertedSet, start: start)
  }
  
  /// Skip characters from a particular character set, returning the first non-match
  private func skipCharacterSet(set: NSCharacterSet, start: String.Index) -> String.Index {
    guard start != data.endIndex else {
      return data.endIndex
    }
    var index = start
    while let char = String(data[index]).utf16.first where index != data.endIndex {
      if !set.characterIsMember(char) {
        break
      }
      index = index.advancedBy(1)
    }
    return index
  }
}