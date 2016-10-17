//
//  NuimoLEDMatrix.swift
//  Nuimo
//
//  Created by Lars Blumberg on 11/02/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

public let NuimoLEDMatrixLEDCount = 81
public let NuimoLEDMatrixLEDOffCharacters: [Character] = [" ", "0"]
public let NuimoLEDMatrixDefaultLEDOffCharacter = NuimoLEDMatrixLEDOffCharacters[0]
public let NuimoLEDMatrixDefaultLEDOnCharacter: Character = "."

public class NuimoLEDMatrix: NSObject {
    public let leds: [Bool]

    public init(matrix: NuimoLEDMatrix) {
        leds = matrix.leds
    }

    public init(string: String) {
        leds = string
            // Cut off after count of LEDs
            .substringToIndex(string.startIndex.advancedBy(min(string.characters.count, NuimoLEDMatrixLEDCount)))
            // Right fill up to count of LEDs
            .stringByPaddingToLength(NuimoLEDMatrixLEDCount, withString: " ", startingAtIndex: 0)
            .characters
            .map{!NuimoLEDMatrixLEDOffCharacters.contains($0)}
    }

    public init(leds: [Bool]) {
        self.leds = leds.prefix(81) + (leds.count < 81 ? Array(count: 81 - leds.count, repeatedValue: false) : [])
    }

    //TODO: Have only one init(progress) method and pass presentation style as 2nd argument
    public convenience init(progressWithVerticalBar progress: Double) {
        let string = (0..<9)
            .reverse()
            .map{progress > Double($0) / 9.0 ? "    .    " : "         "}
            .reduce("", combine: +)
        self.init(string: string)
    }

    public convenience init(progressWithVolumeBar progress: Double) {
        let width = Int(ceil(max(0.0, min(1.0, progress)) * 9))
        let string = (0..<9)
            .map{String(count: 9 - ($0 + 1), repeatedValue: Character(" ")) + String(count: $0 + 1, repeatedValue: Character("."))}
            .enumerate()
            .map{$0.element
                .substringToIndex($0.element.startIndex.advancedBy(width))
                .stringByPaddingToLength(9, withString: " ", startingAtIndex: 0)}
            .reduce("", combine: +)
        self.init(string: string)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        guard let object = object as? NuimoLEDMatrix else { return false }
        return leds == object.leds
    }
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

