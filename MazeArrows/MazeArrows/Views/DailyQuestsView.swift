//
//  DailyQuestsView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct DailyQuestsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progressStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }
    private var quests: [DailyQuest] { progressStore.currentQuests }
    private var state: DailyQuestState { progressStore.progress.dailyQuestState }
    private var completedQuestCount: Int { quests.filter(\.isComplete).count }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.bottom, 20)

                if quests.isEmpty {
                    Spacer()
                    Text("No quests today")
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            streakCard

                            ForEach(quests) { quest in
                                questCard(quest)
                            }

                            allDoneBanner
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Daily Quests")
                .scaledFont(size: 26, weight: .heavy)
                .foregroundStyle(theme.ink)

            let done = quests.filter { $0.isComplete }.count
            Text("\(done)/\(quests.count) completed")
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(theme.inkMuted)

            // Daily streak
            if progressStore.progress.dailyStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.orange)
                    Text("Streak: \(progressStore.progress.dailyStreak) days")
                        .scaledFont(size: 12, weight: .bold)
                        .foregroundStyle(theme.inkSoft)
                }
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily quests")
        .accessibilityValue(
            Text(progressStore.progress.dailyStreak > 0
                 ? "\(completedQuestCount) of \(quests.count) completed. \(progressStore.progress.dailyStreak) day streak."
                 : "\(completedQuestCount) of \(quests.count) completed.")
        )
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - streak card

    private var streakCard: some View {
        let config = EconomyConfigStore.shared.config
        let freezes = progressStore.progress.streakFreezes
        let coins = progressStore.progress.coins
        let atCap = freezes >= config.maxStreakFreezes
        let canAfford = coins >= config.streakFreezeCost
        let nextChest = config.streakChests
            .filter { !progressStore.progress.claimedStreakChests.contains($0.key) }
            .min { $0.key < $1.key }

        return VStack(alignment: .leading, spacing: 12) {
            DynamicTypeStack(spacing: 12) {
                Image(systemName: "snowflake")
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundStyle(freezes > 0 ? theme.accent : theme.inkMuted)
                    .frame(minWidth: 36, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(freezes > 0 ? theme.accent.opacity(0.12) : theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(freezes > 0 ? theme.accent.opacity(0.3) : theme.glassBorder)
                            )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak freeze · \(freezes)/\(config.maxStreakFreezes)")
                        .scaledFont(size: 16, weight: .heavy)
                        .foregroundStyle(theme.ink)
                    Text("Covers one missed day automatically")
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundStyle(theme.inkMuted)
                }

                Spacer()

                if !atCap {
                    Button {
                        progressStore.purchaseStreakFreeze(config: config)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Buy")
                                .scaledFont(size: 11, weight: .heavy)
                            Image(systemName: "circle.fill")
                                .scaledFont(size: 9)
                                .foregroundStyle(canAfford ? theme.achievementGold : theme.inkMuted)
                            Text("\(config.streakFreezeCost)")
                                .scaledFont(size: 11, weight: .heavy)
                                .monospacedDigit()
                        }
                        .foregroundStyle(canAfford ? theme.primaryText : theme.inkMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(canAfford ? AnyShapeStyle(theme.primaryGradient) : AnyShapeStyle(theme.surface))
                                .overlay(Capsule().stroke(canAfford ? .clear : theme.glassBorder))
                        )
                        .minimumTapTarget()
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAfford)
                    .accessibilityLabel("Buy streak freeze")
                    .accessibilityValue(Text("\(config.streakFreezeCost) coins"))
                    .accessibilityHint(canAfford ? Text(verbatim: "") : Text("Not enough coins."))
                }
            }

            if let nextChest {
                DynamicTypeStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundStyle(theme.accent)
                    Text("Day \(nextChest.key) streak chest")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(theme.inkSoft)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .scaledFont(size: 10, weight: .bold)
                            .foregroundStyle(theme.achievementGold)
                        Text("+\(nextChest.value)")
                            .scaledFont(size: 12, weight: .heavy)
                            .foregroundStyle(Color(red: 0.48, green: 0.33, blue: 0.06))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(red: 1, green: 0.96, blue: 0.85)))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Next streak chest")
                .accessibilityValue(
                    Text("Day \(nextChest.key). \(nextChest.value) coins.")
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.glassBorder)
                )
        )
    }

    // MARK: - quest card

    private func questCard(_ quest: DailyQuest) -> some View {
        let claimed = state.claimedRewards.contains(quest.id)

        return VStack(alignment: .leading, spacing: 12) {
            DynamicTypeStack(spacing: 12) {
                Image(systemName: questIcon(quest.type))
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundStyle(quest.isComplete ? theme.accent : theme.inkMuted)
                    .frame(minWidth: 36, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(quest.isComplete ? theme.accent.opacity(0.12) : theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(quest.isComplete ? theme.accent.opacity(0.3) : theme.glassBorder)
                            )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.title)
                        .scaledFont(size: 16, weight: .heavy)
                        .foregroundStyle(theme.ink)
                    Text(quest.details)
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundStyle(theme.inkMuted)
                }

                Spacer()

                // Reward badge
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundStyle(theme.achievementGold)
                    Text("+\(quest.reward)")
                        .scaledFont(size: 12, weight: .heavy)
                        .foregroundStyle(Color(red: 0.48, green: 0.33, blue: 0.06))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(red: 1, green: 0.96, blue: 0.85))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Reward")
                .accessibilityValue(Text("\(quest.reward) coins"))
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.glassBorder)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(quest.isComplete ? theme.success : theme.accent)
                            .frame(width: geo.size.width * quest.progressFraction, height: 6)
                            .animation(
                                reduceMotion ? nil : .spring(duration: 0.5),
                                value: quest.progress
                            )
                    }
                }
                .frame(height: 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Quest progress")
                .accessibilityValue(Text("\(quest.progress) of \(quest.target)"))

                DynamicTypeStack(spacing: 8) {
                    Text("\(quest.progress)/\(quest.target)")
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundStyle(theme.inkSoft)
                        .accessibilityHidden(true)
                    Spacer()
                    if quest.isComplete && !claimed {
                        Button {
                            progressStore.claimQuestReward(questId: quest.id)
                        } label: {
                            Text("Claim")
                                .scaledFont(size: 11, weight: .heavy)
                                .foregroundStyle(theme.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(theme.primaryGradient))
                                .minimumTapTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Claim reward")
                        .accessibilityValue(Text("\(quest.reward) coins"))
                    } else if claimed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .scaledFont(size: 12)
                            Text("Claimed")
                                .scaledFont(size: 11, weight: .heavy)
                        }
                        .foregroundStyle(theme.success)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(quest.isComplete ? theme.accent.opacity(0.35) : theme.glassBorder)
                )
        )
    }

    // MARK: - all done banner

    @ViewBuilder
    private var allDoneBanner: some View {
        if quests.allSatisfy({ $0.isComplete }) {
            DynamicTypeStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .scaledFont(size: 24, weight: .bold)
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("All quests done!")
                        .scaledFont(size: 16, weight: .heavy)
                        .foregroundStyle(theme.ink)
                    Text("Come back tomorrow for new challenges")
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.accent.opacity(0.25))
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("All daily quests completed")
            .accessibilityValue("Come back tomorrow for new challenges")
        }
    }

    // MARK: - helpers

    private func questIcon(_ type: QuestType) -> String {
        switch type {
        case .completeLevels:   return "flag.fill"
        case .perfectClears:    return "star.fill"
        case .hintlessClears:   return "eye.slash.fill"
        case .solveDailyPuzzle: return "moon.stars.fill"
        }
    }
}

#Preview {
    DailyQuestsView()
        .environment(SettingsStore.shared)
        .environment(ProgressStore.shared)
}
