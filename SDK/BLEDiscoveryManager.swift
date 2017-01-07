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

    fileprivate var knownPeripheralUUIDs:   [UUID]
    fileprivate var deviceForUUID:          [UUID : BLEDevice] = [:]
    fileprivate var alreadyDiscoveredUUIDs: Set<UUID> = []
    fileprivate var serviceUUIDs:           [CBUUID] = []
    fileprivate var updateReachability =    false
    fileprivate var shouldDiscover =        false

    public init(delegate: BLEDiscoveryManagerDelegate? = nil, restoreIdentifier: String? = nil, knownPeripheralUUIDs: [UUID] = []) {
        self.delegate = delegate
        self.knownPeripheralUUIDs = knownPeripheralUUIDs
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
    public func startDiscovery(serviceUUIDs: [CBUUID], updateReachability: Bool = false) {
        self.serviceUUIDs           = serviceUUIDs
        self.updateReachability     = updateReachability
        self.shouldDiscover         = true
        self.alreadyDiscoveredUUIDs = []

        continueDiscovery()
    }

    fileprivate func continueDiscovery() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey : updateReachability])
    }

    public func stopDiscovery() {
        shouldDiscover = false
    }
}

extension BLEDiscoveryManager: CBCentralManagerDelegate {
    public func centralManager(_ central: CBCentralManager, willRestoreState state: [String : Any]) {
        print("CENTRAL WILL RESTORE STATE")

        var restorablePeripherals: [CBPeripheral] = []

        #if os(iOS) || os(tvOS)
        restorablePeripherals += state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        #endif

        restorablePeripherals += centralManager.retrievePeripherals(withIdentifiers: knownPeripheralUUIDs).filter {
            peripheral in !restorablePeripherals.contains(where: { $0.identifier == peripheral.identifier })
        }

        restorablePeripherals
            .flatMap { delegate?.bleDiscoveryManager(self, deviceFor: $0, advertisementData: [:]) }
            .forEach {
                deviceForUUID[$0.uuid] = $0
                delegate?.bleDiscoveryManager(self, didRestore: $0)
            }

        deviceForUUID.keys.forEach { print("RESTORED", $0) }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //TODO: Is this method started on every app start into foreground? Currently we assume yes, but what if bluetooth was already on? Do wo then still restore all peripherals?

        print("CENTRAL DID UPDATE STATE", central.state.rawValue)

        if centralManager.state.rawValue >= CBCentralManagerState.poweredOff.rawValue {
            // Update all devices with a freshly retrieved peripheral from central manager for those which have an invalidated peripheral
            centralManager.retrievePeripherals(withIdentifiers: Array(deviceForUUID.keys)).forEach {
                guard let device = self.deviceForUUID[$0.identifier], device.peripheral == nil else { return }
                device.restore(from: $0)
                self.delegate?.bleDiscoveryManager(self, didRestore: device)
            }
        }

        deviceForUUID.values.forEach { $0.centralManagerDidUpdateState() }

        if central.state == .poweredOn && shouldDiscover {
            continueDiscovery()
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var device = deviceForUUID[peripheral.identifier]

        if !alreadyDiscoveredUUIDs.contains(peripheral.identifier) {
            alreadyDiscoveredUUIDs.insert(peripheral.identifier)

            if device == nil {
                device = delegate?.bleDiscoveryManager(self, deviceFor: peripheral, advertisementData: advertisementData)
                if let device = device {
                    deviceForUUID[peripheral.identifier] = device
                    delegate?.bleDiscoveryManager(self, didDiscover: device)
                }
            }
        }

        device?.didAdvertise(advertisementData, RSSI: RSSI, willReceiveSuccessiveAdvertisingData: updateReachability)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        deviceForUUID[peripheral.identifier]?.didConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        deviceForUUID[peripheral.identifier]?.didFailToConnect(error: error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        deviceForUUID[peripheral.identifier]?.didDisconnect(error: error)
    }
}

public protocol BLEDiscoveryManagerDelegate: class {
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, deviceFor peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice?
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscover device: BLEDevice)
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestore device: BLEDevice)
}
