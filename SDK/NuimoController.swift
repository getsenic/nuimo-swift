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
    /// Display interval in seconds
    var defaultMatrixDisplayInterval: NSTimeInterval {get set}
    /// Brightness 0..1 (1=max)
    var matrixBrightness: Float {get set}

    func connect() -> Bool

    func disconnect() -> Bool

    /// Writes an LED matrix for an interval with options (options is of type Int for compatibility with Objective-C)
    func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, options: Int)
}

public extension NuimoController {
    /// Writes an LED matrix with options defaulting to ResendsSameMatrix and WithWriteResponse
    func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval) {
        writeMatrix(matrix, interval: interval, options: 0)
    }

    /// Writes an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func writeMatrix(matrix: NuimoLEDMatrix) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval)
    }

    /// Writes an LED matrix for an interval and with options
    public func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, options: NuimoLEDMatrixWriteOptions) {
        writeMatrix(matrix, interval: interval, options: options.rawValue)
    }

    /// Writes an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func writeMatrix(matrix: NuimoLEDMatrix, options: NuimoLEDMatrixWriteOptions) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval, options: options)
    }
}

@objc public enum NuimoLEDMatrixWriteOption: Int {
    case IgnoreDuplicates     = 1
    case WithFadeTransition   = 2
    case WithoutWriteResponse = 4
}

public struct NuimoLEDMatrixWriteOptions: OptionSetType {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let IgnoreDuplicates     = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.IgnoreDuplicates.rawValue)
    public static let WithFadeTransition   = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.WithFadeTransition.rawValue)
    public static let WithoutWriteResponse = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.WithoutWriteResponse.rawValue)
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
    optional func nuimoController(controller: NuimoController, didChangeConnectionState state: NuimoConnectionState, withError error: NSError?)
    optional func nuimoController(controller: NuimoController, didReadFirmwareVersion firmwareVersion: String)
    optional func nuimoController(controller: NuimoController, didUpdateBatteryLevel batteryLevel: Int)
    optional func nuimoController(controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent)
    optional func nuimoControllerDidDisplayLEDMatrix(controller: NuimoController)
}
