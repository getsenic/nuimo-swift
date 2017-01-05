//
//  BLEDiscoveryManager.swift
//  Nuimo
//
//  Created by Lars Blumberg on 12/10/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import CoreBluetooth

/**
    Allows for easy discovering bluetooth devices.
    Automatically re-starts discovery if bluetooth was disabled for a previous discovery.
*/
public class BLEDiscoveryManager: NSObject {
    public weak var delegate: BLEDiscoveryManagerDelegate?
    public private(set) var centralManager: CBCentralManager!

    fileprivate var serviceUUIDs: [CBUUID] =      []
    fileprivate var detectUnreachableDevices =    false
    fileprivate var shouldDiscover =              false
    fileprivate var peripheralForUUID:            [UUID : CBPeripheral] = [:]
    fileprivate var deviceForPeripheral:          [CBPeripheral : BLEDevice] = [:]
    fileprivate var restoredConnectedPeripherals: [CBPeripheral]?

    public init(delegate: BLEDiscoveryManagerDelegate? = nil, restoreIdentifier: String? = nil) {
        self.delegate = delegate
        super.init()

        var centralManagerOptions: [String : Any] = [:]
        if let restoreIdentifier = restoreIdentifier {
            #if os(iOS) || os(tvOS)
            centralManagerOptions[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
            #endif
        }

        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: centralManagerOptions)
    }

    /// If detectUnreachableDevices is set to true, it will invalidate devices if they stop advertising. Consumes more energy since `CBCentralManagerScanOptionAllowDuplicatesKey` is set to true.
    public func startDiscovery(serviceUUIDs: [CBUUID], detectUnreachableDevices: Bool = false) {
        self.serviceUUIDs = serviceUUIDs
        self.detectUnreachableDevices = detectUnreachableDevices
        self.shouldDiscover = true

        guard centralManager.state == .poweredOn else { return }
        startDiscovery()
    }

    fileprivate func startDiscovery() {
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey : detectUnreachableDevices])
    }

    public func stopDiscovery() {
        shouldDiscover = false
    }
}

extension BLEDiscoveryManager: CBCentralManagerDelegate {
    public func centralManager(_ central: CBCentralManager, willRestoreState state: [String : Any]) {
        //TODO: Should work on OSX as well. http://stackoverflow.com/q/33210078/543875
        #if os(iOS) || os(tvOS)
            restoredConnectedPeripherals = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
        #endif
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            restoredConnectedPeripherals?.forEach{ centralManager(central, didRestorePeripheral: $0) }
            restoredConnectedPeripherals = nil
            // When bluetooth turned on and discovery start had already been triggered before, start discovery now
            shouldDiscover
                ? startDiscovery()
                : ()
        default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var device: BLEDevice?
        if let knownDevice = deviceForPeripheral[peripheral] {
            // Prevent devices from being discovered multiple times. iOS devices in peripheral role are also discovered multiple times.
            if detectUnreachableDevices {
                device = knownDevice
            }
        }
        else if let discoveredDevice = delegate?.bleDiscoveryManager(self, didDiscoverPeripheral: peripheral, advertisementData: advertisementData) {
            deviceForPeripheral[peripheral] = discoveredDevice
            delegate?.bleDiscoveryManager(self, didDiscoverDevice: discoveredDevice)
            device = discoveredDevice
        }
        device?.didAdvertise(advertisementData, RSSI: RSSI, willReceiveSuccessiveAdvertisingData: detectUnreachableDevices)
    }

    public func centralManager(_ central: CBCentralManager, didRestorePeripheral peripheral: CBPeripheral) {
        guard let device = delegate?.bleDiscoveryManager(self, didDiscoverPeripheral: peripheral, advertisementData: [:]) else { return }
        deviceForPeripheral[peripheral] = device
        device.didRestore()
        delegate?.bleDiscoveryManager(self, didRestoreDevice: device)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didFailToConnect(error: error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didDisconnect(error: error)
    }
}

public protocol BLEDiscoveryManagerDelegate: class {
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice?
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverDevice device: BLEDevice)
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestoreDevice device: BLEDevice)
}
