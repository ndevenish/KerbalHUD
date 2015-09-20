//
//  KerbalConfigFile.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 18/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

enum KerbalConfigError : ErrorType {
  case InvalidIdentifier
  case UnexpectedToken(type : KerbalConfigLexer.Token.TokenType)
  case UnexpectedEOF
}

protocol KerbalConfigNode {
  var type : String { get }
  var values : [(name: String, value: String)] { get }
  var nodes : [KerbalConfigNode] { get }

  subscript(name : String) -> String? { get set }
}

extension KerbalConfigNode {
  var name : String? {
    get { return self["name"] }
    set { self["name"] = newValue }
  }
  
  /// Apply a filter to every node in the tree of nodes. Passing means children will not be processed.
  func filterNodes(filter: (KerbalConfigNode) -> Bool) -> [KerbalConfigNode] {
    var nodeList : [KerbalConfigNode] = []
    for node in nodes {
      if filter(node) {
        nodeList.append(node)
      } else {
        nodeList.appendContentsOf(node.filterNodes(filter))
      }
    }
    return nodeList
  }
}

enum NodeEntry {
  case Value(name: String, value: String)
  case Node(KerbalConfigNode)
}

struct Node : KerbalConfigNode {
  var type : String
  var values : [(name: String, value: String)] = []
  var nodes : [KerbalConfigNode] = []
  
  init(type : String, entries: [NodeEntry] = []) {
    self.type = type
    for entry in entries {
      switch entry {
      case .Value(let name, let value):
        values.append((name, value))
      case .Node(let node):
        nodes.append(node)
      }
    }
  }
  
  subscript(name : String) -> String? {
    get { return getOnlyValueNamed(name) }
    set {
      let entries = values.filter({$0.name == name})
      switch entries.count {
      case 0:
        if let newS = newValue {
          values.append((name, newS))
        }
      case 1:
        let nameEntry = values.indexOf({$0.name == "name"})!
        if let newS = newValue {
          values[nameEntry] = (name, newS)
        } else {
          values.removeAtIndex(nameEntry)
        }
      default:
        // We have more than one entry for this name - cannot access via this
        // convenience methos.
        fatalError("Cannot access more than one value via convenience method")
      }
    }
  }
  
  private func getOnlyValueNamed(name : String) -> String? {
    let vals = values.filter({$0.name == name})
    assert(vals.count <= 1)
    return vals.last?.value
  }
}

func parseKerbalConfig(withContentsOfFile data: String) throws -> KerbalConfigNode {
  return try parse(KerbalConfigLexer(data: data))
}

private func parse(lexer : KerbalConfigLexer) throws -> Node {
  let generator = lexer.generate()
  return try parseNode(generator)
}

private func parseNode(lexer : KerbalConfigLexer.Generator) throws -> Node {
  // Read the identifier
  let identifier = try parseIdentifier(lexer)
  try ensureToken(lexer, token: .OpenBrace)
  let entries = try parseNodeContents(lexer)
  try ensureToken(lexer, token: .CloseBrace)

  return Node(type: identifier, entries: entries)
}

private func parseNodeContents(lexer : KerbalConfigLexer.Generator) throws -> [NodeEntry] {
  var entries : [NodeEntry] = []

  // Read tokens IDENT [= | OPENBRACE]* }
  // Read node contents until we hit a closeBrace
  while !peekCheckToken(lexer, token: .CloseBrace) {
    // Read an identifier
    let name = try parseIdentifier(lexer)
    // Next is either an openBrace or =
    if checkToken(lexer, token: .Equals) {
      let value = try ensureToken(lexer, token: .Value(contents: ""))
      entries.append(.Value(name: name, value: value))
    } else if checkToken(lexer, token: .OpenBrace) {
      let nodeEntry = try parseNodeContents(lexer)
      try ensureToken(lexer, token: .CloseBrace)
      entries.append(.Node(Node(type: name, entries: nodeEntry)))
    } else {
      // Unexpected - throw appropriate error
      try throwAppropriateTokenError(lexer)
    }
  }
  return entries
}

/// Throws 'UnexpectedToken' or 'UnexpectedEOF' depending on the situation
private func throwAppropriateTokenError(lexer : KerbalConfigLexer.Generator) throws {
  if let nextTok = lexer.next() {
    throw KerbalConfigError.UnexpectedToken(type: nextTok.type)
  }
  throw KerbalConfigError.UnexpectedEOF
}

private func parseIdentifier(lexer : KerbalConfigLexer.Generator) throws -> String {
  switch lexer.next()!.type {
  case .Identifier(let i):
    return i
  default:
    throw KerbalConfigError.InvalidIdentifier
  }
}

private func ensureToken(lexer: KerbalConfigLexer.Generator, token: KerbalConfigLexer.Token.TokenType) throws -> String { //KerbalConfigLexer.Token.TokenType {
  // Read the next token
  guard let ob = lexer.next() else {
    throw KerbalConfigError.UnexpectedEOF
  }
  switch (ob.type, token) {
  case (.Value(let a), .Value):
    return a
  case (.Identifier(let a), .Identifier):
    return a
  default:
    break
  }
  guard ob.type == token else {
    throw KerbalConfigError.UnexpectedToken(type: ob.type)
  }
  return ""
}

private func checkToken(lexer: KerbalConfigLexer.Generator, token: KerbalConfigLexer.Token.TokenType, swallow: Bool = true) -> Bool {
  guard let neT = lexer.peek() else {
    return false
  }
  if neT.type != token {
    return false
  }
  // Actually swallow the token if it is what we expected
  if swallow { lexer.next() }
  return true
}
private func peekCheckToken(lexer: KerbalConfigLexer.Generator, token: KerbalConfigLexer.Token.TokenType) -> Bool {
  return checkToken(lexer, token: token, swallow: false)
}

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

class PeekableGenerator<T> : AnyGenerator<T>
{
  private var store : [Element] = []
  private var generator : AnyGenerator<Element>
  
  override func next() -> Element? {
    if let entry = store.popLast() {
      return entry
    }
    return generator.next()
  }
  
  func peek() -> Element? {
    if let elem = next() {
      store.append(elem)
      return elem
    }
    return nil
  }
  
  init(generator: AnyGenerator<Element>) {
    self.generator = generator
  }
}

func peekableAnyGenerator<Element>(body: () -> Element?) -> PeekableGenerator<Element> {
  return PeekableGenerator(generator: anyGenerator(body))
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
  typealias Generator = PeekableGenerator<Token>

  /// The entire set of data
  private let data : String
  
  init(data: String) {
    self.data = data
  }
  
  func generate() -> Generator {
    var position = data.startIndex
    var prevToken : Token.TokenType? = nil

    return peekableAnyGenerator {
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