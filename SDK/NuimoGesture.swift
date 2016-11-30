//
//  NuimoGesture.swift
//  Nuimo
//
//  Created by Lars Blumberg on 9/23/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

@objc public enum NuimoGesture : Int {
    case
    ButtonPress = 0,
    ButtonRelease,
    Rotate,
    TouchLeft,
    TouchRight,
    TouchTop,
    TouchBottom,
    SwipeLeft,
    SwipeRight,
    SwipeUp,
    SwipeDown,
    FlyLeft,
    FlyRight,
    FlyUpDown
    
    public init?(identifier: String) {
        guard let gesture = gestureForIdentifier[identifier] else { return nil }
        self = gesture
    }
    
    public var identifier: String { return identifierForGesture[self]! }
}

public enum NuimoGestureError: ErrorType {
    case InvalidIdentifier
}

private let identifierForGesture: [NuimoGesture : String] = [
    .ButtonPress        : "ButtonPress",
    .ButtonRelease      : "ButtonRelease",
    .Rotate             : "Rotate",
    .TouchLeft          : "TouchLeft",
    .TouchRight         : "TouchRight",
    .TouchTop           : "TouchTop",
    .TouchBottom        : "TouchBottom",
    .SwipeLeft          : "SwipeLeft",
    .SwipeRight         : "SwipeRight",
    .SwipeUp            : "SwipeUp",
    .SwipeDown          : "SwipeDown",
    .FlyLeft            : "FlyLeft",
    .FlyRight           : "FlyRight",
    .FlyUpDown          : "FlyUpDown"
]

private let gestureForIdentifier: [String : NuimoGesture] = {
    var dictionary = [String : NuimoGesture]()
    for (gesture, identifier) in identifierForGesture {
        dictionary[identifier] = gesture
    }
    return dictionary
}()
