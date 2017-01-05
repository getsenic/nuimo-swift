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
public class NuimoDiscoveryManager: NSObject {

    public static let sharedManager = NuimoDiscoveryManager()

    public private(set) var bleDiscovery: BLEDiscoveryManager!
    public var centralManager: CBCentralManager { return self.bleDiscovery.centralManager }
    public weak var delegate: NuimoDiscoveryDelegate?

    private var bleDiscoveryDelegate: NuimoDiscoveryManagerPrivate!

    public init(delegate: NuimoDiscoveryDelegate? = nil, restoreIdentifier: String? = nil) {
        self.delegate = delegate
        super.init()
        self.bleDiscoveryDelegate = NuimoDiscoveryManagerPrivate(nuimoDiscoveryManager: self)
        self.bleDiscovery = BLEDiscoveryManager(delegate: self.bleDiscoveryDelegate, restoreIdentifier: restoreIdentifier)
    }
    
    public func startDiscovery(extraServiceUUIDs: [CBUUID] = [], detectUnreachableControllers: Bool = false) {
        bleDiscovery.startDiscovery(serviceUUIDs: nuimoServiceUUIDs + extraServiceUUIDs, detectUnreachableDevices: detectUnreachableControllers)
    }

    public func stopDiscovery() {
        bleDiscovery.stopDiscovery()
    }

    fileprivate func nuimoBluetoothController(with peripheral: CBPeripheral) -> NuimoBluetoothController {
        return NuimoBluetoothController(discoveryManager: self.bleDiscovery, uuid: peripheral.identifier.uuidString, peripheral: peripheral)
    }
}

private class NuimoDiscoveryManagerPrivate: BLEDiscoveryManagerDelegate {
    weak var manager: NuimoDiscoveryManager?

    init(nuimoDiscoveryManager: NuimoDiscoveryManager) {
        self.manager = nuimoDiscoveryManager
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice? {
        guard let manager = manager else { return nil }
        if let device = manager.delegate?.nuimoDiscoveryManager(manager, deviceForPeripheral: peripheral) {
            return device
        }
        guard peripheral.name == "Nuimo" || advertisementData[CBAdvertisementDataLocalNameKey] as? String == "Nuimo" else { return nil }
        return manager.nuimoBluetoothController(with: peripheral)
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverDevice device: BLEDevice) {
        guard let manager = manager else { return }
        manager.delegate?.nuimoDiscoveryManager(manager, didDiscoverNuimoController: device as! NuimoController)
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestoreDevice device: BLEDevice) {
        guard let manager = manager else { return }
        manager.delegate?.nuimoDiscoveryManager(manager, didRestoreNuimoController: device as! NuimoController)
    }

    func bleDiscoveryManagerDidStartDiscovery(_ discovery: BLEDiscoveryManager) {
        guard let manager = manager else { return }
        manager.delegate?.nuimoDiscoveryManagerDidStartDiscovery(manager)
    }

    func bleDiscoveryManagerDidStopDiscovery(_ discovery: BLEDiscoveryManager) {
        guard let manager = manager else { return }
        manager.delegate?.nuimoDiscoveryManagerDidStopDiscovery(manager)
    }
}

public protocol NuimoDiscoveryDelegate: class {
    func nuimoDiscoveryManagerDidStartDiscovery(_ discovery: NuimoDiscoveryManager)
    func nuimoDiscoveryManagerDidStopDiscovery(_ discovery: NuimoDiscoveryManager)
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, deviceForPeripheral peripheral: CBPeripheral) -> BLEDevice?
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController)
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didRestoreNuimoController controller: NuimoController)
}

public extension NuimoDiscoveryDelegate {
    func nuimoDiscoveryManagerDidStartDiscovery(_ discovery: NuimoDiscoveryManager) {}
    func nuimoDiscoveryManagerDidStopDiscovery(_ discovery: NuimoDiscoveryManager) {}
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, deviceForPeripheral peripheral: CBPeripheral) -> BLEDevice? { return nil }
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didRestoreNuimoController controller: NuimoController) {}
}
