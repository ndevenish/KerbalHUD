//
//  GeometryGeneration.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 02/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

func generateSphereTriangles(r : GLfloat, latSteps : UInt, longSteps : UInt) -> [Triangle<TexturedPoint3D>]
{
//  let t = (1 + sqrt(5.0)) / 2
  
  var tris : [Triangle<TexturedPoint3D>] = []
  
  // Main body
  for iLong in 0..<longSteps {
    for iLat in 0..<latSteps {
      // B-----D
      // |     |
      // A-----C
      let u = Float(iLong)/Float(longSteps)
      let v = Float(iLat)/Float(latSteps)
      let uPlus = Float(iLong+1)/Float(longSteps)
      let vPlus = Float(iLat+1)/Float(latSteps)
      let positionA = TexturedPoint3D(
        SphericalPoint(
          theta: 2*π * Float(iLong)/Float(longSteps),
          phi: π * (1-Float(iLat)/Float(latSteps)),
          r: r),
        u: u, v: v)
      let positionB = TexturedPoint3D(
        SphericalPoint(
          theta: 2*π * Float(iLong)/Float(longSteps),
          phi: π * (1-Float(iLat+1)/Float(latSteps)),
          r: r),
        u: u, v: vPlus)
      let positionC = TexturedPoint3D(
        SphericalPoint(
          theta: 2*π * Float(iLong+1)/Float(longSteps),
          phi: π * (1-Float(iLat)/Float(latSteps)),
          r: r),
        u: uPlus, v: v)
      let positionD = TexturedPoint3D(
        SphericalPoint(
          theta: 2*π * Float(iLong+1)/Float(longSteps),
          phi: π * (1-Float(iLat+1)/Float(latSteps)),
          r: r),
        u: uPlus, v: vPlus)
      tris.append(Triangle(positionC, positionA, positionB))
      tris.append(Triangle(positionB, positionD, positionC))
      
    }
  }
  return tris
}

/// Generates a series of triangles for an open circle
func GenerateCircleTriangles(r : GLfloat, w : GLfloat, steps Csteps : Int = 20) -> [Triangle<Point2D>]
{
  var tris : [Triangle<Point2D>] = []
//  let Csteps = 20
  let innerR = r - w/2
  let outerR = r + w/2
  
  for step in 0..<Csteps {
    let theta = Float(2*M_PI*(Double(step)/Double(Csteps)))
    let nextTheta = Float(2*M_PI*(Double(step+1)/Double(Csteps)))
    tris.append(Triangle(
      Point2D(x: innerR*sin(theta), y: innerR*cos(theta)),
      Point2D(x: outerR*sin(theta), y: outerR*cos(theta)),
      Point2D(x: innerR*sin(nextTheta), y: innerR*cos(nextTheta))
    ))
    tris.append(Triangle(
      Point2D(x: innerR*sin(nextTheta), y: innerR*cos(nextTheta)),
      Point2D(x: outerR*sin(theta), y: outerR*cos(theta)),
      Point2D(x: outerR*sin(nextTheta), y: outerR*cos(nextTheta))
    ))
  }
  return tris
}

func GenerateBoxTriangles(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat) -> [Triangle<Point2D>] {
  return [
    Triangle(Point2D(x: left, y: bottom), Point2D(x: left, y: top), Point2D(x: right, y: top)),
    Triangle(Point2D(x: right, y: top), Point2D(x: right, y: bottom), Point2D(x: left, y: bottom))
  ]
}

func GenerateRoundedBoxPoints(
  left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat,
  radius: GLfloat,
  topLeft: Bool = true, topRight: Bool = true,
  bottomRight: Bool = true, bottomLeft: Bool = true)
    -> [Point2D]
{
  // How many steps to do in a corner
  let STEPS = 5
  let STEP_ANGLE = π/2.0/Float(STEPS+2)
  // Start before the top-left circle
  var points : [(Float, Float)] = [(left, top-radius)]
  if topLeft {
    // Do the inner circle points
    for step in 1...STEPS {
      let x = -cos(STEP_ANGLE*Float(step))*radius
      let y = sin(STEP_ANGLE*Float(step))*radius
      points.append((left+radius+x, top-radius+y))
    }
  } else {
    points.append((left, top))
  }
  points.append((left+radius, top))
  points.append((right-radius, top))
  if topRight {
    // Do the inner circle points
    for step in 1...STEPS {
      let x = sin(STEP_ANGLE*Float(step))*radius
      let y = cos(STEP_ANGLE*Float(step))*radius
      points.append((right-radius+x, top-radius+y))
    }
  } else {
    points.append((right, top))
  }
  points.append((right, top-radius))
  points.append((right, bottom+radius))
  if bottomRight {
    for step in 1...STEPS {
      let x = cos(STEP_ANGLE*Float(step))*radius
      let y = -sin(STEP_ANGLE*Float(step))*radius
      points.append((right-radius+x, bottom+radius+y))
    }
  } else {
    points.append((right, bottom))
  }
  points.append((right-radius, bottom))
  points.append((left+radius, bottom))
  if bottomLeft {
    for step in 1...STEPS {
      let x = -sin(STEP_ANGLE*Float(step))*radius
      let y = -cos(STEP_ANGLE*Float(step))*radius
      points.append((left+radius+x, bottom+radius+y))
    }
  } else {
    points.append((left, bottom))
  }
  points.append((left, bottom+radius))
  
  //  return
  return points.map({Point2D(x: $0.0, y: $0.1)})
}
