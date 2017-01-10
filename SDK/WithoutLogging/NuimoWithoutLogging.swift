//
//  NuimoWithoutLogging.swift
//  Nuimo
//
//  Created by Lars Blumberg on 01/10/17.
//  Copyright © 2017 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

@inline(__always) internal func DDLogDebug(_ message: String) { }
@inline(__always) internal func DDLogError(_ message: String) { print(message) }
