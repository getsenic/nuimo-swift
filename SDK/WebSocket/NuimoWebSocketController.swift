//
//  NuimoWebSocketController.swift
//  Nuimo
//
//  Created by Lars Blumberg on 10/9/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import SwiftWebSocket

// Represents a virtual (websocket) controller that connects to a web server. Good for testing when you haven't got an actual Nuimo hardware device at hand.
public class NuimoWebSocketController : NSObject, NuimoController {
    public let url: String
    public var delegate: NuimoControllerDelegate?
    public var uuid: String { get { return url } }
    
    public var state: NuimoConnectionState { return connectionStateForWebSocketReadyState[self.webSocket?.readyState ?? .Closed] ?? .Disconnected }
    public var batteryLevel: Int = -1 { didSet { if self.batteryLevel != oldValue { delegate?.nuimoController?(self, didUpdateBatteryLevel: self.batteryLevel) } } }
    
    private var webSocket: WebSocket?
    
    public init(url: String) {
        self.url = url
        super.init()
    }
    
    public func connect() {
        if webSocket?.readyState ?? .Closed != .Closed { return }
        webSocket = {
            let webSocket = WebSocket(url)
            webSocket.event.open = {
                self.delegate?.nuimoControllerDidConnect?(self)
            }
            webSocket.event.close = { _ in
                self.webSocket = nil
                self.delegate?.nuimoControllerDidDisconnect?(self)
            }
            webSocket.event.end = { _ in
                self.webSocket = nil
                self.delegate?.nuimoControllerDidDisconnect?(self)
            }
            webSocket.event.error = { error in
                //TODO: Figure out which error occurred and eventually call adeguate delegate methode
                self.delegate?.nuimoControllerDidFailToConnect?(self)
            }
            webSocket.event.message = { message in
                if let text = message as? String {
                    self.handleMessage(text) ? webSocket.send("OK") : webSocket.send("Invalid gesture event")
                }
            }
            return webSocket
        }()
    }
    
    public func disconnect() {
        self.webSocket?.close()
    }
    
    public func writeMatrix(matrix: NuimoLEDMatrix) {
        //TODO: Send matrix to websocket
    }
    
    private func handleMessage(message: String) -> Bool {
        let event = message.characters.split{$0 == ","}.map(String.init)
        guard let gesture = try? NuimoGesture(identifier: event[0]) else { return false }
        let eventValue = (event.count > 1 ? Int(event[1]) : nil) ?? 0
        delegate?.nuimoController?(self, didReceiveGestureEvent: NuimoGestureEvent(gesture: gesture, value: eventValue))
        return true
    }
}

private let connectionStateForWebSocketReadyState: [WebSocketReadyState : NuimoConnectionState] = [
    .Connecting: .Connecting,
    .Open: .Connected,
    .Closing: .Disconnecting,
    .Closed: .Disconnected
]
