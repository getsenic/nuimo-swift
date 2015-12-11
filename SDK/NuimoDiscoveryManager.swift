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

// Allows for discovering Nuimo BLE hardware controllers and virtual (websocket) controllers
public class NuimoDiscoveryManager: BLEDiscoveryManager {
    
    public static let sharedManager = NuimoDiscoveryManager()
    
    public var delegate: NuimoDiscoveryDelegate?
    public var webSocketControllerURLs: [String]
    public var detectUnreachableControllers: Bool

    public init(delegate: NuimoDiscoveryDelegate? = nil, options: [String : AnyObject] = [:]) {
        webSocketControllerURLs = options[NuimoDiscoveryManagerWebSocketControllerURLsKey] as? [String] ?? []
        detectUnreachableControllers = options[NuimoDiscoveryManagerAutoDetectUnreachableControllersKey] as? Bool ?? false
        super.init(options: options)
        self.delegate = delegate
    }
    
    public func startDiscovery() {
        // Discover websocket controllers
        #if NUIMO_USE_WEBSOCKETS
        webSocketControllerURLs.forEach {
            delegate?.nuimoDiscoveryManager(self, didDiscoverNuimoController: NuimoWebSocketController(url: $0))
        }
        #endif

        super.startDiscovery(nuimoServiceUUIDs, detectUnreachableControllers: detectUnreachableControllers)
    }

    override public func deviceWithPeripheral(peripheral: CBPeripheral) -> BLEDevice? {
        guard peripheral.name == "Nuimo" else { return nil }
        return NuimoBluetoothController(centralManager: centralManager, uuid: peripheral.identifier.UUIDString, peripheral: peripheral)
    }

    override public func didInvalidateDevice(device: BLEDevice) {
        delegate?.nuimoDiscoveryManager?(self, didInvalidateController: device as! NuimoController)
    }
    
    override public func didDiscoverDevice(device: BLEDevice) {
        delegate?.nuimoDiscoveryManager(self, didDiscoverNuimoController: device as! NuimoController)
    }

    override public func didConnectDevice(device: BLEDevice) {
        delegate?.nuimoDiscoveryManager?(self, didConnectNuimoController: device as! NuimoController)
    }

    override public func didFailToConnectDevice(device: BLEDevice, error: NSError?) {
        delegate?.nuimoDiscoveryManager?(self, didFailToConnectNuimoController: device as! NuimoController, error: error)
    }

    override public func didDisconnectDevice(device: BLEDevice, error: NSError?) {
        delegate?.nuimoDiscoveryManager?(self, didDisconnectNuimoController: device as! NuimoController, error: error)
    }
}

@objc public protocol NuimoDiscoveryDelegate {
    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didConnectNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didFailToConnectNuimoController controller: NuimoController, error: NSError?)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDisconnectNuimoController controller: NuimoController, error: NSError?)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didInvalidateController controller: NuimoController)
}
