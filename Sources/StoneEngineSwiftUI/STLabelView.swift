/*
STLabelView.swift

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import SwiftUI
import stone_engine

/// A SwiftUI view that displays read-only text with `STLabel`.
public struct STLabelView {
    public var text: String
    public var direction: STDirection
    public var fontSize: CGFloat
    public var lineHeightScale: CGFloat

    /// How a reading is written into the text, where one is written at all.
    ///
    /// Nothing by default — see `STRubyNotation`. The marks a reading is
    /// written with are then ordinary characters, and the text is set exactly
    /// as it is given.
    ///
    /// A reading needs room above the line it is set over, which a line set to
    /// its own height does not leave: `lineHeightScale` is what gives it, and
    /// one and a half is enough for a reading set at half size
    public var rubyNotation: STRubyNotation

    /// How large a reading is set, against the text it is read from
    public var rubyFontScale: CGFloat

    /// How many lines the text may be set on. Zero leaves it as many as it
    /// takes
    public var maxLineCount: Int

    /// Whether what is cut off is marked with an ellipsis
    public var isShownEllipsis: Bool

    /// What is made of a character as it comes out — see `STRevealAnimation`.
    ///
    /// Nothing by default, which is a text that is simply there
    public var revealAnimation: STRevealAnimation

    /// How many characters of the text have come out.
    ///
    /// All of them by default. Counted as somebody reads them: a reading is no
    /// character of its own, so a word of three carrying a reading of five is
    /// three.
    ///
    /// Nothing is laid out again as this moves. The text is set once and
    /// whole, so the line breaks are settled before the first character shows
    /// and nothing shifts as the rest arrive — which is why this is a count
    /// rather than a shorter string
    public var revealedCharacterCount: Int

    /// How long one character takes to come out
    public var revealDuration: TimeInterval

    /// Which side a character comes in from, where it comes in from one —
    /// see `STRevealAnimation.flyIn`, which is the only one that asks
    public var revealOrigin: STRevealOrigin

    public init(
        _ text: String,
        direction: STDirection = .lrTb,
        fontSize: CGFloat = 17,
        lineHeightScale: CGFloat = 1.5,
        rubyNotation: STRubyNotation = .none,
        rubyFontScale: CGFloat = 0.5,
        maxLineCount: Int = 0,
        isShownEllipsis: Bool = false,
        revealAnimation: STRevealAnimation = .none,
        revealedCharacterCount: Int = .max,
        revealDuration: TimeInterval = 0.2,
        revealOrigin: STRevealOrigin = .bottom
    ) {
        self.text = text
        self.direction = direction
        self.fontSize = fontSize
        self.lineHeightScale = lineHeightScale
        self.rubyNotation = rubyNotation
        self.rubyFontScale = rubyFontScale
        self.maxLineCount = maxLineCount
        self.isShownEllipsis = isShownEllipsis
        self.revealAnimation = revealAnimation
        self.revealedCharacterCount = revealedCharacterCount
        self.revealDuration = revealDuration
        self.revealOrigin = revealOrigin
    }

    @MainActor
    private func makeLabel() -> STLabel {
        // Create label
        let label = STLabel(frame: .zero)
        #if os(iOS)
        label.backgroundColor = .clear
        #elseif os(macOS)
        label.context.textColor = .labelColor
        #endif

        return label
    }

    @MainActor
    private func update(_ label: STLabel) {
        // Set properties. The text last, so that everything it is set by is
        // already on the label when it is parsed and laid out
        label.direction = direction
        label.fontSize = fontSize
        label.lineHeightScale = lineHeightScale
        label.rubyNotation = rubyNotation
        label.rubyFontScale = rubyFontScale
        label.maxLineCount = maxLineCount
        label.isShownEllipsis = isShownEllipsis
        label.revealAnimation = revealAnimation
        label.revealDuration = revealDuration
        label.revealOrigin = revealOrigin
        label.revealedCharacterCount = revealedCharacterCount
        label.text = text
    }

    @MainActor
    static func fittingSize(of label: STLabel, proposal: ProposedViewSize) -> CGSize {
        // Limit only the length of lines, lines are added as many as needed
        let size: CGSize
        switch label.direction {
        case .lrTb: size = CGSize(width: proposal.width ?? STLayoutLimit.unbounded, height: 0)
        case .tbRl: size = CGSize(width: 0, height: proposal.height ?? STLayoutLimit.unbounded)
        }

        // Fit to pixel grid upward not to clip text
        let fittingSize = label.sizeThatFits(size)
        return CGSize(width: ceil(fittingSize.width), height: ceil(fittingSize.height))
    }
}

enum STLayoutLimit {
    static let unbounded: CGFloat = 10_000_000
}

#if os(iOS)
extension STLabelView: UIViewRepresentable {
    public func makeUIView(context: Context) -> STLabel {
        return makeLabel()
    }

    public func updateUIView(_ label: STLabel, context: Context) {
        update(label)
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView label: STLabel, context: Context) -> CGSize? {
        update(label)
        return Self.fittingSize(of: label, proposal: proposal)
    }
}
#elseif os(macOS)
extension STLabelView: NSViewRepresentable {
    public func makeNSView(context: Context) -> STLabel {
        return makeLabel()
    }

    public func updateNSView(_ label: STLabel, context: Context) {
        update(label)
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView label: STLabel, context: Context) -> CGSize? {
        update(label)
        return Self.fittingSize(of: label, proposal: proposal)
    }
}
#endif
