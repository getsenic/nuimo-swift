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
    public var delegate: NuimoControllerDelegate?
    public var state: NuimoConnectionState { get{ return self.peripheral.state.nuimoConnectionState } }
    public var batteryLevel: Int = -1 { didSet { if self.batteryLevel != oldValue { delegate?.nuimoController?(self, didUpdateBatteryLevel: self.batteryLevel) } } }
    public var defaultMatrixDisplayInterval: NSTimeInterval = 2.0
    public var matrixBrightness: Float = 1.0
    public var firmwareVersion = 0.1
    
    public override var serviceUUIDs: [CBUUID] { get { return nuimoServiceUUIDs } }
    public override var charactericUUIDsForServiceUUID: [CBUUID : [CBUUID]] { get { return nuimoCharactericUUIDsForServiceUUID } }
    public override var notificationCharacteristicUUIDs: [CBUUID] { get { return nuimoNotificationCharacteristicnUUIDs } }

    private var matrixCharacteristic: CBCharacteristic?
    private var currentMatrix: NuimoLEDMatrix?
    private var lastWriteMatrixDate: NSDate?
    private var isWaitingForMatrixWriteResponse: Bool = false
    private var writeMatrixOnWriteResponseReceived: Bool = false
    private var writeMatrixOnWriteResponseReceivedDisplayInterval: NSTimeInterval = 0.0
    private var writeMatrixResponseTimeoutTimer: NSTimer?
    
    public override func connect() {
        super.connect()
        delegate?.nuimoControllerDidStartConnecting?(self)
    }
    
    public override func didConnect() {
        super.didConnect()
        isWaitingForMatrixWriteResponse = false
        writeMatrixOnWriteResponseReceived = false
        delegate?.nuimoControllerDidConnect?(self)
    }
    
    public override func didFailToConnect() {
        super.didFailToConnect()
        delegate?.nuimoControllerDidFailToConnect?(self)
    }
    
    public override func didDisconnect() {
        super.didDisconnect()
        matrixCharacteristic = nil
        delegate?.nuimoControllerDidDisconnect?(self)
    }
    
    public override func invalidate() {
        super.invalidate()
        peripheral.delegate = nil
        delegate?.nuimoControllerDidInvalidate?(self)
    }
    
    //MARK: - CBPeripheralDelegate
    
    public override func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        super.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: error)
        service.characteristics?.forEach{ characteristic in
            switch characteristic.UUID {
            case kBatteryCharacteristicUUID:
                peripheral.readValueForCharacteristic(characteristic)
            case kLEDMatrixCharacteristicUUID:
                matrixCharacteristic = characteristic
                delegate?.nuimoControllerDidDiscoverMatrixService?(self)
            default:
                break
            }
        }
    }
    
    public override func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        super.peripheral(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)

        guard let data = characteristic.value else { return }
        
        switch characteristic.UUID {
        case kBatteryCharacteristicUUID:
            batteryLevel = Int(UnsafePointer<UInt8>(data.bytes).memory)
        default:
            if let event = characteristic.nuimoGestureEvent() {
                delegate?.nuimoController?(self, didReceiveGestureEvent: event)
            }
        }
    }
    
    public override func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        super.peripheral(peripheral, didWriteValueForCharacteristic: characteristic, error: error)
        if characteristic.UUID == kLEDMatrixCharacteristicUUID {
            didRetrieveMatrixWriteResponse()
        }
    }
    
    //MARK: - LED matrix writing
    
    //TODO: Move matrix write handling into a private class
    public func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval) {
        // Do not write same matrix again that is already shown unless the display interval has timed out
        //TODO: We must instead compare lastWriteMatrixDate to the display interval of the matrix that had been written as last
        guard matrix != currentMatrix || NSDate().timeIntervalSinceDate(lastWriteMatrixDate ?? NSDate()) >= interval else {return}
        
        currentMatrix = matrix
        
        // Send matrix later when the write response from previous write request is not yet received
        //TODO: Use WriteQueue instead (as Android SDK does)
        if isWaitingForMatrixWriteResponse {
            writeMatrixOnWriteResponseReceived = true
            writeMatrixOnWriteResponseReceivedDisplayInterval = interval
        } else {
            //TODO: No arguments necessary. Take them from currentMatrix and lastWrittenMatrixDisplayInterval
            writeMatrixNow(matrix, interval: interval)
        }
    }
    
    private func writeMatrixNow(matrix: NuimoLEDMatrix, interval: NSTimeInterval) {
        assert(!isWaitingForMatrixWriteResponse, "Cannot write matrix now, response from previous write request not yet received")
        guard let ledMatrixCharacteristic = matrixCharacteristic else { return }
        
        // Convert matrix string representation into byte representation
        let matrixBytes = matrix.matrixBytes
        
        // Write matrix
        let matrixData = NSMutableData(bytes: matrixBytes, length: matrixBytes.count)
        if firmwareVersion >= 0.1 {
            let matrixAdditionalBytes: [UInt8] = [UInt8(min(max(matrixBrightness, 0.0), 1.0) * 255), UInt8(interval * 10)]
            matrixData.appendBytes(matrixAdditionalBytes, length: matrixAdditionalBytes.count)
        }
        peripheral.writeValue(matrixData, forCharacteristic: ledMatrixCharacteristic, type: .WithResponse)
        lastWriteMatrixDate = NSDate()
        isWaitingForMatrixWriteResponse = true
        
        // When the matrix write response is not retrieved within 100ms we assume the response to have timed out
        writeMatrixResponseTimeoutTimer?.invalidate()
        writeMatrixResponseTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "didRetrieveMatrixWriteResponse", userInfo: nil, repeats: false)
    }
    
    func didRetrieveMatrixWriteResponse() {
        isWaitingForMatrixWriteResponse = false
        writeMatrixResponseTimeoutTimer?.invalidate()
        
        // Write next matrix if any
        if let currentMatrix = currentMatrix where writeMatrixOnWriteResponseReceived {
            writeMatrixOnWriteResponseReceived = false
            writeMatrixNow(currentMatrix, interval: writeMatrixOnWriteResponseReceivedDisplayInterval)
        }
    }
}

//MARK: Nuimo BLE GATT service and characteristic UUIDs

private let kBatteryServiceUUID                  = CBUUID(string: "180F")
private let kBatteryCharacteristicUUID           = CBUUID(string: "2A19")
private let kDeviceInformationServiceUUID        = CBUUID(string: "180A")
private let kDeviceInformationCharacteristicUUID = CBUUID(string: "2A29")
private let kLEDMatrixServiceUUID                = CBUUID(string: "F29B1523-CB19-40F3-BE5C-7241ECB82FD1")
private let kLEDMatrixCharacteristicUUID         = CBUUID(string: "F29B1524-CB19-40F3-BE5C-7241ECB82FD1")
private let kSensorServiceUUID                   = CBUUID(string: "F29B1525-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorFlyCharacteristicUUID         = CBUUID(string: "F29B1526-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorTouchCharacteristicUUID       = CBUUID(string: "F29B1527-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorRotationCharacteristicUUID    = CBUUID(string: "F29B1528-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorButtonCharacteristicUUID      = CBUUID(string: "F29B1529-CB19-40F3-BE5C-7241ECB82FD2")

internal let nuimoServiceUUIDs: [CBUUID] = [
    kBatteryServiceUUID,
    kDeviceInformationServiceUUID,
    kLEDMatrixServiceUUID,
    kSensorServiceUUID
]

private let nuimoCharactericUUIDsForServiceUUID = [
    kBatteryServiceUUID: [kBatteryCharacteristicUUID],
    kDeviceInformationServiceUUID: [kDeviceInformationCharacteristicUUID],
    kLEDMatrixServiceUUID: [kLEDMatrixCharacteristicUUID],
    kSensorServiceUUID: [
        kSensorFlyCharacteristicUUID,
        kSensorTouchCharacteristicUUID,
        kSensorRotationCharacteristicUUID,
        kSensorButtonCharacteristicUUID
    ]
]

private let nuimoNotificationCharacteristicnUUIDs = [
    kBatteryCharacteristicUUID,
    kSensorFlyCharacteristicUUID,
    kSensorTouchCharacteristicUUID,
    kSensorRotationCharacteristicUUID,
    kSensorButtonCharacteristicUUID
]

//MARK: - Private extensions

//MARK: Initializers for NuimoGestureEvents from BLE GATT data

private extension NuimoGestureEvent {
    convenience init(gattFlyData data: NSData) {
        let bytes = UnsafePointer<UInt8>(data.bytes)
        let directionByte = bytes.memory
        let gesture = flyGestureForDirectionByte[directionByte] ?? .Undefined
        //TODO: Support fly up/down events
        self.init(gesture: gesture, value: nil)
    }
    
    convenience init(gattTouchData data: NSData) {
        let bytes = UnsafePointer<Int16>(data.bytes)
        let buttonByte = bytes.memory
        let eventByte = bytes.advancedBy(1).memory
        for i: Int16 in 0...7 where (1 << i) & buttonByte != 0 {
            let touchDownGesture: NuimoGesture = [.TouchLeftDown, .TouchTopDown, .TouchRightDown, .TouchBottomDown][Int(i / 2)]
            if let eventGesture: NuimoGesture = {
                    switch eventByte {
                    case 1:  return touchDownGesture.self
                    case 2:  return touchDownGesture.touchReleaseGesture //TODO: Move this method here as a private extension method
                    case 3:  return nil //TODO: Do we need to handle double touch gestures here as well?
                    case 4:  return touchDownGesture.swipeGesture
                    default: return nil}}() {
                self.init(gesture: eventGesture, value: Int(i))
                return
            }
        }
        self.init(gesture: .Undefined, value: nil)
    }
    
    convenience init(gattRotationData data: NSData) {
        let value = Int(UnsafePointer<Int16>(data.bytes).memory)
        self.init(gesture: value < 0 ? .RotateLeft : .RotateRight, value: value)
    }
    
    convenience init(gattButtonData data: NSData) {
        let value = Int(UnsafePointer<UInt8>(data.bytes).memory)
        //TODO: Evaluate double press events
        self.init(gesture: value == 1 ? .ButtonPress : .ButtonRelease, value: value)
    }
}

private let flyGestureForDirectionByte: [UInt8 : NuimoGesture] = [1 : .FlyLeft, 2 : .FlyRight, 3 : .FlyAway, 4 : .FlyTowards]

//MARK: Matrix string to byte array conversion

private extension NuimoLEDMatrix {
    var matrixBytes: [UInt8] {
        return bits
            .chunk(8)
            .map{ $0
                .enumerate()
                .map{(i: Int, b: Bit) -> Int in return b == Bit.Zero ? 0 : 1 << i}
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
            if --i == 0 {
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

public extension CBPeripheralState {
    var nuimoConnectionState: NuimoConnectionState {
        #if os(iOS)
            switch self {
            case .Connecting:    return .Connecting
            case .Connected:     return .Connected
            case .Disconnecting: return .Disconnecting
            case .Disconnected:  return .Disconnected
            }
        #elseif os(OSX)
            switch self {
            case .Connecting:    return .Connecting
            case .Connected:     return .Connected
            case .Disconnected:  return .Disconnected
            }
        #endif
    }
}

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
