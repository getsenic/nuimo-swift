//
//  NuimoController.swift
//  Nuimo
//
//  Created by Lars Blumberg on 10/9/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

@objc public protocol NuimoController {
    var uuid: String {get}
    var delegate: NuimoControllerDelegate? {get set}
    
    var state: NuimoConnectionState {get}
    var batteryLevel: Int {get set}
    
    func connect()
    
    func disconnect()
    
    func writeMatrix(name: String)
    
    func writeBarMatrix(percent: Int)
}

@objc public enum NuimoConnectionState: Int {
    case
    Connecting,
    Connected,
    Disconnecting,
    Disconnected
}

@objc public protocol NuimoControllerDelegate {
    optional func nuimoControllerDidStartConnecting(controller: NuimoController)
    optional func nuimoControllerDidConnect(controller: NuimoController)
    optional func nuimoControllerDidFailToConnect(controller: NuimoController)
    optional func nuimoControllerDidDisconnect(controller: NuimoController)
    optional func nuimoControllerDidInvalidate(controller: NuimoController)
    optional func nuimoControllerDidDiscoverMatrixService(controller: NuimoController)
    optional func nuimoController(controller: NuimoController, didUpdateBatteryLevel bateryLevel: Int)
    optional func nuimoController(controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent)
}
