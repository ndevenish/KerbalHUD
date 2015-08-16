//
//  NavUtilities.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 15/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

class HSIIndicator : RPMInstrument {
  
  enum DeviationMode {
    case Coarse
    case Fine
  }
  struct FlightData {
    var Heading : GLfloat = 0
    var RunwayHeading : GLfloat = 0
    var LocationDeviation : GLfloat = 0
    var BeaconDistance : GLfloat = 0
    var BeaconBearing : GLfloat = 0
    
    var TrackingMode : DeviationMode = .Coarse
    var BackCourse : Bool = false
  }
  
  var overlay : Drawable2D?
  var overlayBackground : Drawable2D?
  var needleNDB : Drawable2D?
  var courseWhite : Drawable2D?
  var coursePurpl : Drawable2D?
  
  var data : FlightData = FlightData()
  
  struct HSISettings {
    var enableFineLoc : Bool = true
  }
  var hsiSettings = HSISettings()
  
  
  required init(tools: DrawingTools) {
    let set = RPMPageSettings(textSize: (40,23), screenSize: (640,640),
      backgroundColor: Color4(0,0,0,1), fontName: "Menlo", fontColor: Color4(1,1,1,1))
    super.init(tools: tools, settings: set)
    variables = ["n.heading"]
    
    let d : GLfloat = 0.8284271247461902
    // Inner loop
    let overlayBase : [Point2D] = [(128,70), (128,113), (50, 191), (50, 452), (128, 530), (128, 574),
      (306, 574), (319, 561), (319, 471), (321, 471), (321, 561), (334,574),
      (510, 574), (510, 530), (588, 452), (588, 70),
      (336, 70), (320, 86), (304, 70), (128,70),
      // move to outer edge (rem (590, 191+d),  from second to last on next line)
      (128,68), (640, 68), (640, 70), (590, 70), (590, 452+d),
      (512, 530+d), (512, 574), (640, 574), (640, 576), (0, 576), (0, 574),
      (126, 574), (126, 530+d), (48, 452+d), (48, 191-d), (126, 113-d), (126, 70),
      (0, 70), (0, 68), (128, 68)]
    overlay = tools.Load2DPolygon(overlayBase)

    // Do the overlay background separately
    let overlayBackgroundPts : [Point2D] = [
      (128,70), (128,113), (50, 191), (50, 452), (128, 530), (128, 574),
      (510, 574), (510, 530), (588, 452), (588, 70), (128,70),
      (0,0), (640,0), (640,640), (0, 640), (0,0) ]
    overlayBackground = tools.Load2DPolygon(overlayBackgroundPts)
    
    // NDB Needle
    needleNDB = tools.Load2DPolygon([
      // 154 height total
      (-4.5, -148.5), (-7.5, -150.5), (-7.5, 150.5), (0, 158), (7.5, 150.5),
      (7.5, -150.5), (-7.5, -150.5), (-4.5, -148.5), (4.5, -148.5), (4.5, 148.5),
      (-4.5, 148.5)])
    
    
    var whiteTri : [Triangle] = []
    whiteTri.append(Triangle((-15, 19), (0, 54), (15, 19)))
    whiteTri.extend(drawing.DecomposePolygon([(-46,0), (-50, -7.5), (-54, 0), (-50, 7.5)]))
    whiteTri.extend(drawing.DecomposePolygon([(-96,0), (-100, -7.5), (-104, 0), (-100, 7.5)]))
    whiteTri.extend(drawing.DecomposePolygon([(46,0), (50, -7.5), (54, 0), (50, 7.5)]))
    whiteTri.extend(drawing.DecomposePolygon([(96,0), (100, -7.5), (104, 0), (100, 7.5)]))
    courseWhite = tools.LoadTriangles(whiteTri)
    
    var purpTri : [Triangle] = []
    purpTri.extend(drawing.DecomposePolygon([
      (-2.5, 126), (-2.5, 162), (-10.5, 162), (-10.5, 166), (-2.5, 166), (-2.5, 210), (0, 212.5),
      (2.5, 210), (2.5, 166), (10.5, 166), (10.5, 162), (2.5, 162), (2.5, 126)]))
    purpTri.extend(drawing.DecomposePolygon([
      (-2, -127), (-2, -127-48), (2, -127-48), (2, -127)]))
    coursePurpl = tools.LoadTriangles(purpTri)
   //-127, 4x48
  }
  
  override func update(variables: [String : JSON]) {
    var newData = FlightData()
    newData.Heading = variables["n.heading"]?.floatValue ?? 0
    data = newData
    
    if hsiSettings.enableFineLoc && data.LocationDeviation < 0.75 && data.BeaconDistance < 7500 {
      data.TrackingMode = .Fine
    }
//    var LocationDeviation : GLfloat = 0
//    var DeviationMode : String
    
    if data.LocationDeviation < -90 || data.LocationDeviation > 90 {
      data.BackCourse = true
    }

  }
  
  override func draw() {
    data.BeaconBearing = 30
    data.RunwayHeading = data.Heading

    drawCompass()
    drawNeedleNDB()
    drawCourseNeedle()
    
    // Draw the background overlay
    drawing.program.setModelView(GLKMatrix4Identity)
    drawing.program.setColor(red: 16.0/255,green: 16.0/255,blue: 16.0/255)
    drawing.Draw(overlayBackground!)
    drawing.program.setColor(red: 1,green: 1,blue: 1)
    drawing.Draw(overlay!)
  }
  
  func drawCourseNeedle() {
    let needleRotation = data.Heading-data.RunwayHeading

    var offset = GLKMatrix4MakeTranslation(320, 320, 0)
    offset = GLKMatrix4Rotate(offset, needleRotation*π/180, 0, 0, 1)
    drawing.program.setModelView(offset)
    
    drawing.Draw(courseWhite!)
    drawing.program.setColor(red: 1, green: 0, blue: 1)
    drawing.Draw(coursePurpl!)

    // 247x5 for the course indicator
    // Deviation mode? In fine mode, each tick (50px) == 0.25˚
    // In coarse mode, each tick == 1˚
    let needleOffset : GLfloat = 50 * data.LocationDeviation * (data.TrackingMode == .Coarse ? 1 : 4)
    if data.TrackingMode == .Fine {
      drawing.program.setColor(red: 1, green: 1, blue: 0)
    }
    drawing.DrawLine((needleOffset, -123.5), to: (needleOffset, 123.5), width: 5, transform: offset)
    
  }
  
  func drawNeedleNDB() {
    let bearingRotation = data.Heading-data.BeaconBearing
    
    
    var offset = GLKMatrix4MakeTranslation(320, 320, 0)
    offset = GLKMatrix4Rotate(offset, bearingRotation*π/180, 0, 0, 1)
    drawing.program.setModelView(offset)
    drawing.Draw(needleNDB!)
  }
  
  func drawCompass() {
    let heading = data.Heading
    let inner : GLfloat = 356.0/2
    var offset = GLKMatrix4Identity
    offset = GLKMatrix4Translate(offset, 320, 320, 0)
    offset = GLKMatrix4Rotate(offset, heading*π/180, 0, 0, 1)

    drawing.program.setColor(red: 1,green: 1,blue: 1)
    
    for var angle = 0; angle < 360; angle += 5 {
      let rad = GLfloat(angle) * π/180
      let length : GLfloat = angle % 90 == 0 ? 16 : (angle % 10 == 0 ? 25 : 20)
      let width : GLfloat = angle % 30 == 0 ? 4 : 3
      let outer = inner+length
      drawing.DrawLine((inner*sin(rad), inner*cos(rad)) , to: (outer*sin(rad), outer*cos(rad)), width: width, transform: offset)
    }
    
    // Draw text
    for var angle = 0; angle < 36; angle += 3 {
      let txt : String
      switch (angle) {
      case 0:
        txt = "N"
      case 9:
        txt = "E"
      case 18:
        txt = "S"
      case 27:
        txt = "W"
      default:
        txt = String(angle)
      }
      let rad = GLfloat(angle)*10*π/180
      let transform = GLKMatrix4Rotate(offset, rad, 0, 0, -1)
      text.draw(txt, size: 32, position: (0, inner + 25 + 16), align: .Center, rotation: 0, transform: transform)
    }
  }
}