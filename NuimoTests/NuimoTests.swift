//
//  NuimoTests.swift
//  NuimoTests
//
//  Created by Lars Blumberg on 12/11/15.
//  Copyright © 2015 senic. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import Nuimo

class NuimoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    
    func testDiscoveryManagerDiscoversNuimoController() {
        let expectation = expectationWithDescription("Discovery manager should discover nuimo controller")
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { _ in
            discovery.stopDiscovery()
            expectation.fulfill()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(10.0) {_ in discovery.stopDiscovery() }
    }

    func testDiscoveryManagerDiscoversSameNuimoControllerOnlyOnce() {
        continueAfterFailure = false
        let expectation = expectationWithDescription("Discovery manager should discovery same nuimo controller only once")
        var controllers = [String]()
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: {
            print("Found \($0.uuid)")
            XCTAssertFalse(controllers.contains($0.uuid))
            controllers.append($0.uuid)
        })
        discovery.startDiscovery()
        after(19.0) {
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(20.0) {_ in
            discovery.stopDiscovery()
        }
        continueAfterFailure = true
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
        waitForExpectationsWithTimeout(10.0) {_ in discovery.stopDiscovery() }
    }

    func testNuimoControllerDisplaysLEDMatrix() {
        let expectation = expectationWithDescription("Nuimo controller should display LED matrix")
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { controller in
            discovery.stopDiscovery()
            controller.delegate = NuimoControllerDelegateClosures(
                onConnect: {
                    controller.writeMatrix(NuimoLEDMatrix(string: String(count: 81, repeatedValue: Character("*"))), interval: 5.0)
                },
                onLEDMatrixDisplayed: {
                    after(2.0) {
                        controller.disconnect()
                        expectation.fulfill()
                    }
                }
            )
            controller.connect()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(10.0) {_ in discovery.stopDiscovery() }
    }

    func testNuimoControllerDisplaysLEDMatrixAnimation() {
        let expectation = expectationWithDescription("Nuimo controller should display LED matrix animation")
        let discovery = NuimoDiscoveryManager()
        discovery.delegate = NuimoDiscoveryDelegateClosures(onDiscoverController: { controller in
            discovery.stopDiscovery()
            var frameIndex = 0
            let displayFrame = {
                controller.writeMatrix(NuimoLEDMatrix(string: String(count: (frameIndex % 81) + 1, repeatedValue: Character("*"))), interval: 5.0)
            }
            controller.delegate = NuimoControllerDelegateClosures(
                onConnect: {
                    displayFrame()
                },
                onLEDMatrixDisplayed: {
                    frameIndex += 1
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
        waitForExpectationsWithTimeout(30.0) {_ in discovery.stopDiscovery() }
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
                onConnect: {
                    var frameIndex = 0
                    var nextFrame = {}
                    nextFrame = {
                        after(sendFramesRepeatInterval) {
                            guard frameIndex < sendFramesCount else {
                                controller.disconnect()
                                expectation.fulfill()
                                return
                            }
                            frameIndex += 1
                            controller.writeMatrix(NuimoLEDMatrix(string: String(count: frameIndex % 81, repeatedValue: Character("*"))), interval: 2.0)
                            nextFrame()
                        }
                    }
                    nextFrame()
                },
                onLEDMatrixDisplayed: {
                    framesDisplayed += 1
                }
            )
            controller.connect()
        })
        discovery.startDiscovery()
        waitForExpectationsWithTimeout(20.0) {_ in discovery.stopDiscovery() }

        XCTAssert(framesDisplayed >= expectedMinDisplayedFrameCount, "Nuimo controller should display at least \(expectedMinDisplayedFrameCount) animation frames but it displayed only \(framesDisplayed) frames")
        XCTAssert(framesDisplayed <= expectedMaxDisplayedFrameCount, "Nuimo controller should not display more than \(expectedMaxDisplayedFrameCount) but it displayed \(framesDisplayed)")
    }
}

func after(delay: NSTimeInterval, block: dispatch_block_t) {
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
    let onLEDMatrixDisplayed: (() -> Void)?

    init(onConnect: (() -> Void)? = nil, onLEDMatrixDisplayed: (() -> Void)? = nil) {
        self.onConnect = onConnect
        self.onLEDMatrixDisplayed = onLEDMatrixDisplayed
    }

    @objc func nuimoController(controller: NuimoController, didChangeConnectionState state: NuimoConnectionState, withError error: NSError?) {
        if state == .Connected {
            onConnect?()
        }
    }
    @objc func nuimoControllerDidDisplayLEDMatrix(controller: NuimoController) {
        onLEDMatrixDisplayed?()
    }

    @objc func nuimoController(controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent) {
    }

    @objc func nuimoController(controller: NuimoController, didUpdateBatteryLevel bateryLevel: Int) {
    }
}
