/*
STTextView.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa

extension STTextView {
    public static let textChanged = Notification.Name("STTextViewTextChanged")
    public static let selectionChanged = Notification.Name("STTextViewSelectionChanged")
    public static let contentSizeChanged = Notification.Name("STTextViewContentSizeChanged")
    public static let enterPressed = Notification.Name("STTextViewEnterPressed")
    public static let didBecomeFirstResponder = Notification.Name("STTextViewDidBecomeFirstResponder")
    public static let didResignFirstResponder = Notification.Name("STTextViewDidResignFirstResponder")
}

// Kind of the current edit run, used to break undo groups
enum STUndoEditKind {
    case none
    case inserting
    case deleting
}

open class STTextView: NSScrollView {
    // Text
    open var text: String? {
        get {
            label.text
        }
        set {
            label.text = newValue
            keepTextRangesInText()
            needsLayout = true
            
            // Notify it
            NotificationCenter.default.post(name: STTextView.textChanged, object: self)
        }
    }
    
    private func keepTextRangesInText() {
        // Get text length
        let count = text?.count ?? 0

        // Keep selected range in text
        let selectedRange = selectedSTTextRange.range
        if selectedRange.upperBound > count {
            selectedSTTextRange = STTextRange(range: min(selectedRange.lowerBound, count) ..< count)
        }

        // Keep marked range in text
        if let markedRange = markedSTTextRange?.range, markedRange.upperBound > count {
            markedSTTextRange = STTextRange(range: min(markedRange.lowerBound, count) ..< count)
        }
    }
    
    // Layout
    open var fontSize: CGFloat {
        get {
            label.fontSize
        }
        set {
            label.fontSize = newValue
            needsLayout = true
        }
    }
    
    open var lineHeightScale: CGFloat {
        get {
            label.lineHeightScale
        }
        set {
            label.lineHeightScale = newValue
            needsLayout = true
        }
    }
    
    open var textAlign: STTextAlign {
        get {
            label.textAlign
        }
        set {
            label.textAlign = newValue
            needsLayout = true
        }
    }
    
    open var directionAlign: STDirectionAlign {
        get {
            label.directionAlign
        }
        set {
            label.directionAlign = newValue
            needsLayout = true
        }
    }
    
    open var direction: STDirection {
        get {
            label.direction
        }
        set {
            label.direction = newValue
            needsLayout = true
            
            // Update appearance
            updateScroller()
        }
    }
    
    open var isAllowedTateChuYoko: Bool {
        get {
            label.isAllowedTateChuYoko
        }
        set {
            label.isAllowedTateChuYoko = newValue
            needsLayout = true
        }
    }
    
    open var adjustsFontSizeToFitWidth: Bool {
        get {
            label.adjustsFontSizeToFitWidth
        }
        set {
            label.adjustsFontSizeToFitWidth = newValue
            needsLayout = true
        }
    }
    
    open var minimumScaleFactor: CGFloat {
        get {
            label.minimumScaleFactor
        }
        set {
            label.minimumScaleFactor = newValue
            needsLayout = true
        }
    }
    
    open var isFixedWidth: Bool {
        get {
            label.isFixedWidth
        }
        set {
            label.isFixedWidth = newValue
            needsLayout = true
        }
    }

    open var isSingleLine: Bool {
        get {
            label.isSingleLine
        }
        set {
            label.isSingleLine = newValue
            needsLayout = true
        }
    }
    
    open var hasSelectedAreaLineGap: Bool {
        get {
            label.hasSelectedAreaLineGap
        }
        set {
            label.hasSelectedAreaLineGap = newValue
            needsLayout = true
        }
    }
    
    // Text input
    open var selectedSTTextRange = STTextRange(range: 0 ..< 0) {
        didSet {
            // Update appearance
            updateCursorShown()

            // Forget the goal of the line moves, unless they moved the cursor. A
            // click, typing or a move along the line starts a new goal
            if !isMovingCursorByLine {
                cursorRectForUpDown = .zero
            }

            // Reset cursor blink phase on input / cursor move
            cursorView?.resetBlinking()

            // Redraw the selection. The layout itself is unaffected, so this must
            // not invalidate it.
            label?.needsDisplay = true

            // Set needs layout, to reposition the cursor view
            needsLayout = true

            // Notify it
            NotificationCenter.default.post(name: STTextView.selectionChanged, object: self)
        }
    }
    open var markedSTTextRange: STTextRange?
    open var markedRanges: [(Range<Int>, Bool)]?

    // Cursor
    open var isCursorShown: Bool = false {
        didSet {
            // Update appearance
            updateCursorShown()

            // Set needs layout
            needsLayout = true
        }
    }

    open var isWindowKey: Bool = true {
        didSet {
            // Update appearance
            updateCursorShown()

            // Set needs layout
            needsLayout = true
        }
    }

    open var isCursorBeginSelected = false
    open var cursorRectForUpDown: CGRect = .zero
    var isMovingCursorByLine = false
    open var mouseDownIndex: Int = 0
    open var needsToScrollToShowCurosr = false

    // The visible size the scroll position was last put on a line for. A change
    // means the lines moved under it (a resize, a different character size or
    // line spacing, a switch of writing direction).
    private var lastWholeLineVisibleSize: CGSize = .zero

    // Content size
    private var lastContentSize: CGSize = .zero
    
    // Undo
    let _undoManager = STUndoManager()
    open override var undoManager: UndoManager? { _undoManager }

    // Undo grouping state
    var undoEditKind: STUndoEditKind = .none
    var isComposingText = false

    // Views
    open var textDocumentView: STTextDocumentView!
    open var label: STLabel!
    open var cursorView: STCursorView!
    
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Configure itself
        clipsToBounds = true
        automaticallyAdjustsContentInsets = false
        contentInsets = .init(top: 1, left: 2, bottom: 1, right: 2)
        
        // Create text document view
        textDocumentView = STTextDocumentView(frame: .zero)
        addSubview(textDocumentView)
        documentView = textDocumentView
        
        // Create label
        label = STLabel(frame: .zero)
        label.textInput = self
        textDocumentView.addSubview(label)
        
        // Create cursor view
        cursorView = STCursorView(frame: .zero)

        // Update appearance
        updateScroller()

        // Observe layout notification
        NotificationCenter.default.addObserver(self, selector: #selector(_didLayout(_:)), name: STLayout.didLayout, object: nil)

        // Snap to whole lines once the user stops scrolling
        NotificationCenter.default.addObserver(
            self, selector: #selector(_didEndLiveScroll(_:)),
            name: NSScrollView.didEndLiveScrollNotification, object: self)

        // Configure undo manager
        _undoManager.textView = self
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func _didLayout(_ notification: Notification) {
        // Check if the notification is from our label's context
        guard let layout = notification.object as? STLayout, layout.context === label.context else { return }

        // Only react when the content size actually changed. Setting needs layout
        // unconditionally made every layout pass schedule another one.
        let contentSize = layout.context.renderedSize
        guard contentSize != lastContentSize else { return }
        lastContentSize = contentSize

        // Layout subviews to fit the new content size
        needsLayout = true

        // Notify content size change
        NotificationCenter.default.post(name: STTextView.contentSizeChanged, object: self)
    }

    //--------------------------------------------------------------//
    // MARK: - Window
    //--------------------------------------------------------------//

    open override func viewDidMoveToWindow() {
        // Invoke super
        super.viewDidMoveToWindow()

        // Remove previous window key observers
        let center = NotificationCenter.default
        center.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        center.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)

        // Observe key state of the current window
        if let window = window {
            center.addObserver(self, selector: #selector(_windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(_windowDidResignKey(_:)), name: NSWindow.didResignKeyNotification, object: window)

            // Sync current key state
            isWindowKey = window.isKeyWindow
        }
    }

    @objc private func _windowDidBecomeKey(_ notification: Notification) {
        // Window became frontmost
        isWindowKey = true
    }

    @objc private func _windowDidResignKey(_ notification: Notification) {
        // Window is no longer frontmost
        isWindowKey = false
    }

    public override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)
        
        // Common init
        _init()
    }
    
    required public init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)
        
        // Common init
        _init()
    }
    
    open override var isFlipped: Bool {
        true
    }
    
    //--------------------------------------------------------------//
    // MARK: - Apperance
    //--------------------------------------------------------------//
    
    private func updateScroller() {
        // Switch by direction
        switch direction {
        case .lrTb:
            // For horizontal scroller
            horizontalScrollElasticity = .none
            hasHorizontalScroller = false

            // For vertical scroller
            verticalScrollElasticity = .allowed
            hasVerticalScroller = true
        case .tbRl:
            // For horizontal scroller
            horizontalScrollElasticity = .allowed
            hasHorizontalScroller = true
             
            // For vertical scroller
            verticalScrollElasticity = .none 
            hasVerticalScroller = false
        }
    }
    
    private func updateCursorShown() {
        // Decide cursor shown
        let shown = isCursorShown && selectedSTTextRange.isEmpty && isWindowKey
        
        // For shown
        if shown && cursorView.superview == nil {
            textDocumentView.addSubview(cursorView)
        }
        // For hidden
        else if !shown && cursorView.superview != nil {
            cursorView.removeFromSuperview()
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    open func layoutTextDocumentViewH() {
        var rect: CGRect = .zero
        
        // Decide label size
        let contentFrame = CGRect(origin: .zero, size: bounds.size).inset(by: contentInsets)
        let renderSize = contentFrame.size
        let renderedSize = label.sizeThatFits(renderSize)
        
        // Layout text document view
        rect.origin.x = 0
        rect.origin.y = 0
        // For single line, grow width with content so it scrolls horizontally
        if isSingleLine {
            rect.size.width = max(bounds.width, renderedSize.width + contentInsets.left + contentInsets.right)
        }
        else {
            rect.size.width = bounds.width
        }
        rect.size.height = renderedSize.height + contentInsets.top + contentInsets.bottom
        textDocumentView.frame = rect
    }

    open func layoutTextDocumentViewV() {
        var rect: CGRect = .zero
        
        // Decide label size
        let contentFrame = CGRect(origin: .zero, size: bounds.size).inset(by: contentInsets)
        let renderSize = contentFrame.size
        let renderedSize = label.sizeThatFits(renderSize)
        
        // Layout text document view
        rect.origin.x = 0
        rect.origin.y = 0
        // Vertical text starts from the right edge. Keep the document at least as
        // wide as the view, so short text sits against the right edge and new lines
        // are added to its left, the way horizontal text sits at the top and new
        // lines go below it. A narrower document would be pinned to the left of the
        // view instead, and every new line would push the text before it rightward.
        rect.size.width = max(renderedSize.width + contentInsets.left + contentInsets.right, bounds.width)
        rect.size.height = bounds.height
        textDocumentView.frame = rect
    }
    
    open func layoutTextDocumentView() {
        // Switch by direction
        switch direction {
        case .lrTb: layoutTextDocumentViewH()
        case .tbRl: layoutTextDocumentViewV()
        }
    }
    
    open func layoutLabelH() {
        var rect: CGRect = .zero
        
        // Decide label frame from text document view
        rect = textDocumentView.frame.inset(by: contentInsets)
        
        // Layout label
        label.frame = rect
    }
    
    open func layoutLabelV() {
        var rect: CGRect = .zero
        
        // Decide label frame from text document view
        rect = textDocumentView.frame.inset(by: contentInsets)

        // Fit the label to the text and put it against the right edge, where
        // vertical text begins. The document can be wider than the text (it is
        // never narrower than the view), and the label lays its lines out from
        // its own right edge while placing an empty last line by the width the
        // text takes, so the two have to agree. The iOS view does the same.
        let width = min(label.context.renderedSize.width, rect.width)
        rect.origin.x = rect.maxX - width
        rect.size.width = width
        
        // Layout label
        label.frame = rect
    }
    
    open func layoutLabel() {
        // Switch by direction
        switch direction {
        case .lrTb: layoutLabelH()
        case .tbRl: layoutLabelV()
        }
    }
    
    open func layoutCursorView() {
        // Check cursor shown
        guard isCursorShown else { return }

        // Convert cursor frame
        let cursorFrame = textDocumentView.convert(label.context.cursorFrame(at: selectedSTTextRange.end.index), from: label)
        
        // Set cursor view frame
        cursorView.frame = cursorFrame
    }

    // The end of the selection that is moving.
    //
    // STTextRange only ever holds an ascending range, so the range itself does
    // not say which end the user is dragging. isCursorBeginSelected remembers
    // it. Scrolling has to follow this end: using the range's upper bound
    // unconditionally means an upward drag or a shift-up selection chases the
    // anchor, which is already on screen, and the view never scrolls.
    open var movingSelectionIndex: Int {
        let range = selectedSTTextRange.range
        return isCursorBeginSelected ? range.lowerBound : range.upperBound
    }

    open func scrollCursorToVisible() {
        // Get cursor frame in documentView coordinates
        let cursorInLabel = label.context.cursorFrame(at: movingSelectionIndex)
        let cursorInDoc = textDocumentView.convert(cursorInLabel, from: label)

        // Pad along the scrollable axis so the cursor isn't flush with the edge
        let padded: CGRect
        switch direction {
        case .lrTb: padded = cursorInDoc.insetBy(dx: 0, dy: -fontSize * 0.5)
        case .tbRl: padded = cursorInDoc.insetBy(dx: -fontSize * 0.5, dy: 0)
        }

        // Scroll
        textDocumentView.scrollToVisible(padded)
    }

    @objc private func _didEndLiveScroll(_ notification: Notification) {
        // Snap to whole lines
        scrollToWholeLines(animated: true)
    }

    // Duration of the nudge that pushes a part-shown line out of view
    public static let wholeLineScrollDuration: TimeInterval = 0.1

    // Tolerance for treating an edge as already sitting on a line boundary
    private static let wholeLineEpsilon: CGFloat = 0.5

    // Which boundary of a straddling line the edge is moved onto
    public enum WholeLineSnap {
        // The nearer of the two, so the line is shown whole or scrolled out,
        // whichever is the shorter nudge. This is what a stopped scroll wants.
        case nearest

        // The one that keeps the line on screen. Used after scrolling to follow
        // the caret, where scrolling the line out would take the caret with it.
        case showing
    }

    // A scroll can stop with a line straddling the edge the text starts from - the
    // top in horizontal writing, the right in vertical - so that only part of that
    // line shows. Move the edge onto a boundary of that line, so it is either shown
    // whole or scrolled out. Nothing moves when the edge already falls between two
    // lines.
    open func scrollToWholeLines(animated: Bool, snap: WholeLineSnap = .nearest) {
        // Check runs
        guard !label.context.runs.isEmpty else { return }

        // Get visible rect
        let visibleRect = documentVisibleRect
        guard !visibleRect.isEmpty else { return }

        // Get the edge the text starts from
        let epsilon = Self.wholeLineEpsilon
        let edge: CGFloat
        switch direction {
        case .lrTb: edge = visibleRect.minY
        case .tbRl: edge = visibleRect.maxX
        }

        // Union the runs the edge cuts through. Every run on that line reports
        // nearly the same extent across the line, so the union is the line's band.
        var lower: CGFloat = .greatestFiniteMagnitude
        var upper: CGFloat = -.greatestFiniteMagnitude
        for run in label.context.runs {
            // Skip the runs that carry no glyph of their own
            guard !run.isNewline, !run.isHidden else { continue }

            // Get run rect in document view coordinates
            let runRect = textDocumentView.convert(run.frame, from: label)
            let runLower: CGFloat, runUpper: CGFloat
            switch direction {
            case .lrTb: runLower = runRect.minY; runUpper = runRect.maxY
            case .tbRl: runLower = runRect.minX; runUpper = runRect.maxX
            }

            // Check the run is cut by the edge
            guard runLower < edge - epsilon, runUpper > edge + epsilon else { continue }

            // Union the band
            lower = min(lower, runLower)
            upper = max(upper, runUpper)
        }

        // For no line on the edge, it already falls between two lines
        guard lower < upper else { return }

        // Move the edge to a boundary of that line
        let boundary: CGFloat
        switch snap {
        case .nearest:
            boundary = (edge - lower) <= (upper - edge) ? lower : upper
        case .showing:
            // The side the line begins on: its top in horizontal writing, its
            // right in vertical. Putting the edge there leaves the line inside.
            boundary = direction == .lrTb ? lower : upper
        }

        // Decide scroll point
        var point: CGPoint
        switch direction {
        case .lrTb: point = .init(x: visibleRect.minX, y: boundary)
        case .tbRl: point = .init(x: boundary - visibleRect.width, y: visibleRect.minY)
        }

        // Keep the point inside the scrollable range
        let documentRect = contentView.documentRect
        point.x = min(max(point.x, documentRect.minX), max(documentRect.maxX - visibleRect.width, documentRect.minX))
        point.y = min(max(point.y, documentRect.minY), max(documentRect.maxY - visibleRect.height, documentRect.minY))

        // Check the point is worth scrolling to
        guard abs(point.x - visibleRect.minX) > epsilon || abs(point.y - visibleRect.minY) > epsilon else { return }

        // Scroll to point
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                // Configure context
                context.allowsImplicitAnimation = true
                context.duration = Self.wholeLineScrollDuration

                // Scroll itself
                contentView.animator().setBoundsOrigin(point)
                reflectScrolledClipView(contentView)
            })
        }
        else {
            // Scroll itself
            contentView.setBoundsOrigin(point)
            reflectScrolledClipView(contentView)
        }
    }

    // Gives the document view and the label the size this view constrains them to,
    // before anything measures. The measurement in layoutTextDocumentView() can
    // then reuse the label's own layout instead of laying out a throwaway copy of
    // the whole document, which is what made resizing expensive.
    open func prepareConstrainedFrames() {
        var rect = textDocumentView.frame
        switch direction {
        case .lrTb:
            rect.size.width = bounds.width
            rect.size.height = max(rect.size.height, bounds.height)
        case .tbRl:
            rect.size.height = bounds.height
            rect.size.width = max(rect.size.width, bounds.width)
        }
        if rect != textDocumentView.frame {
            textDocumentView.frame = rect
        }

        // Layout label at that constrained size
        layoutLabel()
    }

    open override func layout() {
        // Invoke super
        super.layout()

        // Remember how far the visible area is from the right edge of the document.
        // In vertical writing the document begins on the right and grows to the
        // left, so a line added or removed changes its width, and the text already
        // laid out moves with the right edge.
        let documentWidth = textDocumentView.frame.width
        let distanceFromRight = documentWidth - contentView.bounds.origin.x

        // Constrain the label before measuring
        prepareConstrainedFrames()

        // Layout document view
        layoutTextDocumentView()

        // Keep the visible area where it was against the text. Without this a new
        // line pushes everything on screen one line toward the beginning, while in
        // horizontal writing the text stays put and the new line comes in below it.
        if direction == .tbRl, textDocumentView.frame.width != documentWidth {
            var visible = contentView.bounds
            visible.origin.x = textDocumentView.frame.width - distanceFromRight
            contentView.setBoundsOrigin(contentView.constrainBoundsRect(visible).origin)
            reflectScrolledClipView(contentView)
        }

        // Layout label
        // Force label to finish its layout so run frames and cursor position are current
        layoutLabel()
        label.layoutSubtreeIfNeeded()
        
        // Layout cursor
        layoutCursorView()
        
        // Scroll to show cursor if requested
        if needsToScrollToShowCurosr {
            needsToScrollToShowCurosr = false
            scrollCursorToVisible()

            // Following the caret scrolls by the least it can, which leaves the
            // caret's line straddling the edge. Push it back in.
            scrollToWholeLines(animated: false, snap: .showing)
        }
        // Resizing the window, or changing the size the text is set in, moves the
        // lines under a scroll position that was snapped to the old ones. Nothing
        // posts a scroll notification for that, so the position is put back on a
        // line here.
        else if documentVisibleRect.size != lastWholeLineVisibleSize {
            scrollToWholeLines(animated: false)
        }
        lastWholeLineVisibleSize = documentVisibleRect.size
    }

    // Page scrolling is not hooked here. NSResponder only declares
    // scrollPageDown: and friends through NSStandardKeyBindingResponding and does
    // not implement them, so calling super raises unrecognized selector - and
    // stone does not implement them either, so those keys scroll nothing today.
    // Making them work is a separate piece of work, not a snap.
}
#endif

#if os(macOS)
extension CGRect {
    func inset(by insets: NSEdgeInsets) -> CGRect {
        return CGRect(
            x: origin.x + insets.left,
            y: origin.y + insets.top,
            width: size.width - insets.left - insets.right,
            height: size.height - insets.top - insets.bottom
        )
    }
}
#endif
