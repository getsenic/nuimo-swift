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
    Undefined = 0, // TODO: Do we really need this enum value? We don't need to handle an "undefined" gesture
    ButtonPress,
    ButtonDoublePress,
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
    FlyBackwards,
    FlyTowards,
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
    .Undefined          : "Undefined",
    .ButtonPress        : "ButtonPress",
    .ButtonRelease      : "ButtonRelease",
    .ButtonDoublePress  : "ButtonDoublePress",
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
    .FlyBackwards       : "FlyBackwards",
    .FlyTowards         : "FlyTowards",
    .FlyUpDown          : "FlyUpDown"
]

private let gestureForIdentifier: [String : NuimoGesture] = {
    var dictionary = [String : NuimoGesture]()
    for (gesture, identifier) in identifierForGesture {
        dictionary[identifier] = gesture
    }
    return dictionary
}()
