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

public let NuimoDiscoveryManagerAutoDetectUnreachableControllersKey = "NuimoDiscoveryManagerAutoDetectUnreachableControllers"
public let NuimoDiscoveryManagerWebSocketControllerURLsKey = "NuimoDiscoveryManagerWebSocketControllerURLs"
public let NuimoDiscoveryManagerAdditionalDiscoverServiceUUIDsKey = "NuimoDiscoveryManagerAdditionalDiscoverServiceUUIDs"

// Allows for discovering Nuimo BLE hardware controllers and virtual (websocket) controllers
public class NuimoDiscoveryManager: NSObject, BLEDiscoveryDelegate {
    
    public static let sharedManager = NuimoDiscoveryManager()
    public private (set) lazy var centralManager: CBCentralManager = self.bleDiscovery.centralManager
    
    public var delegate: NuimoDiscoveryDelegate?

    private let options: [String : AnyObject]
    private lazy var bleDiscovery: BLEDiscoveryManager = BLEDiscoveryManager(delegate: self, options: self.options)

    public init(delegate: NuimoDiscoveryDelegate? = nil, options: [String : AnyObject] = [:]) {
        self.options = options
        super.init()
        self.delegate = delegate
    }
    
    public func startDiscovery() {
        // Discover websocket controllers
        #if NUIMO_USE_WEBSOCKETS
        (options[NuimoDiscoveryManagerWebSocketControllerURLsKey] as? [String])?.forEach {
            delegate?.nuimoDiscoveryManager(self, didDiscoverNuimoController: NuimoWebSocketController(url: $0))
        }
        #endif

        let detectUnreachableControllers = options[NuimoDiscoveryManagerAutoDetectUnreachableControllersKey] as? Bool ?? false
        let additionalDiscoverServiceUUIDs = options[NuimoDiscoveryManagerAdditionalDiscoverServiceUUIDsKey] as? [CBUUID] ?? []
        bleDiscovery.startDiscovery(nuimoServiceUUIDs + additionalDiscoverServiceUUIDs, detectUnreachableControllers: detectUnreachableControllers)
    }

    public func stopDiscovery() {
        bleDiscovery.stopDiscovery()
    }

    public func bleDiscoveryManager(discovery: BLEDiscoveryManager, deviceWithPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject]?) -> BLEDevice? {
        guard peripheral.name == "Nuimo" || advertisementData?[CBAdvertisementDataLocalNameKey] as? String == "Nuimo" else { return nil }
        return NuimoBluetoothController(centralManager: bleDiscovery.centralManager, uuid: peripheral.identifier.UUIDString, peripheral: peripheral)
    }

    public func bleDiscoveryManager(discovery: BLEDiscoveryManager, didDiscoverDevice device: BLEDevice) {
        delegate?.nuimoDiscoveryManager(self, didDiscoverNuimoController: device as! NuimoController)
    }

    public func bleDiscoveryManager(discovery: BLEDiscoveryManager, didRestoreDevice device: BLEDevice) {
        delegate?.nuimoDiscoveryManager?(self, didRestoreNuimoController: device as! NuimoController)
    }

    public func bleDiscoveryManager(discovery: BLEDiscoveryManager, didConnectDevice device: BLEDevice) {
        delegate?.nuimoDiscoveryManager?(self, didConnectNuimoController: device as! NuimoController)
    }

    public func bleDiscoveryManager(discovery: BLEDiscoveryManager, didFailToConnectDevice device: BLEDevice, error: NSError?) {
        delegate?.nuimoDiscoveryManager?(self, didFailToConnectNuimoController: device as! NuimoController, error: error)
    }

    public func bleDiscoveryManager(discovery: BLEDiscoveryManager, didDisconnectDevice device: BLEDevice, error: NSError?) {
        delegate?.nuimoDiscoveryManager?(self, didDisconnectNuimoController: device as! NuimoController, error: error)
    }

    public func bleDiscoveryManager(discovery: BLEDiscoveryManager, didInvalidateDevice device: BLEDevice) {
        delegate?.nuimoDiscoveryManager?(self, didInvalidateController: device as! NuimoController)
    }
}

@objc public protocol NuimoDiscoveryDelegate {
    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didRestoreNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didConnectNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didFailToConnectNuimoController controller: NuimoController, error: NSError?)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDisconnectNuimoController controller: NuimoController, error: NSError?)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didInvalidateController controller: NuimoController)
}
