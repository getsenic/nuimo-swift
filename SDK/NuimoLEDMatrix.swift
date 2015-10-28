//
//  NuimoLEDMatrix.swift
//  Nuimo
//
//  Created by je on 9/1/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

public enum NuimoLEDMatrix: String {
    case
    MusicNote = "music-note",
    LightBulb = "light-bulb",
    VerticalBar1 = "vertical-bar1",
    VerticalBar2 = "vertical-bar2",
    VerticalBar3 = "vertical-bar3",
    VerticalBar4 = "vertical-bar4",
    VerticalBar5 = "vertical-bar5",
    VerticalBar6 = "vertical-bar6",
    VerticalBar7 = "vertical-bar7",
    VerticalBar8 = "vertical-bar8",
    VerticalBar9 = "vertical-bar9",
    PowerOn = "power-on",
    PowerOff = "power-off",
    Shuffle = "shuffle",
    LetterB = "B",
    LetterO = "O",
    LetterG = "G",
    LetterW = "W",
    LetterY = "Y",
    QuestionMark = "?",
    Play = "play",
    Pause = "pause",
    Next = "next",
    Previous = "previous"
    
    public var stringRepresentation: String { return stringRepresentationForMatrix[self] ?? "" }
    public var matrixBytes: [UInt8] { return NuimoLEDMatrix.matrixBytesForString(self.stringRepresentation) }
    
    //TODO: Implement a simple FIFO cache that stores the byte representation for the last 256? (< 32 KB) matrices used IF calculating the string representation is significantly slower than a dictionary lookup
    public static func matrixBytesForString(string: String) -> [UInt8] {
        let ledCount = 81
        let ledOffCharacters = " 0".characters
        return string
            .substringToIndex(string.startIndex.advancedBy(min(string.characters.count, ledCount))) // Cut off after 81 characters
            .stringByPaddingToLength(ledCount, withString: " ", startingAtIndex: 0)                 // Right fill up to 81 characters
            .characters
            .chunk(8)
            .map{ $0
                .reverse()
                .enumerate()
                .map{(i: Int, c: Character) -> Int in return ledOffCharacters.contains(c) ? 0 : 1 << (7 - i)}
                .reduce(UInt8(0), combine: {(s: UInt8, v: Int) -> UInt8 in s + UInt8(v)})
        }
    }
}

extension SequenceType {
    public func chunk(n: Int) -> [[Generator.Element]] {
        var chunks: [[Generator.Element]] = []
        var chunk: [Generator.Element] = []
        chunk.reserveCapacity(n)
        chunks.reserveCapacity(underestimateCount() / n)
        var i = n
        self.forEach {
            chunk.append($0)
            if --i == 0 {
                chunks.append(chunk)
                chunk.removeAll(keepCapacity: true)
                i = n
            }
        }
        if !chunk.isEmpty { chunks.append(chunk) }
        return chunks
    }
}

//MARK: - Predefined string representations

private let stringRepresentationForMatrix: [NuimoLEDMatrix : String] = [
    .MusicNote: musicNoteMatrix,
    .LightBulb: lightBulbMatrix,
    .VerticalBar1: verticalBar1Matrix,
    .VerticalBar2: verticalBar2Matrix,
    .VerticalBar3: verticalBar3Matrix,
    .VerticalBar4: verticalBar4Matrix,
    .VerticalBar5: verticalBar5Matrix,
    .VerticalBar6: verticalBar6Matrix,
    .VerticalBar7: verticalBar7Matrix,
    .VerticalBar8: verticalBar8Matrix,
    .VerticalBar9: verticalBar9Matrix,
    .PowerOn: powerOnMatrix,
    .PowerOff: powerOffMatrix,
    .Shuffle: shuffleMatrix,
    .LetterB: letterBMatrix,
    .LetterO: letterOMatrix,
    .LetterG: letterGMatrix,
    .LetterW: letterWMatrix,
    .LetterY: letterYMatrix,
    .QuestionMark: questionMarkMatrix,
    .Play: playMatrix,
    .Pause: pauseMatrix,
    .Next: nextMatrix,
    .Previous: previousMatrix
]

let musicNoteMatrix =
        "         " +
        "  .....  " +
        "  .....  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        " ..  ..  " +
        "... ...  " +
        " .   .   "
let lightBulbMatrix =
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "   ...   " +
        "   ...   " +
        "    .    "
let verticalBar1Matrix =
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    "
let verticalBar2Matrix =
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    "
let verticalBar3Matrix =
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    "
let verticalBar4Matrix =
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    "
let verticalBar5Matrix =
        "         " +
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    "
let verticalBar6Matrix =
        "         " +
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    "
let verticalBar7Matrix =
        "         " +
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    "
let verticalBar8Matrix =
        "         " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    "
let verticalBar9Matrix =
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    "
let powerOnMatrix =
        "         " +
        "         " +
        "   ...   " +
        "  .....  " +
        "  .....  " +
        "  .....  " +
        "   ...   " +
        "         " +
        "         "
let powerOffMatrix =
        "         " +
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         " +
        "         "
let shuffleMatrix =
        "         " +
        "         " +
        " ..   .. " +
        "   . .   " +
        "    .    " +
        "   . .   " +
        " ..   .. " +
        "         " +
        "         "
let letterBMatrix =
        "         " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "         "
let letterOMatrix =
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         "
let letterGMatrix =
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .      " +
        "  . ...  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         "
let letterWMatrix =
        "         " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .  .  . " +
        " .  .  . " +
        "  .. ..  " +
        "         "
let letterYMatrix =
        "         " +
        "  .   .  " +
        "  .   .  " +
        "   . .   " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "         "
let playMatrix =
        "         " +
        "   .     " +
        "   ..    " +
        "   ...   " +
        "   ....  " +
        "   ...   " +
        "   ..    " +
        "   .     " +
        "         "
let pauseMatrix =
        "         " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "         "
let nextMatrix =
        "         " +
        "         " +
        "   .  .  " +
        "   .. .  " +
        "   ....  " +
        "   .. .  " +
        "   .  .  " +
        "         " +
        "         "
let previousMatrix =
        "         " +
        "         " +
        "  .  .   " +
        "  . ..   " +
        "  ....   " +
        "  . ..   " +
        "  .  .   " +
        "         " +
        "         "
let questionMarkMatrix =
        "   ...   " +
        "  .   .  " +
        " .     . " +
        "      .  " +
        "     .   " +
        "    .    " +
        "    .    " +
        "         " +
        "    .    "