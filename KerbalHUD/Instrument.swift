//
//  Instrument.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 13/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation

protocol Instrument {
  /// The INTERNAL screen size e.g. the coordinate system this expects to draw on
  var screenSize : Size2D<Float> { get }
  
  var drawing : DrawingTools { get }
  
  /// Initialise with a toolset to draw with
  init(tools : DrawingTools)
  
  /// Start communicating with the kerbal data store
  func connect(to : IKerbalDataStore)
  /// Stop communicating with the kerbal data store
  func disconnect(from : IKerbalDataStore)

  /// Update this instrument
  func update()
  
  func draw()
}