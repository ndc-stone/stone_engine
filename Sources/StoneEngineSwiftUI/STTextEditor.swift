/*
STTextEditor.swift

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import SwiftUI
import stone_engine

/// A SwiftUI view that edits text with `STTextView`.
///
/// The editor is sized to a whole number of lines across the direction lines are
/// stacked, so that the lines at both edges are not cut.
public struct STTextEditor {
    @Binding public var text: String
    public var direction: STDirection
    public var fontSize: CGFloat
    public var lineHeightScale: CGFloat

    public init(
        text: Binding<String>,
        direction: STDirection = .lrTb,
        fontSize: CGFloat = 17,
        lineHeightScale: CGFloat = 1.5
    ) {
        self._text = text
        self.direction = direction
        self.fontSize = fontSize
        self.lineHeightScale = lineHeightScale
    }

    @MainActor
    public func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }

    @MainActor
    private func makeTextView(coordinator: Coordinator) -> STTextView {
        // Create text view
        let textView = STEditorTextView(frame: .zero)
        #if os(iOS)
        textView.contentInset = .zero
        textView.label.backgroundColor = .clear
        textView.backgroundColor = .clear
        textView.delegate = coordinator
        #elseif os(macOS)
        textView.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        textView.drawsBackground = false
        textView.label.context.textColor = .labelColor
        textView.label.context.selectedTextColor = .labelColor
        textView.label.context.markedTextColor = .labelColor
        #endif

        // Observe text
        coordinator.observe(textView)

        // Set values
        update(textView, coordinator: coordinator)

        return textView
    }

    @MainActor
    private func update(_ textView: STTextView, coordinator: Coordinator) {
        // Keep latest binding
        coordinator.text = $text

        // Set properties
        let isDirectionChanged = textView.direction != direction
        if isDirectionChanged { textView.direction = direction }
        if textView.fontSize != fontSize { textView.fontSize = fontSize }
        if textView.lineHeightScale != lineHeightScale { textView.lineHeightScale = lineHeightScale }

        // Set text unless it is being composed by input method
        if (textView.text ?? "") != text, textView.markedRanges?.isEmpty != false {
            coordinator.setText(text, to: textView)
        }

        // Lines start from another edge
        if isDirectionChanged {
            (textView as? STEditorTextView)?.showStartOfText()
        }
    }

    @MainActor
    static func wholeLineSize(proposal: ProposedViewSize, direction: STDirection, lineHeight: CGFloat) -> CGSize? {
        // Check proposed size
        guard lineHeight > 0, let width = proposal.width, let height = proposal.height else { return nil }

        // Round down the side lines are stacked along
        switch direction {
        case .lrTb:
            let lines = floor(height / lineHeight)
            return CGSize(width: width, height: lines >= 1 ? lines * lineHeight : height)
        case .tbRl:
            let lines = floor(width / lineHeight)
            return CGSize(width: lines >= 1 ? lines * lineHeight : width, height: height)
        }
    }

    @MainActor
    public final class Coordinator: NSObject {
        fileprivate var text: Binding<String>
        private var observer: NSObjectProtocol?
        private var isSettingText = false

        fileprivate init(text: Binding<String>) {
            self.text = text
        }

        fileprivate func observe(_ textView: STTextView) {
            // Observe text changed by user
            observer = NotificationCenter.default.addObserver(
                forName: STTextView.textChanged, object: textView, queue: nil
            ) { [weak self, weak textView] _ in
                MainActor.assumeIsolated {
                    guard let self, let textView, !self.isSettingText else { return }
                    let text = textView.text ?? ""
                    if self.text.wrappedValue != text {
                        self.text.wrappedValue = text
                    }
                }
            }
        }

        fileprivate func stopObserving() {
            // Remove observer
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }

        fileprivate func setText(_ text: String, to textView: STTextView) {
            // Set text without writing it back to binding
            isSettingText = true
            textView.text = text
            isSettingText = false
        }
    }
}

#if os(iOS)
final class STEditorTextView: STTextView {
    private var needsToShowStartOfText = false

    func showStartOfText() {
        // Show it after layout
        selectedSTTextRange = STTextRange(range: 0 ..< 0)
        needsToShowStartOfText = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        // Invoke super
        super.layoutSubviews()

        // Show start of text
        guard needsToShowStartOfText, !bounds.isEmpty else { return }
        needsToShowStartOfText = false
        switch direction {
        case .lrTb: contentOffset = .zero
        case .tbRl: showSelectedRange()
        }
    }
}

extension STTextEditor: UIViewRepresentable {
    public func makeUIView(context: Context) -> STTextView {
        return makeTextView(coordinator: context.coordinator)
    }

    public func updateUIView(_ textView: STTextView, context: Context) {
        update(textView, coordinator: context.coordinator)
    }

    public static func dismantleUIView(_ textView: STTextView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: STTextView, context: Context) -> CGSize? {
        return Self.wholeLineSize(proposal: proposal, direction: direction, lineHeight: fontSize * lineHeightScale)
    }
}

extension STTextEditor.Coordinator: UIScrollViewDelegate {
    public func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        // Stop at a position showing whole lines
        guard let textView = scrollView as? STTextView else { return }
        targetContentOffset.pointee = textView.adjustedContentOffset(targetContentOffset: targetContentOffset.pointee)
    }
}
#elseif os(macOS)
final class STEditorTextView: STTextView {
    func showStartOfText() {
        // Scroll to it on next layout
        selectedSTTextRange = STTextRange(range: 0 ..< 0)
        needsToScrollToShowCurosr = true
        needsLayout = true
    }
}

extension STTextEditor: NSViewRepresentable {
    public func makeNSView(context: Context) -> STTextView {
        return makeTextView(coordinator: context.coordinator)
    }

    public func updateNSView(_ textView: STTextView, context: Context) {
        update(textView, coordinator: context.coordinator)
    }

    public static func dismantleNSView(_ textView: STTextView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: STTextView, context: Context) -> CGSize? {
        return Self.wholeLineSize(proposal: proposal, direction: direction, lineHeight: fontSize * lineHeightScale)
    }
}
#endif
