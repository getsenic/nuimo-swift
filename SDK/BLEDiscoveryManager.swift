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
    public var centralManager: CBCentralManager! {
        guard let centralManager = _centralManager else {
            print("BLEDiscoveryManager.centralManager is accessed while it is not yet set. This happens when CBCentralManager() calls a delegate function while still instantiating BLEDiscoveryManager. If BLEDiscoveryManager.centralManager is accessed without checking for `nil` the program will consequently crash.")
            return nil
        }
        return centralManager
    }

    internal let queue: DispatchQueue

    fileprivate var didRestoreState =       false
    fileprivate var knownPeripheralUUIDs:   [UUID]
    fileprivate var deviceForUUID:          [UUID : BLEDevice] = [:]
    fileprivate var alreadyDiscoveredUUIDs: Set<UUID> = []
    fileprivate var serviceUUIDs:           [CBUUID] = []
    fileprivate var updateReachability =    false
    fileprivate var shouldDiscover =        false

    private var _centralManager: CBCentralManager?

    public init(delegate: BLEDiscoveryManagerDelegate? = nil, queue: DispatchQueue? = nil, restoreIdentifier: String? = nil, knownPeripheralUUIDs: [UUID] = []) {
        self.delegate = delegate
        self.queue = queue ?? DispatchQueue.main
        self.knownPeripheralUUIDs = knownPeripheralUUIDs
        super.init()

        var centralManagerOptions: [String : Any] = [:]
        if let restoreIdentifier = restoreIdentifier {
            #if os(iOS) || os(tvOS)
            centralManagerOptions[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
            #endif
        }
        self._centralManager = CBCentralManager(delegate: self, queue: self.queue, options: centralManagerOptions)
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

    internal func deviceDidStopAdvertising(_ device: BLEDevice) {
        alreadyDiscoveredUUIDs.remove(device.uuid)
        delegate?.bleDiscoveryManager(self, didStopAdvertising: device)
    }
}

extension BLEDiscoveryManager: CBCentralManagerDelegate {
    public func centralManager(_ central: CBCentralManager, willRestoreState state: [String : Any]) {
        didRestoreState = true

        NuimoSwift.DDLogDebug("BLEDiscoveryManager willRestoreState with state \(central.state.rawValue) on queue \(DispatchQueue.currentQueueLabel)")
        guard let centralManager = centralManager else {
            queue.async { self.centralManager(central, willRestoreState: state) }
            return
        }

        var restorablePeripherals: [CBPeripheral] = []

        #if os(iOS) || os(tvOS)
        restorablePeripherals += state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        #endif

        restorablePeripherals += centralManager.retrievePeripherals(withIdentifiers: knownPeripheralUUIDs).filter { peripheral in
            !restorablePeripherals.contains(where: { $0.identifier == peripheral.identifier })
        }

        restorablePeripherals
            .flatMap { delegate?.bleDiscoveryManager(self, deviceFor: $0, advertisementData: [:]) }
            .forEach {
                deviceForUUID[$0.uuid] = $0
                delegate?.bleDiscoveryManager(self, didRestore: $0)
            }

        restorablePeripherals.forEach {
            NuimoSwift.DDLogDebug("Restored/retrieved \($0.identifier.uuidString) with state \($0.state.rawValue)")
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NuimoSwift.DDLogDebug("BLEDiscoveryManager didUpdateState: \(central.state.rawValue)")
        guard let centralManager = centralManager else {
            queue.async { self.centralManagerDidUpdateState(central) }
            return
        }

        if centralManager.state.rawValue >= CBCentralManagerState.poweredOff.rawValue {
            if !didRestoreState {
                self.centralManager(central, willRestoreState: [:])
            }

            // Update all devices with a freshly retrieved peripheral from central manager for those which have an invalidated peripheral
            centralManager.retrievePeripherals(withIdentifiers: Array(deviceForUUID.keys)).forEach {
                guard let device = self.deviceForUUID[$0.identifier], device.peripheral == nil else { return }
                device.restore(from: $0)
                NuimoSwift.DDLogDebug("Restored/retrieved \($0.identifier.uuidString) with state \($0.state.rawValue)")
                self.delegate?.bleDiscoveryManager(self, didRestore: device)
            }
        }

        deviceForUUID.values.forEach { $0.centralManagerDidUpdateState() }

        if central.state == .poweredOn && shouldDiscover {
            continueDiscovery()
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let device = deviceForUUID[peripheral.identifier]

        if !alreadyDiscoveredUUIDs.contains(peripheral.identifier) {
            alreadyDiscoveredUUIDs.insert(peripheral.identifier)

            if let device = device ?? delegate?.bleDiscoveryManager(self, deviceFor: peripheral, advertisementData: advertisementData) {
                deviceForUUID[peripheral.identifier] = device
                delegate?.bleDiscoveryManager(self, didDiscover: device)
            }
        }

        device?.didAdvertise(advertisementData, RSSI: RSSI, willReceiveSuccessiveAdvertisingData: updateReachability)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        deviceForUUID[peripheral.identifier]?.didConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        alreadyDiscoveredUUIDs.remove(peripheral.identifier)
        deviceForUUID[peripheral.identifier]?.didFailToConnect(error: error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        alreadyDiscoveredUUIDs.remove(peripheral.identifier)
        deviceForUUID[peripheral.identifier]?.didDisconnect(error: error)
    }
}

public protocol BLEDiscoveryManagerDelegate: class {
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, deviceFor peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEDevice?
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscover device: BLEDevice)
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestore device: BLEDevice)
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didStopAdvertising device: BLEDevice)
}

internal extension DispatchQueue {
    static var currentQueueLabel: String { return String(cString: __dispatch_queue_get_label(nil), encoding: .utf8)! }

    func assertIsDispatching() {
        if DispatchQueue.currentQueueLabel != label {
            NuimoSwift.DDLogError("Dispatching should take place on queue '\(label)' but is taking place on queue '\(DispatchQueue.currentQueueLabel)'")
            Thread.callStackSymbols.forEach{ NuimoSwift.DDLogError($0) }
        }
    }
}
