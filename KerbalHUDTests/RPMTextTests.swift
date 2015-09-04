//
//  RPMTextTests.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 03/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import XCTest
@testable import KerbalHUD

class RPMTextTests: XCTestCase {

//    override func setUp() {
//        super.setUp()
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//    
//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//        super.tearDown()
//    }
//
//    func testExample() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//    }

//    func testParse() {
//      let c = RPMTextFile(file: NSBundle.mainBundle().URLForResource("RPMHUD", withExtension: "txt")!)
//    }

  func testSIP() {
    XCTAssertEqual(processSIPFormat(2000, formatString: "SIP4.0"), "2k")
    XCTAssertEqual(processSIPFormat(2453, formatString: "SIP6"), "2.453k")
    XCTAssertEqual(processSIPFormat(2453, formatString: "SIP_6"), "2.45 k")
  }
}
