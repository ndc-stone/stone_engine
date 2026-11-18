/*
LabelDemoView.swift

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import SwiftUI
import StoneEngineSwiftUI
import stone_engine

struct LabelDemoView: View {
    @State private var direction = STDirection.tbRl
    @State private var fontSize: CGFloat = 17
    @State private var lineHeightScale: CGFloat = 1.625

    private var label: some View {
        STLabelView(
            SampleText.rashomon,
            direction: direction,
            fontSize: fontSize,
            lineHeightScale: lineHeightScale
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            TypesettingControls(
                direction: $direction,
                fontSize: $fontSize,
                lineHeightScale: $lineHeightScale
            )

            // Lines are stacked downward in horizontal text and leftward in vertical text
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
}
