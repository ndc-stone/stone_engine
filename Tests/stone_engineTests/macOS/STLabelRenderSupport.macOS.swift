/*
STLabelRenderSupport.swift

STLabel をオフスクリーンで描いて調べるための共通の土台。
描画パスの検証（STLabelRenderTests）と画素の突き合わせ（STLabelSnapshotTests）が
どちらも使う。テストメソッドは持たない。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
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
        label.fontSize = fontSize
        label.direction = direction
        label.text = text
        configure?(label)
        label.parseAndLayout()

        return label
    }

    /// STLabel をオフスクリーンで描いてビットマップにする。
    func render(_ label: STLabel) throws -> NSBitmapImageRep {
        let rep = try XCTUnwrap(
            label.bitmapImageRepForCachingDisplay(in: label.bounds),
            "ビットマップを用意できない"
        )
        label.cacheDisplay(in: label.bounds, to: rep)

        return rep
    }

    /// インク（背景でない画素）が乗っている領域。何も描かれていなければ nil。
    ///
    /// 背景は透明なので、アルファのある画素をインクとみなす。
    func inkBounds(_ rep: NSBitmapImageRep) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0 ..< rep.pixelsHigh {
            for x in 0 ..< rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.05 else { continue }
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }

        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// インクの乗った画素の割合。
    func inkRatio(_ rep: NSBitmapImageRep) -> Double {
        var count = 0
        for y in 0 ..< rep.pixelsHigh {
            for x in 0 ..< rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.05 { count += 1 }
            }
        }

        return Double(count) / Double(rep.pixelsWide * rep.pixelsHigh)
    }

}
#endif
