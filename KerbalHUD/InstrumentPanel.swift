//
//  InstrumentPanel.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 26/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit


private struct PanelEntry {
  var instrument : Instrument
  let framebuffer : GLuint
}

class InstrumentPanel
{
  var connection : TelemachusInterface? {
    didSet {
      for var i in instruments {
        i.instrument.dataProvider = connection
      }
    }
  }
  
  private let drawing : DrawingTools
  private var instruments : [PanelEntry] = []
  
  init(tools : DrawingTools)
  {
    drawing = tools
  }
  
  func update()
  {
    for i in instruments {
      i.instrument.update()
    }
  }
  
  func draw()
  {
    for i in instruments {
      i.instrument.draw()
    }
  }
  
  func AddInstrument(item : Instrument)
  {
    let newI = PanelEntry(instrument: item, framebuffer: 0)
    instruments.append(newI)
  }
}