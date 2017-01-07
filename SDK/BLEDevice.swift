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
    - Automatically updates its reachability
    - Automatically reconnects if peripheral becomes reachable again (if `autoReconnect` was set to true)
*/
open class BLEDevice: NSObject {
    /// Maximum interval between two advertising packages. If the OS doesn't receive a successive advertisement package after that interval the device is assumed to be unreachable. If not overridden, this interval defaults to `nil`, meaning that the device will never be assumed unreachable, even in case the OS doesn't receive any more advertising packages.
    //TODO: Make this an instance variable, so subclasses can update it on the fly if necessary or provide different values for the same device type
    open class var maxAdvertisingPackageInterval: TimeInterval? { get { return nil } }
    open class var connectionRetryCount: Int { return 0 }

    open var serviceUUIDs: [CBUUID] { get { return [] } }
    open var charactericUUIDsForServiceUUID: [CBUUID : [CBUUID]] { get { return [:] } }
    open var notificationCharacteristicUUIDs: [CBUUID] { get { return [] } }

    public let discoveryManager: BLEDiscoveryManager
    public let uuid: UUID
    public private(set) var peripheral: CBPeripheral?
    public var centralManager: CBCentralManager { return discoveryManager.centralManager }
    public var isReachable: Bool {
        if centralManager.state != .poweredOn { return false }
        if peripheral?.state == .connected { return true }
        if let lastAdvertisingDate = lastAdvertisingDate, let maxAdvertisingPackageInterval = type(of: self).maxAdvertisingPackageInterval, -lastAdvertisingDate.timeIntervalSinceNow < maxAdvertisingPackageInterval { return true }
        return false
    }

    private var lastAdvertisingDate: Date?
    private var advertisingTimeoutTimer: Timer?
    private var connectionAttempt = 0
    private var autoReconnect = false

    /// Convenience initializer that takes a BLEDiscoveryManager instead of a CBCentralManager. This initializer allows to detect that the device has disappeared by checking if the OS didn't receive any more advertising packages.
    public required init(discoveryManager: BLEDiscoveryManager, peripheral: CBPeripheral) {
        self.discoveryManager = discoveryManager
        self.uuid = peripheral.identifier
        super.init()
        restore(from: peripheral)
    }

    internal func restore(from peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        defer { didUpdateState() }
        invalidateAdvertisingState()
        guard centralManager.state == .poweredOn, peripheral.state == .connected else { return }
        discoverServices()
    }

    open func didAdvertise(_ advertisementData: [String: Any], RSSI: NSNumber, willReceiveSuccessiveAdvertisingData: Bool) {
        guard let peripheral = peripheral else { return }
        guard willReceiveSuccessiveAdvertisingData, let maxAdvertisingPackageInterval = type(of: self).maxAdvertisingPackageInterval else { return }
        advertisingTimeoutTimer?.invalidate()
        advertisingTimeoutTimer = Timer.scheduledTimer(timeInterval: maxAdvertisingPackageInterval, target: self, selector: #selector(didUpdateState), userInfo: nil, repeats: false)
        lastAdvertisingDate = Date()
        didUpdateState()
    }

    open func connect(autoReconnect: Bool = false) {
        self.autoReconnect = autoReconnect
        guard let peripheral = peripheral, centralManager.state == .poweredOn else { return }
        connectionAttempt = 0
        centralManager.connect(peripheral, options: nil)
        didUpdateState()
    }

    open func didConnect() {
        guard let peripheral = peripheral else { return }
        discoverServices()
        invalidateAdvertisingState()
        didUpdateState()
    }

    open func didFailToConnect(error: Error?) {
        guard let peripheral = peripheral else { return }
        if connectionAttempt < type(of: self).connectionRetryCount {
            connectionAttempt += 1
            centralManager.connect(peripheral, options: nil)
        }
        invalidateAdvertisingState()
        didUpdateState(error: error)
    }

    open func disconnect() {
        autoReconnect = false
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    open func didDisconnect(error: Error?) {
        if autoReconnect {
            connect(autoReconnect: true)
        }
        didUpdateState(error: error)
    }

    open func willDiscoverServices() {
    }

    private func discoverServices() {
        guard let peripheral = peripheral else { return }
        willDiscoverServices()
        // Collect any already known service and characterstic (i.e. from device restoring)
        peripheral.services?.forEach {
            // Notify already discovered services, it will discover their characteristics if not already discovered
            self.peripheral(peripheral, didDiscoverServices: nil)
            // Notify already discovered characteristics
            self.peripheral(peripheral, didDiscoverCharacteristicsFor: $0, error: nil)
        }
        // Discover not yet discovered services and characteristics
        peripheral.discoverServices(serviceUUIDs.filter{ !peripheral.serviceUUIDs.contains($0) })
    }

    private func invalidateAdvertisingState() {
        advertisingTimeoutTimer?.invalidate()
        lastAdvertisingDate = nil
    }

    open func didUpdateState(error: Error? = nil) {
    }

    internal func centralManagerDidUpdateState() {
        switch centralManager.state {
        case .poweredOn:
            if autoReconnect {
                connect(autoReconnect: true)
            }
            break
        case .poweredOff:
            break
        default:
            peripheral = nil
        }
        didUpdateState()
    }
}

extension BLEDevice: CBPeripheralDelegate {
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?
            .flatMap{ service in (service, charactericUUIDsForServiceUUID[service.uuid]?.filter { !service.characteristicUUIDs.contains($0) } ?? [] ) }
            .forEach{ peripheral.discoverCharacteristics($0.1, for: $0.0) }
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        service.characteristics?.forEach{ characteristic in
            if notificationCharacteristicUUIDs.contains(characteristic.uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    }

    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    }
}

extension CBPeripheral {
    var serviceUUIDs: [CBUUID] { return services?.map{ $0.uuid } ?? [] }

    func service(with UUID: CBUUID) -> CBService? {
        return services?.filter{ $0.uuid == UUID }.first
    }
}

extension CBService {
    var characteristicUUIDs: [CBUUID] { return characteristics?.map{ $0.uuid } ?? [] }

    func characteristic(with UUID: CBUUID) -> CBCharacteristic? {
        return characteristics?.filter{ $0.uuid == UUID }.first
    }
}
