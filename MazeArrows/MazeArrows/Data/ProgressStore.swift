//
//  ProgressStore.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import Observation

@MainActor
@Observable
final class ProgressStore {
    static let shared = ProgressStore()
    private let defaultsKey = "MazeArrows.PlayerProgress.v2"
    private let defaults: UserDefaults

    var progress: PlayerProgress {
        didSet { save() }
    }

    /// Recently earned achievement IDs — consumed by the UI to show banners.
    private(set) var newlyEarnedAchievements: [AchievementID] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            self.progress = decoded
        } else {
            // Migrate from v1 key if present
            if let oldData = defaults.data(forKey: "MazeArrows.PlayerProgress.v1"),
               let old = try? JSONDecoder().decode(PlayerProgress.self, from: oldData) {
                self.progress = old
            } else {
                self.progress = .initial
            }
        }
        refreshDailyQuestsIfNeeded()
        #if DEBUG
        // Dev shortcut for testing late levels: launch with -unlockAllLevels.
        if ProcessInfo.processInfo.arguments.contains("-unlockAllLevels") {
            progress.unlockedLevelIndex = 999
        }
        #endif
    }

    // MARK: - Level completion

    @discardableResult
    func recordStoryCompletion(levelIndex: Int, mistakesCount: Int, level: Level) -> Int {
        guard levelIndex > 0 else {
            assertionFailure("Campaign progress requires a positive story level index")
            return 0
        }
        let stars = level.stars(for: mistakesCount)
        let earnedStarDelta = progress.mark(levelIndex: levelIndex, stars: stars)
        let reward = 25 * earnedStarDelta
        grantCoins(reward)

        checkProgressAchievements(levelIndex: levelIndex)
        return reward
    }

    func recordStoryBestTime(levelIndex: Int, seconds: Int) {
        guard levelIndex > 0 else {
            assertionFailure("Campaign best times require a positive story level index")
            return
        }
        progress.recordBestTime(levelIndex: levelIndex, seconds: seconds)
    }

    /// Applies the campaign handoff promised by onboarding without triggering
    /// normal level rewards, quests, or achievements a second time.
    func applyCompletedOnboardingProgress() {
        var updated = progress
        for levelIndex in 1...4 {
            updated.completedLevels.insert(levelIndex)
            updated.stars[levelIndex] = max(updated.stars[levelIndex] ?? 0, 3)
        }
        updated.unlockedLevelIndex = max(updated.unlockedLevelIndex, 5)
        progress = updated
    }

    /// The one-time Day 1 onboarding gift. Idempotence is owned by
    /// `OnboardingStore`, keeping campaign and achievement accounting clean.
    func grantOnboardingStarterReward() {
        progress.coins += 25
    }

    // MARK: - Consumables

    func consumeHint() -> Bool {
        guard progress.hintsCount > 0 else { return false }
        progress.hintsCount -= 1
        return true
    }

    func consumeUndo() -> Bool {
        guard progress.undosCount > 0 else { return false }
        progress.undosCount -= 1
        return true
    }

    func grantHint(_ count: Int = 1) { progress.hintsCount += count }
    func grantUndo(_ count: Int = 1) { progress.undosCount += count }

    // MARK: - Photo Maze

    func photoMazeFreeGenerationsRemaining(
        policy: PhotoMazeGenerationPolicy = .standard
    ) -> Int {
        policy.freeGenerationsRemaining(
            used: progress.photoMazeFreeGenerationsUsed
        )
    }

    func photoMazeGenerationAccess(
        isPremium: Bool,
        policy: PhotoMazeGenerationPolicy = .standard
    ) -> PhotoMazeGenerationAccess? {
        policy.access(
            isPremium: isPremium,
            freeGenerationsUsed: progress.photoMazeFreeGenerationsUsed,
            rewardedCredits: progress.photoMazeRewardedCredits
        )
    }

    /// The reward is stored immediately when Google confirms it. If the next
    /// maze build fails, the user keeps the credit and can try another photo.
    func grantPhotoMazeRewardedCredit() {
        progress.photoMazeRewardedCredits += 1
    }

    /// Charges only a successfully built maze. Reopening or sharing the
    /// cached maze does not call this method and therefore costs nothing.
    @discardableResult
    func commitSuccessfulPhotoMazeGeneration(
        using access: PhotoMazeGenerationAccess,
        policy: PhotoMazeGenerationPolicy = .standard
    ) -> Bool {
        switch access {
        case .premium:
            return true
        case .free:
            guard photoMazeFreeGenerationsRemaining(policy: policy) > 0 else {
                return false
            }
            progress.photoMazeFreeGenerationsUsed += 1
            return true
        case .rewarded:
            guard progress.photoMazeRewardedCredits > 0 else { return false }
            progress.photoMazeRewardedCredits -= 1
            return true
        }
    }

    // MARK: - Economy

    /// Single point where coins leave the balance.
    @discardableResult
    func spendCoins(_ amount: Int) -> Bool {
        guard amount > 0, progress.coins >= amount else { return false }
        progress.coins -= amount
        return true
    }

    @discardableResult
    func purchaseHint(config: EconomyConfig = EconomyConfigStore.shared.config) -> Bool {
        guard spendCoins(config.hintCost) else { return false }
        grantHint()
        Analytics.log(.coinsSpent(sink: "hint", amount: config.hintCost, balance: progress.coins))
        return true
    }

    @discardableResult
    func purchaseUndo(config: EconomyConfig = EconomyConfigStore.shared.config) -> Bool {
        guard spendCoins(config.undoCost) else { return false }
        grantUndo()
        Analytics.log(.coinsSpent(sink: "undo", amount: config.undoCost, balance: progress.coins))
        return true
    }

    /// Pays for a revive. Restoring lives is the game session's job — the
    /// view model owns `lives`, so this only settles the coin side.
    @discardableResult
    func purchaseRevive(config: EconomyConfig = EconomyConfigStore.shared.config) -> Bool {
        guard spendCoins(config.reviveCost) else { return false }
        Analytics.log(.coinsSpent(sink: "revive", amount: config.reviveCost, balance: progress.coins))
        return true
    }

    @discardableResult
    func purchaseStreakFreeze(config: EconomyConfig = EconomyConfigStore.shared.config) -> Bool {
        guard progress.streakFreezes < config.maxStreakFreezes else { return false }
        guard spendCoins(config.streakFreezeCost) else { return false }
        progress.streakFreezes += 1
        Analytics.log(.coinsSpent(sink: "streak_freeze", amount: config.streakFreezeCost, balance: progress.coins))
        return true
    }

    // MARK: - Zen

    /// Free Zen levels left for the given UTC day.
    func zenRemainingToday(
        date: String,
        config: EconomyConfig = EconomyConfigStore.shared.config
    ) -> Int {
        let played = progress.zenPlayedDate == date ? progress.zenPlayedCount : 0
        return max(0, config.zenFreeLevelsPerDay - played)
    }

    /// Zen completions count toward the daily free limit and grant nothing —
    /// generated content must never feed the coin economy.
    func recordZenCompletion(date: String) {
        if progress.zenPlayedDate != date {
            progress.zenPlayedDate = date
            progress.zenPlayedCount = 0
        }
        progress.zenPlayedCount += 1
    }

    // MARK: - Master layer

    func masterClears(levelIndex: Int) -> Set<GameMode> {
        progress.masterClears[levelIndex] ?? []
    }

    /// One-time crown + coin reward per (level, modifier) pair. Deliberately
    /// leaves stars, unlocks, best times and quests untouched.
    @discardableResult
    func recordMasterCompletion(
        levelIndex: Int,
        modifier: GameMode,
        config: EconomyConfig = EconomyConfigStore.shared.config
    ) -> Int {
        guard levelIndex > 0, GameMode.masterModifiers.contains(modifier) else { return 0 }
        var cleared = progress.masterClears[levelIndex] ?? []
        guard cleared.insert(modifier).inserted else { return 0 }
        progress.masterClears[levelIndex] = cleared
        grantCoins(config.masterClearReward)
        Analytics.log(.masterClear(levelIndex: levelIndex, modifier: modifier.rawValue))
        return config.masterClearReward
    }

    // MARK: - Reset

    func resetAll() {
        progress = .initial
        refreshDailyQuestsIfNeeded()
    }

    // MARK: - Daily

    @discardableResult
    func recordDailyCompletion(
        date: String,
        mistakesCount: Int,
        level: Level,
        config: EconomyConfig = EconomyConfigStore.shared.config
    ) -> Int {
        let isFirstCompletion = progress.claimDailyCompletion(date)
        let reward = isFirstCompletion ? 25 * level.stars(for: mistakesCount) : 0
        grantCoins(reward)

        if isFirstCompletion {
            updateStreak(completionDate: date)
            claimStreakChests(config: config)
        }

        updateQuestProgress(type: .solveDailyPuzzle, increment: 1)
        checkStreakAchievements()
        return reward
    }

    private func updateStreak(completionDate date: String) {
        guard let last = progress.lastDailyCompletionDate else {
            progress.dailyStreak = 1
            progress.bestDailyStreak = max(progress.bestDailyStreak, progress.dailyStreak)
            progress.lastDailyCompletionDate = date
            return
        }
        guard last != date else { return }

        switch dayGap(from: last, to: date) {
        case 1:
            progress.dailyStreak += 1
        case 2 where progress.streakFreezes > 0:
            // Exactly one missed day — a streak freeze silently covers it.
            progress.streakFreezes -= 1
            progress.dailyStreak += 1
            Analytics.log(.streakFreezeUsed)
        default:
            progress.dailyStreak = 1
        }
        progress.bestDailyStreak = max(progress.bestDailyStreak, progress.dailyStreak)
        progress.lastDailyCompletionDate = date
    }

    /// One-time milestone chests. Thresholds stay claimed forever, so a
    /// broken-and-rebuilt streak cannot farm them.
    private func claimStreakChests(config: EconomyConfig) {
        for (threshold, coins) in config.streakChests.sorted(by: { $0.key < $1.key }) {
            guard progress.dailyStreak >= threshold,
                  !progress.claimedStreakChests.contains(threshold) else { continue }
            progress.claimedStreakChests.insert(threshold)
            grantCoins(coins)
            Analytics.log(.streakChestClaimed(day: threshold, coins: coins))
        }
    }

    // MARK: - Achievements

    func unlockAchievement(_ id: AchievementID) {
        guard !progress.hasEarned(id) else { return }
        progress.earn(id)
        newlyEarnedAchievements.append(id)
        // Bonus coins for earning an achievement
        grantCoins(50)
    }

    func consumeNewAchievements() -> [AchievementID] {
        let earned = newlyEarnedAchievements
        newlyEarnedAchievements = []
        return earned
    }

    func checkSkillAchievements(
        mistakesCount: Int,
        hintsUsed: Int,
        elapsedSeconds: Int,
        maxCombo: Int,
        levelIndex: Int
    ) {
        if mistakesCount == 0 && hintsUsed == 0 {
            unlockAchievement(.perfectClear)
        }
        if hintsUsed == 0 {
            unlockAchievement(.hintlessWin)
        }
        if elapsedSeconds > 0 && elapsedSeconds < 60 {
            unlockAchievement(.speedrun)
        }
        if maxCombo >= 5 {
            unlockAchievement(.comboMaster)
        }

        // Flawless Meadow: all Chapter 1 levels at 3 stars
        let chapter1 = Chapter.all[0]
        let allPerfect = chapter1.levelRange.allSatisfy { progress.bestStars($0) == 3 }
        if allPerfect { unlockAchievement(.perfectChapter1) }
    }

    // MARK: - Weekly challenge

    @discardableResult
    func markWeeklyCompleted(week: String) -> Int {
        guard !progress.hasCompletedWeekly(week) else { return 0 }
        progress.weeklyCompletions.insert(week)
        grantCoins(150)
        unlockAchievement(.weeklyChampion)
        return 150
    }

    // MARK: - Daily Quests

    var currentQuests: [DailyQuest] {
        progress.dailyQuestState.quests
    }

    func refreshDailyQuestsIfNeeded() {
        let provider = DailyQuestProvider.shared
        let today = provider.todayDateString()
        guard progress.dailyQuestState.date != today else { return }
        let fresh = provider.quests(for: today)
        progress.dailyQuestState = DailyQuestState(date: today, quests: fresh, claimedRewards: [])
    }

    func updateQuestProgress(type: QuestType, increment: Int = 1) {
        refreshDailyQuestsIfNeeded()
        var state = progress.dailyQuestState
        var anyCompleted = false
        for i in state.quests.indices {
            guard state.quests[i].type == type,
                  !state.quests[i].isComplete else { continue }
            state.quests[i].progress = min(
                state.quests[i].target,
                state.quests[i].progress + increment
            )
            if state.quests[i].isComplete { anyCompleted = true }
        }
        progress.dailyQuestState = state

        if anyCompleted { checkQuestAchievement() }
    }

    func claimQuestReward(questId: String) {
        guard var state = Optional(progress.dailyQuestState),
              !state.claimedRewards.contains(questId),
              let idx = state.quests.firstIndex(where: { $0.id == questId }),
              state.quests[idx].isComplete
        else { return }

        state.claimedRewards.insert(questId)
        let reward = state.quests[idx].reward
        progress.dailyQuestState = state
        grantCoins(reward)
    }

    // MARK: - private

    private func checkProgressAchievements(levelIndex: Int) {
        if !progress.completedLevels.isEmpty {
            unlockAchievement(.firstClear)
        }
        for chapter in Chapter.all {
            if chapter.isComplete(progress: progress) {
                switch chapter.id {
                case 1: unlockAchievement(.chapter1Complete)
                case 2: unlockAchievement(.chapter2Complete)
                case 3: unlockAchievement(.chapter3Complete)
                default: break
                }
            }
        }
        if Chapter.originalCampaignRange.allSatisfy({ progress.completedLevels.contains($0) }) {
            unlockAchievement(.allLevelsComplete)
        }
        // Only count story levels (positive index) toward "complete N levels" quests
        if levelIndex > 0 {
            updateQuestProgress(type: .completeLevels, increment: 1)
        }
    }

    private func checkStreakAchievements() {
        if progress.dailyStreak >= 3 { unlockAchievement(.streak3) }
        if progress.dailyStreak >= 7 { unlockAchievement(.streak7) }
    }

    private func checkQuestAchievement() {
        let allDone = progress.dailyQuestState.quests.allSatisfy { $0.isComplete }
        if allDone { unlockAchievement(.questComplete) }
    }

    private func grantCoins(_ amount: Int) {
        guard amount > 0 else { return }
        progress.coins += amount
        if progress.coins >= 200, !progress.hasEarned(.coinCollector) {
            unlockAchievement(.coinCollector)
        }
    }

    private func dayGap(from a: String, to b: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        guard let da = f.date(from: a), let db = f.date(from: b) else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: da, to: db).day
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
