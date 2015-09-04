//
//  SphericalPoint.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

//typealias SphericalPoint = (theta: GLfloat, phi: GLfloat, r: GLfloat)
//

public struct SphericalPoint : Equatable {
  public var theta : GLfloat
  public var phi : GLfloat
  public var r : GLfloat
  
  var lat : GLfloat { return (π/2 - phi) * 180/π }
  var long : GLfloat { return theta * 180/π }
  
  public init(fromCartesian from: GLKVector3) {
    theta = atan2(from.y, from.x)
    r = GLKVector3Length(from)
    phi = acos(from.z/r)
  }
  
  public init(theta: GLfloat, phi: GLfloat, r: GLfloat) {
    self.theta = theta
    self.phi = phi
    self.r = r
  }
  
  public init(lat: GLfloat, long: GLfloat, r: GLfloat) {
    self.theta = long * π/180
    self.phi = π/2 - (lat * π/180)
    self.r = r
  }
}

public func ==(left: SphericalPoint, right: SphericalPoint) -> Bool {
  return left.theta == right.theta && left.phi == right.phi && left.r == right.r
}

public func GLKVector3Make(fromSpherical from: SphericalPoint) -> GLKVector3 {
  return GLKVector3Make(
    from.r*cos(from.theta)*sin(from.phi),
    from.r*sin(from.theta)*sin(from.phi),
    from.r*cos(from.phi))
}

public extension SphericalPoint {
  var unitVectorPhi : GLKVector3 {
    return GLKVector3Make(
        cos(theta)*cos(phi),
        sin(theta)*cos(phi),
        -sin(phi))
  }
  var unitVectorTheta : GLKVector3 {
    return GLKVector3Make(-sin(theta), cos(theta), 0)
  }
  var unitVectorR : GLKVector3 {
    return GLKVector3Make(
      cos(theta)*sin(phi),
      sin(theta)*sin(phi),
      cos(phi))
  }
}

func modSq(of: GLKVector3) -> GLfloat
{
  return GLKVector3DotProduct(of, of)
}

/// Casts an orthographic ray along the -r axis of the spherical point + 2D offset, and 
/// returns the closest point of intersection (if there is one). Assumes a sphere 
/// of radius 1 at the origin.
public func pointOffsetRayIntercept(sphericalPoint point: SphericalPoint, offset: Point2D, radius : Float = 1.0)
  -> SphericalPoint?
{
  // l = line direction
  // o = line origin
  // c = center point of sphere
  // r = radius of sphere
  let l = -point.unitVectorR
  let o = GLKVector3Make(fromSpherical: point)
    + offset.x*point.unitVectorTheta
    - offset.y*point.unitVectorPhi
  let c = GLKVector3Make(0, 0, 0)
  let r : GLfloat = radius
  
  let sqrtPart = pow(l•(o-c), 2) - modSq(o-c) + r*r
  
  if sqrtPart < 0 {
    return nil
  }
  // We have at least one intersection. Calculate the smallest.
  let dBoth = -(l•(o-c)) ± sqrt(sqrtPart)
  let d = min(dBoth.0, dBoth.1)
  
  // Calculate the point on the sphere of this point
  let intersect = SphericalPoint(fromCartesian: o + d*l)
  return SphericalPoint(theta: intersect.theta, phi: intersect.phi, r: r)
}

private enum BulkSpherePosition {
  case Left
  case Right
  case Middle
}

extension DrawingTools {
  func drawProjectedGridOntoSphere(
    position position : SphericalPoint,
    left: Float, bottom: Float, right: Float, top: Float,
    xSteps : UInt, ySteps : UInt, slicePoint : Float)
  {
    // Work out if we are near the slice point
    let shiftedPosition = position.theta == π ? π : cyc_mod(position.theta - slicePoint + π, m: 2*π) - π
    let sphereDomain : BulkSpherePosition
    if shiftedPosition < -120 * π/180 {
      sphereDomain = .Left
    } else if shiftedPosition > 120*π/180 {
      sphereDomain = .Right
    } else {
      sphereDomain = .Middle
    }
    // Generate the grid projected onto the sphere
    let geometry = projectGridOntoSphere(position: position, left: left, bottom: bottom, right: right, top: top, xSteps: xSteps, ySteps: ySteps)

    // Flatten this into a data array, handling the slice shift
    var data = geometry.flatMap { (pos: Point2D, uv: Point2D) -> [GLfloat] in
      let theta : GLfloat
      let shiftedThetaA = cyc_mod(pos.x - slicePoint + 180, m: 360)-180
      let shiftedTheta = pos.x > 179 && shiftedThetaA == -180 ? 180 : shiftedThetaA
      if sphereDomain == .Left && shiftedTheta > 120 {
        theta = pos.x - 360
      } else if sphereDomain == .Right && shiftedTheta < -120 {
        theta = pos.x + 360
      } else {
        theta = pos.x
      }
      return [theta, pos.y, uv.x, uv.y]
    }
    
    // Load into a buffer object!
    let array = createVertexArray(positions: 2, textures: 2)
    glBufferData(
      GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*data.count,
      &data, GLenum(GL_DYNAMIC_DRAW))
    // Draw!
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, GLsizei(geometry.count))
    // Delete the array and buffer
    bind(VertexArray.Empty)
    deleteVertexArray(array)
  }
}

func projectGridOntoSphere(position basePosition : SphericalPoint,
  left: Float, bottom: Float, right: Float, top: Float,
  xSteps : UInt, ySteps : UInt) -> [(pos: Point2D, uv: Point2D)]
{
  let position = SphericalPoint(theta: basePosition.theta, phi: basePosition.phi, r: 60)
  let bounds = FixedBounds(left: left, bottom: bottom, right: right, top: top)
  let data = generateTriangleStripGrid(bounds, xSteps: xSteps, ySteps: ySteps)
  
  let geometry = data.map { (pos : Point2D, uv: Point2D) -> (pos : Point2D, uv: Point2D) in
    
//    let sphePos : SphericalPoint
    guard let sphePos = pointOffsetRayIntercept(sphericalPoint: position,
      offset: pos, radius: 59) else {
      let sphePos = pointOffsetRayIntercept(sphericalPoint: position,
        offset: pos, radius: 59)
      fatalError()
    }
    
    return (Point2D(sphePos.long, sphePos.lat), uv)
  }

  return geometry
}

func generateTriangleStripGrid(bounds : Bounds, xSteps : UInt, ySteps : UInt)
  -> [(pos: Point2D, uv: Point2D)]
{
  var data : [(pos: Point2D, uv: Point2D)] = []
  
  // Generate all the points on a grid for this
  for iY in 0..<ySteps {
    for iX in 0...xSteps {
      let xFrac = Float(iX)/Float(xSteps)
      let yFrac = Float(iY)/Float(ySteps)
      
      // The offset points of this index specifically
      let xOffset = bounds.size.w * xFrac + bounds.left
      let yOffset = bounds.size.h * yFrac + bounds.bottom
      
      let uv = Point2D(x: xFrac, y: 1-yFrac)
      
      // If we have data already, double-up the first vertex as we will
      // need to do so for a triangle strip
      if iX == 0 && data.count > 0 {
        data.append((pos: Point2D(x: xOffset, y: yOffset), uv: uv))
      }
      data.append((Point2D(x: xOffset, y: yOffset), uv))
      
      // Calculate the y of the next one up
      let nextYFrac = Float(iY+1)/Float(ySteps)
      let yOffset2 = bounds.size.h * nextYFrac + bounds.bottom
      let uvUp = Point2D(x: xFrac, y: 1-nextYFrac)
      data.append((Point2D(x: xOffset, y: yOffset2), uvUp))
    }
    // Finish the triangle strip line
    data.append(data.last!)
  }
  // Remove the last item as it will double up otherwise (empty triangle)
  data.removeLast()

  return data
}
