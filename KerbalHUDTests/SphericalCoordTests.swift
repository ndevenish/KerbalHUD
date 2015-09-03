//
//  KerbalHUDTests.swift
//  KerbalHUDTests
//
//  Created by Nicholas Devenish on 29/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import XCTest
@testable import KerbalHUD

class SphericalCoordTests : XCTestCase {
  
  override func setUp() {
    super.setUp()
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testRayIntersection() {
    let oneR = SphericalPoint(theta: 0, phi: 0, r: 1)
    let ll = pointOffsetRayIntercept(sphericalPoint: oneR, offset: nil)
    XCTAssertEqual(ll, SphericalPoint(theta: 0, phi: 0, r: 1))
    let llEdge = pointOffsetRayIntercept(sphericalPoint: oneR, offset: Point2D(x: 0, y: 1))
    XCTAssertEqual(llEdge, SphericalPoint(theta: 0, phi: π/2, r: 1))
    
    let llMid = pointOffsetRayIntercept(sphericalPoint: SphericalPoint(theta: 0, phi: 0, r: 2), offset: nil)
    XCTAssertEqual(llEdge, SphericalPoint(theta: 0, phi: 0, r: 1))
  }
  
  func testPointConversion() {
    let nullPoint = SphericalPoint(theta: 0, phi: 0, r: 1)
    let cart = GLKVector3Make(fromSpherical: nullPoint)
    let redo = SphericalPoint(fromCartesian: cart)
    XCTAssertEqual(nullPoint, redo)
  }
}
