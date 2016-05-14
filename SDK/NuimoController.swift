//
//  NuimoController.swift
//  Nuimo
//
//  Created by Lars Blumberg on 10/9/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

@objc public protocol NuimoController {
    var uuid: String {get}
    var delegate: NuimoControllerDelegate? {get set}

    var connectionState: NuimoConnectionState {get}
    // Battery level 0..100
    var batteryLevel: Int {get set}
    // Display interval in seconds
    var defaultMatrixDisplayInterval: NSTimeInterval {get set}
    // Brightness 0..1 (1=max)
    var matrixBrightness: Float {get set}

    func connect() -> Bool

    func disconnect() -> Bool

    /// Displays an LED matrix for an interval
    func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, withFadeTransition: Bool, resendsSameMatrix: Bool, writesWithResponse: Bool)
}

public extension NuimoController {
    /// Displays an LED matrix for an interval with withFadeTransition defaulting to false, resendsSameMatrix defaulting to true and writesWithResponse defaulting to true
    public func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, withFadeTransition: Bool = false, resendsSameMatrix: Bool = true, writesWithResponse: Bool = true) {
        writeMatrix(matrix, interval: interval, withFadeTransition: withFadeTransition, resendsSameMatrix: resendsSameMatrix, writesWithResponse: writesWithResponse)
    }

    /// Displays an LED matrix using the default display interval and with withFadeTransition defaulting to false, resendsSameMatrix defaulting to true and writesWithResponse defaulting to true
    public func writeMatrix(matrix: NuimoLEDMatrix, withFadeTransition: Bool = false, resendsSameMatrix: Bool = true, writesWithResponse: Bool = true) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval, withFadeTransition: withFadeTransition, resendsSameMatrix: resendsSameMatrix, writesWithResponse: writesWithResponse)
    }
}

@objc public enum NuimoConnectionState: Int {
    case
    Connecting,
    Connected,
    Disconnecting,
    Disconnected,
    Invalidated
}

@objc public protocol NuimoControllerDelegate {
    optional func nuimoControllerDidStartConnecting(controller: NuimoController)
    optional func nuimoControllerDidConnect(controller: NuimoController)
    optional func nuimoController(controller: NuimoController, didFailToConnect error: NSError?)
    optional func nuimoController(controller: NuimoController, didDisconnect error: NSError?)
    optional func nuimoControllerDidInvalidate(controller: NuimoController)
    optional func nuimoController(controller: NuimoController, didUpdateBatteryLevel bateryLevel: Int)
    optional func nuimoController(controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent)
    optional func nuimoControllerDidDisplayLEDMatrix(controller: NuimoController)
}
