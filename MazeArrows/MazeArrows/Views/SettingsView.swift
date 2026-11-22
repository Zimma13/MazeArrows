//
//  SettingsView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @Environment(GameCenterStore.self) private var gameCenter
    @Environment(\.openURL) private var openURL

    @State private var showResetConfirm = false
    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }

    var body: some View {
        @Bindable var settings = settings

        ZStack {
            theme.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    sectionTitle("Game Center")
                    settingsCard {
                        gameCenterStatusRow
                        if gameCenter.isAuthenticated {
                            Divider().background(theme.glassBorder)
                            gameCenterDestinationButton(
                                label: "Game Center",
                                icon: "square.grid.2x2.fill",
                                destination: .dashboard
                            )
                            Divider().background(theme.glassBorder)
                            gameCenterDestinationButton(
                                label: "Achievements",
                                icon: "medal.fill",
                                destination: .achievements
                            )
                            Divider().background(theme.glassBorder)
                            gameCenterDestinationButton(
                                label: "Leaderboards",
                                icon: "trophy.fill",
                                destination: .leaderboards
                            )
                        } else if gameCenter.connectionState == .unavailable {
                            Divider().background(theme.glassBorder)
                            Button(action: gameCenter.retryAuthentication) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                    Spacer()
                                }
                                .scaledFont(size: 15, weight: .semibold)
                                .foregroundStyle(theme.accent)
                                .padding(.vertical, 10)
                                .minimumTapTarget()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    sectionTitle("Privacy")
                    settingsCard {
                        PrivacySettingsRows(theme: theme)
                    }

                    sectionTitle("Support")
                    settingsCard {
                        Link(destination: AppLegalLinks.support) {
                            HStack(spacing: 12) {
                                Image(systemName: "questionmark.circle.fill")
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(theme.accent)
                                    .background(theme.accent.opacity(0.12), in: Circle())
                                    .accessibilityHidden(true)

                                Text("Support")
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
                        .buttonStyle(.plain)

                        Divider().background(theme.glassBorder)

                        Button {
                            openURL(ReviewRequestStore.appStoreReviewURL)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "star.fill")
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(theme.achievementGold)
                                    .background(
                                        theme.achievementGold.opacity(0.12),
                                        in: Circle()
                                    )
                                    .accessibilityHidden(true)

                                Text("Rate Arrow Maze")
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
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rate Arrow Maze")
                        .accessibilityHint("Opens the App Store review page.")
                    }

                    sectionTitle("Audio & Feel")
                    settingsCard {
                        toggleRow(
                            label: "Sound",
                            icon: "speaker.wave.2.fill",
                            isOn: $settings.settings.soundEnabled
                        )
                        Divider().background(theme.glassBorder)
                        toggleRow(
                            label: "Haptics",
                            icon: "iphone.radiowaves.left.and.right",
                            isOn: $settings.settings.hapticsEnabled
                        )
                        Divider().background(theme.glassBorder)
                        toggleRow(
                            label: "Path preview on long press",
                            icon: "hand.tap.fill",
                            isOn: $settings.settings.previewPathEnabled
                        )
                    }

                    sectionTitle("Board")
                    settingsCard {
                        toggleRow(
                            label: "Arrow outlines",
                            icon: "pencil.line",
                            isOn: $settings.settings.arrowOutlinesEnabled
                        )
                        Divider().background(theme.glassBorder)
                        outlineColorRow
                    }

                    sectionTitle("Hints")
                    settingsCard {
                        hintDepthRow
                    }

                    sectionTitle("Theme")
                    settingsCard {
                        ForEach(Array(AppThemeID.allCases.enumerated()), id: \.element) { index, id in
                            themeRow(id: id, isSelected: settings.settings.themeID == id)
                            if index < AppThemeID.allCases.count - 1 {
                                Divider().background(theme.glassBorder)
                            }
                        }
                    }

                    sectionTitle("Progress")
                    settingsCard {
                        infoRow(label: "Levels cleared", value: "\(progress.progress.completedLevels.count)")
                        Divider().background(theme.glassBorder)
                        infoRow(label: "Coins", value: "\(progress.progress.coins)")
                        Divider().background(theme.glassBorder)
                        infoRow(label: "Daily streak", value: "\(progress.progress.dailyStreak)")
                        Divider().background(theme.glassBorder)
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Reset progress")
                                Spacer()
                            }
                            .scaledFont(size: 15, weight: .semibold)
                            .foregroundStyle(theme.danger)
                            .padding(.vertical, 10)
                            .minimumTapTarget()
                        }
                        .accessibilityLabel("Reset progress")
                    }

                    Text("Arrow Maze — Untangle every path")
                        .font(.footnote)
                        .foregroundStyle(theme.inkMuted)
                        .padding(.top, 24)
                }
                .padding(20)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .scaledFont(size: 18, weight: .heavy)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .designedBackButton(theme: theme)
        .edgeFades(theme: theme)
        .alert("Reset progress?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { progress.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All stars, best times and unlocked levels will be cleared.")
        }
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        HStack {
            Text(text)
                .textCase(.uppercase)
                .scaledFont(size: 11, weight: .heavy)
                .tracking(1.2)
                .foregroundStyle(theme.inkMuted)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var gameCenterStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .frame(width: 32, height: 32)
                .foregroundStyle(theme.accent)
                .background(theme.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(gameCenter.player?.displayName ?? "Game Center")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(theme.ink)
                Text(gameCenterStatusText)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            if gameCenter.connectionState == .authenticating {
                ProgressView()
                    .tint(theme.accent)
            } else if gameCenter.isAuthenticated {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.success)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game Center")
        .accessibilityValue(Text(gameCenterStatusText))
    }

    private var gameCenterStatusText: LocalizedStringKey {
        switch gameCenter.connectionState {
        case .idle:
            "Not connected"
        case .authenticating:
            "Connecting…"
        case .awaitingPlayerAction:
            "Waiting for sign-in"
        case .authenticated:
            "Connected"
        case .unavailable:
            "Not connected"
        }
    }

    private func gameCenterDestinationButton(
        label: LocalizedStringKey,
        icon: String,
        destination: GameCenterDestination
    ) -> some View {
        Button {
            gameCenter.presentGameCenter(destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(theme.accent)
                    .background(theme.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                Text(label)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .scaledFont(size: 12, weight: .bold)
                    .foregroundStyle(theme.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .minimumTapTarget()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.glassBorder)
                )
        )
    }

    private func toggleRow(label: LocalizedStringKey, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack {
                Image(systemName: icon)
                    .frame(minWidth: 22)
                    .foregroundStyle(theme.inkSoft)
                Text(label)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
            }
        }
        .tint(theme.accent)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(label))
    }

    private var outlineColorRow: some View {
        ColorPicker(
            selection: outlineColorBinding,
            supportsOpacity: false
        ) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .frame(minWidth: 22)
                    .foregroundStyle(theme.inkSoft)
                Text("Outline color")
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .disabled(!settings.settings.arrowOutlinesEnabled)
        .opacity(settings.settings.arrowOutlinesEnabled ? 1 : 0.45)
        .accessibilityLabel("Outline color")
        .accessibilityHint("Selects the color drawn around every arrow.")
    }

    private var outlineColorBinding: Binding<Color> {
        Binding(
            get: {
                let color = settings.settings.arrowOutlineColor
                return Color(
                    .sRGB,
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    opacity: 1
                )
            },
            set: { color in
                let uiColor = UIColor(color)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                guard uiColor.getRed(
                    &red,
                    green: &green,
                    blue: &blue,
                    alpha: &alpha
                ) else { return }
                settings.settings.arrowOutlineColor = PieceGroupPaletteColor(
                    red: Double(red),
                    green: Double(green),
                    blue: Double(blue)
                )
            }
        )
    }

    @ViewBuilder
    private var hintDepthRow: some View {
        @Bindable var s = settings
        VStack(alignment: .leading, spacing: 8) {
            DynamicTypeStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .frame(minWidth: 22)
                    .foregroundStyle(theme.inkSoft)
                Text("Hint depth")
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(hintDepthLabel(s.settings.hintDepth))
                    .scaledFont(size: 13, weight: .heavy)
                    .foregroundStyle(theme.accent)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hint depth")
            .accessibilityValue(Text(hintDepthLabel(s.settings.hintDepth)))
            DynamicTypeStack(spacing: 8) {
                ForEach(1...3, id: \.self) { depth in
                    Button {
                        s.settings.hintDepth = depth
                    } label: {
                        HStack(spacing: 4) {
                            if s.settings.hintDepth == depth {
                                Image(systemName: "checkmark")
                                    .scaledFont(size: 11, weight: .black)
                            }
                            Text("\(depth)")
                                .scaledFont(size: 14, weight: .heavy)
                        }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(s.settings.hintDepth == depth ? theme.primaryText : theme.ink)
                            .background(
                                Capsule()
                                    .fill(s.settings.hintDepth == depth
                                          ? theme.primaryGradient
                                          : LinearGradient(colors: [theme.surface, theme.surface], startPoint: .top, endPoint: .bottom))
                                    .overlay(Capsule().stroke(theme.glassBorder))
                            )
                            .minimumTapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Hint depth \(depth): \(hintDepthLabel(depth))"))
                    .accessibilityAddTraits(s.settings.hintDepth == depth ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func hintDepthLabel(_ depth: Int) -> String {
        switch depth {
        case 1: return String(localized: "Area")
        case 3: return String(localized: "Piece + next")
        default: return String(localized: "Piece")
        }
    }

    private func themeRow(id: AppThemeID, isSelected: Bool) -> some View {
        return Button {
            settings.selectTheme(id)
        } label: {
            HStack {
                themeSwatch(for: id)
                Text(id.displayName)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, 8)
            .minimumTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Theme: \(id.displayName)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func themeSwatch(for id: AppThemeID) -> some View {
        Image(id.appIconPreviewAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(theme.glassBorder, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
        DynamicTypeStack(spacing: 8) {
            Text(label)
                .scaledFont(size: 15, weight: .medium)
                .foregroundStyle(theme.ink)
            Spacer()
            Text(value)
                .scaledFont(size: 15, weight: .heavy)
                .foregroundStyle(theme.inkSoft)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(SettingsStore.shared)
        .environment(ProgressStore.shared)
        .environment(GameCenterStore())
}
