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
//TODO: Internalize CBPeripheralDelegate implementation
public class NuimoBluetoothController: BLEDevice, NuimoController {
    public override class var connectionTimeoutInterval:     NSTimeInterval  { return 5.0 }
    public override class var connectionRetryCount:          Int             { return 5 }
    public override class var maxAdvertisingPackageInterval: NSTimeInterval? { return 5.0 }

    public var delegate: NuimoControllerDelegate?
    public private(set) dynamic var connectionState = NuimoConnectionState.Disconnected
    public var defaultMatrixDisplayInterval: NSTimeInterval = 2.0
    public var matrixBrightness: Float = 1.0 { didSet { matrixWriter?.brightness = self.matrixBrightness } }

    public override var serviceUUIDs: [CBUUID] { get { return nuimoServiceUUIDs } }
    public override var charactericUUIDsForServiceUUID: [CBUUID : [CBUUID]] { get { return nuimoCharactericUUIDsForServiceUUID } }
    public override var notificationCharacteristicUUIDs: [CBUUID] { get { return nuimoNotificationCharacteristicnUUIDs } }

    public var heartBeatInterval: NSTimeInterval = 0.0 { didSet { writeHeartBeatInterval() } }

    private var matrixWriter: LEDMatrixWriter?
    private var connectTimeoutTimer: NSTimer?

    public override func connect() -> Bool {
        guard super.connect() else { return false }
        setConnectionState(.Connecting)
        return true
    }

    public override func didConnect() {
        matrixWriter = nil
        super.didConnect()
        //TODO: When the matrix characteristic is being found, didConnect() is fired. But if matrix characteristic is not found, didFailToConnect() should be fired instead!
    }

    public override func didFailToConnect(error: NSError?) {
        super.didFailToConnect(error)
        setConnectionState(.Disconnected, withError: error)
    }

    public override func disconnect() -> Bool {
        guard super.disconnect() else { return false }
        setConnectionState(.Disconnecting)
        return true
    }

    public override func didDisconnect(error: NSError?) {
        super.didDisconnect(error)
        matrixWriter = nil
        setConnectionState(.Disconnected, withError: error)
    }

    public override func didInvalidate() {
        super.didInvalidate()
        setConnectionState(.Invalidated)
    }

    private func setConnectionState(state: NuimoConnectionState, withError error: NSError? = nil) {
        guard state != connectionState else { return }
        connectionState = state
        delegate?.nuimoController?(self, didChangeConnectionState: connectionState, withError: error)
    }

    //TODO: Rename to displayMatrix
    public func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, options: Int) {
        matrixWriter?.writeMatrix(matrix, interval: interval, options: options)
    }

    private func writeHeartBeatInterval() {
        guard peripheral.state == .Connected else { return }
        guard let service = peripheral.services?.filter({ $0.UUID == kSensorServiceUUID }).first else { return }
        guard let characteristic = service.characteristics?.filter({ $0.UUID == kHeartBeatCharacteristicUUID }).first else { return }
        let interval = UInt8(max(0, min(255, heartBeatInterval)))
        peripheral.writeValue(NSData(bytes: [interval], length: 1), forCharacteristic: characteristic, type: .WithResponse)
    }
}

public let NuimoBluetoothControllerDidSendHeartBeatNotification = "NuimoBluetoothControllerDidSendHeartBeatNotification"

extension NuimoBluetoothController /* CBPeripheralDelegate */ {
    public override func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        super.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: error)
        service.characteristics?.forEach{ characteristic in
            switch characteristic.UUID {
            case kFirmwareVersionCharacteristicUUID:
                peripheral.readValueForCharacteristic(characteristic)
            case kBatteryCharacteristicUUID:
                peripheral.readValueForCharacteristic(characteristic)
            case kLEDMatrixCharacteristicUUID:
                matrixWriter = LEDMatrixWriter(peripheral: peripheral, matrixCharacteristic: characteristic, brightness: matrixBrightness)
                setConnectionState(.Connected)
            case kHeartBeatCharacteristicUUID:
                writeHeartBeatInterval()
            default:
                break
            }
        }
    }

    public override func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        super.peripheral(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)

        guard let data = characteristic.value else { return }

        switch characteristic.UUID {
        case kFirmwareVersionCharacteristicUUID:
            if let firmwareVersion = String(data: data, encoding: NSUTF8StringEncoding) {
                delegate?.nuimoController?(self, didReadFirmwareVersion: firmwareVersion)
            }
        case kBatteryCharacteristicUUID:
            delegate?.nuimoController?(self, didUpdateBatteryLevel: Int(UnsafePointer<UInt8>(data.bytes).memory))
        case kHeartBeatCharacteristicUUID:
            NSNotificationCenter.defaultCenter().postNotificationName(NuimoBluetoothControllerDidSendHeartBeatNotification, object: self, userInfo: nil)
        default:
            if let event = characteristic.nuimoGestureEvent() {
                delegate?.nuimoController?(self, didReceiveGestureEvent: event)
            }
        }
    }

    public override func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        super.peripheral(peripheral, didWriteValueForCharacteristic: characteristic, error: error)
        if characteristic.UUID == kLEDMatrixCharacteristicUUID {
            matrixWriter?.didRetrieveMatrixWriteResponse()
            delegate?.nuimoControllerDidDisplayLEDMatrix?(self)
        }
    }
}

//MARK: - LED matrix writing

private class LEDMatrixWriter {
    let peripheral: CBPeripheral
    let matrixCharacteristic: CBCharacteristic
    var brightness: Float

    private var currentMatrix: NuimoLEDMatrix?
    private var currentMatrixDisplayInterval: NSTimeInterval = 0.0
    private var currentMatrixWithFadeTransition = false
    private var lastWrittenMatrix: NuimoLEDMatrix?
    private var lastWrittenMatrixDate = NSDate(timeIntervalSince1970: 0.0)
    private var lastWrittenMatrixDisplayInterval: NSTimeInterval = 0.0
    private var isWaitingForMatrixWriteResponse = false
    private var writeMatrixOnWriteResponseReceived = false
    private var writeMatrixResponseTimeoutTimer: NSTimer?

    init(peripheral: CBPeripheral, matrixCharacteristic: CBCharacteristic, brightness: Float) {
        self.peripheral = peripheral
        self.matrixCharacteristic = matrixCharacteristic
        self.brightness = brightness
    }

    func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval, options: Int) {
        let resendsSameMatrix  = options & NuimoLEDMatrixWriteOption.IgnoreDuplicates.rawValue     == 0
        let withFadeTransition = options & NuimoLEDMatrixWriteOption.WithFadeTransition.rawValue   != 0
        let withWriteResponse  = options & NuimoLEDMatrixWriteOption.WithoutWriteResponse.rawValue == 0

        guard
            resendsSameMatrix ||
            lastWrittenMatrix != matrix ||
            (lastWrittenMatrixDisplayInterval > 0 && -lastWrittenMatrixDate.timeIntervalSinceNow >= lastWrittenMatrixDisplayInterval)
            else { return }

        currentMatrix                   = matrix
        currentMatrixDisplayInterval    = interval
        currentMatrixWithFadeTransition = withFadeTransition

        if withWriteResponse && isWaitingForMatrixWriteResponse {
            writeMatrixOnWriteResponseReceived = true
        }
        else {
            writeMatrixNow(withWriteResponse)
        }
    }

    private func writeMatrixNow(withWriteResponse: Bool) {
        guard var matrixBytes = currentMatrix?.matrixBytes where matrixBytes.count == 11 && !(withWriteResponse && isWaitingForMatrixWriteResponse) else { fatalError("Invalid matrix write request") }

        matrixBytes[10] = matrixBytes[10] + (currentMatrixWithFadeTransition ? UInt8(1 << 4) : 0)
        matrixBytes += [UInt8(min(max(brightness, 0.0), 1.0) * 255), UInt8(currentMatrixDisplayInterval * 10.0)]
        peripheral.writeValue(NSData(bytes: matrixBytes, length: matrixBytes.count), forCharacteristic: matrixCharacteristic, type: withWriteResponse ? .WithResponse : .WithoutResponse)

        isWaitingForMatrixWriteResponse  = withWriteResponse
        lastWrittenMatrix                = currentMatrix
        lastWrittenMatrixDate            = NSDate()
        lastWrittenMatrixDisplayInterval = currentMatrixDisplayInterval

        if withWriteResponse {
            // When the matrix write response is not retrieved within 500ms we assume the response to have timed out
            dispatch_async(dispatch_get_main_queue()) {
                self.writeMatrixResponseTimeoutTimer?.invalidate()
                self.writeMatrixResponseTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(self.didRetrieveMatrixWriteResponse), userInfo: nil, repeats: false)
            }
        }
    }

    @objc func didRetrieveMatrixWriteResponse() {
        guard isWaitingForMatrixWriteResponse else { return }
        isWaitingForMatrixWriteResponse = false
        dispatch_async(dispatch_get_main_queue()) {
            self.writeMatrixResponseTimeoutTimer?.invalidate()
        }

        // Write next matrix if any
        if writeMatrixOnWriteResponseReceived {
            writeMatrixOnWriteResponseReceived = false
            writeMatrixNow(true)
        }
    }
}

//MARK: Nuimo BLE GATT service and characteristic UUIDs

private let kBatteryServiceUUID                  = CBUUID(string: "180F")
private let kBatteryCharacteristicUUID           = CBUUID(string: "2A19")
private let kDeviceInformationServiceUUID        = CBUUID(string: "180A")
private let kFirmwareVersionCharacteristicUUID   = CBUUID(string: "2A26")
private let kLEDMatrixServiceUUID                = CBUUID(string: "F29B1523-CB19-40F3-BE5C-7241ECB82FD1")
private let kLEDMatrixCharacteristicUUID         = CBUUID(string: "F29B1524-CB19-40F3-BE5C-7241ECB82FD1")
private let kSensorServiceUUID                   = CBUUID(string: "F29B1525-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorFlyCharacteristicUUID         = CBUUID(string: "F29B1526-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorTouchCharacteristicUUID       = CBUUID(string: "F29B1527-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorRotationCharacteristicUUID    = CBUUID(string: "F29B1528-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorButtonCharacteristicUUID      = CBUUID(string: "F29B1529-CB19-40F3-BE5C-7241ECB82FD2")
private let kHeartBeatCharacteristicUUID         = CBUUID(string: "F29B152B-CB19-40F3-BE5C-7241ECB82FD2")

internal let nuimoServiceUUIDs: [CBUUID] = [
    kBatteryServiceUUID,
    kDeviceInformationServiceUUID,
    kLEDMatrixServiceUUID,
    kSensorServiceUUID
]

private let nuimoCharactericUUIDsForServiceUUID = [
    kBatteryServiceUUID: [kBatteryCharacteristicUUID],
    kDeviceInformationServiceUUID: [kFirmwareVersionCharacteristicUUID],
    kLEDMatrixServiceUUID: [kLEDMatrixCharacteristicUUID],
    kSensorServiceUUID: [
        kSensorFlyCharacteristicUUID,
        kSensorTouchCharacteristicUUID,
        kSensorRotationCharacteristicUUID,
        kSensorButtonCharacteristicUUID,
        kHeartBeatCharacteristicUUID
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
    convenience init(gattFlyData data: NSData) {
        let bytes = UnsafePointer<UInt8>(data.bytes)
        let directionByte = bytes.memory
        let speedByte = bytes.advancedBy(1).memory
        print("direction byte: \(directionByte)")
        print("speed byte: \(speedByte)")
        //TODO: When firmware bug is fixed fallback to .Undefined gesture
        let gesture: NuimoGesture = [0: .FlyLeft, 1: .FlyRight, 2: .FlyBackwards, 3: .FlyTowards, 4: .FlyUpDown][directionByte] ?? .FlyRight //.Undefined
        self.init(gesture: gesture, value: gesture == .FlyUpDown ? Int(speedByte) : nil)
    }

    convenience init(gattTouchData data: NSData) {
        let bytes = UnsafePointer<UInt8>(data.bytes)
        let gesture: NuimoGesture = [0: .SwipeLeft, 1: .SwipeRight, 2: .SwipeUp, 3: .SwipeDown, 4: .TouchLeft, 5: .TouchRight, 6: .TouchTop, 7: .TouchBottom][bytes.memory] ?? .Undefined
        self.init(gesture: gesture, value: nil)
    }

    convenience init(gattRotationData data: NSData) {
        let value = Int(UnsafePointer<Int16>(data.bytes).memory)
        self.init(gesture: .Rotate, value: value)
    }

    convenience init(gattButtonData data: NSData) {
        let value = Int(UnsafePointer<UInt8>(data.bytes).memory)
        //TODO: Evaluate double press events
        self.init(gesture: value == 1 ? .ButtonPress : .ButtonRelease, value: value)
    }
}

//MARK: Matrix string to byte array conversion

private extension NuimoLEDMatrix {
    var matrixBytes: [UInt8] {
        return leds
            .chunk(8)
            .map{ $0
                .enumerate()
                .map{(i: Int, b: Bool) -> Int in return b ? 1 << i : 0}
                .reduce(UInt8(0), combine: {(s: UInt8, v: Int) -> UInt8 in s + UInt8(v)})
        }
    }
}

private extension SequenceType {
    func chunk(n: Int) -> [[Generator.Element]] {
        var chunks: [[Generator.Element]] = []
        var chunk: [Generator.Element] = []
        chunk.reserveCapacity(n)
        chunks.reserveCapacity(underestimateCount() / n)
        var i = n
        self.forEach {
            chunk.append($0)
            i -= 1
            if i == 0 {
                chunks.append(chunk)
                chunk.removeAll(keepCapacity: true)
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

        switch UUID {
        case kSensorFlyCharacteristicUUID:      return NuimoGestureEvent(gattFlyData: data)
        case kSensorTouchCharacteristicUUID:    return NuimoGestureEvent(gattTouchData: data)
        case kSensorRotationCharacteristicUUID: return NuimoGestureEvent(gattRotationData: data)
        case kSensorButtonCharacteristicUUID:   return NuimoGestureEvent(gattButtonData: data)
        default: return nil
        }
    }
}
