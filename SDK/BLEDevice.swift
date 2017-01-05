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

    public var uuid: UUID { return peripheral.identifier }
    public let peripheral: CBPeripheral
    public let centralManager: CBCentralManager
    public private(set) var didInitiateConnection = false

    private var discoveryManager: BLEDiscoveryManager?
    private var advertisingTimeoutTimer: Timer?
    private var connectionTimeoutTimer: Timer?
    private var connectionAttempt = 0

    /// Convenience initializer that takes a BLEDiscoveryManager instead of a CBCentralManager. This initializer allows to detect that the device has disappeared by checking if the OS didn't receive any more advertising packages.
    public convenience init(discoveryManager: BLEDiscoveryManager, peripheral: CBPeripheral) {
        self.init(centralManager: discoveryManager.centralManager, peripheral: peripheral)
        self.discoveryManager = discoveryManager
    }

    public required init(centralManager: CBCentralManager, peripheral: CBPeripheral) {
        self.centralManager = centralManager
        self.peripheral = peripheral
        super.init()
    }

    open func didAdvertise(_ advertisementData: [String: Any], RSSI: NSNumber, willReceiveSuccessiveAdvertisingData: Bool) {
        // Invalidate device if it stops advertising after a given interval of not sending any other advertising packages. Works only if `discoveryManager` known.
        advertisingTimeoutTimer?.invalidate()
        if let maxAdvertisingPackageInterval = type(of: self).maxAdvertisingPackageInterval, peripheral.state == .disconnected && willReceiveSuccessiveAdvertisingData {
            advertisingTimeoutTimer = Timer.scheduledTimer(timeInterval: maxAdvertisingPackageInterval, target: self, selector: #selector(updateReachability), userInfo: nil, repeats: false)
        }
    }

    private dynamic func updateReachability() {
        //TODO: Implement me
    }

    open func connect() {
        didInitiateConnection = true
        connectionAttempt = 0
    }

    open func didConnect() {
        connectionTimeoutTimer?.invalidate()
        peripheral.delegate = self
        peripheral.discoverServices(serviceUUIDs)
    }

    open func didConnectTimeout() {
        centralManager.cancelPeripheralConnection(peripheral)
        // CoreBluetooth doesn't call didFailToConnectPeripheral delegate method – that's why we call it here
        centralManager.delegate?.centralManager?(centralManager, didFailToConnect: peripheral, error: NSError(domain: "BLEDevice", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to peripheral", NSLocalizedFailureReasonErrorKey: "Connection attempt timed out"]))
    }

    open func didFailToConnect(error: Error?) {
        if connectionAttempt < type(of: self).connectionRetryCount {
            connectionAttempt += 1
            centralManager.connect(peripheral, options: nil)
        }
    }

    open func didRestore() {
        peripheral.delegate = self
        guard peripheral.state == .connected else { return }
        didInitiateConnection = true
        peripheral.services?.forEach {
            // Notify already discovered services, it will discover their characteristics if not already discovered
            peripheral(peripheral, didDiscoverServices: nil)
            // Notify already discovered characteristics
            peripheral(peripheral, didDiscoverCharacteristicsFor: $0, error: nil)
        }
        // Discover not yet discovered services
        peripheral.discoverServices(serviceUUIDs.filter{ !peripheral.serviceUUIDs.contains($0) })
    }

    open func disconnect() {
        // Only disconnect if connection was initiated by this instance. BLEDevice can also be used to only discover peripherals but somebody else takes then ownership over the `delegate` instance.
        guard didInitiateConnection else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    open func didDisconnect(error: Error?) {
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
