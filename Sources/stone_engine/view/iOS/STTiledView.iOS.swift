/*
STTiledView.iOS.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit

/// A view that draws itself in tiles, without the tiles being seen to tear.
///
/// Subclasses draw in `draw(_:)` as any view does, in their own coordinates.
/// The drawing is not done into this view's own layer, though, but into a
/// tiled layer behind it (`tiledContentView`), so that a long text need not be
/// held in one image.
///
/// A tiled layer draws its tiles later, on other threads, and shows each one
/// as it is drawn. Where a change moves what is drawn across several tiles -
/// a line broken in the middle of a text moves every line after it - the
/// tiles drawn again come up a frame or more apart, and for those frames the
/// text is shown half before the change and half after: it flickers. So when
/// something is to be drawn again, the part of this view that is on screen is
/// drawn at once, on the main thread, into a view laid over the tiles
/// (`overlayView`), which shows the change whole. It is taken away once the
/// tiles under it have all been drawn again, which shows the same.
///
/// The tiles have a second way of showing the text out of place. They are
/// drawn in the tiled layer's coordinates, and vertical text, laid out from
/// the right edge and growing to the left, moves every character across in
/// this view's coordinates each time a line is added, so every tile would
/// have to be drawn again for it. Where `anchorsToRightEdge` is true, the
/// tiled layer takes its coordinates from the right edge instead, so that
/// what is already drawn keeps its place in the tiles as the view grows to
/// the left.
///
/// This view's own coordinates are left as they are: whatever converts to and
/// from them, and whatever draws in them, needs to know nothing of either.
open class STTiledView: UIView {
    /// The view that holds the tiles. It covers this view and draws by calling
    /// this view's `draw(_:)`.
    public let tiledContentView = STTiledContentView(frame: .zero)

    /// The view laid over the tiles while they are being drawn again. It
    /// covers the part of this view on screen and draws by calling this view's
    /// `draw(_:)`, at once.
    public let overlayView = STTiledOverlayView(frame: .zero)

    /// Whether the tiles are fixed against the right edge. True where the
    /// content is laid out from the right edge and grows to the left, as
    /// vertical text is.
    open var anchorsToRightEdge: Bool { false }

    // Whether the overlay is to be put over what is on screen at the next layout
    private var needsToLayoutOverlay = false

    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//

    private func _init() {
        // Add tiled content view behind everything else
        tiledContentView.owner = self
        insertSubview(tiledContentView, at: 0)

        // Add overlay view over the tiles
        overlayView.owner = self
        overlayView.isHidden = true
        insertSubview(overlayView, aboveSubview: tiledContentView)
    }

    public override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)

        // Common init
        _init()
    }

    public required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)

        // Common init
        _init()
    }

    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//

    open override func layoutSubviews() {
        // Invoke super
        super.layoutSubviews()

        // Layout tiled content view
        layoutTiledContentView()

        // Layout overlay view
        if needsToLayoutOverlay {
            needsToLayoutOverlay = false
            layoutOverlayView()
        }
    }

    /// Puts the tiled content view over this view, with its coordinates taken
    /// from the right edge where `anchorsToRightEdge` is true.
    open func layoutTiledContentView() {
        // Decide how far the tiles' coordinates are from ours
        let offsetX = anchorsToRightEdge ? bounds.width : 0

        // Check anything changed
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let contentBounds = CGRect(origin: .init(x: bounds.minX - offsetX, y: bounds.minY), size: bounds.size)
        guard tiledContentView.bounds != contentBounds || tiledContentView.center != center else { return }

        // Layout without animation. The tiles have to move with this view in
        // the same frame, or the text is shown out of place while they catch up.
        UIView.performWithoutAnimation {
            tiledContentView.offsetX = offsetX
            tiledContentView.bounds = contentBounds
            tiledContentView.center = center
        }
    }

    /// The part of this view on screen: what the nearest scroll view, or else
    /// the window, shows of it.
    open var visibleBounds: CGRect {
        // Find the view that clips us
        var view = superview
        while let current = view, !(current is UIScrollView) {
            view = current.superview
        }
        guard let clippingView = view ?? window else { return .zero }

        // Convert what it shows to our coordinates
        return convert(clippingView.bounds, from: clippingView).intersection(bounds)
    }

    /// Puts the overlay over the part of this view on screen and has it drawn.
    open func layoutOverlayView() {
        // Decide where to cover. Nothing on screen needs no overlay.
        let rect = visibleBounds
        guard window != nil, !rect.isNull, !rect.isEmpty else {
            hideOverlayView()
            return
        }

        // Layout overlay over that part, in our own coordinates
        UIView.performWithoutAnimation {
            overlayView.frame = rect
            overlayView.bounds = rect
            overlayView.fillColor = overlayFillColor
            overlayView.isHidden = false
            overlayView.setNeedsDisplay()
        }

        // Take the overlay away once the tiles under it are drawn again
        tiledContentView.waitForTiles(covering: rect.offsetBy(dx: -tiledContentView.offsetX, dy: 0)) { [weak self] in
            self?.hideOverlayView()
        }
    }

    /// Takes the overlay away, and the image it holds.
    open func hideOverlayView() {
        overlayView.isHidden = true
        overlayView.layer.contents = nil
    }

    /// What the overlay is filled with before it is drawn on: the first colour
    /// behind us. The overlay hides the tiles, which are to show through
    /// nowhere, so it cannot be left clear where we are.
    open var overlayFillColor: UIColor {
        // Find the first view with a colour, from us outwards
        var view: UIView? = self
        while let current = view {
            if let color = current.backgroundColor, color.resolvedColor(with: traitCollection).cgColor.alpha > 0 {
                return color
            }
            view = current.superview
        }

        return .systemBackground
    }

    //--------------------------------------------------------------//
    // MARK: - Display
    //--------------------------------------------------------------//

    // Our own layer draws nothing: the tiled content view and the overlay draw
    // what we do. Leaving it to draw too would hold the whole content in one
    // image again.
    open override func display(_ layer: CALayer) {
        // Hold no image
        layer.contents = nil
    }

    open override func setNeedsDisplay() {
        // Invoke super
        super.setNeedsDisplay()

        // Draw tiles again
        tiledContentView.setNeedsDisplay()

        // Show the change at once over the tiles
        setNeedsOverlay()
    }

    open override func setNeedsDisplay(_ rect: CGRect) {
        // Invoke super
        super.setNeedsDisplay(rect)

        // Draw tiles in that rect again
        tiledContentView.setNeedsDisplay(rect.offsetBy(dx: -tiledContentView.offsetX, dy: 0))

        // Show the change at once over the tiles
        setNeedsOverlay()
    }

    // The overlay is laid out at the next layout, not here. A change is drawn
    // from layout, and whoever holds us may scroll after laying us out (to
    // keep vertical text in place as it grows, say), so what is on screen is
    // known only once that is done. Our next layout comes right after our
    // superview's, in the same pass.
    private func setNeedsOverlay() {
        // Check on screen
        guard window != nil else { return }

        // Set needs layout
        needsToLayoutOverlay = true
        setNeedsLayout()
    }
}

/// The view behind an `STTiledView` that holds its tiles.
open class STTiledContentView: UIView {
    /// The view whose drawing this view holds.
    open weak var owner: UIView?

    /// How far this view's coordinates are from the owner's: a point at x in
    /// the owner is at x - offsetX here.
    ///
    /// Kept apart from `bounds`, because tiles are drawn on other threads and
    /// should not read the view's geometry there.
    open var offsetX: CGFloat = 0

    // Which round of drawing the tiles belong to. Moved on each time the
    // tiles are to be drawn again, so that a tile drawn before that is not
    // taken for one drawn after it. Read on the threads the tiles are drawn on.
    private let generationLock = NSLock()
    private var _generation = 0
    private var generation: Int {
        generationLock.lock()
        defer { generationLock.unlock() }
        return _generation
    }

    // What has to be drawn again before the waiting is over, what has been,
    // and whom to tell
    private var waitingRect: CGRect?
    private var drawnRects: [CGRect] = []
    private var waitingHandler: (() -> Void)?

    open override class var layerClass: AnyClass {
        // Use tiled layer
        return STTiledLayer.self
    }

    public override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)

        // Configure itself. Leave touches to the owner, and let its background show.
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear

        // Draw again for colors of new appearance. This also has UIKit set up
        // its record of trait changes for this view here, on the main thread.
        // Left alone, it is set up the first time the view is asked for its
        // traits, which is while a tile is being drawn on another thread, and
        // the view's teardown then frees it from under that thread.
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (view: STTiledContentView, _: UITraitCollection) in
            view.setNeedsDisplay()
        }
    }

    public required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)
    }

    //--------------------------------------------------------------//
    // MARK: - Waiting for tiles
    //--------------------------------------------------------------//

    /// Calls `handler` once the tiles covering `rect`, in this view's
    /// coordinates, have all been drawn again. Waiting again replaces the
    /// earlier wait, which is not called.
    open func waitForTiles(covering rect: CGRect, handler: @escaping () -> Void) {
        // Start a new round
        generationLock.lock()
        _generation += 1
        generationLock.unlock()

        // Wait for it
        waitingRect = rect
        drawnRects.removeAll()
        waitingHandler = handler
    }

    private func tileDidDraw(_ rect: CGRect, generation drawnGeneration: Int) {
        // Check it belongs to this round
        guard let waitingRect, drawnGeneration == generation else { return }

        // Check the tiles drawn cover what was waited for
        drawnRects.append(rect)
        guard Self.rects(drawnRects, cover: waitingRect) else { return }

        // Done waiting
        let handler = waitingHandler
        self.waitingRect = nil
        drawnRects.removeAll()
        waitingHandler = nil
        handler?()
    }

    /// Whether `rects` together cover `rect`. Looked at on a grid of points
    /// finer than any tile, which is enough for rects that are whole tiles.
    static func rects(_ rects: [CGRect], cover rect: CGRect) -> Bool {
        // Check each point on the grid
        let step: CGFloat = 8
        let inner = rect.insetBy(dx: 0.5, dy: 0.5)
        guard !inner.isEmpty else { return true }
        var y = inner.minY
        while true {
            var x = inner.minX
            while true {
                guard rects.contains(where: { $0.contains(CGPoint(x: x, y: y)) }) else { return false }
                if x >= inner.maxX { break }
                x = min(x + step, inner.maxX)
            }
            if y >= inner.maxY { break }
            y = min(y + step, inner.maxY)
        }

        return true
    }

    //--------------------------------------------------------------//
    // MARK: - Draw
    //--------------------------------------------------------------//

    open override func draw(_ rect: CGRect) {
        // Get owner and context
        guard let owner, let context = UIGraphicsGetCurrentContext() else { return }

        // Note the round this tile is drawn in, before drawing it
        let drawnGeneration = generation

        // Draw the owner in its own coordinates
        let offsetX = offsetX
        context.saveGState()
        context.translateBy(x: -offsetX, y: 0)
        owner.draw(rect.offsetBy(dx: offsetX, dy: 0))
        context.restoreGState()

        // Tell it is drawn
        DispatchQueue.main.async { [weak self] in
            self?.tileDidDraw(rect, generation: drawnGeneration)
        }
    }
}

/// The view laid over the tiles of an `STTiledView` while they are being
/// drawn again. Its bounds are in the owner's coordinates.
open class STTiledOverlayView: UIView {
    /// The view whose drawing this view shows.
    open weak var owner: UIView?

    /// What to fill with before drawing the owner on it.
    open var fillColor: UIColor = .systemBackground

    public override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)

        // Configure itself. Leave touches to the owner.
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
    }

    public required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)
    }

    open override func draw(_ rect: CGRect) {
        // Fill, so the tiles under do not show through
        fillColor.setFill()
        UIRectFill(rect)

        // Draw the owner. Our coordinates are the owner's.
        owner?.draw(rect)
    }
}
#endif
