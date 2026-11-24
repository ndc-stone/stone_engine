/*
RevealDemoView.swift

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import SwiftUI
import StoneEngineSwiftUI
import stone_engine

/// A text coming out a character at a time, and what it comes out by.
///
/// Everything here is about the coming out. How the text is set otherwise —
/// the size it is set at, the room between its lines — is what the other
/// sample is for, and is left at something readable so that nothing here has
/// to be settled before the thing this is about can be looked at.
struct RevealDemoView: View {
    @State private var usesRuby = true
    @State private var direction = STDirection.lrTb
    @State private var revealAnimation = STRevealAnimation.fade
    @State private var revealDuration: TimeInterval = 0.25
    @State private var revealOrigin = STRevealOrigin.bottom

    /// How many characters have come out, which the slider moves.
    ///
    /// Kept as a Double because that is what a slider moves
    @State private var revealedCharacterCount: Double = 0

    /// Whether the text is counting itself out on its own
    @State private var isPlaying = false

    /// How long between one character and the next while it is
    @State private var interval: TimeInterval = 0.08

    //--------------------------------------------------------------//
    // MARK: - Text
    //--------------------------------------------------------------//

    private var text: String {
        usesRuby ? RevealSampleText.ruby : RevealSampleText.plain
    }

    private var rubyNotation: STRubyNotation {
        usesRuby ? .braces : .none
    }

    /// How many characters there are to come out.
    ///
    /// Asked of the engine rather than counted off the string. A text written
    /// with readings is longer to write than it is to read — the marks and the
    /// readings are characters of the string and no part of what comes out —
    /// so counting the string would leave the end of the slider doing nothing
    private var characterCount: Int {
        STContext.revealCharacterCount(of: text, rubyNotation: rubyNotation)
    }

    //--------------------------------------------------------------//
    // MARK: - Body
    //--------------------------------------------------------------//

    var body: some View {
        VStack(spacing: 16) {
            controls

            // Lines are stacked downward in horizontal text and leftward in
            // vertical text
            Group {
                switch direction {
                case .lrTb:
                    ScrollView(.vertical) {
                        label
                    }
                case .tbRl:
                    ScrollView(.horizontal) {
                        label
                    }
                    .defaultScrollAnchor(.trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding()
        // A text swapped for a shorter one leaves the count past its end
        .onChange(of: characterCount) { _, newValue in
            revealedCharacterCount = min(revealedCharacterCount, Double(newValue))
        }
        // Count it out, while it is being counted out. Started again from the
        // beginning where it had run to the end, there being nothing to watch
        // in a text that is already whole
        .task(id: isPlaying) {
            guard isPlaying else { return }
            if Int(revealedCharacterCount) >= characterCount {
                revealedCharacterCount = 0
            }
            while isPlaying, Int(revealedCharacterCount) < characterCount {
                try? await Task.sleep(for: .seconds(interval))
                revealedCharacterCount += 1
            }
            isPlaying = false
        }
    }

    private var label: some View {
        STLabelView(
            text,
            direction: direction,
            fontSize: 22,
            lineHeightScale: 1.75,
            rubyNotation: rubyNotation,
            revealAnimation: revealAnimation,
            revealedCharacterCount: Int(revealedCharacterCount),
            revealDuration: revealDuration,
            revealOrigin: revealOrigin
        )
    }
}

extension RevealDemoView {
    //--------------------------------------------------------------//
    // MARK: - Controls
    //--------------------------------------------------------------//

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("文章", selection: $usesRuby) {
                Text("ルビあり").tag(true)
                Text("ルビなし").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("rubyPicker")

            Picker("組み方向", selection: $direction) {
                Text("横書き").tag(STDirection.lrTb)
                Text("縦書き").tag(STDirection.tbRl)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("directionPicker")

            Picker("出現", selection: $revealAnimation) {
                Text("なし").tag(STRevealAnimation.none)
                Text("フェード").tag(STRevealAnimation.fade)
                Text("ポップ").tag(STRevealAnimation.pop)
                Text("せり上がり").tag(STRevealAnimation.rise)
                Text("落下").tag(STRevealAnimation.drop)
                Text("回転").tag(STRevealAnimation.spin)
                Text("裏返し").tag(STRevealAnimation.flip)
                Text("フライイン").tag(STRevealAnimation.flyIn)
            }
            // Not segmented as the two above are. Four of them in a row
            // leaves each too narrow for the words in it
            .pickerStyle(.menu)
            .accessibilityIdentifier("revealAnimationPicker")

            // Only the one that comes in from a side has a side to come
            // from. Shown with it rather than always, a setting that does
            // nothing being a setting somebody will try
            if revealAnimation == .flyIn {
                Picker("向き", selection: $revealOrigin) {
                    Text("下から").tag(STRevealOrigin.bottom)
                    Text("上から").tag(STRevealOrigin.top)
                    Text("左から").tag(STRevealOrigin.left)
                    Text("右から").tag(STRevealOrigin.right)
                    Text("左上から").tag(STRevealOrigin.topLeft)
                    Text("右上から").tag(STRevealOrigin.topRight)
                    Text("左下から").tag(STRevealOrigin.bottomLeft)
                    Text("右下から").tag(STRevealOrigin.bottomRight)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("revealOriginPicker")
            }

            HStack {
                Text("出現の秒数 \(revealDuration, specifier: "%.2f")")
                    .frame(width: 140, alignment: .leading)
                Slider(value: $revealDuration, in: 0.05 ... 1, step: 0.05)
                    .accessibilityIdentifier("revealDurationSlider")
            }

            HStack {
                Text("送りの秒数 \(interval, specifier: "%.2f")")
                    .frame(width: 140, alignment: .leading)
                Slider(value: $interval, in: 0.02 ... 0.5, step: 0.02)
                    .accessibilityIdentifier("revealIntervalSlider")
            }

            HStack {
                Text("文字数 \(Int(revealedCharacterCount)) / \(characterCount)")
                    .frame(width: 140, alignment: .leading)
                Slider(
                    value: $revealedCharacterCount,
                    in: 0 ... Double(max(characterCount, 1)),
                    step: 1
                )
                .accessibilityIdentifier("revealedCharacterSlider")
            }

            HStack {
                // Counting it out on its own, which is what one of these is
                // for. The slider is for stopping in the middle of a character
                // and looking at it
                Button(isPlaying ? "停止" : "再生") {
                    isPlaying.toggle()
                }
                .accessibilityIdentifier("playButton")

                Button("最初から") {
                    isPlaying = false
                    revealedCharacterCount = 0
                }
                .accessibilityIdentifier("rewindButton")

                Button("全部") {
                    isPlaying = false
                    revealedCharacterCount = Double(characterCount)
                }
                .accessibilityIdentifier("revealAllButton")

                Spacer()
            }
            .buttonStyle(.bordered)
        }
        .font(.callout)
    }
}

#Preview {
    RevealDemoView()
}
