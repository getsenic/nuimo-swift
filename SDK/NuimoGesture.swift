//
//  NuimoGesture.swift
//  Nuimo
//
//  Created by Lars Blumberg on 9/23/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

public enum NuimoGesture {
    case buttonPress
    case buttonRelease
    case rotate
    case touchLeft
    case touchRight
    case touchTop
    case touchBottom
    case longTouchLeft
    case longTouchRight
    case longTouchTop
    case longTouchBottom
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case flyLeft
    case flyRight
    case flyUpDown
    
    public init?(identifier: String) {
        guard let gesture = gestureForIdentifier[identifier] else { return nil }
        self = gesture
    }
    
    public var identifier: String { return identifierForGesture[self]! }
}

private let identifierForGesture: [NuimoGesture : String] = [
    .buttonPress        : "ButtonPress",
    .buttonRelease      : "ButtonRelease",
    .rotate             : "Rotate",
    .touchLeft          : "TouchLeft",
    .touchRight         : "TouchRight",
    .touchTop           : "TouchTop",
    .touchBottom        : "TouchBottom",
    .longTouchLeft      : "LongTouchLeft",
    .longTouchRight     : "LongTouchRight",
    .longTouchTop       : "LongTouchTop",
    .longTouchBottom    : "LongTouchBottom",
    .swipeLeft          : "SwipeLeft",
    .swipeRight         : "SwipeRight",
    .swipeUp            : "SwipeUp",
    .swipeDown          : "SwipeDown",
    .flyLeft            : "FlyLeft",
    .flyRight           : "FlyRight",
    .flyUpDown          : "FlyUpDown"
]

private let gestureForIdentifier: [String : NuimoGesture] = {
    var dictionary = [String : NuimoGesture]()
    for (gesture, identifier) in identifierForGesture {
        dictionary[identifier] = gesture
    }
    return dictionary
}()
