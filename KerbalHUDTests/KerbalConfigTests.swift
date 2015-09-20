//
//  Created by Nicholas Devenish on 08/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import XCTest
@testable import KerbalHUD

class KerbalConfigTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

  func testLexer() {
    let u = NSBundle.mainBundle().URLForResource("mfd.txt", withExtension: nil)
    let f = try! String(contentsOfURL: u!)
//    let l = KerbalConfigLexer(data: "    TEST //dome\nt")
    let l = KerbalConfigLexer(data: f)
    for token in l {
      print(token)
    }
  }
  
  func testParser() {
    let u = NSBundle.mainBundle().URLForResource("mfd.txt", withExtension: nil)!
    let data = try! String(contentsOfURL: u)
    let f = try! parseKerbalConfig(withContentsOfFile: data)
//    print(f)
    let pages = f.filterNodes { $0.type == "PAGE" }
    print(pages)
  }
  
  
}
