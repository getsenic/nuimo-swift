//
//  NuimoSwift.swift
//  Nuimo
//
//  Created by Lars Blumberg on 01/10/17.
//  Copyright © 2017 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

public struct NuimoSwift {
    public static var DDLogDebug: (_ message: String) -> Void = { message in }
    public static var DDLogError: (_ message: String) -> Void = { message in print(message) }
}
