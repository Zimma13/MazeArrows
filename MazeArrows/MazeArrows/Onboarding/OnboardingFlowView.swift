//
//  OnboardingFlowView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct OnboardingFlowView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(AppIconStore.self) private var appIcons
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            currentStep
                .id(onboarding.step)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.985)),
                            removal: .opacity
                        )
                )
        }
        .overlay(alignment: .topTrailing) {
            if showsSkipButton {
                Button(OnboardingCopy.skip, action: onboarding.skip)
                    .scaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(theme.inkSoft)
                    .padding(.horizontal, 18)
                    .minimumTapTarget()
                    .themedGlass(theme: theme, in: Capsule(), prominence: .compact)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .onAppear {
            #if DEBUG
            precondition(
                TutorialLevelDefinition.validateDefinitions(),
                "Onboarding tutorial boards must remain solvable"
            )
            #endif
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch onboarding.step {
        case .tutorialOne:
            OnboardingTutorialView(stage: .one) { move(to: .tutorialTwo) }

        case .tutorialTwo:
            OnboardingTutorialView(stage: .two) { move(to: .tutorialThree) }

        case .tutorialThree:
            OnboardingTutorialView(stage: .three) { move(to: .tutorialFour) }

        case .tutorialFour:
            OnboardingTutorialView(stage: .four) { move(to: .streak) }

        case .streak:
            OnboardingStreakView {
                onboarding.claimStarterReward(in: progress)
                move(to: .pushPrompt)
            }

        case .pushPrompt:
            OnboardingPushView(
                accept: enableDailyReminder,
                decline: { move(to: .themePicker) }
            )

        case .themePicker:
            OnboardingThemePickerView(
                select: settings.selectTheme,
                confirm: confirmThemeSelection,
                skip: { move(to: .handoff) }
            )

        case .handoff:
            OnboardingHandoffView(
                continueToLevelFive: {
                    onboarding.complete(in: progress, destination: .levelFive)
                },
                openWorldMap: {
                    onboarding.complete(in: progress, destination: .worldMap)
                }
            )
        }
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }

    private var showsSkipButton: Bool {
        onboarding.step.isTutorial
    }

    private func move(to step: OnboardingStep) {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.28)) {
            onboarding.move(to: step)
        }
    }

    private func enableDailyReminder() {
        Task {
            _ = await OnboardingNotificationService.requestDailyReminder()
            move(to: .themePicker)
        }
    }

    private func confirmThemeSelection() {
        let iconStore = appIcons
        let selectedTheme = settings.settings.themeID
        move(to: .handoff)
        Task { @MainActor [iconStore] in
            await Task.yield()
            iconStore.offerMatchingIcon(for: selectedTheme)
        }
    }
}

private struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void
    let theme: GameTheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 18, weight: .bold, design: .rounded, relativeTo: .headline)
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, 22)
                .frame(maxWidth: 540)
                .frame(minHeight: 56)
                .background(theme.primaryGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: theme.primaryShadow.opacity(0.27), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .minimumTapTarget(height: 56)
    }
}

private struct OnboardingStreakView: View {
    @Environment(SettingsStore.self) private var settings

    let claim: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 16)

                ZStack {
                    Circle().fill(theme.accent.opacity(0.13))
                    Circle().strokeBorder(theme.accent.opacity(0.28), lineWidth: 2)
                    VStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundStyle(theme.accent2)
                        Text(OnboardingCopy.oneDay)
                            .font(.headline.bold())
                    }
                }
                .frame(width: 104, height: 104)

                VStack(spacing: 8) {
                    Text(OnboardingCopy.firstStreakDay)
                        .scaledFont(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle)
                        .multilineTextAlignment(.center)
                    Label(OnboardingCopy.starterGift, systemImage: "gift.fill")
                        .font(.headline)
                        .foregroundStyle(theme.success)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(OnboardingCopy.firstSteps).font(.headline.bold())
                        Spacer()
                        Text(OnboardingCopy.fortyPercent)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.accent)
                    }
                    ProgressView(value: 0.4)
                        .tint(theme.accent)

                    ChecklistRow(text: OnboardingCopy.firstFlight, isDone: true, theme: theme)
                    ChecklistRow(text: OnboardingCopy.firstCombo, isDone: true, theme: theme)
                    ChecklistRow(text: OnboardingCopy.clearLevelFive, isDone: false, theme: theme)
                    ChecklistRow(text: OnboardingCopy.playDailyMaze, isDone: false, theme: theme)
                    ChecklistRow(text: OnboardingCopy.returnTomorrow, isDone: false, theme: theme)
                }
                .padding(20)
                .frame(maxWidth: 540)
                .themedGlass(
                    theme: theme,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )

                Label(OnboardingCopy.streakContinues, systemImage: "arrow.forward.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)

                OnboardingPrimaryButton(
                    title: OnboardingCopy.claimGift,
                    action: claim,
                    theme: theme
                )
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }
}

private struct ChecklistRow: View {
    let text: String
    let isDone: Bool
    let theme: GameTheme

    var body: some View {
        Label {
            Text(text).foregroundStyle(isDone ? theme.inkSoft : theme.inkMuted)
        } icon: {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? theme.success : theme.inkMuted)
        }
        .font(.subheadline.weight(.semibold))
    }
}

private struct OnboardingPushView: View {
    @Environment(SettingsStore.self) private var settings

    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 66, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(theme.accent2, theme.accent)
                .frame(width: 132, height: 132)
                .themedGlass(theme: theme, in: Circle(), prominence: .compact)

            Text(OnboardingCopy.pushTitle)
                .scaledFont(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)

            Text(OnboardingCopy.pushBody)
                .font(.body)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)

            Spacer()

            OnboardingPrimaryButton(
                title: OnboardingCopy.yesRemind,
                action: accept,
                theme: theme
            )

            Button(OnboardingCopy.notNow, action: decline)
                .font(.headline)
                .foregroundStyle(theme.inkSoft)
                .minimumTapTarget()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }
}

private struct OnboardingThemePickerView: View {
    @Environment(SettingsStore.self) private var settings

    let select: (AppThemeID) -> Void
    let confirm: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 18)

                    VStack(spacing: 8) {
                        Text(OnboardingCopy.chooseStyle)
                            .scaledFont(size: 34, weight: .black, design: .rounded, relativeTo: .largeTitle)
                            .foregroundStyle(theme.ink)
                        Text(OnboardingCopy.themeApplies)
                            .font(.body)
                            .foregroundStyle(theme.inkMuted)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        ForEach(AppThemeID.allCases, id: \.self) { id in
                            ThemeChoiceButton(
                                id: id,
                                selectedID: settings.settings.themeID,
                                action: select
                            )
                        }
                    }
                    .frame(maxWidth: 560)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 4) {
                Button(OnboardingCopy.later, action: skip)
                    .font(.headline)
                    .foregroundStyle(theme.inkSoft)
                    .minimumTapTarget()

                OnboardingPrimaryButton(
                    title: OnboardingCopy.continueAction,
                    action: confirm,
                    theme: theme
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }
}

private struct ThemeChoiceButton: View {
    let id: AppThemeID
    let selectedID: AppThemeID
    let action: (AppThemeID) -> Void

    private var description: String? {
        switch id {
        case .aurora: OnboardingCopy.auroraDescription
        case .neon: OnboardingCopy.neonDescription
        case .petal: OnboardingCopy.petalDescription
        case .sakura, .atlas, .nordic: nil
        }
    }

    var body: some View {
        let previewTheme = GameTheme.theme(for: id)
        let isSelected = selectedID == id

        Button { action(id) } label: {
            HStack(spacing: 14) {
                ZStack {
                    previewTheme.appBackground
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index == 1 ? "arrow.up" : "arrow.right")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(previewTheme.pieceStroke)
                        }
                    }
                }
                .frame(width: 92, height: 60)
                .clipShape(.rect(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 4) {
                    Text(OnboardingCopy.themeName(id)).font(.headline.bold())
                    if let description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(previewTheme.inkMuted)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? previewTheme.accent : previewTheme.inkMuted)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(previewTheme.appBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? previewTheme.accent : previewTheme.glassBorder, lineWidth: isSelected ? 2 : 1)
            }
            .foregroundStyle(previewTheme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingHandoffView: View {
    @Environment(SettingsStore.self) private var settings

    let continueToLevelFive: () -> Void
    let openWorldMap: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 20)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 58, weight: .black))
                    .foregroundStyle(theme.accent2)

                VStack(spacing: 7) {
                    Text(OnboardingCopy.onARoll)
                        .scaledFont(size: 38, weight: .black, design: .rounded, relativeTo: .largeTitle)
                    Text(OnboardingCopy.fourLevelsCleared)
                        .font(.headline)
                        .foregroundStyle(theme.success)
                }

                HStack(spacing: 9) {
                    ForEach(1...5, id: \.self) { level in
                        Text("\(level)")
                            .font(.headline.bold())
                            .foregroundStyle(level <= 4 ? theme.primaryText : theme.accent)
                            .frame(width: 48, height: 48)
                            .background(level <= 4 ? AnyShapeStyle(theme.primaryGradient) : AnyShapeStyle(theme.surface), in: Circle())
                            .overlay {
                                Circle().strokeBorder(level == 5 ? theme.accent : .clear, lineWidth: 2)
                            }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(OnboardingCopy.fourLevelsCleared)

                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .foregroundStyle(theme.inkMuted)
                    Text(OnboardingCopy.chapterTwoLocked)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(22)
                .frame(maxWidth: 540)
                .themedGlass(
                    theme: theme,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )

                OnboardingPrimaryButton(
                    title: OnboardingCopy.goToLevelFive,
                    action: continueToLevelFive,
                    theme: theme
                )

                Button(OnboardingCopy.worldMap, action: openWorldMap)
                    .font(.headline)
                    .foregroundStyle(theme.inkSoft)
                    .minimumTapTarget()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }
}
