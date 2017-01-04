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
    public private (set) lazy var bleDiscovery: BLEDiscoveryManager = BLEDiscoveryManager(delegate: self.bleDiscoveryDelegate, options: self.options)
    
    public weak var delegate: NuimoDiscoveryDelegate?

    private let options: [String : Any]
    private lazy var bleDiscoveryDelegate: PrivateBLEDiscoveryManagerDelegate = PrivateBLEDiscoveryManagerDelegate(nuimoDiscoveryManager: self)

    public init(delegate: NuimoDiscoveryDelegate? = nil, options: [String : Any] = [:]) {
        self.options = options
        super.init()
        self.delegate = delegate
    }
    
    public func startDiscovery(detectUnreachableControllers: Bool = false) {
        let additionalDiscoverServiceUUIDs = options[NuimoDiscoveryManagerAdditionalDiscoverServiceUUIDsKey] as? [CBUUID] ?? []
        bleDiscovery.startDiscovery(serviceUUIDs: nuimoServiceUUIDs + additionalDiscoverServiceUUIDs, detectUnreachableDevices: detectUnreachableControllers)
    }

    public func stopDiscovery() {
        bleDiscovery.stopDiscovery()
    }

    fileprivate func nuimoBluetoothController(with peripheral: CBPeripheral) -> NuimoBluetoothController {
        return NuimoBluetoothController(discoveryManager: self.bleDiscovery, uuid: peripheral.identifier.uuidString, peripheral: peripheral)
    }
}

private class PrivateBLEDiscoveryManagerDelegate: BLEDiscoveryManagerDelegate {
    let nuimoDiscoveryManager: NuimoDiscoveryManager

    init(nuimoDiscoveryManager: NuimoDiscoveryManager) {
        self.nuimoDiscoveryManager = nuimoDiscoveryManager
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice? {
        if let device = nuimoDiscoveryManager.delegate?.nuimoDiscoveryManager?(nuimoDiscoveryManager, deviceForPeripheral: peripheral) {
            return device
        }
        guard peripheral.name == "Nuimo" || advertisementData[CBAdvertisementDataLocalNameKey] as? String == "Nuimo" else { return nil }
        return nuimoDiscoveryManager.nuimoBluetoothController(with: peripheral)
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverDevice device: BLEDevice) {
        nuimoDiscoveryManager.delegate?.nuimoDiscoveryManager(nuimoDiscoveryManager, didDiscoverNuimoController: device as! NuimoController)
    }

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestoreDevice device: BLEDevice) {
        nuimoDiscoveryManager.delegate?.nuimoDiscoveryManager?(nuimoDiscoveryManager, didRestoreNuimoController: device as! NuimoController)
    }

    fileprivate func bleDiscoveryManagerDidStartDiscovery(_ discovery: BLEDiscoveryManager) {
        nuimoDiscoveryManager.delegate?.nuimoDiscoveryManagerDidStartDiscovery?(nuimoDiscoveryManager)
    }

    fileprivate func bleDiscoveryManagerDidStopDiscovery(_ discovery: BLEDiscoveryManager) {
        nuimoDiscoveryManager.delegate?.nuimoDiscoveryManagerDidStopDiscovery?(nuimoDiscoveryManager)
    }
}

@objc public protocol NuimoDiscoveryDelegate: class {
    @objc optional func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, deviceForPeripheral peripheral: CBPeripheral) -> BLEDevice?
    func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController)
    @objc optional func nuimoDiscoveryManager(_ discovery: NuimoDiscoveryManager, didRestoreNuimoController controller: NuimoController)
    @objc optional func nuimoDiscoveryManagerDidStartDiscovery(_ discovery: NuimoDiscoveryManager)
    @objc optional func nuimoDiscoveryManagerDidStopDiscovery(_ discovery: NuimoDiscoveryManager)
}
