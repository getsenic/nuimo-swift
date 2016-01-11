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
    public var matrixBrightness: Float = 1.0 { didSet { matrixWriter?.brightness = self.matrixBrightness } }
    
    public override var serviceUUIDs: [CBUUID] { get { return nuimoServiceUUIDs } }
    public override var charactericUUIDsForServiceUUID: [CBUUID : [CBUUID]] { get { return nuimoCharactericUUIDsForServiceUUID } }
    public override var notificationCharacteristicUUIDs: [CBUUID] { get { return nuimoNotificationCharacteristicnUUIDs } }

    private var matrixWriter: LEDMatrixWriter?
    
    public override func connect() {
        super.connect()
        delegate?.nuimoControllerDidStartConnecting?(self)
    }
    
    public override func didConnect() {
        matrixWriter = nil
        super.didConnect()
        //TODO: When the matrix characteristic is being found, didConnect() is fired. But if matrix characteristic is not found, didFailToConnect() should be fired instead!
    }
    
    public override func didFailToConnect(error: NSError?) {
        super.didFailToConnect(error)
        delegate?.nuimoController?(self, didFailToConnect: error)
    }
    
    public override func didDisconnect(error: NSError?) {
        super.didDisconnect(error)
        matrixWriter = nil
        delegate?.nuimoController?(self, didDisconnect: error)
    }
    
    public override func invalidate() {
        super.invalidate()
        peripheral.delegate = nil
        delegate?.nuimoControllerDidInvalidate?(self)
    }

    //TODO: Rename to displayMatrix
    public func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval) {
        matrixWriter?.writeMatrix(matrix, interval: interval)
    }
    
    //MARK: - CBPeripheralDelegate
    
    public override func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        super.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: error)
        service.characteristics?.forEach{ characteristic in
            switch characteristic.UUID {
            case kBatteryCharacteristicUUID:
                peripheral.readValueForCharacteristic(characteristic)
            case kLEDMatrixCharacteristicUUID:
                matrixWriter = LEDMatrixWriter(peripheral: peripheral, matrixCharacteristic: characteristic, brightness: matrixBrightness)
                delegate?.nuimoControllerDidConnect?(self)
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
    private var lastWrittenMatrix: NuimoLEDMatrix?
    private var lastWrittenMatrixDate = NSDate(timeIntervalSince1970: 0.0)
    private var isWaitingForMatrixWriteResponse = false
    private var writeMatrixOnWriteResponseReceived = false
    private var writeMatrixResponseTimeoutTimer: NSTimer?
    // Minimum interval before a matrix, that has already been sent, can be send again. This improves user experience when a lot of matrices are sent with a high rate.
    private let minSameMatrixResendInterval: NSTimeInterval = 0.2

    init(peripheral: CBPeripheral, matrixCharacteristic: CBCharacteristic, brightness: Float) {
        self.peripheral = peripheral
        self.matrixCharacteristic = matrixCharacteristic
        self.brightness = brightness
    }

    func writeMatrix(matrix: NuimoLEDMatrix, interval: NSTimeInterval) {
        currentMatrix = matrix
        currentMatrixDisplayInterval = interval

        // Send matrix later when the write response from previous write request is not yet received
        if isWaitingForMatrixWriteResponse {
            writeMatrixOnWriteResponseReceived = true
        } else if lastWrittenMatrix != matrix || (-lastWrittenMatrixDate.timeIntervalSinceNow >= minSameMatrixResendInterval) {
            writeMatrixNow()
        }
    }

    func writeMatrixNow() {
        guard let currentMatrix = self.currentMatrix where !isWaitingForMatrixWriteResponse else { return }

        // Convert matrix string representation into byte representation
        let matrixBytes = currentMatrix.matrixBytes

        // Write matrix
        let matrixData = NSMutableData(bytes: matrixBytes, length: matrixBytes.count)
        let matrixAdditionalBytes = [UInt8(min(max(brightness, 0.0), 1.0) * 255), UInt8(currentMatrixDisplayInterval * 10.0)]
        matrixData.appendBytes(matrixAdditionalBytes, length: matrixAdditionalBytes.count)
        peripheral.writeValue(matrixData, forCharacteristic: matrixCharacteristic, type: .WithResponse)
        isWaitingForMatrixWriteResponse = true

        // When the matrix write response is not retrieved within 500ms we assume the response to have timed out
        dispatch_async(dispatch_get_main_queue()) {
            self.writeMatrixResponseTimeoutTimer?.invalidate()
            self.writeMatrixResponseTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "didRetrieveMatrixWriteResponse", userInfo: nil, repeats: false)
        }

        lastWrittenMatrix = currentMatrix
    }

    @objc func didRetrieveMatrixWriteResponse() {
        guard isWaitingForMatrixWriteResponse else { return }
        isWaitingForMatrixWriteResponse = false
        dispatch_async(dispatch_get_main_queue()) {
            self.writeMatrixResponseTimeoutTimer?.invalidate()
        }
        lastWrittenMatrixDate = NSDate()

        // Write next matrix if any
        if writeMatrixOnWriteResponseReceived {
            writeMatrixOnWriteResponseReceived = false
            writeMatrixNow()
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
        let speedByte = bytes.advancedBy(1).memory
        print("direction byte: \(directionByte)")
        print("speed byte: \(speedByte)")
        //TODO: When firmware bug is fixed fallback to .Undefined gesture
        let gesture: NuimoGesture = [0 : .FlyLeft, 1 : .FlyRight, 2 : .FlyBackwards, 3 : .FlyTowards][directionByte] ?? .FlyRight //.Undefined
        //TODO: Support fly up/down events
        self.init(gesture: gesture, value: nil)
    }
    
    convenience init(gattTouchData data: NSData) {
        let bytes = UnsafePointer<UInt8>(data.bytes)
        let gesture: NuimoGesture = {
            if data.length == 1 {
                return [0 : .SwipeLeft, 1 : .SwipeRight, 2 : .SwipeUp, 3 : .SwipeDown][bytes.memory] ?? .Undefined
            }
            else {
                //TODO: This is for the previous firmware version. Remove when we have no devices anymore running the old firmware.
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
                        return eventGesture
                    }
                }
                return .Undefined
            }
        }()

        self.init(gesture: gesture, value: nil)
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
