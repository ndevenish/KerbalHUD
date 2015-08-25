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
  struct Runway {
    var Identity : String = "";
    var Altitude : GLfloat = 0
    var OuterMarker : GLfloat = 0
    var MiddleMarker : GLfloat = 0
    var InnerMarker : GLfloat = 0
  }
  struct FlightData {
    var Heading : GLfloat = 0
    var RunwayHeading : GLfloat = 0
    var LocationDeviation : GLfloat = 0
    var BeaconDistance : GLfloat = 0
    var BeaconBearing : GLfloat = 0
    
    var GlideslopeDeviation : GLfloat = 0
    var Glideslope : GLfloat = 0
    

    var TrackingMode : DeviationMode = .Coarse
    var BackCourse : Bool = false
    
    var SelectedRunway : Runway? = nil
  }
  
  var overlay : Drawable2D?
  var overlayBackground : Drawable2D?
  var needleNDB : Drawable2D?
  var courseWhite : Drawable2D?
  var coursePurpl : Drawable2D?
  var gsIndicators : Drawable2D?
  
  var data : FlightData = FlightData()
  
  struct HSISettings {
    var enableFineLoc : Bool = true
  }
  var hsiSettings = HSISettings()
  
  
  required init(tools: DrawingTools) {
    let set = RPMPageSettings(textSize: (40,23), screenSize: (640,640),
      backgroundColor: Color4(0,0,0,1), fontName: "Menlo", fontColor: Color4(1,1,1,1))
    super.init(tools: tools, settings: set)
    variables = ["n.heading", "navutil.glideslope", "navutil.bearing", "navutil.dme",
      "navutil.locdeviation", "navutil.gsdeviation", "navutil.headingtorunway", "navutil.runway"];
    
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
    
    // Generate glideslope indicators
    var glideSlopes : [Triangle] = []
    glideSlopes.extend(GenerateBoxTriangles(-21, bottom: -3, right: 21, top: 3))
    let baseCircle = GenerateCircleTriangles(8, w: 4)
    glideSlopes.extend(ShiftTriangles(baseCircle, shift:Point2D(0, 50)))
    glideSlopes.extend(ShiftTriangles(baseCircle, shift:Point2D(0, -50)))
    glideSlopes.extend(ShiftTriangles(baseCircle, shift:Point2D(0, 100)))
    glideSlopes.extend(ShiftTriangles(baseCircle, shift:Point2D(0, -100)))
    gsIndicators = tools.LoadTriangles(glideSlopes);
  }
  
  override func update(variables: [String : JSON]) {
    var newData = FlightData()
    newData.Heading = variables["n.heading"]?.floatValue ?? 0
    newData.Glideslope = variables["navutil.glideslope"]?.floatValue ?? 0
    newData.BeaconBearing = variables["navutil.bearing"]?.floatValue ?? 0
    newData.BeaconDistance = variables["navutil.dme"]?.floatValue ?? 0
    newData.LocationDeviation = variables["navutil.locdeviation"]?.floatValue ?? 0
    newData.GlideslopeDeviation = variables["navutil.gsdeviation"]?.floatValue ?? 0
    newData.RunwayHeading = variables["navutil.headingtorunway"]?.floatValue ?? 0
    
    if let runwayData = variables["navutil.runway"]?.dictionary {
      var runway = Runway()
      runway.Altitude = runwayData["altitude"]?.floatValue ?? 0
      runway.Identity = runwayData["identity"]?.stringValue ?? "Unknown Runway";
      let markers = runwayData["markers"]?.arrayValue ?? []
      if markers.count == 3 {
        runway.OuterMarker = markers[0].floatValue
        runway.MiddleMarker = markers[1].floatValue
        runway.InnerMarker = markers[2].floatValue
      }
      newData.SelectedRunway = runway;
    }
    
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
//    data.BeaconBearing = 30
//    data.RunwayHeading = data.Heading

    drawCompass()
    drawNeedleNDB()
    drawCourseNeedle()
    
    // Draw the background overlay
    drawing.program.setModelView(GLKMatrix4Identity)
    drawing.program.setColor(red: 16.0/255,green: 16.0/255,blue: 16.0/255)
    drawing.Draw(overlayBackground!)
    drawing.program.setColor(red: 1,green: 1,blue: 1)
    drawing.Draw(overlay!)
    
    // Draw the glideslope indicators
    drawGlideSlopeIndicators()
    
    // Draw the text
//    let lineHeight = floor(screenHeight / settings.textSize.height)
//    let lineY = (0...19).map { (line : Int) -> Float in screenHeight-lineHeight*(Float(line) + 0.5)}
    if let runway = data.SelectedRunway {
      text.draw("RUNWAY: " + runway.Identity, size: 25, position: (40, 606+12.5))
      text.draw(String(format: "GLIDESLOPE: %.1f˚", data.Glideslope), size: 25, position: (40, 596.5))
      text.draw(String(format: "ELEVATION: %.0fm", runway.Altitude), size: 25, position: (320, 596.5))
    }
    text.draw("COURSE", size: 25, position: (60, 555), align: .Center)
    text.draw(String(format:"%.0f", 90.0), size: 25, position: (60, 536), align: .Center)
    
//    530,556
    text.draw(String(format:"HDG", data.Heading), size:22, position:(530,555));
    text.draw(String(format:"BRG", data.BeaconBearing), size:22, position:(530,526));
    text.draw(String(format:"   %03.0f", data.Heading), size:25, position:(530,555));
    text.draw(String(format:"   %03.0f", data.BeaconBearing), size:25, position:(530,526));
    
    text.draw(String(format:"DME", data.Heading), size:22, position:(50,124));
    text.draw(String(format:"%.1f", data.BeaconDistance/1000), size:25, position:(45,95));
    
    
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
  
  func drawGlideSlopeIndicators() {
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    drawing.program.setModelView(GLKMatrix4MakeTranslation(24, 232, 0))
    drawing.Draw(gsIndicators!)
    drawing.program.setModelView(GLKMatrix4MakeTranslation(640-24, 232, 0))
    drawing.Draw(gsIndicators!)
  }
}