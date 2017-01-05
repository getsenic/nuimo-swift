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
    open override class var connectionRetryCount:          Int           { return 5 }
    open override class var maxAdvertisingPackageInterval: TimeInterval? { return 10.0 }

    public weak var delegate: NuimoControllerDelegate?
    public private(set) var connectionState = NuimoConnectionState.disconnected
    public var defaultMatrixDisplayInterval: TimeInterval = 2.0
    public var matrixBrightness: Float = 1.0 { didSet { matrixWriter?.brightness = self.matrixBrightness } }

    public private(set) var hardwareVersion: String?
    public private(set) var firmwareVersion: String? { didSet { setConnectionState(.connected) } }
    public private(set) var color:           String?

    open override var serviceUUIDs:                    [CBUUID]            { return nuimoServiceUUIDs }
    open override var charactericUUIDsForServiceUUID:  [CBUUID : [CBUUID]] { return nuimoCharactericUUIDsForServiceUUID }
    open override var notificationCharacteristicUUIDs: [CBUUID]            { return nuimoNotificationCharacteristicnUUIDs }

    public var supportsRebootToDFUMode:      Bool { return rebootToDFUModeCharacteristic != nil }
    public var supportsFlySensorCalibration: Bool { return flySensorCalibrationCharacteristic != nil }
    public var heartBeatInterval: TimeInterval = 0.0 { didSet { writeHeartBeatInterval() } }

    private var matrixWriter: LEDMatrixWriter?
    private var connectTimeoutTimer: Timer?
    private var rebootToDFUModeCharacteristic: CBCharacteristic? { return peripheral.service(with: kSensorServiceUUID)?.characteristic(with: kRebootToDFUModeCharacteristicUUID) }
    private var flySensorCalibrationCharacteristic: CBCharacteristic? { return peripheral.service(with: kSensorServiceUUID)?.characteristic(with: kFlySensorCalibrationCharacteristicUUID) }

    open override func connect() {
        super.connect()
        setConnectionState(.connecting)
    }

    open override func didConnect() {
        matrixWriter = nil
        super.didConnect()
        //TODO: When the matrix characteristic is being found, didConnect() is fired. But if matrix characteristic is not found, didFailToConnect() should be fired instead!
    }

    open override func didFailToConnect(error: Error?) {
        super.didFailToConnect(error: error)
        setConnectionState(.disconnected, withError: error)
    }

    open override func disconnect() {
        super.disconnect()
        setConnectionState(.disconnecting)
    }

    open override func didDisconnect(error: Error?) {
        super.didDisconnect(error: error)
        matrixWriter = nil
        setConnectionState(.disconnected, withError: error)
    }

    private func setConnectionState(_ state: NuimoConnectionState, withError error: Error? = nil) {
        guard state != connectionState else { return }
        connectionState = state
        delegate?.nuimoController(self, didChangeConnectionState: connectionState, withError: error)
    }

    public func display(matrix: NuimoLEDMatrix, interval: TimeInterval, options: Int) {
        matrixWriter?.write(matrix: matrix, interval: interval, options: options)
    }

    @discardableResult public func rebootToDFUMode() -> Bool {
        guard peripheral.state == .connected else { return false }
        guard let rebootToDFUModeCharacteristic = rebootToDFUModeCharacteristic else { return false }
        peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>([UInt8(1)]), count: 1), for: rebootToDFUModeCharacteristic, type: .withResponse)
        return true
    }

    @discardableResult public func calibrateFlySensor() -> Bool {
        guard peripheral.state == .connected else { return false }
        guard let flySensorCalibrationCharacteristic = flySensorCalibrationCharacteristic else { return false }
        peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>([UInt8(1)]), count: 1), for: flySensorCalibrationCharacteristic, type: .withResponse)
        return true
    }

    fileprivate func writeHeartBeatInterval() {
        guard
            peripheral.state == .connected,
            let service = peripheral.services?.filter({ $0.uuid == kSensorServiceUUID }).first,
            let characteristic = service.characteristics?.filter({ $0.uuid == kHeartBeatCharacteristicUUID }).first
        else {
            return
        }
        let interval = UInt8(max(0, min(255, heartBeatInterval)))
        peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>([interval]), count: 1), for: characteristic, type: .withResponse)
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
            case kLEDMatrixCharacteristicUUID:       matrixWriter = LEDMatrixWriter(peripheral: peripheral, matrixCharacteristic: characteristic, brightness: matrixBrightness)
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
        switch characteristic.uuid {
        case kLEDMatrixCharacteristicUUID:
            matrixWriter?.didRetrieveMatrixWriteResponse()
            delegate?.nuimoControllerDidDisplayLEDMatrix(self)
        case kRebootToDFUModeCharacteristicUUID:
            disconnect()
        default: break
        }
    }
}

public let NuimoBluetoothControllerDidSendHeartBeatNotification = "NuimoBluetoothControllerDidSendHeartBeatNotification"
public extension Notification.Name {
    public static let NuimoBluetoothControllerDidSendHeartBeat = Notification.Name(rawValue: NuimoBluetoothControllerDidSendHeartBeatNotification)
}

//MARK: - LED matrix writing

private class LEDMatrixWriter {
    let peripheral: CBPeripheral
    let matrixCharacteristic: CBCharacteristic
    var brightness: Float

    private var currentMatrix: NuimoLEDMatrix?
    private var currentMatrixDisplayInterval: TimeInterval = 0.0
    private var currentMatrixWithFadeTransition = false
    private var lastWrittenMatrix = NuimoLEDMatrix(string: "")
    private var lastWrittenMatrixDate = Date(timeIntervalSince1970: 0.0)
    private var lastWrittenMatrixDisplayInterval: TimeInterval = 0.0
    private var isWaitingForMatrixWriteResponse = false
    private var writeMatrixOnWriteResponseReceived = false
    private var writeMatrixResponseTimeoutTimer: Timer?

    init(peripheral: CBPeripheral, matrixCharacteristic: CBCharacteristic, brightness: Float) {
        self.peripheral = peripheral
        self.matrixCharacteristic = matrixCharacteristic
        self.brightness = brightness
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

        currentMatrix                   = matrix
        currentMatrixDisplayInterval    = interval
        currentMatrixWithFadeTransition = withFadeTransition

        if withWriteResponse && isWaitingForMatrixWriteResponse {
            writeMatrixOnWriteResponseReceived = true
        }
        else {
            writeMatrixNow(withWriteResponse: withWriteResponse)
        }
    }

    private func writeMatrixNow(withWriteResponse: Bool) {
        guard let currentMatrix = currentMatrix else { fatalError("Invalid matrix write request") }
        var matrixBytes = currentMatrix.matrixBytes
        guard currentMatrix.matrixBytes.count == 11 && !(withWriteResponse && isWaitingForMatrixWriteResponse) else { fatalError("Invalid matrix write request") }

        matrixBytes[10] = matrixBytes[10] +
            (currentMatrixWithFadeTransition        ? UInt8(1 << 4) : 0) +
            (currentMatrix is NuimoBuiltInLEDMatrix ? UInt8(1 << 5) : 0)
        matrixBytes += [UInt8(min(max(brightness, 0.0), 1.0) * 255), UInt8(currentMatrixDisplayInterval * 10.0)]
        peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>(matrixBytes), count: matrixBytes.count), for: matrixCharacteristic, type: withWriteResponse ? .withResponse : .withoutResponse)

        isWaitingForMatrixWriteResponse  = withWriteResponse
        lastWrittenMatrix                = currentMatrix
        lastWrittenMatrixDate            = Date()
        lastWrittenMatrixDisplayInterval = currentMatrixDisplayInterval

        if withWriteResponse {
            // When the matrix write response is not retrieved within 500ms we assume the response to have timed out
            DispatchQueue.main.async {
                self.writeMatrixResponseTimeoutTimer?.invalidate()
                self.writeMatrixResponseTimeoutTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.didRetrieveMatrixWriteResponse), userInfo: nil, repeats: false)
            }
        }
    }

    dynamic func didRetrieveMatrixWriteResponse() {
        guard isWaitingForMatrixWriteResponse else { return }
        isWaitingForMatrixWriteResponse = false
        DispatchQueue.main.async {
            self.writeMatrixResponseTimeoutTimer?.invalidate()
        }

        // Write next matrix if any
        if writeMatrixOnWriteResponseReceived {
            writeMatrixOnWriteResponseReceived = false
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
