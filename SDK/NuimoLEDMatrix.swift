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