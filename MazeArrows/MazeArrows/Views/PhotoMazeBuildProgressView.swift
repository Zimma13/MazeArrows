//
//  PhotoMazeBuildProgressView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct PhotoMazeBuildProgressView: View {
    let progress: Double
    let theme: GameTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let arrowSymbols = [
        "arrow.up", "arrow.up.right", "arrow.right", "arrow.down.right",
        "arrow.down", "arrow.down.left", "arrow.left", "arrow.up.left"
    ]

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    private var activeArrowCount: Int {
        min(
            arrowSymbols.count,
            Int(ceil(clampedProgress * Double(arrowSymbols.count)))
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Building Photo Maze")
                    .scaledFont(size: 17, weight: .black, design: .rounded)
                    .foregroundStyle(theme.ink)
                Spacer(minLength: 12)
                Text(clampedProgress, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .scaledFont(size: 18, weight: .black, design: .rounded)
                    .foregroundStyle(theme.accent)
            }

            ProgressView(value: clampedProgress)
                .tint(theme.accent)

            HStack(spacing: 8) {
                ForEach(Array(arrowSymbols.enumerated()), id: \.offset) { index, symbol in
                    arrow(symbol: symbol, isActive: index < activeArrowCount)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .themedGlass(
            theme: theme,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Building Photo Maze")
        .accessibilityValue(Text(clampedProgress, format: .percent.precision(.fractionLength(0))))
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private func arrow(symbol: String, isActive: Bool) -> some View {
        let image = Image(systemName: symbol)
            .scaledFont(size: 16, weight: .black)
            .foregroundStyle(isActive ? theme.accent : theme.inkMuted.opacity(0.28))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

        if reduceMotion {
            image
        } else {
            image.symbolEffect(.pulse, value: activeArrowCount)
        }
    }
}
