//
//  NuimoGestureEvent+BLEGattDataInitialization.swift
//  Nuimo
//
//  Created by Lars Blumberg on 10/15/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

internal extension NuimoGestureEvent {
    convenience init(gattFlyData data: NSData) {
        //TODO: Evaluate fly events
        self.init(gesture: .Undefined, value: nil)
    }
    
    convenience init(gattTouchData data: NSData) {
        let bytes = UnsafePointer<Int16>(data.bytes)
        let buttonByte = bytes.memory
        let eventByte = bytes.advancedBy(1).memory
        for i: Int16 in 0...7 where (1 << i) & buttonByte != 0 {
            let touchDownGesture: NuimoGesture = [.TouchLeftDown, .TouchTopDown, .TouchRightDown, .TouchBottomDown][Int(i / 2)]
            if let eventGesture: NuimoGesture = {
                    switch eventByte {
                    case 1:  return touchDownGesture.self
                    case 2:  return touchDownGesture.touchUpGesture
                    case 3:  return nil //TODO: Do we need to handle double touch gestures here as well?
                    case 4:  return touchDownGesture.swipeGesture
                    default: return nil}}() {
                self.init(gesture: eventGesture, value: Int(i))
                return
            }
        }
        self.init(gesture: .Undefined, value: nil)
    }
    
    convenience init(gattRotationData data: NSData) {
        let value = Int(UnsafePointer<Int16>(data.bytes).memory)
        self.init(gesture: value < 0 ? .RotateLeft : .RotateRight, value: value)
    }
    
    convenience init(gattButtonData data: NSData) {
        let value = Int(UnsafePointer<UInt8>(data.bytes).memory)
        //TODO: Evaluate double press events
        self.init(gesture: value == 1 ? .ButtonPress : .ButtonRelease, value: value)
    }
}
