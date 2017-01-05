//
//  NuimoBuiltInLEDMatrix.swift
//  Pods
//
//  Created by Lars Blumberg on 10/17/16.
//
//

public class NuimoBuiltInLEDMatrix: NuimoLEDMatrix {
    public static let busy = NuimoBuiltInLEDMatrix(identifier: 1)

    private init(identifier: UInt8) {
        var leds = Array(repeating: false, count: 81)
        var n = identifier
        var i = 0
        while n > 0 {
            leds[i] = n % 2 > 0
            n = n / 2
            i += 1
        }
        super.init(leds: leds)
    }

    internal override func equals(_ other: NuimoLEDMatrix) -> Bool {
        guard let other = other as? NuimoBuiltInLEDMatrix else { return false }
        return super.equals(other)
    }
}
