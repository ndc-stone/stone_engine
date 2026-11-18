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

    public init(
        _ text: String,
        direction: STDirection = .lrTb,
        fontSize: CGFloat = 17,
        lineHeightScale: CGFloat = 1.5
    ) {
        self.text = text
        self.direction = direction
        self.fontSize = fontSize
        self.lineHeightScale = lineHeightScale
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
        // Set properties
        label.direction = direction
        label.fontSize = fontSize
        label.lineHeightScale = lineHeightScale
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
