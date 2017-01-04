//
//  NuimoController.swift
//  Nuimo
//
//  Created by Lars Blumberg on 10/9/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

public protocol NuimoController: class {
    var uuid: String {get}
    var delegate: NuimoControllerDelegate? {get set}

    var connectionState: NuimoConnectionState {get}
    /// Display interval in seconds
    var defaultMatrixDisplayInterval: TimeInterval {get set}
    /// Brightness 0..1 (1=max)
    var matrixBrightness: Float {get set}

    var hardwareVersion: String? {get}
    var firmwareVersion: String? {get}
    var color:           String? {get}

    @discardableResult func connect() -> Bool

    @discardableResult func disconnect() -> Bool

    /// Displays an LED matrix for an interval with options (options is of type Int for compatibility with Objective-C)
    func display(matrix: NuimoLEDMatrix, interval: TimeInterval, options: Int)
}

public extension NuimoController {
    /// Displays an LED matrix with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func display(matrix: NuimoLEDMatrix, interval: TimeInterval) {
        display(matrix: matrix, interval: interval, options: 0)
    }

    /// Displays an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func display(matrix: NuimoLEDMatrix) {
        display(matrix: matrix, interval: defaultMatrixDisplayInterval)
    }

    /// Displays an LED matrix for an interval and with options
    public func display(matrix: NuimoLEDMatrix, interval: TimeInterval, options: NuimoLEDMatrixWriteOptions) {
        display(matrix: matrix, interval: interval, options: options.rawValue)
    }

    /// Displays an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func display(matrix: NuimoLEDMatrix, options: NuimoLEDMatrixWriteOptions) {
        display(matrix: matrix, interval: defaultMatrixDisplayInterval, options: options)
    }
}

@objc public enum NuimoLEDMatrixWriteOption: Int {
    case ignoreDuplicates     = 1
    case withFadeTransition   = 2
    case withoutWriteResponse = 4
}

public struct NuimoLEDMatrixWriteOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let IgnoreDuplicates     = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.ignoreDuplicates.rawValue)
    public static let WithFadeTransition   = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.withFadeTransition.rawValue)
    public static let WithoutWriteResponse = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.withoutWriteResponse.rawValue)
}

@objc public enum NuimoConnectionState: Int {
    case
    connecting,
    connected,
    disconnecting,
    disconnected,
    invalidated
}

public protocol NuimoControllerDelegate: class {
    func nuimoController(_ controller: NuimoController, didChangeConnectionState state: NuimoConnectionState, withError error: Error?)
    func nuimoController(_ controller: NuimoController, didUpdateBatteryLevel batteryLevel: Int)
    func nuimoController(_ controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent)
    func nuimoControllerDidDisplayLEDMatrix(_ controller: NuimoController)
}

public extension NuimoControllerDelegate {
    func nuimoController(_ controller: NuimoController, didChangeConnectionState state: NuimoConnectionState, withError error: Error?) {}
    func nuimoController(_ controller: NuimoController, didUpdateBatteryLevel batteryLevel: Int) {}
    func nuimoController(_ controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent) {}
    func nuimoControllerDidDisplayLEDMatrix(_ controller: NuimoController) {}
}
