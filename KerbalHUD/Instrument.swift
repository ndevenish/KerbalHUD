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
  
  /// Start communicating with the kerbal data store
  func connect(to : IKerbalDataStore)
  /// Stop communicating with the kerbal data store
  func disconnect(from : IKerbalDataStore)

  /// Update this instrument
  func update()
  
  func draw()
}

// Configuring a widget. 
// - Remapping input variables
// - Configuration
// - Position and Size
protocol Widget {
  /// The bounding rectangle for this widget
  var bounds : Bounds { get }
  /// List of variables that this widget uses
  var variables : [String] { get }
  func update(data : [String : JSON])
  func draw()
}