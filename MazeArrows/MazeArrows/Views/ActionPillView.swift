//
//  ActionPillView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct ActionPillView: View {
    let systemImage: String
    let label: LocalizedStringKey
    let badge: String?
    let isDisabled: Bool
    let voiceOverHint: LocalizedStringKey?
    let theme: GameTheme
    let action: () -> Void

    init(
        systemImage: String,
        label: LocalizedStringKey,
        badge: String? = nil,
        isDisabled: Bool = false,
        voiceOverHint: LocalizedStringKey? = nil,
        theme: GameTheme,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.badge = badge
        self.isDisabled = isDisabled
        self.voiceOverHint = voiceOverHint
        self.theme = theme
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        let button = Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(theme.glassBorder)
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: systemImage)
                                .scaledFont(size: 22, weight: .semibold)
                                .foregroundStyle(theme.ink)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 4)

                    if let badge {
                        Text(badge)
                            .scaledFont(size: 11, weight: .heavy)
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(theme.primaryGradient))
                            .offset(x: 6, y: -6)
                    }

                }
                .overlay(alignment: .bottomTrailing) {
                    if isDisabled {
                        Image(systemName: "nosign")
                            .scaledFont(size: 12, weight: .black)
                            .foregroundStyle(theme.inkMuted)
                            .padding(3)
                            .background(Circle().fill(theme.surface))
                            .offset(x: 6, y: 6)
                    }
                }
                Text(label)
                    .textCase(.uppercase)
                    .scaledFont(size: 11, weight: .semibold)
                    .tracking(0.6)
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.72 : 1.0)
        .accessibilityLabel(Text(label))
        .accessibilityValue(accessibilityValue)

        if let voiceOverHint {
            button.accessibilityHint(Text(voiceOverHint))
        } else {
            button
        }
    }

    private var accessibilityValue: Text {
        if isDisabled { return Text("Unavailable") }
        if badge == "∞" { return Text("Unlimited") }
        if let badge { return Text("\(badge) available") }
        return Text("")
    }
}

#Preview {
    HStack {
        ActionPillView(systemImage: "lightbulb", label: "Hint", badge: "∞", theme: .aurora) {}
        ActionPillView(systemImage: "arrow.uturn.backward", label: "Undo", badge: "5", theme: .aurora) {}
        ActionPillView(systemImage: "arrow.clockwise", label: "Restart", theme: .aurora) {}
    }
    .padding()
    .background(.gray.opacity(0.1))
}
