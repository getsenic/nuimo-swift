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
    public let bits: [Bit]
    
    public init(matrix: NuimoLEDMatrix) {
        bits = matrix.bits
    }
    
    public init(string: String) {
        bits = string
            // Cut off after count of LEDs
            .substringToIndex(string.startIndex.advancedBy(min(string.characters.count, NuimoLEDMatrixLEDCount)))
            // Right fill up to count of LEDs
            .stringByPaddingToLength(NuimoLEDMatrixLEDCount, withString: " ", startingAtIndex: 0)
            .characters
            .map{NuimoLEDMatrixLEDOffCharacters.contains($0) ? Bit.Zero : Bit.One}
    }
    
    public convenience init(progressWithVerticalBar progress: Double) {
        let string = (0..<9)
            .reverse()
            .map{progress > Double($0) / 9.0 ? "   ...   " : "         "}
            .reduce(""){(s: String, row: String) in s + row}
        self.init(string: string)
    }
    
}

public func ==(left: NuimoLEDMatrix, right: NuimoLEDMatrix) -> Bool {
    return left.bits == right.bits
}

public func !=(left: NuimoLEDMatrix, right: NuimoLEDMatrix) -> Bool {
    return !(left == right)
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
}

