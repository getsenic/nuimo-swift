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
public class BLEDiscoveryManager {
    public weak var delegate: BLEDiscoveryManagerDelegate?
    public var centralManager: CBCentralManager { return self.discovery.centralManager }

    private var discovery: BLEDiscoveryManagerPrivate!

    public init(delegate: BLEDiscoveryManagerDelegate? = nil, restoreIdentifier: String? = nil) {
        self.delegate = delegate

        var centralManagerOptions: [String : Any] = [:]
        if let restoreIdentifier = restoreIdentifier {
            #if os(iOS) || os(tvOS)
            centralManagerOptions[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
            #endif
        }
        self.discovery = BLEDiscoveryManagerPrivate(discovery: self, centralManagerOptions: centralManagerOptions)
    }

    /// If detectUnreachableDevices is set to true, it will invalidate devices if they stop advertising. Consumes more energy since `CBCentralManagerScanOptionAllowDuplicatesKey` is set to true.
    public func startDiscovery(serviceUUIDs: [CBUUID], detectUnreachableDevices: Bool = false) {
        discovery.startDiscovery(serviceUUIDs: serviceUUIDs, detectUnreachableDevices: detectUnreachableDevices)
    }

    public func stopDiscovery() {
        discovery.stopDiscovery()
    }
}

public protocol BLEDiscoveryManagerDelegate: class {
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice?
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverDevice device: BLEDevice)
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestoreDevice device: BLEDevice)
}

/**
    Private implementation of BLEDiscoveryManager.
    Hides implementation of CBCentralManagerDelegate.
*/
private class BLEDiscoveryManagerPrivate: NSObject, CBCentralManagerDelegate {
    weak var discovery: BLEDiscoveryManager?

    var centralManager:               CBCentralManager!
    var serviceUUIDs: [CBUUID] =      []
    var detectUnreachableDevices =    false
    var shouldDiscover =              false
    var peripheralForUUID:            [UUID : CBPeripheral] = [:]
    var deviceForPeripheral:          [CBPeripheral : BLEDevice] = [:]
    var restoredConnectedPeripherals: [CBPeripheral]?

    init(discovery: BLEDiscoveryManager, centralManagerOptions: [String : Any]) {
        self.discovery = discovery
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: centralManagerOptions)
    }

    func startDiscovery(serviceUUIDs: [CBUUID], detectUnreachableDevices: Bool) {
        self.serviceUUIDs = serviceUUIDs
        self.detectUnreachableDevices = detectUnreachableDevices
        self.shouldDiscover = true

        guard centralManager.state == .poweredOn else { return }
        startDiscovery()
    }

    private func startDiscovery() {
        guard let discovery = discovery else { return }
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey : detectUnreachableDevices])
    }

    func stopDiscovery() {
        guard let discovery = discovery else { return }
        shouldDiscover = false
    }

    func centralManager(_ central: CBCentralManager, willRestoreState state: [String : Any]) {
        //TODO: Should work on OSX as well. http://stackoverflow.com/q/33210078/543875
        #if os(iOS) || os(tvOS)
            restoredConnectedPeripherals = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
        #endif
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
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

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let discovery = discovery else { return }
        var device: BLEDevice?
        if let knownDevice = deviceForPeripheral[peripheral] {
            // Prevent devices from being discovered multiple times. iOS devices in peripheral role are also discovered multiple times.
            if detectUnreachableDevices {
                device = knownDevice
            }
        }
        else if let discoveredDevice = discovery.delegate?.bleDiscoveryManager(discovery, didDiscoverPeripheral: peripheral, advertisementData: advertisementData) {
            deviceForPeripheral[peripheral] = discoveredDevice
            discovery.delegate?.bleDiscoveryManager(discovery, didDiscoverDevice: discoveredDevice)
            device = discoveredDevice
        }
        device?.didAdvertise(advertisementData, RSSI: RSSI, willReceiveSuccessiveAdvertisingData: detectUnreachableDevices)
    }

    func centralManager(_ central: CBCentralManager, didRestorePeripheral peripheral: CBPeripheral) {
        guard let discovery = discovery, let device = discovery.delegate?.bleDiscoveryManager(discovery, didDiscoverPeripheral: peripheral, advertisementData: [:]) else { return }
        deviceForPeripheral[peripheral] = device
        device.didRestore()
        discovery.delegate?.bleDiscoveryManager(discovery, didRestoreDevice: device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didConnect()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didFailToConnect(error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didDisconnect(error: error)
    }
}
