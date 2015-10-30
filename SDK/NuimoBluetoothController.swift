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
public class NuimoBluetoothController: NSObject, NuimoController, CBPeripheralDelegate {
    public let uuid: String
    public var delegate: NuimoControllerDelegate?
    
    public var state: NuimoConnectionState { get{ return self.peripheral.state.nuimoConnectionState } }
    public var batteryLevel: Int = -1 { didSet { if self.batteryLevel != oldValue { delegate?.nuimoController?(self, didUpdateBatteryLevel: self.batteryLevel) } } }
    public var matrixDisplayTimeout: NSTimeInterval = 1.0
    public var matrixBrightness: UInt8 = 0xff
    public var firmwareVersion = 0.0
    
    private let peripheral: CBPeripheral
    private let centralManager: CBCentralManager
    private var matrixCharacteristic: CBCharacteristic?
    private var currentMatrix: String?
    private var lastWriteMatrixDate: NSDate?
    private var isWaitingForMatrixWriteResponse: Bool = false
    private var writeMatrixOnWriteResponseReceived: Bool = false
    private var writeMatrixResponseTimeoutTimer: NSTimer?
    
    public init(centralManager: CBCentralManager, uuid: String, peripheral: CBPeripheral) {
        self.centralManager = centralManager
        self.uuid = uuid
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }
    
    public func connect() {
        if peripheral.state == .Disconnected {
            centralManager.connectPeripheral(peripheral, options: nil)
            delegate?.nuimoControllerDidStartConnecting?(self)
        }
    }
    
    internal func didConnect() {
        isWaitingForMatrixWriteResponse = false
        writeMatrixOnWriteResponseReceived = false
        // Discover bluetooth services
        peripheral.discoverServices(nuimoServiceUUIDs)
        delegate?.nuimoControllerDidConnect?(self)
    }
    
    internal func didFailToConnect() {
        delegate?.nuimoControllerDidFailToConnect?(self)
    }
    
    public func disconnect() {
        if peripheral.state != .Connected {
            return
        }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    internal func didDisconnect() {
        peripheral.delegate = nil
        matrixCharacteristic = nil
        delegate?.nuimoControllerDidDisconnect?(self)
    }
    
    internal func invalidate() {
        peripheral.delegate = nil
        delegate?.nuimoControllerDidInvalidate?(self)
    }
    
    //MARK: - CBPeripheralDelegate
    
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        peripheral.services?
            .flatMap{ ($0, charactericUUIDsForServiceUUID[$0.UUID]) }
            .forEach{ peripheral.discoverCharacteristics($0.1, forService: $0.0) }
    }
    
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
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
            if characteristicNotificationUUIDs.contains(characteristic.UUID) {
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
        }
    }
    
    @objc public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard let data = characteristic.value else {
            return
        }
        
        switch characteristic.UUID {
        case kBatteryCharacteristicUUID:
            batteryLevel = Int(UnsafePointer<UInt8>(data.bytes).memory)
        default:
            if let event = characteristic.nuimoGestureEvent() {
                delegate?.nuimoController?(self, didReceiveGestureEvent: event)
            }
        }
    }
    
    @objc public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        // Nothing to do here
    }
    
    @objc public func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if characteristic.UUID == kLEDMatrixCharacteristicUUID {
            didRetrieveMatrixWriteResponse()
        }
    }
    
    //MARK: - LED matrix writing
    
    //TODO: Allow for writing custom matrices
    public func writeMatrix(matrix: String?) {
        // Do not write same matrix again that is already shown unless the display interval has timed out
        guard matrix != currentMatrix || NSDate().timeIntervalSinceDate(lastWriteMatrixDate ?? NSDate()) >= matrixDisplayTimeout else {return}
        
        currentMatrix = matrix
        
        // Send matrix later when the write response from previous write request is not yet received
        if isWaitingForMatrixWriteResponse {
            writeMatrixOnWriteResponseReceived = true
        } else {
            writeMatrixNow(matrix)
        }
    }
    
    public func writeBarMatrix(percent: Int){
        let suffix = min(max(percent / 10, 1), 9)
        writeMatrix(NuimoLEDMatrix(rawValue: "vertical-bar\(suffix)")?.stringRepresentation)
    }
    
    private func writeMatrixNow(matrix: String?) {
        assert(!isWaitingForMatrixWriteResponse, "Cannot write matrix now, response from previous write request not yet received")
        guard let ledMatrixCharacteristic = matrixCharacteristic else { return }
        
        // Convert matrix string representation into byte representation
        let matrixBytes = NuimoLEDMatrix.matrixBytesForString(matrix ?? "")
        
        // Write matrix
        let matrixData = NSMutableData(bytes: matrixBytes, length: matrixBytes.count)
        if firmwareVersion >= 0.1 {
            let matrixAdditionalBytes: [UInt8] = [UInt8(matrixBrightness), UInt8(matrixDisplayTimeout * 0.1)]
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
        if writeMatrixOnWriteResponseReceived {
            writeMatrixOnWriteResponseReceived = false
            writeMatrixNow(currentMatrix)
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

private let charactericUUIDsForServiceUUID = [
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

private let characteristicNotificationUUIDs = [
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
                    case 2:  return touchDownGesture.touchUpGesture
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

//MARK: Extension methods for CoreBluetooth

private extension CBPeripheralState {
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
