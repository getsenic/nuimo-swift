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
        var leds = Array(count: 81, repeatedValue: false)
        var n = identifier
        var i = 0
        while n > 0 {
            leds[i] = n % 2 > 0
            n = n / 2
            i += 1
        }
        super.init(leds: leds)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        guard let object = object as? NuimoBuiltInLEDMatrix else { return false }
        return super.isEqual(object)
    }
}
