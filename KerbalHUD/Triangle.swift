//
//  Triangle.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 02/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

struct Triangle<T : Point> {
  var p1 : T
  var p2 : T
  var p3 : T
  
  init(_ a : T, _ b : T, _ c : T) {
    p1 = a
    p2 = b
    p3 = c
  }
}