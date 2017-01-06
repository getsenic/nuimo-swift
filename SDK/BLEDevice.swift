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
    public private(set) var peripheral: CBPeripheral? { didSet { updateReachability() } }
    public var centralManager: CBCentralManager { return discoveryManager.centralManager }
    public internal(set) var isReachable = false
    public private(set) var didInitiateConnection = false

    private var lastAdvertisingDate: Date?      { didSet { updateReachability() } }
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

        guard peripheral.state == .connected else { return }

        didInitiateConnection = true
        peripheral.services?.forEach {
            // Notify already discovered services, it will discover their characteristics if not already discovered
            self.peripheral(peripheral, didDiscoverServices: nil)
            // Notify already discovered characteristics
            self.peripheral(peripheral, didDiscoverCharacteristicsFor: $0, error: nil)
        }
        // Discover not yet discovered services
        peripheral.discoverServices(serviceUUIDs.filter{ !peripheral.serviceUUIDs.contains($0) })
    }

    open func didRestore() {
    }

    open func didAdvertise(_ advertisementData: [String: Any], RSSI: NSNumber, willReceiveSuccessiveAdvertisingData: Bool) {
        guard let peripheral = peripheral else { return }
        // Invalidate device if it stops advertising after a given interval of not sending any other advertising packages. Works only if `discoveryManager` known.
        advertisingTimeoutTimer?.invalidate()

        guard willReceiveSuccessiveAdvertisingData, let maxAdvertisingPackageInterval = type(of: self).maxAdvertisingPackageInterval else { return }
        lastAdvertisingDate = Date()
        advertisingTimeoutTimer = Timer.scheduledTimer(timeInterval: maxAdvertisingPackageInterval, target: self, selector: #selector(updateReachability), userInfo: nil, repeats: false)
    }

    open func connect(autoReconnect: Bool = false) {
        self.autoReconnect = autoReconnect
        guard let peripheral = peripheral, centralManager.state == .poweredOn else { return }
        didInitiateConnection = true
        connectionAttempt = 0
        centralManager.connect(peripheral, options: nil)
    }

    open func didConnect() {
        guard let peripheral = peripheral else { return }
        peripheral.discoverServices(serviceUUIDs)
        updateReachability()
    }

    open func didFailToConnect(error: Error?) {
        guard let peripheral = peripheral else { return }
        if connectionAttempt < type(of: self).connectionRetryCount {
            connectionAttempt += 1
            centralManager.connect(peripheral, options: nil)
        }
    }

    open func disconnect() {
        autoReconnect = false
        guard let peripheral = peripheral else { return }
        // Only disconnect if connection was initiated by this instance. BLEDevice can also be used to only discover peripherals but somebody else takes then ownership over the `delegate` instance.
        guard didInitiateConnection else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    open func didDisconnect(error: Error?) {
        if autoReconnect {
            connect(autoReconnect: true)
        }
    }

    internal func centralManagerDidUpdateState() {
        switch centralManager.state {
        case .poweredOn:
            if autoReconnect {
                connect(autoReconnect: true)
            }
            updateReachability()
            break
        case .poweredOff:
            updateReachability()
        default:
            peripheral = nil
        }
    }

    private dynamic func updateReachability() {
        isReachable = {
            if centralManager.state == .poweredOn { return false }
            if peripheral?.state == .connected { return true }
            if let lastAdvertisingDate = lastAdvertisingDate, let maxAdvertisingPackageInterval = type(of: self).maxAdvertisingPackageInterval, -lastAdvertisingDate.timeIntervalSinceNow < maxAdvertisingPackageInterval { return true }
            return false
        }()
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
