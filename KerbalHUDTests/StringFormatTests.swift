//
//  StringFormatTests.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 08/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import XCTest
@testable import KerbalHUD

class StringFormatTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPercent() {
      let format = "{0,6:00.A0V%}"
      let result = try! String.Format(format, 4.434)
      XCTAssertEqual(result, "443.A4V%")
    }

}
