//
//  NuimoDiscoveryManager.swift
//  Nuimo
//
//  Created by Lars Blumberg on 9/23/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import UIKit
import CoreBluetooth

private let NuimoControllerName = "Nuimo"

// Allows for discovering Nuimo BLE hardware controllers and virtual (websocket) controllers
public class NuimoDiscoveryManager: NSObject, CBCentralManagerDelegate {
    
    public static let sharedManager = NuimoDiscoveryManager()
    
    public var delegate: NuimoDiscoveryDelegate?
    public var centralManager: CBCentralManager? { didSet { oldValue?.delegate = nil; centralManager?.delegate = self } }
    public var detectUnreachableControllers: Bool = false
    
    private var isDiscovering = false
    // List of discovered nuimo peripherals
    private var controllerForPeripheral = [CBPeripheral : NuimoBluetoothController]()
    private lazy var unreachableDevicesDetector: UnreachableDevicesDetector = UnreachableDevicesDetector(discoveryManager: self)
    
    public convenience init(centralManager: CBCentralManager) {
        self.init()
        self.centralManager = centralManager
    }
    
    public func discoverControllers() {
        // Discover websocket controllers
        #if (arch(i386) || arch(x86_64)) && os(iOS) // Simulator
            let controller = NuimoWebSocketController(url: "ws://localhost:9999")
            delegate?.nuimoDiscoveryManager(self, didDiscoverNuimoController: controller)
        #else
            //TODO: Read possible URLs addresses from a property
            //let websocketAddress = "ws://192.168.1.112:9999"
        #endif
        
        // Discover bluetooth controllers
        guard let centralManager = self.centralManager where centralManager.state == .PoweredOn else {
            return
        }
        isDiscovering = true
        
        centralManager.scanForPeripheralsWithServices(nuimoServiceUUIDs, options: nil)
        
        unreachableDevicesDetector.stop()
        if detectUnreachableControllers {
            // Periodically check for unreachable nuimo devices
            unreachableDevicesDetector.start()
        }
    }
    
    public func stopDiscovery() {
        unreachableDevicesDetector.stop()
        centralManager?.stopScan()
        isDiscovering = false
    }
    
    private func invalidateController(controller: NuimoBluetoothController) {
        controller.invalidate()
        delegate?.nuimoDiscoveryManager?(self, didInvalidateController: controller)
        // Remove all peripherals associated with controller (there should be only one)
        controllerForPeripheral.filter{ $0.1 == controller }.forEach {
            controllerForPeripheral.removeValueForKey($0.0)
        }
    }
    
    //MARK: - CBCentralManagerDelegate
    
    public func centralManager(central: CBCentralManager, willRestoreState state: [String : AnyObject]) {
        if let peripherals = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                centralManager(central, didDiscoverPeripheral: peripheral, advertisementData: [CBAdvertisementDataLocalNameKey: NuimoControllerName], RSSI: 0)
            }
        }
    }
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        // If bluetooth turned on and discovery start had already been triggered before, start discovery now
        if central.state == .PoweredOn && isDiscovering {
            discoverControllers()
        }
        
        // Invalidate all connections when state moves below .PoweredOff as they are then invalid
        if central.state.rawValue < CBCentralManagerState.PoweredOff.rawValue {
            controllerForPeripheral.values.forEach(invalidateController)
        }
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        //TODO: There's no need to check for the device's name as we only discover controllers with our set of services
        if advertisementData[CBAdvertisementDataLocalNameKey] as? String != NuimoControllerName {
            return
        }
        let controller = NuimoBluetoothController(centralManager: central, uuid: peripheral.identifier.UUIDString, peripheral: peripheral)
        controllerForPeripheral[peripheral] = controller
        unreachableDevicesDetector.didFindController(controller)
        delegate?.nuimoDiscoveryManager(self, didDiscoverNuimoController: controller)
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        guard let controller = self.controllerForPeripheral[peripheral] else {
            assertionFailure("Peripheral not registered")
            return
        }
        controller.didConnect()
        delegate?.nuimoDiscoveryManager?(self, didConnectNuimoController: controller)
    }
    
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard let controller = self.controllerForPeripheral[peripheral] else {
            assertionFailure("Peripheral not registered")
            return
        }
        controller.didFailToConnect()
        delegate?.nuimoDiscoveryManager?(self, didFailToConnectNuimoController: controller, error: error)
    }
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard let controller = self.controllerForPeripheral[peripheral] else {
            assertionFailure("Peripheral not registered")
            return
        }
        controller.didDisconnect()
        delegate?.nuimoDiscoveryManager?(self, didDisconnectNuimoController: controller, error: error)
        if error != nil {
            // Controller probably went offline
            invalidateController(controller)
        }
    }
}

@objc public protocol NuimoDiscoveryDelegate {
    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didConnectNuimoController controller: NuimoController)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didFailToConnectNuimoController controller: NuimoController, error: NSError?)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDisconnectNuimoController controller: NuimoController, error: NSError?)
    optional func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didInvalidateController controller: NuimoController)
}

private class UnreachableDevicesDetector {
    // Minimum interval to wait before a device is considered to be unreachable
    private let minUnreachableDevicesDetectionInterval: NSTimeInterval = 5.0
    
    private let discoveryManager: NuimoDiscoveryManager
    private var lastUnreachableDevicesRemovedTimestamp: NSDate?
    private var unreachableDevicesDetectionTimer: NSTimer?
    // List of unconnected nuimos discovered during the current discovery session
    private var currentlyDiscoveredControllers = Set<NuimoBluetoothController>()
    // List of unconnected nuimos discovered during the previous discovery session
    private var previouslyDiscoveredControllers = Set<NuimoBluetoothController>()
    
    init(discoveryManager: NuimoDiscoveryManager) {
        self.discoveryManager = discoveryManager
    }
    
    func start() {
        lastUnreachableDevicesRemovedTimestamp = NSDate()
        previouslyDiscoveredControllers = Set()
        currentlyDiscoveredControllers = Set()
        unreachableDevicesDetectionTimer?.invalidate()
        unreachableDevicesDetectionTimer = NSTimer.scheduledTimerWithTimeInterval(minUnreachableDevicesDetectionInterval + 0.5, target: self, selector: "removeUnreachableDevices", userInfo: nil, repeats: true)
    }
    
    func stop() {
        unreachableDevicesDetectionTimer?.invalidate()
    }
    
    @objc func removeUnreachableDevices() {
        // Remove unreachable devices if the discovery session was running at least for some time
        guard let lastTimestamp = lastUnreachableDevicesRemovedTimestamp where NSDate().timeIntervalSinceDate(lastTimestamp) >= minUnreachableDevicesDetectionInterval else {
            return
        }
        lastUnreachableDevicesRemovedTimestamp = NSDate()
        
        // All nuimo devices found during the *previous* discovery session and not found during the currently running discovery session will assumed to be now unreachable
        previouslyDiscoveredControllers.filter { (previouslyDiscoveredController: NuimoBluetoothController) -> Bool in
            return (previouslyDiscoveredController.state == .Disconnected) &&
                (currentlyDiscoveredControllers.filter{$0.uuid == previouslyDiscoveredController.uuid}).count == 0
        }.forEach(discoveryManager.invalidateController)
        
        // Rescan peripherals
        previouslyDiscoveredControllers = currentlyDiscoveredControllers
        currentlyDiscoveredControllers = Set()
        discoveryManager.centralManager?.scanForPeripheralsWithServices(nuimoServiceUUIDs, options: nil)
    }
    
    func didFindController(controller: NuimoBluetoothController) {
        currentlyDiscoveredControllers.insert(controller)
    }
}
