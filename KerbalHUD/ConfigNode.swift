//
//  ConfigNode.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 15/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

protocol ConfigNode {
  var name : String { get }
  
  func GetNode(name : String) -> ConfigNode?
  func GetNodes(name : String) -> [ConfigNode]
  func GetValue(name : String) -> String?
  func GetValues(name : String) -> [String]
}

struct ConfigNodeImpl : ConfigNode {

  var name : String

  init(data : String) {
    name = ""
  }
  
  func GetNode(name : String) -> ConfigNode? {
    return nil
  }
  func GetNodes(name : String) -> [ConfigNode] {
    return []
  }
  func GetValue(name : String) -> String? {
    return nil
  }
  func GetValues(name : String) -> [String] {
    return []
  }
}

class ConfigStringTokenizer {
  let data : String
  let index : Int = 0
  
  init(data : String) {
    self.data = data
  }
  
  func next() -> String? {
//    let finder = NSRegularExpression(pattern: " \t\n\r={{}}", options: nil)
    return nil
    
  }
}
