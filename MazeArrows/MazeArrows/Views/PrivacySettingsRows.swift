//
//  PrivacySettingsRows.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct PrivacySettingsRows: View {
    let theme: GameTheme
    let showsAdvertisingChoices: Bool
    let isPresentingAdvertisingChoices: Bool
    let presentAdvertisingChoices: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Link(destination: AppLegalLinks.privacy) {
                rowLabel(
                    title: "Privacy Policy",
                    systemImage: "hand.raised.fill",
                    showsProgress: false
                )
            }
            .buttonStyle(.plain)

            Divider().background(theme.glassBorder)

            Link(destination: AppLegalLinks.terms) {
                rowLabel(
                    title: "Terms of Use",
                    systemImage: "doc.text.fill",
                    showsProgress: false
                )
            }
            .buttonStyle(.plain)

            if showsAdvertisingChoices {
                Divider().background(theme.glassBorder)
                Button(
                    action: presentAdvertisingChoices,
                    label: {
                        rowLabel(
                            title: "Advertising choices",
                            systemImage: "checkmark.shield.fill",
                            showsProgress: isPresentingAdvertisingChoices
                        )
                    }
                )
                .buttonStyle(.plain)
                .disabled(isPresentingAdvertisingChoices)
            }
        }
    }

    private func rowLabel(
        title: LocalizedStringKey,
        systemImage: String,
        showsProgress: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 32, height: 32)
                .foregroundStyle(theme.accent)
                .background(theme.accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(theme.ink)

            Spacer()

            if showsProgress {
                ProgressView()
                    .tint(theme.accent)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "arrow.up.right")
                    .scaledFont(size: 12, weight: .bold)
                    .foregroundStyle(theme.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .minimumTapTarget()
        .contentShape(.rect)
    }
}
