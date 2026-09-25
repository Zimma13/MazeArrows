//
//  AdService.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import GoogleMobileAds
import Observation
import UserMessagingPlatform

/// Resolves the advertising treatment from the age signal already supplied by
/// Game Center. Unknown players keep the app's general-audience configuration;
/// ads stay fail-closed only while Game Center authentication is still pending.
enum AdAgePolicy: Equatable, Sendable {
    case pending
    case restricted
    case unrestricted
    case unknown

    static func resolve(
        connectionState: GameCenterConnectionState,
        player: GameCenterPlayerProfile?
    ) -> Self {
        switch connectionState {
        case .idle, .authenticating, .awaitingPlayerAction:
            return .pending
        case .authenticated:
            guard let player else { return .pending }
            return player.isUnderage ? .restricted : .unrestricted
        case .unavailable:
            return .unknown
        }
    }

    var allowsAdBootstrap: Bool {
        self != .pending
    }

    var isTaggedForUnderAgeOfConsent: Bool {
        self == .restricted
    }

    var usesChildAgeTreatment: Bool {
        self == .restricted
    }
}

/// Owns privacy consent and the lifetime of Google Mobile Ads. Every format
/// stays fail-closed until StoreKit, age treatment, and UMP have allowed ad
/// requests.
@MainActor
@Observable
final class AdService: NSObject {
    enum State: Equatable {
        case waitingForEntitlements
        case waitingForAgeTreatment
        case disabledForPremium
        case requestingConsent
        case consentRequired
        case ready
        case unavailable
    }

    private(set) var state: State = .waitingForEntitlements
    private(set) var canRequestAds = false
    private(set) var isPrivacyOptionsRequired = false
    private(set) var isPresentingPrivacyOptions = false
    private(set) var isInterstitialReady = false
    private(set) var isPresentingInterstitial = false
    private(set) var rewardedReadyPlacements: Set<RewardedAdPlacement> = []
    private(set) var isPresentingRewardedAd = false

    @ObservationIgnored
    private var isPremium = true
    @ObservationIgnored
    private var agePolicy: AdAgePolicy = .pending
    @ObservationIgnored
    private var isPreparing = false
    @ObservationIgnored
    private var needsPreparation = false
    @ObservationIgnored
    private var statusRevision = 0
    @ObservationIgnored
    private var lastRequestedAgePolicy: AdAgePolicy?
    @ObservationIgnored
    private var inventoryGeneration = 0
    @ObservationIgnored
    private var hasStartedMobileAds = false
    @ObservationIgnored
    private var interstitialAd: InterstitialAd?
    @ObservationIgnored
    private var interstitialLoadedAt: Date?
    @ObservationIgnored
    private var interstitialLoadTask: Task<Void, Never>?
    @ObservationIgnored
    private var interstitialLoadID: UUID?
    @ObservationIgnored
    private var interstitialRetryTask: Task<Void, Never>?
    @ObservationIgnored
    private var interstitialRetryAttempt = 0
    @ObservationIgnored
    private let interstitialPolicy = InterstitialAdFrequencyPolicy.standard
    @ObservationIgnored
    private var interstitialPolicyState = InterstitialAdFrequencyPolicy.State()
    @ObservationIgnored
    private var rewardedAds: [RewardedAdPlacement: RewardedAd] = [:]
    @ObservationIgnored
    private var rewardedLoadedAt: [RewardedAdPlacement: Date] = [:]
    @ObservationIgnored
    private var rewardedLoadTasks: [RewardedAdPlacement: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var rewardedLoadIDs: [RewardedAdPlacement: UUID] = [:]
    @ObservationIgnored
    private var rewardedRetryTasks: [RewardedAdPlacement: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var rewardedRetryAttempts: [RewardedAdPlacement: Int] = [:]
    @ObservationIgnored
    private var presentingRewardedPlacement: RewardedAdPlacement?
    @ObservationIgnored
    private var rewardedUserEarnedReward = false
    @ObservationIgnored
    private var rewardedResultContinuation: CheckedContinuation<Bool, Never>?

    private static let maximumInterstitialAge: TimeInterval = 55 * 60
    private static let maximumRewardedAge: TimeInterval = 55 * 60
    private static let interstitialRetryDelays: [Duration] = [
        .seconds(5), .seconds(15), .seconds(60), .seconds(300)
    ]
    private static let rewardedRetryDelays: [Duration] = [
        .seconds(5), .seconds(15), .seconds(60), .seconds(300)
    ]

    private enum InterstitialDefaultsKey {
        static let eligibleCompletions = "ads.interstitial.eligibleCompletions"
        static let presentationCount = "ads.interstitial.presentationCount"
        static let lastPresentedAt = "ads.interstitial.lastPresentedAt"
    }

    override init() {
        super.init()
        restoreInterstitialPolicyState()
    }

    /// Resolves the fail-closed startup state after StoreKit entitlements and
    /// Game Center's available age signal load. Premium users never initialize
    /// Google Mobile Ads or make ad requests.
    func updateStatus(isPremium: Bool, agePolicy: AdAgePolicy) async {
        let statusChanged = self.isPremium != isPremium || self.agePolicy != agePolicy
        self.isPremium = isPremium
        self.agePolicy = agePolicy

        if statusChanged {
            statusRevision += 1
        }

        guard !isPremium else {
            canRequestAds = false
            state = .disabledForPremium
            discardAllInventory()
            return
        }

        guard agePolicy.allowsAdBootstrap else {
            canRequestAds = false
            state = .waitingForAgeTreatment
            discardAllInventory()
            return
        }

        if statusChanged, lastRequestedAgePolicy != agePolicy {
            canRequestAds = false
            discardAllInventory()
        }

        await prepareIfNeeded()
    }

    /// Presents the publisher privacy choices form in response to a user tap.
    /// Returns `false` when no form could be presented.
    func presentPrivacyOptions() async -> Bool {
        guard !isPremium,
              agePolicy.allowsAdBootstrap,
              lastRequestedAgePolicy == agePolicy,
              isPrivacyOptionsRequired,
              !isPresentingPrivacyOptions
        else { return false }

        isPresentingPrivacyOptions = true
        defer { isPresentingPrivacyOptions = false }

        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            refreshConsentState()
            if canRequestAds {
                startMobileAdsIfNeeded()
                preloadInterstitialIfNeeded()
                preloadRewardedOfferAdsIfNeeded()
            } else {
                discardAllInventory()
            }
            return true
        } catch {
            refreshConsentState()
            if !canRequestAds {
                discardAllInventory()
            }
            return false
        }
    }

    private func prepareIfNeeded() async {
        guard !isPreparing else {
            needsPreparation = true
            return
        }

        isPreparing = true
        defer { isPreparing = false }

        repeat {
            needsPreparation = false
            await prepareCurrentStatus()
        } while needsPreparation
    }

    private func prepareCurrentStatus() async {
        guard !isPremium else {
            canRequestAds = false
            state = .disabledForPremium
            return
        }

        guard agePolicy.allowsAdBootstrap else {
            canRequestAds = false
            state = .waitingForAgeTreatment
            return
        }

        let requestedPolicy = agePolicy
        let requestedRevision = statusRevision
        applyMobileAdsRequestConfiguration(for: requestedPolicy)

        if hasStartedMobileAds,
           lastRequestedAgePolicy == requestedPolicy,
           ConsentInformation.shared.canRequestAds {
            refreshConsentState()
            state = .ready
            preloadInterstitialIfNeeded()
            preloadRewardedOfferAdsIfNeeded()
            return
        }

        state = .requestingConsent
        let parameters = consentRequestParameters(for: requestedPolicy)
        let updateSucceeded = await requestConsentInfoUpdate(with: parameters)

        guard requestedRevision == statusRevision,
              requestedPolicy == agePolicy
        else {
            needsPreparation = true
            return
        }

        guard updateSucceeded else {
            lastRequestedAgePolicy = nil
            refreshConsentState()
            discardAllInventory()
            state = .unavailable
            return
        }
        lastRequestedAgePolicy = requestedPolicy

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // The successfully refreshed consent information below remains the
            // source of truth when no form could be presented.
        }

        guard requestedRevision == statusRevision,
              requestedPolicy == agePolicy
        else {
            needsPreparation = true
            return
        }

        refreshConsentState()

        guard canRequestAds else {
            discardAllInventory()
            state = ConsentInformation.shared.consentStatus == .required
                ? .consentRequired
                : .unavailable
            return
        }

        startMobileAdsIfNeeded()
        state = .ready
        preloadInterstitialIfNeeded()
        preloadRewardedOfferAdsIfNeeded()
    }

    /// Records a first-time story clear and returns whether the UI should
    /// insert a short transition before presenting the already-loaded ad.
    func registerInterstitialOpportunity(
        isFirstStoryCompletion: Bool,
        allowsPresentation: Bool
    ) -> Bool {
        guard FeatureFlags.interstitialAdsAvailable,
              isFirstStoryCompletion,
              !isPremium,
              !isPresentingRewardedAd
        else { return false }

        let isDue = interstitialPolicy.recordEligibleCompletion(
            in: &interstitialPolicyState,
            now: .now
        )
        persistInterstitialPolicyState()

        guard isDue,
              allowsPresentation,
              canRequestAds,
              !isPresentingInterstitial,
              !isPresentingRewardedAd,
              freshInterstitialAd() != nil
        else {
            preloadInterstitialIfNeeded()
            return false
        }

        return true
    }

    /// Presents only inventory that was preloaded before the level ended.
    /// A late load never interrupts a user after they have continued.
    func presentInterstitialIfReady() -> Bool {
        guard FeatureFlags.interstitialAdsAvailable,
              !isPremium,
              canRequestAds,
              !isPresentingInterstitial,
              !isPresentingRewardedAd,
              let interstitialAd = freshInterstitialAd()
        else {
            preloadInterstitialIfNeeded()
            return false
        }

        do {
            try interstitialAd.canPresent(from: nil)
        } catch {
            clearInterstitial()
            preloadInterstitialIfNeeded()
            return false
        }

        isInterstitialReady = false
        interstitialAd.present(from: nil)
        return true
    }

    private func requestConsentInfoUpdate(
        with parameters: RequestParameters
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(
                with: parameters
            ) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private func refreshConsentState() {
        isPrivacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        canRequestAds = !isPremium
            && agePolicy.allowsAdBootstrap
            && lastRequestedAgePolicy == agePolicy
            && ConsentInformation.shared.canRequestAds
    }

    private func startMobileAdsIfNeeded() {
        guard !isPremium, canRequestAds, !hasStartedMobileAds else { return }

        applyMobileAdsRequestConfiguration(for: agePolicy)
        MobileAds.shared.start()
        hasStartedMobileAds = true
        preloadInterstitialIfNeeded()
        preloadRewardedOfferAdsIfNeeded()
    }

    private func applyMobileAdsRequestConfiguration(for policy: AdAgePolicy) {
        let requestConfiguration = MobileAds.shared.requestConfiguration
        requestConfiguration.ageRestrictedTreatment = policy.usesChildAgeTreatment
            ? .child
            : .unspecified
        requestConfiguration.maxAdContentRating = GADMaxAdContentRating.general
        requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        requestConfiguration.setPublisherFirstPartyIDEnabled(false)
    }

    private func preloadInterstitialIfNeeded() {
        guard FeatureFlags.interstitialAdsAvailable,
              !isPremium,
              canRequestAds,
              hasStartedMobileAds,
              !isPresentingInterstitial,
              interstitialLoadTask == nil
        else { return }

        if freshInterstitialAd() != nil {
            isInterstitialReady = true
            return
        }

        let loadID = UUID()
        let loadGeneration = inventoryGeneration
        interstitialLoadID = loadID
        interstitialLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let ad = try await InterstitialAd.load(
                    with: AdMobConfiguration.current.interstitialLevelComplete,
                    request: Request()
                )
                guard !Task.isCancelled,
                      self.ownsInterstitialLoad(
                          id: loadID,
                          generation: loadGeneration
                      ),
                      !self.isPremium,
                      self.canRequestAds
                else {
                    self.finishInterstitialLoad(id: loadID)
                    return
                }

                ad.fullScreenContentDelegate = self
                self.interstitialAd = ad
                self.interstitialLoadedAt = .now
                self.isInterstitialReady = true
                self.interstitialRetryAttempt = 0
                self.interstitialRetryTask?.cancel()
                self.interstitialRetryTask = nil
                self.finishInterstitialLoad(id: loadID)
            } catch {
                guard !Task.isCancelled,
                      self.ownsInterstitialLoad(
                          id: loadID,
                          generation: loadGeneration
                      )
                else {
                    self.finishInterstitialLoad(id: loadID)
                    return
                }
                self.finishInterstitialLoad(id: loadID)
                self.clearInterstitial()
                self.scheduleInterstitialRetry()
            }
        }
    }

    private func scheduleInterstitialRetry() {
        guard !isPremium,
              canRequestAds,
              interstitialRetryTask == nil
        else { return }

        let index = min(
            interstitialRetryAttempt,
            Self.interstitialRetryDelays.count - 1
        )
        let delay = Self.interstitialRetryDelays[index]
        interstitialRetryAttempt += 1

        interstitialRetryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.interstitialRetryTask = nil
            self.preloadInterstitialIfNeeded()
        }
    }

    private func freshInterstitialAd() -> InterstitialAd? {
        guard let interstitialAd,
              let interstitialLoadedAt,
              Date.now.timeIntervalSince(interstitialLoadedAt) < Self.maximumInterstitialAge
        else {
            clearInterstitial()
            return nil
        }
        return interstitialAd
    }

    private func clearInterstitial() {
        interstitialAd = nil
        interstitialLoadedAt = nil
        isInterstitialReady = false
    }

    private func ownsInterstitialLoad(id: UUID, generation: Int) -> Bool {
        interstitialLoadID == id && inventoryGeneration == generation
    }

    private func finishInterstitialLoad(id: UUID) {
        guard interstitialLoadID == id else { return }
        interstitialLoadTask = nil
        interstitialLoadID = nil
    }

    private func discardInterstitialInventory() {
        interstitialLoadTask?.cancel()
        interstitialLoadTask = nil
        interstitialLoadID = nil
        interstitialRetryTask?.cancel()
        interstitialRetryTask = nil
        interstitialRetryAttempt = 0
        clearInterstitial()
    }

    /// Returns true only for fresh inventory that can be offered immediately.
    /// Rewarded ads are never started speculatively after the user taps.
    func isRewardedAdReady(for placement: RewardedAdPlacement) -> Bool {
        guard FeatureFlags.adsAvailable,
              !isPremium,
              canRequestAds,
              !isPresentingInterstitial,
              !isPresentingRewardedAd,
              rewardedReadyPlacements.contains(placement),
              rewardedAds[placement] != nil,
              let loadedAt = rewardedLoadedAt[placement]
        else { return false }

        return Date.now.timeIntervalSince(loadedAt) < Self.maximumRewardedAge
    }

    /// Lets feature flows warm a placement before showing an offer. Ordinary
    /// gameplay preloads the three resource placements automatically.
    func preloadRewardedAd(for placement: RewardedAdPlacement) {
        preloadRewardedAdIfNeeded(for: placement)
    }

    /// Presents an explicitly selected rewarded ad and resolves only after it
    /// closes. `true` means Google's earn-reward callback was received.
    func presentRewardedAd(
        for placement: RewardedAdPlacement,
        onUserEarnedReward: @escaping @MainActor () -> Void
    ) async -> Bool {
        guard isRewardedAdReady(for: placement),
              let rewardedAd = freshRewardedAd(for: placement)
        else {
            preloadRewardedAdIfNeeded(for: placement)
            return false
        }

        do {
            try rewardedAd.canPresent(from: nil)
        } catch {
            clearRewardedAd(for: placement)
            preloadRewardedAdIfNeeded(for: placement)
            return false
        }

        rewardedAds[placement] = nil
        rewardedLoadedAt[placement] = nil
        rewardedReadyPlacements.remove(placement)
        presentingRewardedPlacement = placement
        rewardedUserEarnedReward = false
        isPresentingRewardedAd = true

        return await withCheckedContinuation { continuation in
            rewardedResultContinuation = continuation
            rewardedAd.present(from: nil) { [weak self] in
                guard let self, !self.rewardedUserEarnedReward else { return }
                self.rewardedUserEarnedReward = true
                onUserEarnedReward()
            }
        }
    }

    private func preloadRewardedOfferAdsIfNeeded() {
        for placement in RewardedAdPlacement.resourceOffers {
            preloadRewardedAdIfNeeded(for: placement)
        }
    }

    private func preloadRewardedAdIfNeeded(for placement: RewardedAdPlacement) {
        guard FeatureFlags.adsAvailable,
              !isPremium,
              canRequestAds,
              hasStartedMobileAds,
              presentingRewardedPlacement != placement,
              rewardedLoadTasks[placement] == nil
        else { return }

        if freshRewardedAd(for: placement) != nil {
            rewardedReadyPlacements.insert(placement)
            return
        }

        let loadID = UUID()
        let loadGeneration = inventoryGeneration
        rewardedLoadIDs[placement] = loadID
        rewardedLoadTasks[placement] = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let ad = try await RewardedAd.load(
                    with: placement.adUnitID(in: AdMobConfiguration.current),
                    request: Request()
                )
                guard !Task.isCancelled,
                      self.ownsRewardedLoad(
                          id: loadID,
                          generation: loadGeneration,
                          for: placement
                      ),
                      !self.isPremium,
                      self.canRequestAds
                else {
                    self.finishRewardedLoad(id: loadID, for: placement)
                    return
                }

                ad.fullScreenContentDelegate = self
                self.rewardedAds[placement] = ad
                self.rewardedLoadedAt[placement] = .now
                self.rewardedReadyPlacements.insert(placement)
                self.rewardedRetryAttempts[placement] = 0
                self.rewardedRetryTasks[placement]?.cancel()
                self.rewardedRetryTasks[placement] = nil
                self.finishRewardedLoad(id: loadID, for: placement)
            } catch {
                guard !Task.isCancelled,
                      self.ownsRewardedLoad(
                          id: loadID,
                          generation: loadGeneration,
                          for: placement
                      )
                else {
                    self.finishRewardedLoad(id: loadID, for: placement)
                    return
                }
                self.finishRewardedLoad(id: loadID, for: placement)
                self.clearRewardedAd(for: placement)
                self.scheduleRewardedRetry(for: placement)
            }
        }
    }

    private func scheduleRewardedRetry(for placement: RewardedAdPlacement) {
        guard !isPremium,
              canRequestAds,
              rewardedRetryTasks[placement] == nil
        else { return }

        let attempt = rewardedRetryAttempts[placement, default: 0]
        let index = min(attempt, Self.rewardedRetryDelays.count - 1)
        let delay = Self.rewardedRetryDelays[index]
        rewardedRetryAttempts[placement] = attempt + 1

        rewardedRetryTasks[placement] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.rewardedRetryTasks[placement] = nil
            self.preloadRewardedAdIfNeeded(for: placement)
        }
    }

    private func freshRewardedAd(for placement: RewardedAdPlacement) -> RewardedAd? {
        guard let ad = rewardedAds[placement],
              let loadedAt = rewardedLoadedAt[placement],
              Date.now.timeIntervalSince(loadedAt) < Self.maximumRewardedAge
        else {
            clearRewardedAd(for: placement)
            return nil
        }
        return ad
    }

    private func clearRewardedAd(for placement: RewardedAdPlacement) {
        rewardedAds[placement] = nil
        rewardedLoadedAt[placement] = nil
        rewardedReadyPlacements.remove(placement)
    }

    private func ownsRewardedLoad(
        id: UUID,
        generation: Int,
        for placement: RewardedAdPlacement
    ) -> Bool {
        rewardedLoadIDs[placement] == id && inventoryGeneration == generation
    }

    private func finishRewardedLoad(id: UUID, for placement: RewardedAdPlacement) {
        guard rewardedLoadIDs[placement] == id else { return }
        rewardedLoadTasks[placement] = nil
        rewardedLoadIDs[placement] = nil
    }

    private func finishRewardedPresentation(
        for placement: RewardedAdPlacement,
        earnedReward: Bool
    ) {
        let continuation = rewardedResultContinuation
        rewardedResultContinuation = nil
        presentingRewardedPlacement = nil
        rewardedUserEarnedReward = false
        isPresentingRewardedAd = false
        clearRewardedAd(for: placement)
        preloadRewardedAdIfNeeded(for: placement)
        continuation?.resume(returning: earnedReward)
    }

    private func discardRewardedInventory() {
        rewardedLoadTasks.values.forEach { $0.cancel() }
        rewardedLoadTasks.removeAll()
        rewardedLoadIDs.removeAll()
        rewardedRetryTasks.values.forEach { $0.cancel() }
        rewardedRetryTasks.removeAll()
        rewardedRetryAttempts.removeAll()

        for placement in RewardedAdPlacement.allCases
        where placement != presentingRewardedPlacement {
            clearRewardedAd(for: placement)
        }
    }

    private func discardAllInventory() {
        inventoryGeneration += 1
        discardInterstitialInventory()
        discardRewardedInventory()
    }

    private func restoreInterstitialPolicyState() {
        let defaults = UserDefaults.standard
        interstitialPolicyState = .init(
            eligibleCompletionsSinceLastPresentation: max(
                0,
                defaults.integer(forKey: InterstitialDefaultsKey.eligibleCompletions)
            ),
            presentationCount: max(
                0,
                defaults.integer(forKey: InterstitialDefaultsKey.presentationCount)
            ),
            lastPresentedAt: defaults.object(
                forKey: InterstitialDefaultsKey.lastPresentedAt
            ) as? Date
        )
    }

    private func persistInterstitialPolicyState() {
        let defaults = UserDefaults.standard
        defaults.set(
            interstitialPolicyState.eligibleCompletionsSinceLastPresentation,
            forKey: InterstitialDefaultsKey.eligibleCompletions
        )
        defaults.set(
            interstitialPolicyState.presentationCount,
            forKey: InterstitialDefaultsKey.presentationCount
        )
        defaults.set(
            interstitialPolicyState.lastPresentedAt,
            forKey: InterstitialDefaultsKey.lastPresentedAt
        )
    }

    private func consentRequestParameters(for policy: AdAgePolicy) -> RequestParameters {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = policy.isTaggedForUnderAgeOfConsent

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ads.forceEEA") {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
        #endif

        return parameters
    }
}

extension AdService: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        if presentingRewardedPlacement != nil {
            isPresentingRewardedAd = true
            SoundEffectsPlayer.shared.suspend()
            return
        }

        isPresentingInterstitial = true
        isInterstitialReady = false
        interstitialPolicy.recordPresentation(
            in: &interstitialPolicyState,
            now: .now
        )
        persistInterstitialPolicyState()
        SoundEffectsPlayer.shared.suspend()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        if let placement = presentingRewardedPlacement {
            finishRewardedPresentation(for: placement, earnedReward: false)
            return
        }

        isPresentingInterstitial = false
        clearInterstitial()
        preloadInterstitialIfNeeded()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let placement = presentingRewardedPlacement {
            finishRewardedPresentation(
                for: placement,
                earnedReward: rewardedUserEarnedReward
            )
            return
        }

        isPresentingInterstitial = false
        clearInterstitial()
        preloadInterstitialIfNeeded()
    }
}
