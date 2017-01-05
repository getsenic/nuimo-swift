//
//  NuimoLEDMatrix.swift
//  Nuimo
//
//  Created by Lars Blumberg on 11/02/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

open class NuimoLEDMatrix {
    public static let ledCount = 81
    public static let ledOffCharacters: [Character] = [" ", "0"]

    public let leds: [Bool]

    public init(matrix: NuimoLEDMatrix) {
        leds = matrix.leds
    }

    public init(string: String) {
        leds = string
            // Cut off after count of LEDs
            .substring(to: string.characters.index(string.startIndex, offsetBy: min(string.characters.count, NuimoLEDMatrix.ledCount)))
            // Right fill up to count of LEDs
            .padding(toLength: NuimoLEDMatrix.ledCount, withPad: " ", startingAt: 0)
            .characters
            .map{!NuimoLEDMatrix.ledOffCharacters.contains($0)}
    }

    public init(leds: [Bool]) {
        self.leds = leds.prefix(81) + (leds.count < 81 ? Array(repeating: false, count: 81 - leds.count) : [])
    }

    //TODO: Have only one init(progress) method and pass presentation style as 2nd argument
    public convenience init(progressWithVerticalBar progress: Double) {
        let string = (0..<9)
            .reversed()
            .map{progress > Double($0) / 9.0 ? "    .    " : "         "}
            .reduce("", +)
        self.init(string: string)
    }

    public convenience init(progressWithVolumeBar progress: Double) {
        let width = Int(ceil(max(0.0, min(1.0, progress)) * 9))
        let string = (0..<9)
            .map{String(repeating: " ", count: 9 - ($0 + 1)) + String(repeating: ".", count: $0 + 1)}
            .enumerated()
            .map{$0.element
                .substring(to: $0.element.characters.index($0.element.startIndex, offsetBy: width))
                .padding(toLength: 9, withPad: " ", startingAt: 0)}
            .reduce("", +)
        self.init(string: string)
    }

    internal func equals(_ other: NuimoLEDMatrix) -> Bool {
        return leds == other.leds
    }
}

extension NuimoLEDMatrix: Equatable {}

public func ==(lhs: NuimoLEDMatrix, rhs: NuimoLEDMatrix) -> Bool {
    return lhs.equals(rhs)
}

//MARK: Predefined matrices

extension NuimoLEDMatrix {
    public static var emptyMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         ")}

    public static var musicNoteMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "  .....  " +
        "  .....  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        " ..  ..  " +
        "... ...  " +
        " .   .   ")}

    public static var lightBulbMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "   ...   " +
        "   ...   " +
        "    .    ")}

    public static var powerOnMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   ...   " +
        "  .....  " +
        "  .....  " +
        "  .....  " +
        "   ...   " +
        "         " +
        "         ")}

    public static var powerOffMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         " +
        "         ")}

    public static var shuffleMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        " ..   .. " +
        "   . .   " +
        "    .    " +
        "   . .   " +
        " ..   .. " +
        "         " +
        "         ")}

    public static var letterBMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "         ")}

    public static var letterOMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         ")}

    public static var letterGMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .      " +
        "  . ...  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         ")}

    public static var letterWMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .  .  . " +
        " .  .  . " +
        "  .. ..  " +
        "         ")}

    public static var letterYMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "  .   .  " +
        "  .   .  " +
        "   . .   " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "         ")}

    public static var playMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   .     " +
        "   ..    " +
        "   ...   " +
        "   ....  " +
        "   ...   " +
        "   ..    " +
        "   .     " +
        "         ")}

    public static var pauseMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "         ")}

    public static var nextMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   .  .  " +
        "   .. .  " +
        "   ....  " +
        "   .. .  " +
        "   .  .  " +
        "         " +
        "         ")}

    public static var previousMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "  .  .   " +
        "  . ..   " +
        "  ....   " +
        "  . ..   " +
        "  .  .   " +
        "         " +
        "         ")}

    public static var questionMarkMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "   ...   " +
        "  .   .  " +
        " .     . " +
        "      .  " +
        "     .   " +
        "    .    " +
        "    .    " +
        "         " +
        "    .    ")}

    public static var bluetoothMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "    *    " +
        "    **   " +
        "  * * *  " +
        "   ***   " +
        "    *    " +
        "   ***   " +
        "  * * *  " +
        "    **   " +
        "    *    ")}
        
    public static var upArrowMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "    .    " +
        "   ...   " +
        "  .....  " +
        " ....... " +
        "   ...   " +
        "   ...   " +
        "   ...   " +
        "   ...   " +
        "         ")}   
        
    public static var downArrowMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "   ...   " +
        "   ...   " +
        "   ...   " +
        "   ...   " +
        " ....... " +
        "  .....  " +
        "   ...   " +
        "    .    " +
        "         ")}   
                    
}
