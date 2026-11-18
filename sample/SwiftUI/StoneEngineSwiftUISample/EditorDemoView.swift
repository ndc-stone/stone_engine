/*
EditorDemoView.swift

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import SwiftUI
import StoneEngineSwiftUI
import stone_engine

struct EditorDemoView: View {
    @State private var text = SampleText.mixed
    @State private var direction = STDirection.tbRl
    @State private var fontSize: CGFloat = 17
    @State private var lineHeightScale: CGFloat = 1.625

    var body: some View {
        VStack(spacing: 16) {
            TypesettingControls(
                direction: $direction,
                fontSize: $fontSize,
                lineHeightScale: $lineHeightScale
            )

            STTextEditor(
                text: $text,
                direction: direction,
                fontSize: fontSize,
                lineHeightScale: lineHeightScale
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text("\(text.count) 文字")
                    .monospacedDigit()
                    .accessibilityIdentifier("characterCount")

                Spacer()

                Button("本文を戻す") {
                    text = SampleText.mixed
                }
                .accessibilityIdentifier("resetButton")
            }
            .font(.callout)
        }
        .padding()
    }
}
