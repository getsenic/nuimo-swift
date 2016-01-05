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
    RotateLeft,
    RotateRight,
    TouchLeftDown,
    TouchLeftRelease,
    TouchRightDown,
    TouchRightRelease,
    TouchTopDown,
    TouchTopRelease,
    TouchBottomDown,
    TouchBottomRelease,
    SwipeLeft,
    SwipeRight,
    SwipeUp,
    SwipeDown,
    FlyLeft,
    FlyRight,
    FlyBackwards,
    FlyTowards,
    FlyUp,
    FlyDown
    
    public init(identifier: String) throws {
        guard let gesture = gestureForIdentifier[identifier] else { throw NuimoGestureError.InvalidIdentifier }
        self = gesture
    }
    
    public var identifier: String { return identifierForGesture[self]! }
    
    // Returns the corresponding touch down gesture if self is a touch gesture, nil if not
    public var touchDownGesture: NuimoGesture? { return touchDownGestureForTouchGesture[self] }
    
    // Returns the corresponding touch up gesture if self is a touch gesture, nil if not
    public var touchReleaseGesture: NuimoGesture? { return touchReleaseGestureForTouchGesture[self] }
    
    // Returns the corresponding swipe gesture if self is a touch gesture, nil if not
    public var swipeGesture: NuimoGesture? { return swipeGestureForTouchGesture[self] }
}

public enum NuimoGestureError: ErrorType {
    case InvalidIdentifier
}

private let identifierForGesture: [NuimoGesture : String] = [
    .Undefined          : "Undefined",
    .ButtonPress        : "ButtonPress",
    .ButtonRelease      : "ButtonRelease",
    .ButtonDoublePress  : "ButtonDoublePress",
    .RotateLeft         : "RotateLeft",
    .RotateRight        : "RotateRight",
    .TouchLeftDown      : "TouchLeftDown",
    .TouchLeftRelease   : "TouchLeftRelease",
    .TouchRightDown     : "TouchRightDown",
    .TouchRightRelease  : "TouchRightRelease",
    .TouchTopDown       : "TouchTopDown",
    .TouchTopRelease    : "TouchTopRelease",
    .TouchBottomDown    : "TouchBottomDown",
    .TouchBottomRelease : "TouchBottomRelease",
    .SwipeLeft          : "SwipeLeft",
    .SwipeRight         : "SwipeRight",
    .SwipeUp            : "SwipeUp",
    .SwipeDown          : "SwipeDown",
    .FlyLeft            : "FlyLeft",
    .FlyRight           : "FlyRight",
    .FlyBackwards       : "FlyBackwards",
    .FlyTowards         : "FlyTowards",
    .FlyUp              : "FlyUp",
    .FlyDown            : "FlyDown"
]

private let gestureForIdentifier: [String : NuimoGesture] = {
    var dictionary = [String : NuimoGesture]()
    for (gesture, identifier) in identifierForGesture {
        dictionary[identifier] = gesture
    }
    return dictionary
}()

private let touchDownGestureForTouchGesture: [NuimoGesture : NuimoGesture] = [
    .TouchLeftDown      : .TouchLeftDown,
    .TouchLeftRelease   : .TouchLeftDown,
    .TouchRightDown     : .TouchRightDown,
    .TouchRightRelease  : .TouchRightDown,
    .TouchTopDown       : .TouchTopDown,
    .TouchTopRelease    : .TouchTopDown,
    .TouchBottomDown    : .TouchBottomDown,
    .TouchBottomRelease : .TouchBottomDown,
    .SwipeLeft          : .TouchLeftDown,
    .SwipeRight         : .TouchRightDown,
    .SwipeUp            : .TouchTopDown,
    .SwipeDown          : .TouchBottomDown,
]

private let touchReleaseGestureForTouchGesture: [NuimoGesture : NuimoGesture] = [
    .TouchLeftDown      : .TouchLeftRelease,
    .TouchLeftRelease   : .TouchLeftRelease,
    .TouchRightDown     : .TouchRightRelease,
    .TouchRightRelease  : .TouchRightRelease,
    .TouchTopDown       : .TouchTopRelease,
    .TouchTopRelease    : .TouchTopRelease,
    .TouchBottomDown    : .TouchBottomRelease,
    .TouchBottomRelease : .TouchBottomRelease,
    .SwipeLeft          : .TouchLeftRelease,
    .SwipeRight         : .TouchRightRelease,
    .SwipeUp            : .TouchTopRelease,
    .SwipeDown          : .TouchBottomRelease,
]

private let swipeGestureForTouchGesture: [NuimoGesture : NuimoGesture] = [
    .TouchLeftDown      : .SwipeLeft,
    .TouchLeftRelease   : .SwipeLeft,
    .TouchRightDown     : .SwipeRight,
    .TouchRightRelease  : .SwipeRight,
    .TouchTopDown       : .SwipeUp,
    .TouchTopRelease    : .SwipeUp,
    .TouchBottomDown    : .SwipeDown,
    .TouchBottomRelease : .SwipeDown,
    .SwipeLeft          : .SwipeLeft,
    .SwipeRight         : .SwipeRight,
    .SwipeUp            : .SwipeUp,
    .SwipeDown          : .SwipeDown,
]
