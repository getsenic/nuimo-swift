//
//  NuimoTests.swift
//  NuimoTests
//
//  Created by Lars Blumberg on 12/11/15.
//  Copyright © 2015 senic. All rights reserved.
//

import XCTest
@testable import Nuimo

class NuimoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDiscoveryManagerDiscoversNuimoController() {
        let expectation = expectationWithDescription("Discovery manager should discover nuimo controller")
        let discovery = NuimoDiscoveryManager()
        let testDelegate = NuimoDiscoveryTestDelegate()
        testDelegate.onDiscoverController = { _ in
            discovery.stopDiscovery()
            expectation.fulfill()
        }
        discovery.delegate = testDelegate
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(10.0, handler: { (error) in
            if let _ = error {
                XCTFail("Nuimo controller not discovered before timeout")
            }
        })
    }
}

class NuimoDiscoveryTestDelegate : NuimoDiscoveryDelegate {
    var onDiscoverController: ((NuimoController) -> Void)? = nil

    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController) {
        onDiscoverController?(controller)
    }
}
