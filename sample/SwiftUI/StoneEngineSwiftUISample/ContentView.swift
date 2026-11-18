/*
ContentView.swift

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

import SwiftUI
import stone_engine

struct ContentView: View {
    var body: some View {
        TabView {
            LabelDemoView()
                .tabItem { Label("ラベル", systemImage: "textformat") }

            EditorDemoView()
                .tabItem { Label("エディタ", systemImage: "square.and.pencil") }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
    }
}

/// Settings shared by the demo screens.
struct TypesettingControls: View {
    @Binding var direction: STDirection
    @Binding var fontSize: CGFloat
    @Binding var lineHeightScale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("組み方向", selection: $direction) {
                Text("横書き").tag(STDirection.lrTb)
                Text("縦書き").tag(STDirection.tbRl)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("directionPicker")

            HStack {
                Text("文字サイズ \(Int(fontSize))")
                    .frame(width: 120, alignment: .leading)
                Slider(value: $fontSize, in: 12 ... 32, step: 1)
                    .accessibilityIdentifier("fontSizeSlider")
            }

            HStack {
                Text("行送り \(lineHeightScale, specifier: "%.2f")")
                    .frame(width: 120, alignment: .leading)
                Slider(value: $lineHeightScale, in: 1.25 ... 2.25, step: 0.125)
                    .accessibilityIdentifier("lineHeightSlider")
            }
        }
        .font(.callout)
    }
}

#Preview {
    ContentView()
}
