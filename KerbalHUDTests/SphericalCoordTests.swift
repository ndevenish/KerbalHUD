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
  
  func testBasicProjection() {
    let oneR = SphericalPoint(theta: 0, phi: 0, r: 1)
    // Test no offset
    let ll = pointAndOffsetToLatandLong(sphericalPoint: oneR, offset: Point2D(x: 0, y: 0))
    XCTAssertEqualWithAccuracy(ll.lat, 0, accuracy: 1e-5)
    XCTAssertEqualWithAccuracy(ll.long, 0, accuracy: 1e-5)
    
    // Simple, vertical offset
    let llOff = pointAndOffsetToLatandLong(sphericalPoint: oneR, offset: Point2D(x: 0, y: 1))
    XCTAssertEqualWithAccuracy(llOff.lat, π/4, accuracy: 1e-6)
    XCTAssertEqualWithAccuracy(llOff.long, 0, accuracy: 1e-6)
    XCTAssertEqualWithAccuracy(llOff.r, sqrt(2), accuracy: 1e-6)
    
    // Try putting back in this, and stepping back to the origin
    let llOffBack = pointAndOffsetToLatandLong(sphericalPoint: llOff, offset: Point2D(x: 0, y: -sqrt(2)))
    XCTAssertEqualWithAccuracy(llOffBack.phi, 0, accuracy: 1e-6)
    XCTAssertEqualWithAccuracy(llOffBack.theta, 0, accuracy: 1e-6)
    XCTAssertEqualWithAccuracy(llOffBack.r, 2, accuracy: 1e-6)
  }
  
  func testRayIntersection() {
    let oneR = SphericalPoint(theta: 0, phi: 0, r: 1)
    let ll = pointOffsetRayIntercept(sphericalPoint: oneR, offset: nil)
    XCTAssertEqual(ll, SphericalPoint(theta: 0, phi: 0, r: 1))
    let llEdge = pointOffsetRayIntercept(sphericalPoint: oneR, offset: Point2D(x: 0, y: 1))
    XCTAssertEqual(llEdge, SphericalPoint(theta: 0, phi: π/2, r: 1))
    
  }
}
