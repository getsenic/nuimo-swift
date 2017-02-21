//
//  NuimoController.swift
//  Nuimo
//
//  Created by Lars Blumberg on 9/23/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import CoreBluetooth

// Represents a bluetooth low energy (BLE) Nuimo controller
open class NuimoBluetoothController: BLEDevice, NuimoController {
    public static let serviceUUIDs = nuimoServiceUUIDs

    open override class var connectionRetryCount:          Int           { return 5 }
    open override class var maxAdvertisingPackageInterval: TimeInterval? { return 10.0 }

    public weak var delegate: NuimoControllerDelegate?
    public private(set) var connectionState = NuimoConnectionState.disconnected
    public var defaultMatrixDisplayInterval: TimeInterval = 2.0
    public var matrixBrightness: Float = 1.0

    public private(set) var hardwareVersion: String?
    public private(set) var firmwareVersion: String? { didSet { didUpdateState() } }
    public private(set) var color:           String?

    open override var serviceUUIDs:                    [CBUUID]            { return nuimoServiceUUIDs }
    open override var charactericUUIDsForServiceUUID:  [CBUUID : [CBUUID]] { return nuimoCharactericUUIDsForServiceUUID }
    open override var notificationCharacteristicUUIDs: [CBUUID]            { return nuimoNotificationCharacteristicnUUIDs }

    public var supportsRebootToDFUMode:      Bool { return rebootToDFUModeCharacteristic != nil }
    public var supportsFlySensorCalibration: Bool { return flySensorCalibrationCharacteristic != nil }
    public var heartBeatInterval: TimeInterval = 0.0 { didSet { writeHeartBeatInterval() } }

    private lazy var matrixWriter: LEDMatrixWriter = LEDMatrixWriter(controller: self)
    private var connectTimeoutTimer: Timer?
    private var rebootToDFUModeCharacteristic: CBCharacteristic? { return peripheral?.service(with: kSensorServiceUUID)?.characteristic(with: kRebootToDFUModeCharacteristicUUID) }
    private var flySensorCalibrationCharacteristic: CBCharacteristic? { return peripheral?.service(with: kSensorServiceUUID)?.characteristic(with: kFlySensorCalibrationCharacteristicUUID) }

    open override func didUpdateState(error: Error? = nil) {
        super.didUpdateState()
        if peripheral?.state != .connected {
            matrixWriter.matrixCharacteristic = nil
        }
        let newState: NuimoConnectionState =  {
            guard isReachable, let peripheral = peripheral else { return .invalidated }
            switch peripheral.state {
            case .connected:     return  firmwareVersion == nil ? .connecting : .connected
            case .connecting:    return .connecting
            case .disconnected:  return .disconnected
            default:
                #if os(iOS) || os(tvOS)
                if peripheral.state == .disconnecting { return .disconnecting }
                #endif
                fatalError("Unexpected peripheral state: \(peripheral.state.rawValue)")
            }
        }()
        guard newState != connectionState else { return }
        connectionState = newState
        delegate?.nuimoController(self, didChangeConnectionState: connectionState, withError: error)
    }

    public func display(matrix: NuimoLEDMatrix, interval: TimeInterval, options: Int) {
        queue.async {
            self.matrixWriter.write(matrix: matrix, interval: interval, options: options)
        }
    }

    @discardableResult public func rebootToDFUMode() -> Bool {
        guard
            let peripheral = peripheral, peripheral.state == .connected,
            let rebootToDFUModeCharacteristic = rebootToDFUModeCharacteristic
        else {
            return false
        }
        queue.async {
            peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>([UInt8(1)]), count: 1), for: rebootToDFUModeCharacteristic, type: .withResponse)
        }
        return true
    }

    @discardableResult public func calibrateFlySensor() -> Bool {
        guard
            let peripheral = peripheral, peripheral.state == .connected,
            let flySensorCalibrationCharacteristic = flySensorCalibrationCharacteristic
        else {
            return false
        }
        queue.async {
            peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>([UInt8(1)]), count: 1), for: flySensorCalibrationCharacteristic, type: .withResponse)
        }
        return true
    }

    fileprivate func writeHeartBeatInterval() {
        guard
            let peripheral = peripheral, peripheral.state == .connected,
            let service = peripheral.services?.filter({ $0.uuid == kSensorServiceUUID }).first,
            let characteristic = service.characteristics?.filter({ $0.uuid == kHeartBeatCharacteristicUUID }).first
        else {
            return
        }
        let interval = UInt8(max(0, min(255, heartBeatInterval)))
        queue.async {
            peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>([interval]), count: 1), for: characteristic, type: .withResponse)
        }
    }

    //MARK: CBPeripheralDelegate

    open override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        super.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        service.characteristics?.forEach{ characteristic in
            switch characteristic.uuid {
            case kHardwareVersionCharacteristicUUID: fallthrough
            case kFirmwareVersionCharacteristicUUID: fallthrough
            case kModelNumberCharacteristicUUID:     fallthrough
            case kBatteryCharacteristicUUID:         peripheral.readValue(for: characteristic)
            case kLEDMatrixCharacteristicUUID:       matrixWriter.matrixCharacteristic = characteristic
            case kHeartBeatCharacteristicUUID:       writeHeartBeatInterval()
            default:
                break
            }
        }
    }

    open override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case kHardwareVersionCharacteristicUUID: hardwareVersion = String(data: data, encoding: .utf8)
        case kFirmwareVersionCharacteristicUUID: firmwareVersion = String(data: data, encoding: .utf8)
        case kModelNumberCharacteristicUUID:     color           = String(data: data, encoding: .utf8)
        case kBatteryCharacteristicUUID:         delegate?.nuimoController(self, didUpdateBatteryLevel: Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee))
        case kHeartBeatCharacteristicUUID:       NotificationCenter.default.post(name: .NuimoBluetoothControllerDidSendHeartBeat, object: self, userInfo: nil)
        default:                                 if let event = characteristic.nuimoGestureEvent() { delegate?.nuimoController(self, didReceiveGestureEvent: event) }
        }
    }

    open override func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
        if characteristic.uuid == kLEDMatrixCharacteristicUUID {
            matrixWriter.didRetrieveMatrixWriteResponse()
            delegate?.nuimoControllerDidDisplayLEDMatrix(self)
        }
    }
}

public let NuimoBluetoothControllerDidSendHeartBeatNotification = "NuimoBluetoothControllerDidSendHeartBeatNotification"
public extension Notification.Name {
    public static let NuimoBluetoothControllerDidSendHeartBeat = Notification.Name(rawValue: NuimoBluetoothControllerDidSendHeartBeatNotification)
}

//MARK: - LED matrix writing

private class LEDMatrixWriter {
    unowned let controller: NuimoBluetoothController
    var matrixCharacteristic: CBCharacteristic?

    private var currentMatrix: NuimoLEDMatrix?
    private var currentDisplayInterval: TimeInterval = 0.0
    private var currentWithFadeTransition = false
    private var lastWrittenMatrix = NuimoLEDMatrix(string: "")
    private var lastWrittenMatrixDate = Date(timeIntervalSince1970: 0.0)
    private var lastWrittenMatrixDisplayInterval: TimeInterval = 0.0
    private var isWaitingForWriteResponse = false
    private var writeOnResponseReceived = false
    private var writeResponseTimeoutDispatchWorkItem: DispatchWorkItem?

    init(controller: NuimoBluetoothController) {
        self.controller = controller
    }

    func write(matrix: NuimoLEDMatrix, interval: TimeInterval, options: Int) {
        let resendsSameMatrix  = options & NuimoLEDMatrixWriteOption.ignoreDuplicates.rawValue     == 0
        let withFadeTransition = options & NuimoLEDMatrixWriteOption.withFadeTransition.rawValue   != 0
        let withWriteResponse  = options & NuimoLEDMatrixWriteOption.withoutWriteResponse.rawValue == 0

        guard
            resendsSameMatrix ||
            lastWrittenMatrix != matrix ||
            (lastWrittenMatrixDisplayInterval > 0 && -lastWrittenMatrixDate.timeIntervalSinceNow >= lastWrittenMatrixDisplayInterval)
        else {
            return
        }

        currentMatrix             = matrix
        currentDisplayInterval    = interval
        currentWithFadeTransition = withFadeTransition

        if withWriteResponse && isWaitingForWriteResponse {
            writeOnResponseReceived = true
        }
        else {
            writeMatrixNow(withWriteResponse: withWriteResponse)
        }
    }

    private func writeMatrixNow(withWriteResponse: Bool) {
        guard
            let peripheral = controller.peripheral,
            peripheral.state == .connected,
            let matrixCharacteristic = matrixCharacteristic
        else {
            return
        }
        guard let currentMatrix = currentMatrix else { fatalError("Invalid matrix write request") }
        var matrixBytes = currentMatrix.matrixBytes
        guard currentMatrix.matrixBytes.count == 11 && !(withWriteResponse && isWaitingForWriteResponse) else { fatalError("Invalid matrix write request") }

        matrixBytes[10] = matrixBytes[10] +
            (currentWithFadeTransition              ? UInt8(1 << 4) : 0) +
            (currentMatrix is NuimoBuiltInLEDMatrix ? UInt8(1 << 5) : 0)
        matrixBytes += [UInt8(min(max(controller.matrixBrightness, 0.0), 1.0) * 255), UInt8(currentDisplayInterval * 10.0)]
        peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>(matrixBytes), count: matrixBytes.count), for: matrixCharacteristic, type: withWriteResponse ? .withResponse : .withoutResponse)

        isWaitingForWriteResponse        = withWriteResponse
        lastWrittenMatrix                = currentMatrix
        lastWrittenMatrixDate            = Date()
        lastWrittenMatrixDisplayInterval = currentDisplayInterval

        if withWriteResponse {
            // When the matrix write response is not retrieved within 500ms we assume the response to have timed out
            writeResponseTimeoutDispatchWorkItem?.cancel()
            writeResponseTimeoutDispatchWorkItem = DispatchWorkItem() { [weak self] in self?.didRetrieveMatrixWriteResponse() }
            controller.queue.asyncAfter(deadline: .now() + 0.5, execute: writeResponseTimeoutDispatchWorkItem!)
        }
    }

    dynamic func didRetrieveMatrixWriteResponse() {
        guard isWaitingForWriteResponse else { return }
        isWaitingForWriteResponse = false
        writeResponseTimeoutDispatchWorkItem?.cancel()

        // Write next matrix if any
        if writeOnResponseReceived {
            writeOnResponseReceived = false
            writeMatrixNow(withWriteResponse: true)
        }
    }
}

//MARK: Nuimo BLE GATT service and characteristic UUIDs

private let kBatteryServiceUUID                     = CBUUID(string: "180F")
private let kBatteryCharacteristicUUID              = CBUUID(string: "2A19")
private let kDeviceInformationServiceUUID           = CBUUID(string: "180A")
private let kHardwareVersionCharacteristicUUID      = CBUUID(string: "2A27")
private let kFirmwareVersionCharacteristicUUID      = CBUUID(string: "2A26")
private let kModelNumberCharacteristicUUID          = CBUUID(string: "2A24")
private let kLEDMatrixServiceUUID                   = CBUUID(string: "F29B1523-CB19-40F3-BE5C-7241ECB82FD1")
private let kLEDMatrixCharacteristicUUID            = CBUUID(string: "F29B1524-CB19-40F3-BE5C-7241ECB82FD1")
private let kSensorServiceUUID                      = CBUUID(string: "F29B1525-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorFlyCharacteristicUUID            = CBUUID(string: "F29B1526-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorTouchCharacteristicUUID          = CBUUID(string: "F29B1527-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorRotationCharacteristicUUID       = CBUUID(string: "F29B1528-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorButtonCharacteristicUUID         = CBUUID(string: "F29B1529-CB19-40F3-BE5C-7241ECB82FD2")
private let kRebootToDFUModeCharacteristicUUID      = CBUUID(string: "F29B152A-CB19-40F3-BE5C-7241ECB82FD2")
private let kHeartBeatCharacteristicUUID            = CBUUID(string: "F29B152B-CB19-40F3-BE5C-7241ECB82FD2")
private let kFlySensorCalibrationCharacteristicUUID = CBUUID(string: "F29B152C-CB19-40F3-BE5C-7241ECB82FD2")

internal let nuimoServiceUUIDs: [CBUUID] = [
    kBatteryServiceUUID,
    kDeviceInformationServiceUUID,
    kLEDMatrixServiceUUID,
    kSensorServiceUUID
]

private let nuimoCharactericUUIDsForServiceUUID = [
    kBatteryServiceUUID: [kBatteryCharacteristicUUID],
    kDeviceInformationServiceUUID: [
        kHardwareVersionCharacteristicUUID,
        kFirmwareVersionCharacteristicUUID,
        kModelNumberCharacteristicUUID
    ],
    kLEDMatrixServiceUUID: [kLEDMatrixCharacteristicUUID],
    kSensorServiceUUID: [
        kSensorFlyCharacteristicUUID,
        kSensorTouchCharacteristicUUID,
        kSensorRotationCharacteristicUUID,
        kSensorButtonCharacteristicUUID,
        kRebootToDFUModeCharacteristicUUID,
        kHeartBeatCharacteristicUUID,
        kFlySensorCalibrationCharacteristicUUID
    ]
]

private let nuimoNotificationCharacteristicnUUIDs = [
    kBatteryCharacteristicUUID,
    kSensorFlyCharacteristicUUID,
    kSensorTouchCharacteristicUUID,
    kSensorRotationCharacteristicUUID,
    kSensorButtonCharacteristicUUID,
    kHeartBeatCharacteristicUUID
]

//MARK: - Private extensions

//MARK: Initializers for NuimoGestureEvents from BLE GATT data

private extension NuimoGestureEvent {
    convenience init?(gattFlyData data: Data) {
        let bytes = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
        let directionByte = bytes.pointee
        let speedByte = bytes.advanced(by: 1).pointee
        guard let gesture: NuimoGesture = [0: .flyLeft, 1: .flyRight, 4: .flyUpDown][directionByte] else { return nil }
        self.init(gesture: gesture, value: gesture == .flyUpDown ? Int(speedByte) : nil)
    }

    convenience init?(gattTouchData data: Data) {
        let bytes = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
        guard let gesture: NuimoGesture = [
            0:  .swipeLeft,
            1:  .swipeRight,
            2:  .swipeUp,
            3:  .swipeDown,
            4:  .touchLeft,
            5:  .touchRight,
            6:  .touchTop,
            7:  .touchBottom,
            8:  .longTouchLeft,
            9:  .longTouchRight,
            10: .longTouchTop,
            11: .longTouchBottom
        ][bytes.pointee] else { return nil }
        self.init(gesture: gesture, value: nil)
    }

    convenience init(gattRotationData data: Data) {
        let value = Int((data as NSData).bytes.bindMemory(to: Int16.self, capacity: data.count).pointee)
        self.init(gesture: .rotate, value: value)
    }

    convenience init(gattButtonData data: Data) {
        let value = Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee)
        self.init(gesture: value == 1 ? .buttonPress : .buttonRelease, value: value)
    }
}

//MARK: Matrix string to byte array conversion

private extension NuimoLEDMatrix {
    var matrixBytes: [UInt8] {
        return leds
            .chunk(8)
            .map{ $0
                .enumerated()
                .map { (i: Int, b: Bool) -> Int in return b ? 1 << i : 0 }
                .reduce(UInt8(0)) { (s: UInt8, v: Int) -> UInt8 in s + UInt8(v) }
            }
    }
}

private extension Sequence {
    func chunk(_ n: Int) -> [[Iterator.Element]] {
        var chunks: [[Iterator.Element]] = []
        var chunk: [Iterator.Element] = []
        chunk.reserveCapacity(n)
        chunks.reserveCapacity(underestimatedCount / n)
        var i = n
        self.forEach {
            chunk.append($0)
            i -= 1
            if i == 0 {
                chunks.append(chunk)
                chunk.removeAll(keepingCapacity: true)
                i = n
            }
        }
        if !chunk.isEmpty { chunks.append(chunk) }
        return chunks
    }
}

//MARK: Extension methods for CoreBluetooth

private extension CBCharacteristic {
    func nuimoGestureEvent() -> NuimoGestureEvent? {
        guard let data = value else { return nil }

        switch uuid {
        case kSensorFlyCharacteristicUUID:      return NuimoGestureEvent(gattFlyData: data)
        case kSensorTouchCharacteristicUUID:    return NuimoGestureEvent(gattTouchData: data)
        case kSensorRotationCharacteristicUUID: return NuimoGestureEvent(gattRotationData: data)
        case kSensorButtonCharacteristicUUID:   return NuimoGestureEvent(gattButtonData: data)
        default: return nil
        }
    }
}
