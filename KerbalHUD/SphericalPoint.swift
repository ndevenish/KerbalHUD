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
  
  var lat : GLfloat { return phi }
  var long : GLfloat { return theta }
  
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
    self.theta = long
    self.phi = lat
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

public func pointAndOffsetToLatandLong(sphericalPoint point: SphericalPoint, offset: Point2D)
  -> SphericalPoint
{
  // Calculate the x, y, z from this spherical point, and the unit vectors
  let p = GLKVector3Make(fromSpherical: point)
  let Q = p + offset.x*point.unitVectorTheta + offset.y*point.unitVectorPhi
  
  // Now! Convert this back into sphericals...
  return SphericalPoint(fromCartesian: Q)
}

func modSq(of: GLKVector3) -> GLfloat
{
  return GLKVector3DotProduct(of, of)
}

/// Casts an orthographic ray along the -r axis of the spherical point + 2D offset, and 
/// returns the closest point of intersection (if there is one). Assumes a sphere 
/// of radius 1 at the origin.
public func pointOffsetRayIntercept(sphericalPoint point: SphericalPoint, offset: Point2D)
  -> SphericalPoint?
{
  // l = line direction
  // o = line origin
  // c = center point of sphere
  // r = radius of sphere
  let l = -point.unitVectorR
  let o = GLKVector3Make(fromSpherical: point)
    + offset.x*point.unitVectorTheta
    + offset.y*point.unitVectorPhi
  let c = GLKVector3Make(0, 0, 0)
  let r : GLfloat = 1.0
  
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