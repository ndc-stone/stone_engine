/*
STLayoutSnapshot.swift

レイアウト結果をテキストにダンプする仕組み。

画像で撮ると macOS やフォントのバージョンでいくらでも壊れるうえ、
差分を見ても何が変わったのか分からない。ここではランごとの
「文字・行・枡・描画位置」を 1 行ずつ書き出して、テキストとして比較する。
差分がそのまま git diff に出て、どのケースのどの文字がずれたのか読める。

数値のぶれを避けるため、代表ケースは全角文字だけで組んである
（16pt の枡にちょうど載るので、フォントの送りが多少動いても変わらない）。
ラテンや絵文字を混ぜたケースはフォント依存なので、その旨を見出しに書いてある。
*/

import XCTest
@testable import stone_engine

//--------------------------------------------------------------//
// MARK: - Case
//--------------------------------------------------------------//

/// スナップショット 1 件ぶんの設定。
struct STLayoutSnapshotCase {
    var name: String
    var note: String?
    var text: String

    var direction: STDirection = .lrTb
    var punctuationMode: STPunctuationMode = .stone
    var textAlign: STTextAlign = .leading
    var directionAlign: STDirectionAlign = .start
    var fontSize: CGFloat = 16
    var lineHeightScale: CGFloat = 1.0
    var renderSize: CGSize
    var isKinsokuAvailable = true
    var isFixedWidth = false
    var isSingleLine = false
    var isAllowedTateChuYoko = true
    var rubyNotation: STRubyNotation = .none
    var rubyFontScale: CGFloat = 0.5
    var maxLineCount = 0
    var isShownEllipsis = false

    /// 全角 charsPerLine 文字ぶんの幅（横組み）/ 高さ（縦組み）を持つケース。
    static func make(
        _ name: String,
        _ text: String,
        direction: STDirection = .lrTb,
        charsPerLine: Int,
        fontSize: CGFloat = 16,
        note: String? = nil
    ) -> STLayoutSnapshotCase {
        let inline = fontSize * CGFloat(charsPerLine)
        let block: CGFloat = 400
        return STLayoutSnapshotCase(
            name: name,
            note: note,
            text: text,
            direction: direction,
            fontSize: fontSize,
            renderSize: direction == .lrTb
                ? CGSize(width: inline, height: block)
                : CGSize(width: block, height: inline)
        )
    }
}

//--------------------------------------------------------------//
// MARK: - Dump
//--------------------------------------------------------------//

enum STLayoutSnapshot {

    static let separator = String(repeating: "=", count: 78)
    private static let rule = String(repeating: "-", count: 78)

    /// ケースを組んで、その結果をテキストに書き出す。
    @MainActor
    static func render(_ snapshotCase: STLayoutSnapshotCase) -> String {
        let context = STContext()
        context.direction = snapshotCase.direction
        context.punctuationMode = snapshotCase.punctuationMode
        context.textAlign = snapshotCase.textAlign
        context.directionAlign = snapshotCase.directionAlign
        context.fontSize = snapshotCase.fontSize
        context.lineHeightScale = snapshotCase.lineHeightScale
        context.renderSize = snapshotCase.renderSize
        context.isKinsokuAvailable = snapshotCase.isKinsokuAvailable
        context.isFixedWidth = snapshotCase.isFixedWidth
        context.isSingleLine = snapshotCase.isSingleLine
        context.isAllowedTateChuYoko = snapshotCase.isAllowedTateChuYoko
        context.rubyNotation = snapshotCase.rubyNotation
        context.rubyFontScale = snapshotCase.rubyFontScale
        context.maxLineCount = snapshotCase.maxLineCount
        context.isShownEllipsis = snapshotCase.isShownEllipsis
        context.fontManager.refresh()

        STParser(context: context).parse(text: snapshotCase.text)
        STLayout(context: context).layout()

        var out = separator + "\n"
        out += "CASE \(snapshotCase.name)\n"
        if let note = snapshotCase.note { out += "NOTE \(note)\n" }
        out += "  text        : \(escape(snapshotCase.text))\n"
        out += "  direction   : \(snapshotCase.direction)   fontSize: \(number(snapshotCase.fontSize))"
            + "   lineHeightScale: \(number(snapshotCase.lineHeightScale))\n"
        out += "  renderSize  : \(number(snapshotCase.renderSize.width)) x \(number(snapshotCase.renderSize.height))\n"
        out += "  punctuation : \(snapshotCase.punctuationMode)   kinsoku: \(onOff(snapshotCase.isKinsokuAvailable))"
            + "   fixedWidth: \(onOff(snapshotCase.isFixedWidth))   singleLine: \(onOff(snapshotCase.isSingleLine))\n"
        out += "  align       : text=\(snapshotCase.textAlign)   direction=\(snapshotCase.directionAlign)"
            + "   tateChuYoko: \(onOff(snapshotCase.isAllowedTateChuYoko))\n"
        if snapshotCase.maxLineCount > 0 || snapshotCase.isShownEllipsis {
            out += "  lineLimit   : maxLineCount=\(snapshotCase.maxLineCount)"
                + "   ellipsis: \(onOff(snapshotCase.isShownEllipsis))\n"
        }
        if snapshotCase.rubyNotation != .none {
            out += "  ruby        : \(snapshotCase.rubyNotation)"
                + "   fontScale: \(number(snapshotCase.rubyFontScale))\n"
        }
        out += rule + "\n"
        out += "  lineCount   : \(context.lineCount)\n"
        out += "  renderedSize: \(number(context.renderedSize.width)) x \(number(context.renderedSize.height))\n"
        if context.renderSize != snapshotCase.renderSize {
            // ぶら下がりは renderSize を書き換えるので、変わったときだけ出す
            out += "  renderSize' : \(number(context.renderSize.width)) x \(number(context.renderSize.height))\n"
        }
        out += rule + "\n"

        if context.runs.isEmpty {
            out += "  (no runs)\n"
            return out
        }

        out += "  idx  ch  ln        x        y        w        h     posX     posY  vis  tcy\n"
        for (runId, run) in context.runs.enumerated() {
            out += String(format: "  %3d  %@  %2d %@ %@ %@ %@ %@ %@   %@   %@\n",
                          runId,
                          cell(escape(String(context.runChars[runId]))),
                          run.line,
                          number(run.frame.minX), number(run.frame.minY),
                          number(run.frame.width), number(run.frame.height),
                          number(run.position.x), number(run.position.y),
                          visibility(run.visibility),
                          context.isTateChuYoko(run: run) ? "T" : (context.isClockwise(run: run) ? "R" : "-"))
        }

        return out
    }

    //--------------------------------------------------------------//
    // MARK: - Format
    //--------------------------------------------------------------//

    /// -0.0 を 0.0 に潰したうえで小数第 1 位まで、幅 8 で右寄せ。
    private static func number(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        return String(format: "%8.1f", rounded == 0 ? 0 : rounded)
    }

    private static func onOff(_ value: Bool) -> String {
        return value ? "on" : "off"
    }

    private static func visibility(_ value: STRunVisibility) -> String {
        switch value {
        case .visible: return "V"
        case .invisible: return "-"
        case .ellipsis: return "E"
        }
    }

    /// 制御文字と空白を目に見える形に置き換える。
    private static func escape(_ text: String) -> String {
        var out = ""
        for char in text {
            switch char {
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\r\n": out += "\\r\\n"
            case "\t": out += "\\t"
            case " ": out += "␣"
            default: out.append(char)
            }
        }
        return out
    }

    /// 文字カラムを幅 2 に揃える（エスケープした結果が長いときは切らずにそのまま）。
    private static func cell(_ text: String) -> String {
        return text.count >= 2 ? text : text + " "
    }
}
