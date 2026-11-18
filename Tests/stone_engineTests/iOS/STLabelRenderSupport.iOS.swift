/*
STLabelRenderSupport.swift

STLabel をオフスクリーンで描いて調べるための共通の土台（iOS 版）。

macOS 版は NSView.cacheDisplay(in:to:) と NSBitmapImageRep.colorAt(x:y:) を
使っていた。UIKit には後者に当たるものがないので、UIGraphicsImageRenderer で
描いたうえで、画素の並びが分かっているビットマップに写し取って読む。

座標は macOS 版と同じ「左上原点・y は下向き」にそろえてある
（macOS の STLabel は isFlipped、UIView はもともとこの向き）。
そのため macOS 版の判定文はそのまま通る。

背景も macOS 版にそろえる。iOS の STLabel は不透過の背景を持つので、
描いたものを画素のアルファで見分けるには抜いておく必要がある。
*/

#if os(iOS)
import XCTest
@testable import stone_engine

/// 画素を読めるビットマップ。row 0 が画像の上端。
struct STTestBitmap {
    let pixelsWide: Int
    let pixelsHigh: Int
    let scale: CGFloat
    private let bytes: [UInt8]

    init(pixelsWide: Int, pixelsHigh: Int, scale: CGFloat, bytes: [UInt8]) {
        self.pixelsWide = pixelsWide
        self.pixelsHigh = pixelsHigh
        self.scale = scale
        self.bytes = bytes
    }

    /// premultipliedLast なので、順は R G B A。
    func component(x: Int, y: Int, _ index: Int) -> CGFloat {
        guard x >= 0, x < pixelsWide, y >= 0, y < pixelsHigh else { return 0 }
        return CGFloat(bytes[(y * pixelsWide + x) * 4 + index]) / 255.0
    }

    func alpha(x: Int, y: Int) -> CGFloat { component(x: x, y: y, 3) }

    /// 2 つのビットマップで、色かアルファが threshold を超えて違う画素の割合。
    func differenceRatio(from other: STTestBitmap, threshold: CGFloat = 0.1) -> (ratio: Double, note: String?) {
        guard pixelsWide == other.pixelsWide, pixelsHigh == other.pixelsHigh else {
            return (1.0, "寸法が違う \(other.pixelsWide)x\(other.pixelsHigh) → \(pixelsWide)x\(pixelsHigh)")
        }

        var differing = 0
        for y in 0 ..< pixelsHigh {
            for x in 0 ..< pixelsWide {
                var delta: CGFloat = 0
                for i in 0 ..< 4 {
                    delta = max(delta, abs(component(x: x, y: y, i) - other.component(x: x, y: y, i)))
                }
                if delta > threshold { differing += 1 }
            }
        }

        return (Double(differing) / Double(pixelsWide * pixelsHigh), nil)
    }

    /// PNG にする（スナップショットの保存・比較用）。
    func pngData() -> Data? {
        var copy = bytes
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(copy) as CFData),
              let image = CGImage(
                width: pixelsWide, height: pixelsHigh,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: pixelsWide * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return nil }
        copy.removeAll()

        return UIImage(cgImage: image).pngData()
    }

    /// PNG から読み戻す。
    ///
    /// pngData() は row 0 を画像の上端として CGImage を組むので、
    /// 読み戻すときに反転は要らない。入れると往復が鏡像になる
    /// （実測で確認: 反転したものと比べると差分 0%）。
    static func from(pngData: Data) -> STTestBitmap? {
        guard let image = UIImage(data: pngData), let cgImage = image.cgImage else { return nil }
        return from(cgImage: cgImage, scale: image.scale, flipped: false)
    }

    /// CGImage を、画素を読めるビットマップに写し取る。
    ///
    /// - Parameter flipped: 写すときに上下を入れ替えるか。
    ///   どちらが要るかは経路ごとに違い、いずれも実測で決めている。
    ///   描画の経路（render）は反転が必要で、PNG の読み戻しは不要。
    static func from(cgImage: CGImage, scale: CGFloat, flipped: Bool = true) -> STTestBitmap? {
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let success = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }

            if flipped {
                context.translateBy(x: 0, y: CGFloat(height))
                context.scaleBy(x: 1, y: -1)
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            return true
        }
        guard success else { return nil }

        return STTestBitmap(pixelsWide: width, pixelsHigh: height, scale: scale, bytes: bytes)
    }
}

class STLabelRenderTestCase: XCTestCase {

    //--------------------------------------------------------------//
    // MARK: - Helpers
    //--------------------------------------------------------------//

    /// 指定の設定で STLabel を作り、レイアウトまで済ませる。
    func makeLabel(
        text: String,
        size: CGSize = CGSize(width: 16 * 10, height: 16 * 6),
        direction: STDirection = .lrTb,
        fontSize: CGFloat = 16,
        configure: ((STLabel) -> Void)? = nil
    ) -> STLabel {
        let label = STLabel(frame: CGRect(origin: .zero, size: size))

        // iOS の STLabel は不透過の背景（systemBackground）を持つ。そのままだと
        // 画素のアルファで字面を見分けられないので、背景を抜く。
        // macOS の STLabel は背景を持たないので、これで条件がそろう。
        label.backgroundColor = .clear

        label.fontSize = fontSize
        label.direction = direction
        label.text = text
        configure?(label)

        // iOS の STLabel は layoutSubviews で、パース・レイアウトと
        // 描画バケツの作成（createDrawBcukets）をまとめて行う。
        // parseAndLayout() だけ呼んでもバケツが空のままで何も描かれないので、
        // UIKit がするのと同じくレイアウトを走らせる。
        label.setNeedsLayout()
        label.layoutIfNeeded()

        return label
    }

    /// STLabel をオフスクリーンで描いてビットマップにする。
    ///
    /// STLabel の描画は、UIKit が drawRect を呼ぶときの座標系を前提にしている。
    /// UIGraphicsImageRenderer の文脈へそのまま描くと、字形も位置も上下が
    /// 反転する（実測: 'T' の横棒が下に出て、1 行目が下端に出る）。
    /// 文脈を一度反転してから描くと、両方そろって正しくなり、
    /// ランの frame と同じ座標で読める。
    ///
    /// layer.render(in:) は使わない。backing layer が CATiledLayer
    /// （STTiledLayer）で、タイルの描画が絡むと結果が読みにくい。
    func render(_ label: STLabel, scale: CGFloat = 2) throws -> STTestBitmap {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(bounds: label.bounds, format: format)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: label.bounds.height)
            cgContext.scaleBy(x: 1, y: -1)
            label.draw(label.bounds)
        }

        let cgImage = try XCTUnwrap(image.cgImage, "描いた結果を取り出せない")

        return try XCTUnwrap(
            STTestBitmap.from(cgImage: cgImage, scale: scale),
            "ビットマップに写し取れない"
        )
    }

    /// インク（背景でない画素）が乗っている領域。何も描かれていなければ nil。
    func inkBounds(_ bitmap: STTestBitmap) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0 ..< bitmap.pixelsHigh {
            for x in 0 ..< bitmap.pixelsWide {
                guard bitmap.alpha(x: x, y: y) > 0.05 else { continue }
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }

        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// インクの乗った画素の割合。
    func inkRatio(_ bitmap: STTestBitmap) -> Double {
        var count = 0
        for y in 0 ..< bitmap.pixelsHigh {
            for x in 0 ..< bitmap.pixelsWide {
                if bitmap.alpha(x: x, y: y) > 0.05 { count += 1 }
            }
        }

        return Double(count) / Double(bitmap.pixelsWide * bitmap.pixelsHigh)
    }
}
#endif
