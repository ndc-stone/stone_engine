/*
STTextField.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

#if os(iOS)

#elseif os(macOS)
extension STTextField {
    public static let textChanged = Notification.Name("STTextFieldTextChanged")
    public static let selectionChanged = Notification.Name("STTextFieldSelectionChanged")
    public static let contentSizeChanged = Notification.Name("STTextFieldContentSizeChanged")
    public static let enterPressed = Notification.Name("STTextFieldEnterPressed")
}

open class STTextField: NSControl {
    // Inner views
    public let textView = STTextView(frame: .zero)
    public let placeholderLabel = STLabel(frame: .zero)

    // Text
    open var text: String? {
        get { textView.text }
        set {
            // Single line: collapse any newlines into spaces
            textView.text = newValue.map { value in
                value.replacingOccurrences(of: "\r\n", with: " ")
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
            }

            // Update placeholder
            _updatePlaceholderShown()
        }
    }

    open var placeholder: String? {
        get { placeholderLabel.text }
        set {
            placeholderLabel.text = newValue

            // Lay out and update placeholder
            //_layoutPlaceholder()
            _updatePlaceholderShown()
        }
    }

    open var fontSize: CGFloat {
        get { textView.fontSize }
        set {
            textView.fontSize = newValue
            placeholderLabel.fontSize = newValue

            // Lay out placeholder
            //_layoutPlaceholder()
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//

    private func _init() {
        // Configure placeholder label
        placeholderLabel.direction = .lrTb
        placeholderLabel.fontSize = 16.0
        placeholderLabel.textAlign = .leading
        placeholderLabel.context.textColor = .placeholderTextColor
        placeholderLabel.frame = bounds.insetBy(dx: 2, dy: 1)
        placeholderLabel.autoresizingMask = [.width, .height]
        addSubview(placeholderLabel)

        // Configure inner text view (single line, horizontal)
        textView.direction = .lrTb
        textView.isSingleLine = true
        textView.fontSize = 16.0
        textView.textAlign = .leading
        textView.hasVerticalScroller = false
        textView.hasHorizontalScroller = false
        textView.verticalScrollElasticity = .none
        textView.horizontalScrollElasticity = .none

        // Make the text view transparent so the placeholder behind it shows
        textView.drawsBackground = false
        textView.contentView.drawsBackground = false
        textView.frame = bounds
        textView.autoresizingMask = [.width, .height]
        addSubview(textView)

        // Observe inner text view notifications to toggle placeholder and re-post as our own
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(_textChanged(_:)), name: STTextView.textChanged, object: textView)
        center.addObserver(self, selector: #selector(_selectionChanged(_:)), name: STTextView.selectionChanged, object: textView)
        center.addObserver(self, selector: #selector(_contentSizeChanged(_:)), name: STTextView.contentSizeChanged, object: textView)
        center.addObserver(self, selector: #selector(_enterPressed(_:)), name: STTextView.enterPressed, object: textView)

        // Update placeholder
        _updatePlaceholderShown()
    }

    public override init(frame frameRect: NSRect) {
        // Invoke super
        super.init(frame: frameRect)

        // Common init
        _init()
    }

    public required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)

        // Common init
        _init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    //--------------------------------------------------------------//
    // MARK: - Placeholder
    //--------------------------------------------------------------//

    @objc private func _textChanged(_ notification: Notification) {
        // Update placeholder
        _updatePlaceholderShown()

        // Re-post as our own notification
        NotificationCenter.default.post(name: STTextField.textChanged, object: self)
    }

    @objc private func _selectionChanged(_ notification: Notification) {
        // Re-post as our own notification
        NotificationCenter.default.post(name: STTextField.selectionChanged, object: self)
    }

    @objc private func _contentSizeChanged(_ notification: Notification) {
        // Re-post as our own notification
        NotificationCenter.default.post(name: STTextField.contentSizeChanged, object: self)
    }

    @objc private func _enterPressed(_ notification: Notification) {
        // Re-post as our own notification
        NotificationCenter.default.post(name: STTextField.enterPressed, object: self)
    }

    private func _updatePlaceholderShown() {
        // Show placeholder only while the text is empty
        let isTextEmpty = textView.text?.isEmpty ?? true
        placeholderLabel.isHidden = !isTextEmpty
    }

    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//

    open override func layout() {
        // Invoke super
        super.layout()

        // Layout inner views
        textView.frame = bounds
        placeholderLabel.frame = bounds.insetBy(dx: 2, dy: 1)
    }

    //--------------------------------------------------------------//
    // MARK: - Responder
    //--------------------------------------------------------------//

    open override var acceptsFirstResponder: Bool {
        return true
    }

    open override func becomeFirstResponder() -> Bool {
        // Forwad to inner text view
        return window?.makeFirstResponder(textView) ?? false
    }
    
    open override func selectAll(_ sender: Any?) {
        // Forwad to inner text view
        textView.selectAll(sender)
    }
}
#endif
#endif
