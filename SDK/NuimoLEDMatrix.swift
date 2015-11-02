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
    public let string: String
    
    public init(string: String) {
        self.string = String(string
            .substringToIndex(string.startIndex.advancedBy(min(string.characters.count, NuimoLEDMatrixLEDCount))) // Cut off after count of LEDs
            .stringByPaddingToLength(NuimoLEDMatrixLEDCount, withString: " ", startingAtIndex: 0)                 // Right fill up to count of LEDs
            .characters
            .map{NuimoLEDMatrixLEDOffCharacters.contains($0)
                    ? NuimoLEDMatrixDefaultLEDOffCharacter
                    : NuimoLEDMatrixDefaultLEDOnCharacter})
    }
    
    public init(progressWithVerticalBar: Double) {
        //TODO: Compute string for matrix
        switch progressWithVerticalBar {
        case -Double.infinity..<(1.0/9.0): self.string = NuimoLEDMatrix.verticalBar1Matrix.string
        case 1.0/9.0..<2.0/9.0:            self.string = NuimoLEDMatrix.verticalBar2Matrix.string
        case 2.0/9.0..<3.0/9.0:            self.string = NuimoLEDMatrix.verticalBar3Matrix.string
        case 3.0/9.0..<4.0/9.0:            self.string = NuimoLEDMatrix.verticalBar4Matrix.string
        case 4.0/9.0..<5.0/9.0:            self.string = NuimoLEDMatrix.verticalBar5Matrix.string
        case 5.0/9.0..<6.0/9.0:            self.string = NuimoLEDMatrix.verticalBar6Matrix.string
        case 6.0/9.0..<7.0/9.0:            self.string = NuimoLEDMatrix.verticalBar7Matrix.string
        case 7.0/9.0..<8.0/9.0:            self.string = NuimoLEDMatrix.verticalBar8Matrix.string
        case 8.0/9.0...Double.infinity:    self.string = NuimoLEDMatrix.verticalBar9Matrix.string
        default:                           self.string = NuimoLEDMatrix.verticalBar9Matrix.string
        }
    }
    
    //MARK: Predefined matrices

    public static let emptyMatrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         ")

    public static let musicNoteMatrix = NuimoLEDMatrix(string:
        "         " +
        "  .....  " +
        "  .....  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        " ..  ..  " +
        "... ...  " +
        " .   .   ")
    
    public static let lightBulbMatrix = NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "   ...   " +
        "   ...   " +
        "    .    ")
    
    public static let verticalBar1Matrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    ")
    
    public static let verticalBar2Matrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    ")
    
    public static let verticalBar3Matrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    ")
    
    public static let verticalBar4Matrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    ")
    
    public static let verticalBar5Matrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    ")
    
    public static let verticalBar6Matrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    ")
    
    public static let verticalBar7Matrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    ")
    
    public static let verticalBar8Matrix = NuimoLEDMatrix(string:
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    ")
    
    public static let verticalBar9Matrix = NuimoLEDMatrix(string:
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    ")
    
    public static let powerOnMatrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   ...   " +
        "  .....  " +
        "  .....  " +
        "  .....  " +
        "   ...   " +
        "         " +
        "         ")
    
    public static let powerOffMatrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         " +
        "         ")
    
    public static let shuffleMatrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        " ..   .. " +
        "   . .   " +
        "    .    " +
        "   . .   " +
        " ..   .. " +
        "         " +
        "         ")
    
    public static let letterBMatrix = NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "         ")
    
    public static let letterOMatrix = NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         ")
    
    public static let letterGMatrix = NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .      " +
        "  . ...  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         ")
    
    public static let letterWMatrix = NuimoLEDMatrix(string:
        "         " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .  .  . " +
        " .  .  . " +
        "  .. ..  " +
        "         ")
    
    public static let letterYMatrix = NuimoLEDMatrix(string:
        "         " +
        "  .   .  " +
        "  .   .  " +
        "   . .   " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "         ")
    
    public static let playMatrix = NuimoLEDMatrix(string:
        "         " +
        "   .     " +
        "   ..    " +
        "   ...   " +
        "   ....  " +
        "   ...   " +
        "   ..    " +
        "   .     " +
        "         ")
    
    public static let pauseMatrix = NuimoLEDMatrix(string:
        "         " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "         ")
    
    public static let nextMatrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   .  .  " +
        "   .. .  " +
        "   ....  " +
        "   .. .  " +
        "   .  .  " +
        "         " +
        "         ")
    
    public static let previousMatrix = NuimoLEDMatrix(string:
        "         " +
        "         " +
        "  .  .   " +
        "  . ..   " +
        "  ....   " +
        "  . ..   " +
        "  .  .   " +
        "         " +
        "         ")
    
    public static let questionMarkMatrix = NuimoLEDMatrix(string:
        "   ...   " +
        "  .   .  " +
        " .     . " +
        "      .  " +
        "     .   " +
        "    .    " +
        "    .    " +
        "         " +
        "    .    ")
}

public func ==(left: NuimoLEDMatrix, right: NuimoLEDMatrix) -> Bool {
    return left.string == right.string
}

public func !=(left: NuimoLEDMatrix, right: NuimoLEDMatrix) -> Bool {
    return !(left == right)
}
