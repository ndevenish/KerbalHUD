//
//  Regex.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 03/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

struct Match {
//  var range : Range<String.Index>
  var groups : [String]
  var result : NSTextCheckingResult
  
  init(string: String, result : NSTextCheckingResult) {
    self.result = result
    var groups : [String] = []
    for i in 1..<result.numberOfRanges {
      let range = result.rangeAtIndex(i)
      if range.location == NSNotFound {
        groups.append("")
      } else {
        groups.append(string.substringWithRange(range))
      }
    }
    self.groups = groups
  }
  
  var range : NSRange { return result.range }
}

class Regex {
  let re : NSRegularExpression
  init(pattern: String) {
    re = try! NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions())
  }
  func firstMatchInString(string : String) -> Match? {
    let nss = string as NSString
    if let tr = re.firstMatchInString(string, options: NSMatchingOptions(), range: NSRange(location: 0, length: nss.length)) {
      return Match(string: string, result: tr)
    }
    return nil
  }
  func matchesInString(string : String) -> [Match] {
    let nsS = string as NSString
    return re.matchesInString(string, options: NSMatchingOptions(), range: NSRange(location: 0, length: nsS.length)).map { Match(string: string, result: $0) }
  }
}

extension String {
  func substringWithRange(range : NSRange) -> String {
    let nss = self as NSString
    return nss.substringWithRange(range)
  }
}
