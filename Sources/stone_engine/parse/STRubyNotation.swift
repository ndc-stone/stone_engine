/*
STRubyNotation.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import Foundation

/// How a reading is written into the text.
///
/// Nothing by default: a text is set exactly as it is given, and the marks
/// below are ordinary characters. A reading costs a scan of the text and
/// changes what some perfectly ordinary punctuation means, so it is asked for
/// rather than assumed.
public enum STRubyNotation {
    /// None. The text is set as it is written
    case none

    /// The convention of Aozora Bunko: `漢字《かんじ》`, and `｜漢字《かんじ》`
    /// where what is read has to be said outright.
    ///
    /// Written with full width marks, which keeps it clear of text that is
    /// mostly ASCII: `《` and `》` and `｜` are rare enough in prose that a
    /// text carrying none of them reads the same whether this is on or off
    case aozora

    /// `{漢字|かんじ}`.
    ///
    /// Typed without reaching for full width marks, at the cost of using three
    /// characters that ordinary text does use. A group that is not well formed
    /// is left as it was written, and `\{` is a brace that begins nothing
    case braces
}

/// Where a reading is, once the marks have been taken out.
///
/// Counted in characters of the text as it will be set, which is also how the
/// runs are counted: the parser makes one run of every character, in order
struct STRubyCharRanges {
    let baseRange: Range<Int>
    let readingRange: Range<Int>
}

/// The text with its ruby marks taken out, and what they said
struct STRubyScan {
    /// What is to be set
    let text: String

    /// How large each character is set, against the size the text as a whole
    /// is set at. Empty where nothing is scaled, which saves the array for
    /// every text that carries no reading
    let fontScales: [CGFloat]

    /// The readings found, in the order they were met
    let rubies: [STRubyCharRanges]
}

enum STRubyScanner {
    /// What a character counts as when the base of a reading has to be found
    /// without being marked.
    ///
    /// Aozora's convention lets the base go unsaid: `漢字《かんじ》` reads back
    /// over the characters before `《` for as long as they are of a kind with
    /// the last of them. The kinds are the ones a Japanese reader would see as
    /// one word: a run of kanji, of kana, or of letters and digits. Anything
    /// else — a space, a mark, a bracket — ends the base
    private enum CharClass {
        case han
        case hiragana
        case katakana
        case alnum
        case other
    }

    private static func charClass(_ char: Character) -> CharClass {
        // A character of several scalars is a flag or an emoji, never a word
        var scalars = char.unicodeScalars.makeIterator()
        guard let scalar = scalars.next(), scalars.next() == nil else { return .other }

        switch scalar.value {
        // Kanji, including the repeat mark 々 and the old forms
        case 0x3005, 0x3007, 0x303B, 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF:
            return .han
        // Hiragana, with the voiced marks that sit among them
        case 0x3041 ... 0x309F:
            return .hiragana
        // Katakana, full width and half
        case 0x30A1 ... 0x30FF, 0x31F0 ... 0x31FF, 0xFF66 ... 0xFF9F:
            return .katakana
        // Letters and digits, full width
        case 0xFF10 ... 0xFF19, 0xFF21 ... 0xFF3A, 0xFF41 ... 0xFF5A:
            return .alnum
        default:
            // And half width
            if char.isASCII, char.isLetter || char.isNumber { return .alnum }
            return .other
        }
    }

    // The marks
    private static let aozoraBaseMark: Character = "｜"
    private static let aozoraReadingOpen: Character = "《"
    private static let aozoraReadingClose: Character = "》"
    private static let bracesOpen: Character = "{"
    private static let bracesSeparator: Character = "|"
    private static let bracesClose: Character = "}"
    private static let escape: Character = "\\"

    /// Takes the marks out of the text and says what they said.
    ///
    /// Nothing is thrown away. A group that is not well formed is not a group:
    /// its marks are characters like any others, and the text is set as it was
    /// written. An unclosed brace used to swallow everything after it
    static func scan(
        text: String,
        notation: STRubyNotation,
        readingFontScale: CGFloat
    ) -> STRubyScan {
        // Nothing to look for
        guard notation != .none else {
            return .init(text: text, fontScales: [], rubies: [])
        }

        let source = Array(text)
        var out = [Character]()
        var fontScales = [CGFloat]()
        var rubies = [STRubyCharRanges]()
        out.reserveCapacity(source.count)
        fontScales.reserveCapacity(source.count)

        // Where the last reading ended, so that an unmarked base never reads
        // back into one
        var lastRubyEnd = 0

        var index = 0
        while index < source.count {
            let char = source[index]

            // Switch by notation
            switch notation {
            case .none:
                break

            case .braces:
                // A brace that begins nothing
                if char == escape, index + 1 < source.count, source[index + 1] == bracesOpen {
                    out.append(bracesOpen)
                    fontScales.append(1)
                    index += 2
                    continue
                }

                // A group, where there is a whole one
                if char == bracesOpen,
                    let group = bracesGroup(source, from: index)
                {
                    appendGroup(
                        source: source,
                        baseRange: group.baseRange,
                        readingRange: group.readingRange,
                        readingFontScale: readingFontScale,
                        out: &out,
                        fontScales: &fontScales,
                        rubies: &rubies,
                        lastRubyEnd: &lastRubyEnd
                    )
                    index = group.end
                    continue
                }

            case .aozora:
                // The base said outright
                if char == aozoraBaseMark,
                    let group = aozoraMarkedGroup(source, from: index)
                {
                    appendGroup(
                        source: source,
                        baseRange: group.baseRange,
                        readingRange: group.readingRange,
                        readingFontScale: readingFontScale,
                        out: &out,
                        fontScales: &fontScales,
                        rubies: &rubies,
                        lastRubyEnd: &lastRubyEnd
                    )
                    index = group.end
                    continue
                }

                // Or left to be read back over
                if char == aozoraReadingOpen,
                    let readingRange = aozoraReadingRange(source, from: index),
                    let baseStart = unmarkedBaseStart(out, notBefore: lastRubyEnd)
                {
                    // The base is already out, so it is taken back off and put
                    // down again as the base of this reading
                    let base = Array(out[baseStart ..< out.count])
                    out.removeLast(out.count - baseStart)
                    fontScales.removeLast(fontScales.count - baseStart)

                    appendBaseAndReading(
                        base: base,
                        reading: Array(source[readingRange]),
                        readingFontScale: readingFontScale,
                        out: &out,
                        fontScales: &fontScales,
                        rubies: &rubies,
                        lastRubyEnd: &lastRubyEnd
                    )
                    index = readingRange.upperBound + 1
                    continue
                }
            }

            // An ordinary character, which is most of them
            out.append(char)
            fontScales.append(1)
            index += 1
        }

        return .init(
            text: String(out),
            fontScales: rubies.isEmpty ? [] : fontScales,
            rubies: rubies
        )
    }
}

extension STRubyScanner {
    //--------------------------------------------------------------//
    // MARK: - Group
    //--------------------------------------------------------------//

    /// Whether a character ends whatever group is being looked for.
    ///
    /// A reading sits on one line with the word it is read from, so a group
    /// that runs over a line break is not a group
    private static func isGroupBreaking(_ char: Character) -> Bool {
        return char.isNewline
    }

    /// The whole of `{base|reading}` beginning at `start`, where there is one.
    ///
    /// Nothing where the group is not whole: no separator, no closing brace, a
    /// brace of its own inside it, a line break, or nothing to read. Then the
    /// opening brace is an ordinary character and the text goes on as written
    private static func bracesGroup(
        _ source: [Character],
        from start: Int
    ) -> (baseRange: Range<Int>, readingRange: Range<Int>, end: Int)? {
        var separator: Int?
        var index = start + 1
        while index < source.count {
            let char = source[index]

            // Not a group
            if char == bracesOpen || isGroupBreaking(char) { return nil }

            // The separator, the first one of which splits it
            if char == bracesSeparator, separator == nil {
                separator = index
            }

            // The end of it
            if char == bracesClose {
                guard let separator = separator else { return nil }
                let baseRange = (start + 1) ..< separator
                guard !baseRange.isEmpty else { return nil }
                return (baseRange, (separator + 1) ..< index, index + 1)
            }

            index += 1
        }

        return nil
    }

    /// The whole of `｜base《reading》` beginning at the mark
    private static func aozoraMarkedGroup(
        _ source: [Character],
        from start: Int
    ) -> (baseRange: Range<Int>, readingRange: Range<Int>, end: Int)? {
        // Find where the reading opens
        var index = start + 1
        while index < source.count {
            let char = source[index]
            if char == aozoraReadingOpen { break }
            if char == aozoraBaseMark || char == aozoraReadingClose || isGroupBreaking(char) {
                return nil
            }
            index += 1
        }
        guard index < source.count else { return nil }

        let baseRange = (start + 1) ..< index
        guard !baseRange.isEmpty else { return nil }

        // And where it closes
        guard let readingRange = aozoraReadingRange(source, from: index) else { return nil }

        return (baseRange, readingRange, readingRange.upperBound + 1)
    }

    /// What stands between `《` and the `》` that closes it
    private static func aozoraReadingRange(
        _ source: [Character],
        from open: Int
    ) -> Range<Int>? {
        var index = open + 1
        while index < source.count {
            let char = source[index]
            if char == aozoraReadingClose { return (open + 1) ..< index }
            if char == aozoraReadingOpen || isGroupBreaking(char) { return nil }
            index += 1
        }

        return nil
    }

    /// How far back an unmarked base reaches.
    ///
    /// Back over the characters of a kind with the last one set, and no
    /// further than the end of the reading before it: what has already been
    /// read is not read again
    private static func unmarkedBaseStart(
        _ out: [Character],
        notBefore limit: Int
    ) -> Int? {
        // Check that there is anything to read
        guard out.count > limit else { return nil }

        // The kind is the kind of the character the reading follows
        let kind = charClass(out[out.count - 1])
        guard kind != .other else { return nil }

        var start = out.count - 1
        while start > limit, charClass(out[start - 1]) == kind {
            start -= 1
        }

        return start
    }

    //--------------------------------------------------------------//
    // MARK: - Append
    //--------------------------------------------------------------//

    private static func appendGroup(
        source: [Character],
        baseRange: Range<Int>,
        readingRange: Range<Int>,
        readingFontScale: CGFloat,
        out: inout [Character],
        fontScales: inout [CGFloat],
        rubies: inout [STRubyCharRanges],
        lastRubyEnd: inout Int
    ) {
        appendBaseAndReading(
            base: Array(source[baseRange]),
            reading: Array(source[readingRange]),
            readingFontScale: readingFontScale,
            out: &out,
            fontScales: &fontScales,
            rubies: &rubies,
            lastRubyEnd: &lastRubyEnd
        )
    }

    /// Puts the word down, then the reading, and says that the two belong
    /// together.
    ///
    /// Nothing is said where the reading is empty. A group written with the
    /// reading left out is a word somebody has not finished marking up, and
    /// the word itself is still the text: it is set as it is, and nothing is
    /// set over it
    private static func appendBaseAndReading(
        base: [Character],
        reading: [Character],
        readingFontScale: CGFloat,
        out: inout [Character],
        fontScales: inout [CGFloat],
        rubies: inout [STRubyCharRanges],
        lastRubyEnd: inout Int
    ) {
        // The word
        let baseStart = out.count
        out.append(contentsOf: base)
        fontScales.append(contentsOf: repeatElement(1, count: base.count))

        // A word with nothing set over it
        guard !reading.isEmpty else { return }

        // The reading
        let readingStart = out.count
        out.append(contentsOf: reading)
        fontScales.append(contentsOf: repeatElement(readingFontScale, count: reading.count))

        // And that the two belong together
        rubies.append(
            .init(
                baseRange: baseStart ..< readingStart,
                readingRange: readingStart ..< out.count
            )
        )
        lastRubyEnd = out.count
    }
}
