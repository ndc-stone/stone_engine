/*
STTextView.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

class TrackpadPanGestureRecognizer: UIPanGestureRecognizer {
    override func shouldReceive(_ event: UIEvent) -> Bool {
        // Recieve only left click
        return event.buttonMask == .primary
    }
}

public class STTextView: UIScrollView {
    // Text
    public var text: String? {
        get { label.text }
        set {
            label.text = newValue
            setNeedsLayout()
        }
    }
    
    // Layout
    public var fontSize: CGFloat {
        get { label.fontSize }
        set {
            label.fontSize = newValue
            setNeedsLayout()
        }
    }
    public var lineHeightScale: CGFloat {
        get { label.lineHeightScale }
        set {
            label.lineHeightScale = newValue
            setNeedsLayout()
        }
    }
    public var textAlign: STTextAlign {
        get { label.textAlign }
        set {
            label.textAlign = newValue
            setNeedsLayout()
        }
    }
    public var directionAlign: STDirectionAlign {
        get { label.directionAlign }
        set {
            label.directionAlign = newValue
            setNeedsLayout()
        }
    }
    public var direction: STDirection {
        get { label.direction }
        set {
            label.direction = newValue
            setNeedsLayout()
        }
    }
    public var isAllowedTateChuYoko: Bool {
        get { label.isAllowedTateChuYoko }
        set {
            label.isAllowedTateChuYoko = newValue
            setNeedsLayout()
        }
    }
    public var adjustsFontSizeToFitWidth: Bool {
        get { label.adjustsFontSizeToFitWidth }
        set {
            label.adjustsFontSizeToFitWidth = newValue
            setNeedsLayout()
        }
    }
    public var minimumScaleFactor: CGFloat {
        get { label.minimumScaleFactor }
        set {
            label.minimumScaleFactor = newValue
            setNeedsLayout()
        }
    }
    
    // Color
    public var textColor: UIColor {
        get { label.textColor }
        set {
            label.textColor = newValue
            setNeedsLayout()
        }
    }
    
    // Features
    public var punctuationMode: STPunctuationMode {
        get { label.punctuationMode }
        set {
            label.punctuationMode = newValue
            setNeedsLayout()
        }
    }
    public var isKinsokuAvailable: Bool {
        get { label.isKinsokuAvailable }
        set {
            label.isKinsokuAvailable = newValue
            setNeedsLayout()
        }
    }
    public var isDividedByWords: Bool {
        get { label.isDividedByWords }
        set {
            label.isDividedByWords = newValue
            setNeedsLayout()
        }
    }
    
    // Text input
    public var selectedSTTextRange = STTextRange(range: 0 ..< 0) {
        didSet {
            // Update appearance
            updateCursorShown()
            updateKnobViews()
            
            // Set needs layout
            setNeedsLayout()
        }
    } 
    public var markedSTTextRange: STTextRange?
    public var markedRanges: [(Range<Int>, Bool)]?

    // Cursor
    public var isCursorShown: Bool = false {
        didSet {
            // Update appearance
            updateCursorShown()
            
            // Set needs layout
            setNeedsLayout()
        }
    }
    
    public var isCursorBeginSelected = false
    public var cursorRectForUpDown: CGRect = .zero
    public var needsToScrollToShowCurosr = false

    // Long press
    public var longPressPoint: CGPoint?
    var isLongPressing: Bool { longPressPoint != nil }
    
    // Knob drag
    public var isBeginKnobDragging: Bool?
    public var dragPivotIndex: Int?
    public var isKnobDragging: Bool { isBeginKnobDragging != nil }

    // Lens
    public var needsToShowLens: Bool?

    // Menu
    public var needsToShowMenu: Bool?

    // Views
    public var label: STLabel!
    public var cursorView: STCursorView!
    public var lensView: STLensView!
    public var beginKnobView: STKnobView!
    public var endKnobView: STKnobView!

    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Configure itself
        clipsToBounds = true
        contentInset = .init(top: 1, left: 2, bottom: 1, right: 2)
        
        // Create label
        label = STLabel(frame: .zero)
        label.textInput = self
        addSubview(label)
        
        // Create cursor view
        cursorView = STCursorView(frame: .zero)
        
        // Create lens view
        lensView = STLensView(frame: .zero)
        
        // Create knob views
        beginKnobView = STKnobView(frame: .zero)
        beginKnobView.isAtBegin = true
        endKnobView = STKnobView(frame: .zero)
        
        // Add gesture recognizers
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapRecognizer.delegate = self
        addGestureRecognizer(tapRecognizer)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longPressRecognizer.delegate = self
        addGestureRecognizer(longPressRecognizer)
        
        let trackpadPanRecognizer = TrackpadPanGestureRecognizer(target: self, action: #selector(trackpadPanAction(_:)))
        trackpadPanRecognizer.delegate = self
        addGestureRecognizer(trackpadPanRecognizer)
        
        let beginKnobPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(knobPanAction(_:)))
        beginKnobView.addGestureRecognizer(beginKnobPanRecognizer)
        
        let endKnobPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(knobPanAction(_:)))
        endKnobView.addGestureRecognizer(endKnobPanRecognizer)
    }
    
    override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)
        
        // Common init
        _init()
    }
    
    required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)
        
        // Common init
        _init()
    }
}

public extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Apperance
    //--------------------------------------------------------------//
    
    private func updateCursorShown() {
        // Decide cursor shown
        let shown = isCursorShown && selectedSTTextRange.isEmpty
        
        // For shown
        if shown && cursorView.superview == nil {
            addSubview(cursorView)
        }
        // For hidden
        else if !shown && cursorView.superview != nil {
            cursorView.removeFromSuperview()
        }
    }
    
    private func updateKnobViews() {
        // Set horizontal
        let isHorizontal = direction == .lrTb
        beginKnobView.isHorizontal = isHorizontal
        endKnobView.isHorizontal = isHorizontal
        
        // For selected
        if (selectedTextRange as? STTextRange)?.range.count ?? 0 > 0 || isKnobDragging {
            // Show knob views
            addSubview(beginKnobView)
            addSubview(endKnobView)
        }
        // For not selected
        else {
            // Hide knob views
            beginKnobView.removeFromSuperview()
            endKnobView.removeFromSuperview()
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Font
    //--------------------------------------------------------------//
    
    func fontNames(script: STScript) -> [String] { label.fontNames(script: script) }
    func setFontNames(_ fontNames: [String], script: STScript) { label.setFontNames(fontNames, script: script) }
    func fontScale(script: STScript) -> CGFloat { label.fontScale(script: script) }
    func setFontScale(_ fontScale: CGFloat, script: STScript) { label.setFontScale(fontScale, script: script) }
    
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    private func layoutLabel() {
        // Decide label size
        let contentFrame = CGRect(origin: .zero, size: frame.size).inset(by: contentInset)
        let renderSize = contentFrame.size
        let renderedSize = label.sizeThatFits(renderSize)
        
        // Layout label
        let frame: CGRect
        switch direction {
        case .lrTb: frame = .init(x: 0, y: 0, width: renderSize.width, height: renderedSize.height)
        case .tbRl: frame = .init(x: max(contentFrame.width - renderedSize.width, 0), y: 0, width: renderedSize.width, height: renderSize.height)
        }
        label.frame = frame
        
        // Layout if needed
        label.setNeedsLayout()
        label.layoutIfNeeded()
    }
    
    private func updateContentGeometry(oldOffset: CGPoint, oldSize: CGSize) {
        // Set content size
        contentSize = label.frame.size
        
        // Switch by direction
        switch direction {
        case .lrTb:
            break
        case .tbRl:
            // Keep right X position
            let offsetX: CGFloat
            if oldSize.width < bounds.width {
                offsetX = -contentInset.right
            }
            else {
                let rx = oldSize.width - (oldOffset.x + bounds.width)
                offsetX = contentSize.width - bounds.width - rx
            }
            
            // Set content offset
            contentOffset = .init(x: offsetX, y: oldOffset.y)
        }
    }
    
    private func layoutCursorView() {
        // Check cursor shown
        guard isCursorShown else { return }
        
        // Convert cursor frame
        let cursorFrame = convert(label.context.cursorFrame(at: selectedSTTextRange.end.index), from: label)
        let screenCursorFrame = convert(cursorFrame, to: nil)
        let screenFrame = convert(bounds, to: nil)
        
        // Check flag
        if needsToScrollToShowCurosr {
            // Update content offset to show cursor
            let offset = contentOffset
            switch direction {
            case .lrTb:
                if screenCursorFrame.minY < screenFrame.minY {
                    contentOffset = .init(x: offset.x, y: offset.y - (screenFrame.minY - screenCursorFrame.minY))
                }
                else if screenCursorFrame.maxY > screenFrame.maxY {
                    contentOffset = .init(x: offset.x, y: offset.y + screenCursorFrame.maxY - screenFrame.maxY)
                }
            case .tbRl:
                if screenCursorFrame.minX < screenFrame.minX {
                    contentOffset = .init(x: offset.x - (screenFrame.minX - screenCursorFrame.minX), y: offset.y)
                }
                else if screenCursorFrame.maxX > screenFrame.maxX {
                    contentOffset = .init(x: offset.x + screenCursorFrame.maxX - screenFrame.maxX, y: offset.y)
                }
            }
            
            // Clear flag
            needsToScrollToShowCurosr = false
        }
        
        // Set cursor view frame
        cursorView.frame = cursorFrame
    }
    
    private func layoutKnobViews() {
        var rect = CGRect.zero
        
        // Check knob view shown
        guard beginKnobView.superview != nil else { return }
        
        // Get index at selected
        guard let range = (selectedTextRange as? STTextRange)?.range else { return }
        
        // Get rect at index
        let startIndex = range.lowerBound
        let endIndex = range.upperBound < label.context.runs.count ? range.upperBound : range.upperBound - 1
        let startFrame = convert(label.context.runs[startIndex].frame, from: label)
        let endFrame = convert(label.context.runs[endIndex].frame, from: label)
        let isAtEnd = range.upperBound < label.context.runs.count ? false : true
        
        // Switch by direction
        switch direction {
        case .lrTb:
            // Layout begin knob view
            rect.size.width = STKnobView.knobWide
            rect.size.height = startFrame.height + STKnobView.headWide * 2
            rect.origin.x = startFrame.minX - rect.width * 0.5
            rect.origin.y = startFrame.minY - STKnobView.headWide
            beginKnobView.frame = rect
            
            // Layout end knob view
            rect.size.width = STKnobView.knobWide
            rect.size.height = endFrame.height + STKnobView.headWide * 2
            rect.origin.x = isAtEnd ? endFrame.maxX - rect.width * 0.5 : endFrame.minX - rect.width * 0.5
            rect.origin.y = endFrame.minY - STKnobView.headWide
            endKnobView.frame = rect
        case .tbRl:
            // Layout begin knob view
            rect.size.width = startFrame.width + STKnobView.headWide * 2
            rect.size.height = STKnobView.knobWide
            rect.origin.x = startFrame.minX - STKnobView.headWide
            rect.origin.y = startFrame.minY - rect.height * 0.5
            beginKnobView.frame = rect
            
            // Layout end knob view
            rect.size.width = endFrame.width + STKnobView.headWide * 2
            rect.size.height = STKnobView.knobWide
            rect.origin.x = endFrame.minX - STKnobView.headWide
            rect.origin.y = isAtEnd ? endFrame.maxY - rect.height * 0.5 : endFrame.minY - rect.height * 0.5
            endKnobView.frame = rect
        }
    }
    
    public override func layoutSubviews() {
        // Invoke super
        super.layoutSubviews()
        
        // Keep geometry
        let oldOffset = contentOffset
        let oldSize = contentSize
        
        // Layout label
        layoutLabel()
        
        // Update geometry
        updateContentGeometry(oldOffset: oldOffset, oldSize: oldSize)
        
        // Layout subviews
        layoutCursorView()
        layoutKnobViews()
    }
}
