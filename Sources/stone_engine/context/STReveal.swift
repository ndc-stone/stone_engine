/*
STReveal.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import QuartzCore

/// How a character is drawn as it comes out.
///
/// What is being settled is the one character's appearing, not the order the
/// text comes out in: which character is next, and when, is said by
/// `STContext.revealedCharacterCount`, and this is what happens to the one
/// that has just been reached.
///
/// Meant to be added to. A text that types itself out wants more than one way
/// of putting a character on the page, and every one of them is the same thing
/// asked of the same glyph at the same moment — so each is a case here rather
/// than a flag of its own
public enum STRevealAnimation: Int, CaseIterable, Sendable {
    /// Simply there, from one frame to the next
    case none

    /// Drawn up from nothing to the colour it is set in
    case fade
}

extension STContext {
    //--------------------------------------------------------------//
    // MARK: - Reveal
    //--------------------------------------------------------------//

    /// How many characters a text comes out in.
    ///
    /// What `revealedCharacterCount` counts up to. Asked of the text and of
    /// the notation its readings are written in, rather than of a label that
    /// has been laid out: whoever counts a text out has to know where to stop
    /// before the first character has shown.
    ///
    /// The readings are no part of it. A word of two carrying a reading of
    /// four is two, and the marks the reading is written with are none
    public static func revealCharacterCount(
        of text: String,
        rubyNotation: STRubyNotation = .none
    ) -> Int {
        // Read the markup. What comes back is the text as it will be set,
        // which is the words and the readings together: a reading is set as
        // characters of its own, and the marks it was written with are what
        // has been taken out. The size it is set at has nothing to do with how
        // many there are, so it is given whatever
        let scan = STRubyScanner.scan(
            text: text, notation: rubyNotation, readingFontScale: 1
        )

        // And take the readings back off. They are set over the words rather
        // than after them, so they are no part of what somebody reads — and
        // counting them would leave the end of the count with nothing to show
        let readingCount = scan.rubies.reduce(0) { $0 + $1.readingRange.count }
        return scan.text.count - readingCount
    }

    /// Works out which character each run is drawn with, where it has not been
    /// worked out for this layout already.
    ///
    /// Built from the runs rather than from the text. The two are not the same
    /// list: a reading is laid out as runs of its own, and what is counted
    /// here is what somebody reads — so the readings are passed over, and a
    /// text of five characters is five however many readings stand over them.
    ///
    /// Asked for before the runs are drawn and at no other time. It costs one
    /// walk of the runs, and is kept until the text is laid out again
    public func prepareReveal() {
        // Built for this layout already
        guard revealIndexesVersion != layoutVersion else { return }
        revealIndexesVersion = layoutVersion

        // Which character each run belongs to, the readings aside
        var indexes = [Int](repeating: 0, count: runs.count)
        var characterIndex = 0
        for (runId, run) in runs.enumerated() {
            // A reading is no character of its own. Left with the character
            // before it, which is the last of the word it is set over: the
            // readings are put with the first of that word below, and this is
            // what stands for one the parser left out of a pair
            guard !run.flags.contains(.rubyText) else {
                indexes[runId] = max(0, characterIndex - 1)
                continue
            }

            indexes[runId] = characterIndex
            characterIndex += 1
        }

        // A reading comes out with the word it reads, and a word comes out at
        // its first character — so the whole reading is put with that one.
        // Waiting for the word to finish would leave a reading arriving after
        // what it is a reading of
        for ruby in rubies {
            guard let firstRunId = ruby.rbcRunIdRange.first else { continue }
            guard firstRunId < indexes.count else { continue }
            let wordIndex = indexes[firstRunId]
            for runId in ruby.rtcRunIdRange where runId < indexes.count {
                indexes[runId] = wordIndex
            }
        }

        // Set them
        revealIndexes = indexes
        revealCharacterCount = characterIndex
    }

    /// How far into coming out the character at this index has got.
    ///
    /// One where it is there to be read, nothing where it has not been reached
    /// yet, and something in between while it is on its way.
    ///
    /// Asked of a character rather than of a run, so that a word and the
    /// reading over it answer alike: they are drawn as separate glyphs and
    /// come out as the one thing
    public func revealProgress(ofCharacter index: Int, at time: TimeInterval) -> CGFloat {
        // Not reached yet
        guard index < revealedCharacterCount else { return 0 }

        // There outright, where nothing is made of a character arriving
        guard revealAnimation != .none, revealDuration > 0 else { return 1 }

        // And where it was already there before the last one arrived
        guard index >= revealingFromCharacterIndex else { return 1 }

        // On its way
        let elapsed = time - revealingStartTime
        return max(0, min(1, CGFloat(elapsed / revealDuration)))
    }

    /// Whether anything is still on its way at this moment.
    ///
    /// What a view asks to know whether to draw itself again. Nothing is,
    /// where nothing is made of a character arriving, and nothing is once the
    /// last one to arrive has finished doing so
    public func isRevealing(at time: TimeInterval) -> Bool {
        // Nothing is made of a character arriving
        guard revealAnimation != .none, revealDuration > 0 else { return false }

        // Nothing has arrived since the last one finished
        guard revealedCharacterCount > revealingFromCharacterIndex else { return false }

        return time - revealingStartTime < revealDuration
    }

    /// Takes note that characters are arriving now.
    ///
    /// Called as the count is set rather than worked out while drawing: what
    /// is wanted is the moment they were asked for, and a view is drawn
    /// whenever it is asked for rather than when something changed
    func noteRevealed(from oldValue: Int) {
        // For characters arriving, which are the ones between the two counts
        guard revealedCharacterCount > oldValue else {
            // For a count put back, there is nothing on its way
            revealingFromCharacterIndex = revealedCharacterCount
            revealingStartTime = 0
            return
        }

        revealingFromCharacterIndex = oldValue
        revealingStartTime = CACurrentMediaTime()
    }
}
