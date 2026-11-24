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

    /// Come up small and settle, going a little past its size on the way
    case pop

    /// Stand up out of the foot of its place, flat and wide to begin with
    case rise

    /// Fall into its place from above, gathering speed on the way down
    case drop

    /// Turn into its place, coming up small with it
    case spin

    /// Open out from edge on, as a card turned to face the reader
    case flip

    /// Come in from one side of its place — see `STContext.revealOrigin`, which
    /// says which side
    case flyIn
}

/// Which side or corner of its place something comes in from.
///
/// The screen's sides and not the line's. Read as the line runs, "the side it
/// is read from" is the side the next character is going to appear on anyway,
/// and a character coming from there is one that hardly moves. Said as the
/// screen's, the same setting reads the same whichever way the lines run
public enum STRevealOrigin: Int, CaseIterable, Sendable {
    case top
    case bottom
    case left
    case right

    // And the corners, which are both at once
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

/// How one character is drawn while it is on its way.
///
/// What the drawing is asked for rather than how to draw it: a glyph is drawn
/// the one way, and what tells one of these apart from another is where it is
/// put and how much of its colour it is given
public struct STRevealDrawing {
    /// How much of its colour it is drawn in
    public let alpha: CGFloat

    /// Where it is drawn, against where it comes to rest
    public let transform: CGAffineTransform

    /// There, in its place, in its colour — which is every character that has
    /// finished arriving, and every character of a text that was never told to
    /// come out a character at a time
    public static let settled = STRevealDrawing(alpha: 1, transform: .identity)

    public init(alpha: CGFloat, transform: CGAffineTransform) {
        self.alpha = alpha
        self.transform = transform
    }
}

extension STRevealOrigin {
    //--------------------------------------------------------------//
    // MARK: - Offset
    //--------------------------------------------------------------//

    /// How far out of its place something is, at this much of the way out.
    ///
    /// Measured against the place itself rather than said in points, so that
    /// it holds at every size the text is set at.
    ///
    /// Less than the whole of that place. What is drawn is kept to the room
    /// the text is given and a little around it, so something starting
    /// further out than that would be left undrawn until it had come into
    /// view
    func offset(from anchor: CGRect, away: CGFloat) -> CGPoint {
        let distance = STRevealOrigin.distanceScale * away

        // How far out along each way, which a corner is out along both.
        //
        // The whole of it along both rather than a share of it each. What is
        // being said is which corner it comes from, and something that came
        // from a corner has come the length of the diagonal — held to the
        // length of a side it would start off the corner, somewhere along the
        // edge
        let x = anchor.width * distance
        let y = anchor.height * distance

        // Switch by self
        switch self {
        case .top: return .init(x: 0, y: -y)
        case .bottom: return .init(x: 0, y: y)
        case .left: return .init(x: -x, y: 0)
        case .right: return .init(x: x, y: 0)
        case .topLeft: return .init(x: -x, y: -y)
        case .topRight: return .init(x: x, y: -y)
        case .bottomLeft: return .init(x: -x, y: y)
        case .bottomRight: return .init(x: x, y: y)
        }
    }

    /// How far out it begins, against the size of the place it is coming to
    static let distanceScale: CGFloat = 0.8
}

extension STRevealAnimation {
    //--------------------------------------------------------------//
    // MARK: - Drawing
    //--------------------------------------------------------------//

    /// What a character looks like partway through arriving.
    ///
    /// - Parameter progress: nothing where it has not begun, one where it has
    ///   arrived.
    /// - Parameter anchor: the place the character is coming to, which is what
    ///   it is moved and sized against. The word's place rather than its own
    ///   where it is a reading, so that a reading moves with what it reads
    ///   instead of away from it.
    /// - Parameter origin: where it is coming from, which only `flyIn` asks
    public func drawing(
        progress: CGFloat, anchor: CGRect, origin: STRevealOrigin = .bottom
    ) -> STRevealDrawing {
        // There already
        guard progress < 1 else { return .settled }

        // Switch by self
        switch self {
        case .none:
            return .settled

        case .fade:
            return .init(alpha: progress, transform: .identity)

        case .pop:
            // Up from small, going past its size and settling back. Sized
            // about the middle of its place, there being no side of a
            // character for it to grow out of
            let scale = Self.popFromScale
                + (1 - Self.popFromScale) * Self.easeOutBack(progress)
            return .init(
                alpha: min(1, progress * 2),
                transform: Self.transform(
                    scaleX: scale, scaleY: scale, about: CGPoint(x: anchor.midX, y: anchor.midY)
                )
            )

        case .flyIn:
            // Moved into its place and stopped there, rather than dropped
            // into it: what is being watched is the arriving, so it slows as
            // it arrives
            let arrived = Self.easeOut(progress)
            let away = 1 - arrived
            let offset = origin.offset(from: anchor, away: away)
            return .init(
                alpha: min(1, progress * 2),
                transform: CGAffineTransform(
                    translationX: offset.x, y: offset.y
                )
            )

        case .drop:
            // Falling rather than settling: it gathers speed on the way down
            // and is stopped by its place, which is what tells a thing
            // dropped from a thing let down
            let fallen = Self.easeIn(progress)
            let height = anchor.height * Self.dropHeightScale
            return .init(
                alpha: min(1, progress * 2),
                transform: CGAffineTransform(
                    translationX: 0, y: -height * (1 - fallen)
                )
            )

        case .spin:
            // Turned and sized about the middle of its place, which is the
            // only point of a character that stays still while it turns
            let eased = Self.easeOut(progress)
            let scale = Self.spinFromScale + (1 - Self.spinFromScale) * eased
            return .init(
                alpha: min(1, progress * 2),
                transform: Self.transform(
                    scaleX: scale,
                    scaleY: scale,
                    rotation: Self.spinFromAngle * (1 - eased),
                    about: CGPoint(x: anchor.midX, y: anchor.midY)
                )
            )

        case .flip:
            // Edge on to begin with and square to the reader at the end,
            // which is what a width of nothing opening to its own comes to.
            // Turned about the upright, wherever the lines run: a card is
            // turned the way a page is, and a page is turned sideways
            let opened = sin(progress * .pi / 2)
            return .init(
                alpha: min(1, progress * 3),
                transform: Self.transform(
                    scaleX: opened,
                    scaleY: 1,
                    about: CGPoint(x: anchor.midX, y: anchor.midY)
                )
            )

        case .rise:
            // Flat and wide at the foot of its place, standing up into it.
            // Sized about the foot rather than the middle, which is what makes
            // it stand up rather than open out from the centre.
            //
            // The foot of the place wherever the lines run. Down the page is
            // down the page, and a character standing up reads as one whether
            // the line it is on runs across or down
            let eased = Self.easeOut(progress)
            return .init(
                alpha: min(1, progress * 3),
                transform: Self.transform(
                    scaleX: Self.riseFromScaleX + (1 - Self.riseFromScaleX) * eased,
                    scaleY: Self.riseFromScaleY + (1 - Self.riseFromScaleY) * eased,
                    about: CGPoint(x: anchor.midX, y: anchor.maxY)
                )
            )
        }
    }

    /// How small `pop` begins
    static let popFromScale: CGFloat = 0.6

    /// How wide and how flat `rise` begins
    static let riseFromScaleX: CGFloat = 1.15
    static let riseFromScaleY: CGFloat = 0.05

    /// How far above its place `drop` begins, against the height of that
    /// place.
    ///
    /// Less than the whole of it. What is drawn is kept to the room the text
    /// is given and a little around it, so a character starting further up
    /// than that would be left undrawn until it had fallen into view
    static let dropHeightScale: CGFloat = 0.8

    /// How small `spin` begins, and how far round
    static let spinFromScale: CGFloat = 0.5
    static let spinFromAngle: CGFloat = .pi

    /// Sizing something where it stands, rather than about the origin.
    ///
    /// A scale on its own works out of the corner the whole text is measured
    /// from, which would throw a character across the page rather than size it
    /// in its place
    static func transform(
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotation: CGFloat = 0,
        about point: CGPoint
    ) -> CGAffineTransform {
        return CGAffineTransform(translationX: point.x, y: point.y)
            .rotated(by: rotation)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -point.x, y: -point.y)
    }

    /// Slow to begin with and quick at the end, which is how a thing falling
    /// moves
    static func easeIn(_ progress: CGFloat) -> CGFloat {
        return progress * progress
    }

    /// Quick to begin with and slow to arrive, which is how a thing coming to
    /// rest moves
    static func easeOut(_ progress: CGFloat) -> CGFloat {
        let remaining = 1 - progress
        return 1 - remaining * remaining * remaining
    }

    /// The same, going a little past its end before settling back
    static func easeOutBack(_ progress: CGFloat) -> CGFloat {
        let overshoot: CGFloat = 1.70158
        let remaining = progress - 1
        return 1
            + (overshoot + 1) * remaining * remaining * remaining
            + overshoot * remaining * remaining
    }
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

        // Which character each run belongs to, and the place it is coming to
        var indexes = [Int](repeating: 0, count: runs.count)
        var anchors = runs.map { $0.frame }
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

            // And it is moved against the word's place rather than its own,
            // so that the two are moved as one thing
            var wordRect = CGRect.null
            for runId in ruby.rbcRunIdRange where runId < anchors.count {
                wordRect = wordRect.union(runs[runId].frame)
            }
            guard !wordRect.isNull else { continue }
            for runId in ruby.rtcRunIdRange where runId < anchors.count {
                anchors[runId] = wordRect
            }
        }

        // Set them
        revealIndexes = indexes
        revealAnchors = anchors
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
