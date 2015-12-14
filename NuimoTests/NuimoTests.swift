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
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { _ in
            discovery.stopDiscovery()
            expectation.fulfill()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(10.0, handler: {_ in discovery.stopDiscovery() })
    }

    func testNuimoControllerConnects() {
        let expectation = expectationWithDescription("Nuimo controller should connect")
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { controller in
            discovery.stopDiscovery()
            controller.delegate = NuimoControllerDelegateClosures(onConnect: {
                controller.disconnect()
                expectation.fulfill()
            })
            controller.connect()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(10.0, handler: {_ in discovery.stopDiscovery() })
    }

    func testNuimoControllerDisplayLEDMatrix() {
        let expectation = expectationWithDescription("Nuimo controller should display LED matrix")
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { controller in
            discovery.stopDiscovery()
            controller.delegate = NuimoControllerDelegateClosures(
                onReady: {
                    controller.writeMatrix(NuimoLEDMatrix(string: String(count: 81, repeatedValue: Character("*"))), interval: 5.0)
                },
                onLEDMatrixDisplayed: {
                    after(2.0, {
                        controller.disconnect()
                        expectation.fulfill()
                    })
                }
            )
            controller.connect()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(10.0, handler: {_ in discovery.stopDiscovery() })
    }

    func testNuimoControllerDisplaysLEDMatrixAnimation() {
        let expectation = expectationWithDescription("Nuimo controller should display LED matrix animation")
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { controller in
            discovery.stopDiscovery()
            var frameIndex = 0
            let displayFrame = {
                controller.writeMatrix(NuimoLEDMatrix(string: String(count: frameIndex < 81 ? (frameIndex + 1) : (frameIndex % 2 == 0 ? 0 : 81), repeatedValue: Character("*"))), interval: 5.0)
            }
            controller.delegate = NuimoControllerDelegateClosures(
                onReady: {
                    displayFrame()
                },
                onLEDMatrixDisplayed: {
                    frameIndex++
                    switch (frameIndex) {
                    case 110: after(2.0) {
                        controller.disconnect()
                        expectation.fulfill()
                    }
                    default: displayFrame()
                    }
                }
            )
            controller.connect()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(30.0, handler: {_ in discovery.stopDiscovery() })
    }

    func testNuimoControllerSkipsLEDAnimationFramesIfFramesAreSentTooFast() {
        let sendFramesRepeatInterval = 0.01
        let sendFramesCount = 500
        let expectedMinDisplayedFrameCount = 20
        let expectedMaxDisplayedFrameCount = 100
        var framesDisplayed = 0
        let expectation = expectationWithDescription("All animation frames should be sent")
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { controller in
            discovery.stopDiscovery()
            controller.delegate = NuimoControllerDelegateClosures(
                onReady: {
                    var frameIndex = 0
                    var nextFrame = {}
                    nextFrame = {
                        after(sendFramesRepeatInterval, {
                            guard frameIndex < sendFramesCount else {
                                controller.disconnect()
                                expectation.fulfill()
                                return
                            }
                            frameIndex += 1
                            controller.writeMatrix(NuimoLEDMatrix(string: String(count: frameIndex % 81, repeatedValue: Character("*"))), interval: 2.0)
                            nextFrame()
                        })
                    }
                    nextFrame()
                },
                onLEDMatrixDisplayed: {
                    framesDisplayed++
                }
            )
            controller.connect()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(10.0, handler: {_ in discovery.stopDiscovery() })

        XCTAssert(framesDisplayed >= expectedMinDisplayedFrameCount, "Nuimo controller should display at least \(expectedMinDisplayedFrameCount) animation frames but it displayed only \(framesDisplayed) frames")
        XCTAssert(framesDisplayed <= expectedMaxDisplayedFrameCount, "Nuimo controller should not display more than \(expectedMaxDisplayedFrameCount) but it displayed \(framesDisplayed)")
    }
}

func after(delay: NSTimeInterval, _ block: dispatch_block_t) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), block)
}

//TODO: Make this part of the SDK
class NuimoDiscoveryDelegateClosures : NuimoDiscoveryDelegate {
    let onDiscoverController: ((NuimoController) -> Void)

    init(onDiscoverController: ((NuimoController) -> Void)) {
        self.onDiscoverController = onDiscoverController
    }

    @objc func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController) {
        onDiscoverController(controller)
    }
}

//TODO: Make this part of the SDK
class NuimoControllerDelegateClosures : NuimoControllerDelegate {
    let onConnect: (() -> Void)?
    let onReady: (() -> Void)?
    let onLEDMatrixDisplayed: (() -> Void)?

    init(onConnect: (() -> Void)? = nil, onReady: (() -> Void)? = nil, onLEDMatrixDisplayed: (() -> Void)? = nil) {
        self.onConnect = onConnect
        self.onReady = onReady
        self.onLEDMatrixDisplayed = onLEDMatrixDisplayed
    }

    @objc func nuimoControllerDidStartConnecting(controller: NuimoController) {
    }

    @objc func nuimoControllerDidConnect(controller: NuimoController) {
        onConnect?()
    }

    @objc func nuimoControllerDidFailToConnect(controller: NuimoController) {
    }

    @objc func nuimoControllerDidDisconnect(controller: NuimoController) {
    }

    @objc func nuimoControllerDidDiscoverMatrixService(controller: NuimoController) {
        onReady?()
    }

    @objc func nuimoControllerDidDisplayLEDMatrix(controller: NuimoController) {
        onLEDMatrixDisplayed?()
    }

    @objc func nuimoController(controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent) {
    }

    @objc func nuimoController(controller: NuimoController, didUpdateBatteryLevel bateryLevel: Int) {
    }

    @objc func nuimoControllerDidInvalidate(controller: NuimoController) {
    }
}
