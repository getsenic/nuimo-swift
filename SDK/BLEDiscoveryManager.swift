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
    public private(set) lazy var centralManager: CBCentralManager = self.discovery!.centralManager!

    private var discovery: BLEDiscoveryManagerPrivate? = nil

    public init(options: [String : AnyObject] = [:]) {
        super.init()
        self.discovery = BLEDiscoveryManagerPrivate(discovery: self, options: options)
    }

    public func startDiscovery(discoverServiceUUIDs: [CBUUID], detectUnreachableControllers: Bool) {
        discovery!.startDiscovery(discoverServiceUUIDs, detectUnreachableControllers: detectUnreachableControllers)
    }

    public func stopDiscovery() {
        discovery!.stopDiscovery()
    }

    // MARK: Methods to be overridden by subclass

    public func deviceWithPeripheral(peripheral: CBPeripheral) -> BLEDevice? {
        return nil
    }

    public func didInvalidateDevice(device: BLEDevice) {
    }

    public func didDiscoverDevice(device: BLEDevice) {
    }

    public func didConnectDevice(device: BLEDevice) {
    }

    public func didFailToConnectDevice(device: BLEDevice, error: NSError?) {
    }

    public func didDisconnectDevice(device: BLEDevice, error: NSError?) {
    }
}

/**
    Private implementation of BLEDiscoveryManager.
    Hides implementation of CBCentralManagerDelegate.
*/
private class BLEDiscoveryManagerPrivate: NSObject, CBCentralManagerDelegate {
    let discovery: BLEDiscoveryManager
    var centralManager: CBCentralManager? = nil
    var discoverServiceUUIDs = [CBUUID]()
    var shouldStartDiscoveryWhenPowerStateTurnsOn = false
    var deviceForPeripheral = [CBPeripheral : BLEDevice]()
    var detectUnreachableControllers = false
    lazy var unreachableDevicesDetector: UnreachableDevicesDetector = UnreachableDevicesDetector(discovery: self)

    init(discovery: BLEDiscoveryManager, options: [String : AnyObject]) {
        self.discovery = discovery
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }

    func startDiscovery(discoverServiceUUIDs: [CBUUID], detectUnreachableControllers: Bool) {
        self.discoverServiceUUIDs = discoverServiceUUIDs
        self.detectUnreachableControllers = detectUnreachableControllers
        self.shouldStartDiscoveryWhenPowerStateTurnsOn = true

        guard centralManager?.state == .PoweredOn else { return }
        centralManager?.scanForPeripheralsWithServices(discoverServiceUUIDs, options: nil)

        unreachableDevicesDetector.stop()
        if detectUnreachableControllers {
            // Periodically check for unreachable nuimo devices
            unreachableDevicesDetector.start()
        }
    }

    func restartDiscovery() {
        centralManager!.scanForPeripheralsWithServices(discoverServiceUUIDs, options: nil)
    }

    func stopDiscovery() {
        unreachableDevicesDetector.stop()
        centralManager?.stopScan()
        shouldStartDiscoveryWhenPowerStateTurnsOn = false
    }

    private func invalidateDevice(device: BLEDevice) {
        device.invalidate()
        // Remove all peripherals associated with controller (there should be only one)
        deviceForPeripheral.filter{ $0.1 == device }.forEach {
            deviceForPeripheral.removeValueForKey($0.0)
        }
    }

    @objc func centralManager(central: CBCentralManager, willRestoreState state: [String : AnyObject]) {
        //TODO: Should work on OSX as well. http://stackoverflow.com/q/33210078/543875
        #if os(iOS)
            if let peripherals = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
                for peripheral in peripherals {
                    centralManager(central, didDiscoverPeripheral: peripheral, advertisementData: [:], RSSI: 0)
                }
            }
        #endif
    }

    @objc func centralManagerDidUpdateState(central: CBCentralManager) {
        // If bluetooth turned on and discovery start had already been triggered before, start discovery now
        if central.state == .PoweredOn && shouldStartDiscoveryWhenPowerStateTurnsOn {
            discovery.startDiscovery(discoverServiceUUIDs, detectUnreachableControllers: detectUnreachableControllers)
        }

        // Invalidate all connections when state moves below .PoweredOff as they are then invalid
        if central.state.rawValue < CBCentralManagerState.PoweredOff.rawValue {
            deviceForPeripheral.values.forEach(invalidateDevice)
        }
    }

    @objc func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        guard let device = discovery.deviceWithPeripheral(peripheral) else { return }
        deviceForPeripheral[peripheral] = device
        unreachableDevicesDetector.didFindDevice(device)
        discovery.didDiscoverDevice(device)
    }

    @objc func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        guard let device = self.deviceForPeripheral[peripheral] else {
            assertionFailure("Peripheral not registered")
            return
        }
        device.didConnect()
        discovery.didConnectDevice(device)
    }

    @objc func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard let device = self.deviceForPeripheral[peripheral] else {
            assertionFailure("Peripheral not registered")
            return
        }
        device.didFailToConnect()
    }

    @objc func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard let device = self.deviceForPeripheral[peripheral] else {
            assertionFailure("Peripheral not registered")
            return
        }
        device.didDisconnect()
        if error != nil {
            // Device probably went offline
            invalidateDevice(device)
        }
        discovery.didDisconnectDevice(device, error: error)
    }
}

private class UnreachableDevicesDetector {
    // Minimum interval to wait before a device is considered to be unreachable
    private let minDetectionInterval: NSTimeInterval = 5.0

    private let discovery: BLEDiscoveryManagerPrivate
    private var lastUnreachableDevicesRemovedTimestamp: NSDate?
    private var unreachableDevicesDetectionTimer: NSTimer?
    // List of unconnected devices discovered during the current discovery session
    private var currentlyDiscoveredDevices = Set<BLEDevice>()
    // List of unconnected devices discovered during the previous discovery session
    private var previouslyDiscoveredDevices = Set<BLEDevice>()

    init(discovery: BLEDiscoveryManagerPrivate) {
        self.discovery = discovery
    }

    func start() {
        lastUnreachableDevicesRemovedTimestamp = NSDate()
        previouslyDiscoveredDevices = Set()
        currentlyDiscoveredDevices = Set()
        unreachableDevicesDetectionTimer?.invalidate()
        unreachableDevicesDetectionTimer = NSTimer.scheduledTimerWithTimeInterval(minDetectionInterval + 0.5, target: self, selector: "removeUnreachableDevices", userInfo: nil, repeats: true)
    }

    func stop() {
        unreachableDevicesDetectionTimer?.invalidate()
    }

    @objc func removeUnreachableDevices() {
        // Remove unreachable devices if the discovery session was running at least for some time
        guard let lastTimestamp = lastUnreachableDevicesRemovedTimestamp where NSDate().timeIntervalSinceDate(lastTimestamp) >= minDetectionInterval else {
            return
        }
        lastUnreachableDevicesRemovedTimestamp = NSDate()

        // All bluetooth devices found during the *previous* discovery session and not found during the currently running discovery session will assumed to be now unreachable
        previouslyDiscoveredDevices.filter { previouslyDiscoveredController -> Bool in
            return (previouslyDiscoveredController.peripheral.state == .Disconnected) &&
                (currentlyDiscoveredDevices.filter{$0.uuid == previouslyDiscoveredController.uuid}).count == 0
            }.forEach(discovery.invalidateDevice)

        // Rescan peripherals
        previouslyDiscoveredDevices = currentlyDiscoveredDevices
        currentlyDiscoveredDevices = Set()
        discovery.restartDiscovery()
    }

    func didFindDevice(device: BLEDevice) {
        currentlyDiscoveredDevices.insert(device)
    }
}
