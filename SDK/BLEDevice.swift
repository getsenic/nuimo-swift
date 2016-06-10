//
//  BluetoothDevice.swift
//  Nuimo
//
//  Created by Lars Blumberg on 12/10/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import Foundation
import CoreBluetooth

/**
    Represents a bluetooth low energy (BLE) device.
    - Automatically discovers its services when connected
    - Automatically discovers its characteristics
    - Automatically subscribes for characteristic change notifications
*/
public class BLEDevice: NSObject, CBPeripheralDelegate {
    public let uuid: String
    public var serviceUUIDs: [CBUUID] { get { return [] } }
    public var charactericUUIDsForServiceUUID: [CBUUID : [CBUUID]] { get { return [:] } }
    public var notificationCharacteristicUUIDs: [CBUUID] { get { return [] } }
    public let peripheral: CBPeripheral
    public let centralManager: CBCentralManager
    public var connectionTimeoutInterval: NSTimeInterval { get { return 5.0 } }

    private var connectionTimeoutTimer: NSTimer?

    public init(centralManager: CBCentralManager, uuid: String, peripheral: CBPeripheral) {
        self.centralManager = centralManager
        self.uuid = uuid
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    public func connect() -> Bool {
        guard peripheral.state == .Disconnected else { return false }
        centralManager.connectPeripheral(peripheral, options: nil)
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(connectionTimeoutInterval, target: self, selector: #selector(self.didConnectTimeout), userInfo: nil, repeats: false)
        return true
    }

    public func didConnect() {
        connectionTimeoutTimer?.invalidate()
        // Discover bluetooth services
        peripheral.discoverServices(serviceUUIDs)
    }

    public func didConnectTimeout() {
        centralManager.cancelPeripheralConnection(peripheral)
        // CoreBluetooth doesn't call didFailToConnectPeripheral delegate method – that's why we call it here
        centralManager.delegate?.centralManager?(centralManager, didFailToConnectPeripheral: peripheral, error: NSError(domain: "BLEDevice", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to peripheral", NSLocalizedFailureReasonErrorKey: "Connection attempt timed out"]))
    }

    public func didFailToConnect(error: NSError?) {
    }

    public func didRestore() {
        //TODO: We might want to check first if re-discovering services is not necessary, this is when all services and characteristics and notification subscriptions are present
        peripheral.discoverServices(serviceUUIDs)
    }

    public func disconnect() -> Bool {
        guard peripheral.state == .Connected else { return false }
        centralManager.cancelPeripheralConnection(peripheral)
        return true
    }

    public func didDisconnect(error: NSError?) {
        peripheral.delegate = nil
    }

    public func didInvalidate() {
    }

    internal func invalidate() {
        peripheral.delegate = nil
        didInvalidate()
    }

    //MARK: - CBPeripheralDelegate

    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        peripheral.services?
            .flatMap{ ($0, charactericUUIDsForServiceUUID[$0.UUID]) }
            .forEach{ peripheral.discoverCharacteristics($0.1, forService: $0.0) }
    }

    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        service.characteristics?.forEach{ characteristic in
            if notificationCharacteristicUUIDs.contains(characteristic.UUID) {
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
        }
    }

    @objc public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
    }

    @objc public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
    }

    @objc public func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
    }
}
