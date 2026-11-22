//
//  PrivacySettingsRows.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

enum AppLegalLinks {
    static let terms = URL(string: "https://kinapp.dev/arrowmaze/terms/")!
    static let privacy = URL(string: "https://kinapp.dev/arrowmaze/privacy/")!
    static let support = URL(string: "https://kinapp.dev/arrowmaze/support/")!
}

struct PrivacySettingsRows: View {
    let theme: GameTheme

    var body: some View {
        VStack(spacing: 0) {
            Link(destination: AppLegalLinks.privacy) {
                rowLabel(
                    title: "Privacy Policy",
                    systemImage: "hand.raised.fill"
                )
            }
            .buttonStyle(.plain)

            Divider().background(theme.glassBorder)

            Link(destination: AppLegalLinks.terms) {
                rowLabel(
                    title: "Terms of Use",
                    systemImage: "doc.text.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func rowLabel(
        title: LocalizedStringKey,
        systemImage: String
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

            Image(systemName: "arrow.up.right")
                .scaledFont(size: 12, weight: .bold)
                .foregroundStyle(theme.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .minimumTapTarget()
        .contentShape(.rect)
    }
}
