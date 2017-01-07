//
//  NuimoDiscoveryManager.swift
//  Nuimo
//
//  Created by Lars Blumberg on 9/23/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import CoreBluetooth

// Allows for discovering Nuimo BLE hardware controllers and virtual (websocket) controllers
public class NuimoDiscoveryManager {

    public static let sharedManager = NuimoDiscoveryManager()

    public private(set) var bleDiscoveryManager: BLEDiscoveryManager!
    public var centralManager: CBCentralManager { return self.bleDiscoveryManager.centralManager }
    public weak var delegate: NuimoDiscoveryDelegate?

    private var bleDiscoveryDelegate: NuimoDiscoveryManagerPrivate!

    public init(delegate: NuimoDiscoveryDelegate? = nil, restoreIdentifier: String? = nil, knownNuimoUUIDs: [UUID] = []) {
        self.delegate = delegate
        self.bleDiscoveryDelegate = NuimoDiscoveryManagerPrivate(nuimoDiscoveryManager: self)
        self.bleDiscoveryManager = BLEDiscoveryManager(delegate: self.bleDiscoveryDelegate, restoreIdentifier: restoreIdentifier, knownPeripheralUUIDs: knownNuimoUUIDs)
    }
    
    public func startDiscovery(serviceUUIDs: [CBUUID] = nuimoServiceUUIDs, updateReachability: Bool = false) {
        bleDiscoveryManager.startDiscovery(serviceUUIDs: serviceUUIDs, updateReachability: updateReachability)
    }

    public func stopDiscovery() {
        bleDiscoveryManager.stopDiscovery()
    }
}

private class NuimoDiscoveryManagerPrivate: BLEDiscoveryManagerDelegate {
    weak var manager: NuimoDiscoveryManager?

    init(nuimoDiscoveryManager: NuimoDiscoveryManager) {
        self.manager = nuimoDiscoveryManager
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, deviceFor peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice? {
        guard let manager = manager else { return nil }
        return manager.delegate?.nuimoDiscoveryManager(manager, deviceForPeripheral: peripheral, advertisementData: advertisementData)
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscover device: BLEDevice) {
        guard let manager = manager else { return }
        manager.delegate?.nuimoDiscoveryManager(manager, didDiscoverNuimoController: device as! NuimoController)
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestore device: BLEDevice) {
        guard let manager = manager else { return }
        manager.delegate?.nuimoDiscoveryManager(manager, didRestoreNuimoController: device as! NuimoController)
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didStopAdvertising device: BLEDevice) {
        guard let manager = manager else { return }
        manager.delegate?.nuimoDiscoveryManager(manager, didStopAdvertising: device as! NuimoController)
    }
}

public protocol NuimoDiscoveryDelegate: class {
    //TODO: Rename delegate methods to `deviceFor:` etc.
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, deviceForPeripheral peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice?
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController)
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didRestoreNuimoController controller: NuimoController)
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didStopAdvertising controller: NuimoController)
}

public extension NuimoDiscoveryDelegate {
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, deviceForPeripheral peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice? {
        guard peripheral.name == "Nuimo" || advertisementData[CBAdvertisementDataLocalNameKey] as? String == "Nuimo" else { return nil }
        return NuimoBluetoothController(discoveryManager: discovery.bleDiscoveryManager, peripheral: peripheral)
    }
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didRestoreNuimoController controller: NuimoController) {}
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didStopAdvertising controller: NuimoController) {}
}
