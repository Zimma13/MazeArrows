//
//  HeartsView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct HeartsView: View {
    let total: Int
    let filled: Int
    let theme: GameTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                if reduceMotion {
                    heartImage(at: i)
                        .transition(.opacity)
                } else {
                    heartImage(at: i)
                        .symbolEffect(.bounce, value: filled)
                        .transition(.scale)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(theme.surface)
                .overlay(Capsule().stroke(theme.glassBorder))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lives")
        .accessibilityValue(Text("\(filled) of \(total) remaining"))
    }

    private func heartImage(at index: Int) -> some View {
        Image(systemName: index < filled ? "heart.fill" : "heart")
            .scaledFont(size: 18, weight: .bold)
            .foregroundStyle(index < filled ? theme.heartFill : theme.inkMuted)
    }
}

#Preview {
    HeartsView(total: 5, filled: 3, theme: .aurora)
}
