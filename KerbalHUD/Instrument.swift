//
//  Instrument.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

protocol Instrument {
  var screenSize : Size2D<Float> { get }
  
  var dataProvider : IKerbalDataStore? { get set }
  
  init(tools : DrawingTools)
  
  /// Update this instrument
  func update()
  
  func draw()
}