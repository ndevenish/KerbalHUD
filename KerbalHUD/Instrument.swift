//
//  Instrument.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

protocol Instrument {
  var variables : [String] { get }
  
  /// Update this instrument with all variables recieved from the server
  func update(variables : [String: JSON])
  
  func draw()
}