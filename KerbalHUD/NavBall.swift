//
//  NavBall.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit


class NavBall : Instrument {
  /// The INTERNAL screen size e.g. the coordinate system this expects to draw on
  var screenSize : Size2D<Float>
  
  var drawing : DrawingTools
  var navBall : NavBallTextureRendering
  
  /// Initialise with a toolset to draw with
  required init(tools : DrawingTools) {
    drawing = tools
    navBall = NavBallTextureRendering(tools: drawing)
    screenSize = Size2D(w: 1, h: 1)
  }
  
  /// Start communicating with the kerbal data store
  func connect(to : IKerbalDataStore){
    
  }
  /// Stop communicating with the kerbal data store
  func disconnect(from : IKerbalDataStore) {
    
  }
  
  /// Update this instrument
  func update() {
    
  }
  
  func draw() {
    navBall.generate()
  }
  
}

class NavBallTextureRendering {
  
  var drawing : DrawingTools
  var textures : [Int : Texture] = [:]
  
  init(tools : DrawingTools) {
    drawing = tools
    generateTextTextures()
  }
  
  deinit {
    // Delete all text textures
    for t in textures.values {
      drawing.deleteTexture(t)
    }
    textures.removeAll()
//    drawing.program.setUseTexture(false)
  }
  
  func generateTextTextures() {
    let text = drawing.textRenderer("Menlo-Bold")
    for var angle = -80; angle <= 80; angle += 10 {
      let str = angle == 0 ? "N" : String(angle)
      textures[angle] = text.drawToTexture(str, size: 45)
    }
    for var angle = 45; angle <= 270; angle += 45 {
      textures[angle] = text.drawToTexture(String(angle), size: 45)
    }
  }
  
  func drawTextStrip(thetaDegrees: Float, upper : Bool) {
    drawing.program.setUseTexture(true)
    
    let theta = GLfloat(thetaDegrees)*π/180
    let range : (Int, Int) = upper ? (10, 80) : (-80, -10)
    for var angle = range.0; angle <= range.1; angle += 10 {
      // Don't render the central signs
      if angle == 0 {
        continue
      }
      
      // Bind the texture and calculate the size
      let phi = (90+GLfloat(angle)) * π/180
      let tex = textures[angle]!
      let textHeight : Float = 4
      let size = Size2D(w: tex.size!.aspect*textHeight, h: textHeight)
      drawing.bind(tex)
      
      // Generate the texture buffer for this and draw it
      let buffer = generateGeometryFor(size,
        spherePoint: SphericalPoint(theta: theta, phi: phi, r: 0),
        offset: Point2D(x: 5, y: 0), alignment: .Left)
      drawing.bind(buffer)
      glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 116)
      
      // Draw the left text
      let bufferR = generateGeometryFor(size,
        spherePoint: SphericalPoint(theta: theta, phi: phi, r: 2),
        offset: Point2D(x: -5, y: 0), alignment: .Right)
      drawing.bind(bufferR)
      glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 116)
      
      // Delete these buffers
      drawing.deleteVertexArray(buffer)
      drawing.deleteVertexArray(bufferR)
      
    }
    drawing.program.setUseTexture(false)
  }
  
  /// Generate a geometry grid, with UV indices, for a specified size projected
  private enum BulkSpherePosition {
    case Left
    case Right
    case Middle
  }
  
  func generateGeometryFor(size: Size2D<Float>, spherePoint: SphericalPoint, offset: Point2D, alignment: NSTextAlignment = .Center) -> VertexArray {
    let sphPoint = SphericalPoint(lat: spherePoint.lat, long: spherePoint.long, r: 60)
    let xSteps = 10
    let ySteps = 5
    
    let sphereDomain : BulkSpherePosition
    if sphPoint.theta < -120*π/180 {
      sphereDomain = .Left
    } else if sphPoint.theta > 120*π/180 {
      sphereDomain = .Right
    } else {
      sphereDomain = .Middle
    }
    
    var data : [(pos: Point2D, uv: Point2D)] = []
    
    for iY in 0..<ySteps {
      for iX in 0...xSteps {
        // The offset points of this index specifically
        let xAlign = alignment == .Right ? size.w : (alignment == .Left ? 0 : size.w/2)
        let xOffset = size.w/Float(xSteps) * Float(iX) - xAlign
        let yOffset = size.h/Float(ySteps) * Float(iY) - size.h/2
        // If we have data already, double-up the first vertex as we will
        // need to do so for a triangle strip
        let uv = Point2D(x: Float(iX)/Float(xSteps),
          y: 1 - Float(iY)/Float(ySteps))
        if iX == 0 && data.count > 0 {
          data.append((pos: Point2D(x: xOffset, y: yOffset), uv: uv))
        }
        data.append((Point2D(x: xOffset, y: yOffset), uv))
        // Calculate the y of the next one up
        let yOffset2 = size.h/Float(ySteps) * Float(iY+1) - size.h/2
        let uvUp = Point2D(x: Float(iX)/Float(xSteps),
          y: 1 - Float(iY+1)/Float(ySteps))
        data.append((Point2D(x: xOffset, y: yOffset2), uvUp))
      }
      // Finish the triangle strip line
      data.append(data.last!)
    }
    // Remove the last item as it will double up otherwise (empty triangle)
    data.removeLast()
    
    // Now, transform all of these points
    var geometry = data.flatMap { (point : Point2D, uV: Point2D) -> [GLfloat] in
      //      let uV = (x:(point.x + size.w/2)/size.w, y: (point.y+size.h/2)/size.h)
      var sphePos = pointOffsetRayIntercept(sphericalPoint: sphPoint, offset: point+offset, radius: 59)!
      // Rotate round if we went over a texture edge
      if sphereDomain == .Left && sphePos.theta > 120*π/180 {
        sphePos.theta = sphePos.theta - 2*π
      } else if sphereDomain == .Right && sphePos.theta < -120*π/180 {
        sphePos.theta = sphePos.theta + 2*π
      }
      let dat : [GLfloat] = [sphePos.long*180/π, -(π/2-sphePos.lat)*180/π, uV.x, uV.y]
      return dat
    }
    
    // Load into a buffer object!
    let array = drawing.createVertexArray(positions: 2, textures: 2)
    glBufferData(GLenum(GL_ARRAY_BUFFER),
      sizeof(GLfloat)*geometry.count,
      &geometry, GLenum(GL_DYNAMIC_DRAW))
    drawing.bind(VertexArray.Empty)
    
    return array
  }

  func generate() {
    //    let texture = drawing.createTextureFramebuffer(Size2D(w: 4096, h: 2048), depth: false, stencil: false)
    //    drawing.bind(texture)
    drawing.program.projection = GLKMatrix4MakeOrtho(-180, 180, -90, 90, -10, 10)
    drawing.program.setModelView(GLKMatrix4Identity)
    
    // Upper and lower halves
    drawing.program.setColor(red: 93.0/255, green: 177.0/255, blue: 228.0/225)
    drawing.DrawSquare(-180, bottom: 0, right: 180, top: 90)
    drawing.program.setColor(red: 4.0/255, green: 80.0/255, blue: 117.0/255)
    drawing.DrawSquare(-180, bottom: -90, right: 180, top: 0)
    drawing.program.setModelView(GLKMatrix4Identity)
    

    let thetaSet = [-180, -90, 0, 90, 180]
    
    // Draw the vertical bands of text
    // Angles to draw:
    drawing.program.setColor(red: 33.0/255, green: 48.0/255, blue: 82.0/255)
    for theta in thetaSet {
      drawTextStrip(Float(theta), upper: true)
    }
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    for theta in thetaSet {
      drawTextStrip(Float(theta), upper: false)
    }
    
    // Other uppers
    drawing.program.setModelView(GLKMatrix4Identity)
    drawing.program.setColor(red: 4.0/255, green: 80.0/255, blue: 117.0/255)
    drawVerticalBand(90, width: 1.5, upper: true)
    drawVerticalBand(-90, width: 1.5, upper: true)
    drawVerticalBand(180, width: 1.5, upper: true)
    drawVerticalBand(-180, width: 1.5, upper: true)

    // White lowers
    drawing.program.setColor(red: 1, green: 1, blue: 1)
    drawVerticalBand(90, width: 1.5, upper: false)
    drawVerticalBand(-90, width: 1.5, upper: false)
    drawVerticalBand(180, width: 1.5, upper: false)
    drawVerticalBand(-180, width: 1.5, upper: false)

    // Orange bands
    drawing.program.setColor(red: 247.0/255, green: 101.0/255, blue: 3.0/255)
    drawVerticalBand(0, width: 2.5, upper: true)
    drawVerticalBand(0, width: 2.5, upper: false)
    drawing.DrawSquare(-180, bottom: -1, right: 180, top: 1)
  }
  
  func drawVerticalBand(thetaDeg: Float, width : Float, upper: Bool = true) {
    let theta : GLfloat = thetaDeg * π/180
    let w : GLfloat = sin(width * π/180)
    
    let sphereDomain : BulkSpherePosition
    if thetaDeg < -120*π/180 {
      sphereDomain = .Left
    } else if thetaDeg > 120*π/180 {
      sphereDomain = .Right
    } else {
      sphereDomain = .Middle
    }
    
    drawing.program.setUseTexture(false)
    // Generate the band geometry
    var band : [Point2D] = []
    for i in 0...100 {
      let y = sin(Float(i)/100.0 * π/2) * (upper ? 1 : -1)
      
      guard var sphePos = pointOffsetRayIntercept(
        sphericalPoint: SphericalPoint(theta: theta, phi: π/2, r: 1),
        offset: Point2D(x: -w/2, y: y)) else {
          break
      }
//      if sphePos == nil {
//        break
//      }
      var sphePos2 = pointOffsetRayIntercept(
        sphericalPoint: SphericalPoint(theta: theta, phi: π/2, r: 1),
        offset: Point2D(x: w/2, y: y))!
      
      // Rotate round if we went over a texture edge
      if sphereDomain == .Left && sphePos.theta > 120*π/180 {
        sphePos.theta = sphePos.theta - 2*π
      } else if sphereDomain == .Right && sphePos.theta < -120*π/180 {
        sphePos.theta = sphePos.theta + 2*π
      }
      if sphereDomain == .Left && sphePos2.theta > 120*π/180 {
        sphePos2.theta = sphePos2.theta - 2*π
      } else if sphereDomain == .Right && sphePos2.theta < -120*π/180 {
        sphePos2.theta = sphePos2.theta + 2*π
      }
      
      if upper {
        band.append(Point2D(sphePos.long, sphePos.lat-π/2))
        band.append(Point2D(sphePos2.long, sphePos2.lat-π/2))
      } else {
        band.append(Point2D(sphePos2.long, sphePos2.lat-π/2))
        band.append(Point2D(sphePos.long, sphePos.lat-π/2))
      }
    }
    var data = band.flatMap { return [GLfloat($0.x)*180/π, GLfloat($0.y)*180/π] as [GLfloat] }
    let bandBuffer = drawing.createVertexArray(positions: 2, textures: 0)
    glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*data.count,
      &data, GLenum(GL_STATIC_DRAW))
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, GLsizei(band.count-2))
    drawing.deleteVertexArray(bandBuffer)
  }
}
