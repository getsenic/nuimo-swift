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

    /// Writes an LED matrix for an interval with options (options is of type Int for compatibility with Objective-C)
    func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, options: Int)
}

public extension NuimoController {
    /// Writes an LED matrix with options defaulting to ResendsSameMatrix and WithWriteResponse
    func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval) {
        writeMatrix(matrix, interval: interval, options: NuimoLEDMatrixWriteOption.ResendsSameMatrix.rawValue | NuimoLEDMatrixWriteOption.WithWriteResponse.rawValue)
    }

    /// Writes an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func writeMatrix(matrix: NuimoLEDMatrix) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval)
    }

    /// Writes an LED matrix for an interval and with options
    public func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, options: NuimoLEDMatrixWriteOptions) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval, options: options.rawValue)
    }

    /// Writes an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func writeMatrix(matrix: NuimoLEDMatrix, options: NuimoLEDMatrixWriteOptions) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval, options: options)
    }
}

@objc public enum NuimoLEDMatrixWriteOption: Int {
    case ResendsSameMatrix  = 1
    case WithFadeTransition = 2
    case WithWriteResponse  = 4
}

public struct NuimoLEDMatrixWriteOptions: OptionSetType {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let ResendsSameMatrix  = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.ResendsSameMatrix.rawValue)
    public static let WithFadeTransition = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.WithFadeTransition.rawValue)
    public static let WithWriteResponse  = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.WithWriteResponse.rawValue)
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
