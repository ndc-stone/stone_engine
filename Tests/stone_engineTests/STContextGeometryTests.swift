/*
STContextGeometryTests.swift

STContext の座標まわり（ヒットテスト・カーソル位置・行の引き当て）の検証。

closestRunIndex が返すのは「ラン番号」ではなく「キャレットの位置」で、
0 ... runs.count の範囲を取る。文字の前半分を指せばその文字の手前、
後ろ半分を指せば次の文字の手前になる。ここが崩れるとクリックで
キャレットが 1 文字ずれるので、往復で固定しておく。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STContextGeometryTests: STEngineTestCase {

    //--------------------------------------------------------------//
    // MARK: - closestRunIndex
    //--------------------------------------------------------------//

    /// 各ランの前半分・後ろ半分の中心を指すと、その手前・その次のキャレット位置が返ること。
    private func assertCaretRoundTrip(_ context: STContext, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        for (runId, run) in context.runs.enumerated() where !run.isNewline {
            let frame = run.frame
            let first: CGPoint
            let second: CGPoint
            switch context.direction {
            case .lrTb:
                first = CGPoint(x: frame.minX + frame.width * 0.25, y: frame.midY)
                second = CGPoint(x: frame.minX + frame.width * 0.75, y: frame.midY)
            case .tbRl:
                first = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.25)
                second = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.75)
            }

            XCTAssertEqual(
                context.closestRunIndex(to: first), runId,
                "[\(label)] 文字の前半分を指したのに手前のキャレットが返らない runId=\(runId) '\(context.runChars[runId])'",
                file: file, line: line
            )
            XCTAssertEqual(
                context.closestRunIndex(to: second), runId + 1,
                "[\(label)] 文字の後ろ半分を指したのに次のキャレットが返らない runId=\(runId) '\(context.runChars[runId])'",
                file: file, line: line
            )
        }
    }

    func testCaretRoundTripLrTb() {
        let samples = [
            "あいうえおか",
            "Hello, world!",
            "あいうえお\nかきくけこ",
            "「こんにちは」と、彼は言った。",
        ]
        for text in samples {
            let context = layout(text, into: makeContext(renderSize: CGSize(width: 16 * 4, height: 400)))
            assertCaretRoundTrip(context, "lrTb/\(text)")
        }
    }

    func testCaretRoundTripTbRl() {
        let samples = [
            "あいうえおか",
            "あいうえお\nかきくけこ",
            "「こんにちは」と、彼は言った。",
        ]
        for text in samples {
            let context = layoutFittedTbRl(text, into: makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * 4)))
            assertCaretRoundTrip(context, "tbRl/\(text)")
        }
    }

    /// キャレット位置は必ず 0 ... runs.count に収まること。
    func testClosestRunIndexStaysInBounds() {
        let context = layout("あいうえおかきくけこ", into: makeContext(renderSize: CGSize(width: 16 * 4, height: 400)))
        let points = [
            CGPoint(x: -1000, y: -1000), CGPoint(x: 1000, y: 1000),
            CGPoint(x: 0, y: 0), CGPoint(x: -1000, y: 1000), CGPoint(x: 1000, y: -1000),
        ]
        for point in points {
            let index = context.closestRunIndex(to: point)
            XCTAssertTrue(
                (0 ... context.runs.count).contains(index),
                "キャレット位置が範囲外 \(index) at \(point)"
            )
        }
    }

    /// テキストが空でもクラッシュせず 0 を返すこと。
    func testClosestRunIndexOnEmptyText() {
        let context = layout("")
        XCTAssertEqual(context.closestRunIndex(to: CGPoint(x: 10, y: 10)), 0)
    }

    /// 横書きで改行した短い行の右の空白を指すと、上下の行ではなくその行の末尾が返ること。
    func testClosestRunIndexPastShortLineEndLrTb() {
        let text = "あいうえおかきくけこ\nあ\nあいうえおかきくけこ"
        let context = layout(text, into: makeContext(renderSize: CGSize(width: 16 * 20, height: 400)))

        // Get the short line's last run and its newline
        let shortRunId = 11
        let newlineId = 12
        XCTAssertTrue(context.runs[newlineId].isNewline)
        let frame = context.runs[shortRunId].frame

        // Point well past its end, under the long lines' characters
        for x in [frame.maxX + 16, frame.maxX + 16 * 5, frame.maxX + 16 * 9] {
            let point = CGPoint(x: x, y: frame.midY)
            XCTAssertEqual(context.closestRunIndex(to: point), newlineId, "短い行の右の空白で行末に来ない x=\(x)")
        }
    }

    /// 縦書きで改行した短い行の下の空白を指すと、左右の行ではなくその行の末尾が返ること。
    func testClosestRunIndexPastShortLineEndTbRl() {
        let text = "あいうえおかきくけこ\nあ\nあいうえおかきくけこ"
        let context = layoutFittedTbRl(text, into: makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * 20)))

        // Get the short line's last run and its newline
        let shortRunId = 11
        let newlineId = 12
        XCTAssertTrue(context.runs[newlineId].isNewline)
        let frame = context.runs[shortRunId].frame

        // Point well past its end, beside the long lines' characters
        for y in [frame.maxY + 16, frame.maxY + 16 * 5, frame.maxY + 16 * 9] {
            let point = CGPoint(x: frame.midX, y: y)
            XCTAssertEqual(context.closestRunIndex(to: point), newlineId, "短い行の下の空白で行末に来ない y=\(y)")
        }
    }

    /// 範囲を絞ったときは、その範囲の中のキャレット位置が返ること。
    func testClosestRunIndexWithRange() {
        let context = layout("あいうえおかきくけこ", into: makeContext(renderSize: CGSize(width: 16 * 10, height: 400)))
        let range = 3 ..< 7

        for runId in range {
            let frame = context.runs[runId].frame
            let point = CGPoint(x: frame.minX + frame.width * 0.25, y: frame.midY)
            XCTAssertEqual(context.closestRunIndex(to: point, range: range), runId, "範囲つきの引き当てがずれた runId=\(runId)")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - hitRunIndex
    //--------------------------------------------------------------//

    /// ランの中心を指すとそのラン、外を指すと nil が返ること。
    func testHitRunIndex() {
        for direction in STDirection.allCases {
            let context = direction == .lrTb
                ? layout("あいうえおか", into: makeContext(renderSize: CGSize(width: 16 * 4, height: 400)))
                : layoutFittedTbRl("あいうえおか", into: makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * 4)))

            for (runId, run) in context.runs.enumerated() where !run.isNewline {
                XCTAssertEqual(
                    context.hitRunIndex(to: CGPoint(x: run.frame.midX, y: run.frame.midY)), runId,
                    "[\(direction)] ランの中心が当たらない runId=\(runId)"
                )
            }
            XCTAssertNil(context.hitRunIndex(to: CGPoint(x: -100, y: -100)), "[\(direction)] テキストの外が当たった")
            XCTAssertNil(context.hitRunIndex(to: CGPoint(x: 10000, y: 10000)), "[\(direction)] テキストの外が当たった")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - cursorFrame
    //--------------------------------------------------------------//

    /// すべてのキャレット位置で有限のフレームが返ること（末尾も含む）。
    func testCursorFrameIsFiniteEverywhere() {
        let samples = ["", "あ", "あいうえおかきくけこ", "あいう\nえお", "おわり\n", "\n\n"]
        for direction in STDirection.allCases {
            for text in samples {
                let context = direction == .lrTb
                    ? layout(text, into: makeContext(renderSize: CGSize(width: 16 * 4, height: 400)))
                    : layout(text, into: makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * 4)))

                for index in 0 ... context.runs.count {
                    let frame = context.cursorFrame(at: index)
                    XCTAssertTrue(
                        frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite,
                        "[\(direction)/'\(text)'] キャレットのフレームが有限でない index=\(index) frame=\(frame)"
                    )
                    XCTAssertGreaterThan(
                        frame.width * frame.height, 0,
                        "[\(direction)/'\(text)'] キャレットに面積がない index=\(index) frame=\(frame)"
                    )
                }
            }
        }
    }

    /// 横組みのキャレットは、その文字の左端に、行の高さで立つこと。
    func testCursorFrameLrTb() {
        let context = layout("あいうえおか", into: makeContext(renderSize: CGSize(width: 16 * 4, height: 400)))

        for (runId, run) in context.runs.enumerated() {
            let cursor = context.cursorFrame(at: runId)
            XCTAssertEqual(cursor.midX, run.frame.minX, accuracy: 0.001, "キャレットが文字の左端にない index=\(runId)")
            XCTAssertEqual(cursor.height, context.fontSize, accuracy: 0.001, "キャレットの高さが fontSize でない")
            XCTAssertEqual(cursor.width, STContext.cursorWide, accuracy: 0.001, "キャレットの太さが違う")
            XCTAssertEqual(
                cursor.minY, CGFloat(run.line) * context.lineHeight, accuracy: 0.001,
                "キャレットが行の位置に来ていない index=\(runId)"
            )
        }

        // 末尾のキャレットは最後の文字の右端
        let last = context.cursorFrame(at: context.runs.count)
        XCTAssertEqual(last.midX, context.runs.last!.frame.maxX, accuracy: 0.001, "末尾のキャレットが最後の文字の右端にない")
    }

    /// 縦組みのキャレットは、その文字の上端に、文字の幅で寝ること。
    func testCursorFrameTbRl() {
        let context = layout("あいうえおか", into: makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * 4)))

        for (runId, run) in context.runs.enumerated() {
            let cursor = context.cursorFrame(at: runId)
            XCTAssertEqual(cursor.midY, run.frame.minY, accuracy: 0.001, "キャレットが文字の上端にない index=\(runId)")
            XCTAssertEqual(cursor.height, STContext.cursorWide, accuracy: 0.001, "縦組みのキャレットが寝ていない")
            XCTAssertEqual(cursor.width, run.frame.width, accuracy: 0.001, "キャレットの長さが文字幅と違う")
        }
    }

    /// 改行で終わるテキストでは、末尾のキャレットが次の行の頭に来ること。
    func testCursorFrameAfterTrailingNewline() {
        let context = layout("あい\n", into: makeContext(renderSize: CGSize(width: 16 * 8, height: 400)))
        let last = context.cursorFrame(at: context.runs.count)

        XCTAssertEqual(context.lineCount, 2, "末尾の改行で行が増えていない")
        XCTAssertEqual(
            last.minY, context.lineHeight, accuracy: 0.001,
            "末尾のキャレットが 2 行目に降りていない"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - 行の引き当て
    //--------------------------------------------------------------//

    /// runIndexes(line:) が返す範囲のランは、すべてその行に属すること。
    func testRunIndexesMatchLine() {
        let context = layout("あいうえおかきくけこさしすせそ", into: makeContext(renderSize: CGSize(width: 16 * 4, height: 400)))

        var covered = 0
        for line in 0 ..< context.lineCount {
            guard let range = context.runIndexes(line: line) else {
                XCTFail("行 \(line) の範囲が引けない")
                continue
            }
            for runId in range {
                XCTAssertEqual(context.runs[runId].line, line, "行 \(line) の範囲に別の行のランが入っている runId=\(runId)")
            }
            covered += range.count
        }
        XCTAssertEqual(covered, context.runs.count, "行の範囲が全ランを覆っていない")
    }

    /// line(at:) が run の行番号と一致すること。
    func testLineAtRunId() {
        let context = layout("あいうえおかきくけこ", into: makeContext(renderSize: CGSize(width: 16 * 4, height: 400)))
        for (runId, run) in context.runs.enumerated() {
            XCTAssertEqual(context.line(at: runId), run.line, "line(at:) がランの行と違う runId=\(runId)")
        }
        XCTAssertEqual(context.line(at: context.runs.count), context.runs.last!.line, "末尾のキャレットの行が最終行でない")
    }

    /// 存在しない行を引いても落ちないこと。
    func testRunIndexesForMissingLine() {
        let context = layout("あい", into: makeContext(renderSize: CGSize(width: 16 * 8, height: 400)))
        let range = context.runIndexes(line: 99)
        XCTAssertEqual(range, context.runs.count ..< context.runs.count, "存在しない行が空範囲を返さない")
    }

    //--------------------------------------------------------------//
    // MARK: - tokenString
    //--------------------------------------------------------------//

    /// tokenString がすべてのトークン・ランで引けること。
    /// 範囲外だけ nil になる。
    func testTokenString() {
        let context = layout("abc def ghi", into: makeContext(renderSize: CGSize(width: 400, height: 400)))
        let tokenTexts = context.tokens.map { String(context.runChars[$0.runIdRange]) }
        XCTAssertEqual(tokenTexts, ["abc", " ", "def", " ", "ghi"], "前提のトークン分割が崩れた")

        for tokenId in context.tokens.indices {
            XCTAssertEqual(context.tokenString(tokenId: tokenId), tokenTexts[tokenId], "トークン文字列が違う tokenId=\(tokenId)")
        }
        for runId in context.runs.indices {
            XCTAssertEqual(
                context.tokenString(runId: runId), tokenTexts[context.runs[runId].tokenId],
                "ランから引いたトークン文字列が違う runId=\(runId)"
            )
        }

        XCTAssertNil(context.tokenString(tokenId: -1), "負のトークン ID で nil が返らない")
        XCTAssertNil(context.tokenString(tokenId: context.tokens.count), "範囲外のトークン ID で nil が返らない")
        XCTAssertNil(context.tokenString(runId: -1), "負のラン ID で nil が返らない")
        XCTAssertNil(context.tokenString(runId: context.runs.count), "範囲外のラン ID で nil が返らない")
    }
}
