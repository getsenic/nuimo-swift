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

public let NuimoDiscoveryManagerAdditionalDiscoverServiceUUIDsKey = "NuimoDiscoveryManagerAdditionalDiscoverServiceUUIDs"

// Allows for discovering Nuimo BLE hardware controllers and virtual (websocket) controllers
public class NuimoDiscoveryManager: NSObject {

    public static let sharedManager = NuimoDiscoveryManager()
    public private (set) lazy var centralManager: CBCentralManager = self.bleDiscovery.centralManager
    
    public var delegate: NuimoDiscoveryDelegate?

    private let options: [String : AnyObject]
    private lazy var bleDiscovery: BLEDiscoveryManager = BLEDiscoveryManager(delegate: self.bleDiscoveryDelegate, options: self.options)
    private lazy var bleDiscoveryDelegate: PrivateBLEDiscoveryManagerDelegate = PrivateBLEDiscoveryManagerDelegate(nuimoDiscoveryManager: self)

    public init(delegate: NuimoDiscoveryDelegate? = nil, options: [String : AnyObject] = [:]) {
        self.options = options
        super.init()
        self.delegate = delegate
    }
    
    public func startDiscovery() {
        let additionalDiscoverServiceUUIDs = options[NuimoDiscoveryManagerAdditionalDiscoverServiceUUIDsKey] as? [CBUUID] ?? []
        bleDiscovery.startDiscovery(nuimoServiceUUIDs + additionalDiscoverServiceUUIDs)
    }

    public func stopDiscovery() {
        bleDiscovery.stopDiscovery()
    }
}

private class PrivateBLEDiscoveryManagerDelegate: BLEDiscoveryManagerDelegate {
    let nuimoDiscoveryManager: NuimoDiscoveryManager

    init(nuimoDiscoveryManager: NuimoDiscoveryManager) {
        self.nuimoDiscoveryManager = nuimoDiscoveryManager
    }

    func bleDiscoveryManager(discovery: BLEDiscoveryManager, deviceWithPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject]?) -> BLEDevice? {
        if let device = nuimoDiscoveryManager.delegate?.nuimoDiscoveryManager?(nuimoDiscoveryManager, deviceForPeripheral: peripheral) {
            return device
        }
        guard peripheral.name == "Nuimo" || advertisementData?[CBAdvertisementDataLocalNameKey] as? String == "Nuimo" else { return nil }
        return NuimoBluetoothController(centralManager: nuimoDiscoveryManager.centralManager, uuid: peripheral.identifier.UUIDString, peripheral: peripheral)
    }

    func bleDiscoveryManager(discovery: BLEDiscoveryManager, didDiscoverDevice device: BLEDevice) {
        nuimoDiscoveryManager.delegate?.nuimoDiscoveryManager(nuimoDiscoveryManager, didDiscoverNuimoController: device as! NuimoController)
    }

    func bleDiscoveryManager(discovery: BLEDiscoveryManager, didRestoreDevice device: BLEDevice) {
        nuimoDiscoveryManager.delegate?.nuimoDiscoveryManager?(nuimoDiscoveryManager, didRestoreNuimoController: device as! NuimoController)
    }
}

@objc public protocol NuimoDiscoveryDelegate {
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, deviceForPeripheral peripheral: CBPeripheral) -> BLEDevice?
    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didRestoreNuimoController controller: NuimoController)
}
