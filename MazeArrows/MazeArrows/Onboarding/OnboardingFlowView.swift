//
//  OnboardingFlowView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import StoreKit
import SwiftUI

struct OnboardingFlowView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(PremiumStore.self) private var premium
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(AppIconStore.self) private var appIcons
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if onboarding.step.isPaywall {
                PaywallMazeBackgroundView(theme: theme)
                    .ignoresSafeArea()
            } else {
                theme.appBackground.ignoresSafeArea()
            }

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
            OnboardingTutorialView(stage: .three, onFinished: finishThirdTutorial)

        case .paywallIntro:
            OnboardingPaywallView(page: .intro)

        case .paywallTimeline:
            // Legacy recovery for an onboarding snapshot created before the
            // timeline step was retired.
            OnboardingPaywallView(page: .plans)

        case .paywallPlans:
            OnboardingPaywallView(page: .plans)

        case .tutorialFour:
            OnboardingTutorialView(stage: .four) { move(to: .streak) }

        case .streak:
            OnboardingStreakView {
                onboarding.claimStarterReward(in: progress)
                move(to: premium.isPremium ? .themePicker : .pushPrompt)
            }

        case .pushPrompt:
            OnboardingPushView(
                accept: enableDailyReminder,
                decline: { move(to: .themePicker) }
            )

        case .themePicker:
            OnboardingThemePickerView(
                select: selectTheme,
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

    private func finishThirdTutorial() {
        guard FeatureFlags.onboardingPaywallAvailable else {
            move(to: .tutorialFour)
            return
        }

        Task {
            await premium.refreshEntitlements()
            await premium.loadProductsIfNeeded(waitTimeout: .seconds(4))
            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.28)) {
                onboarding.beginPaywallIfNeeded(
                    canPresent: premium.hasAvailablePaywall,
                    isPremium: premium.isPremium
                )
            }
        }
    }

    private func enableDailyReminder() {
        Task {
            _ = await OnboardingNotificationService.requestDailyReminder()
            move(to: .themePicker)
        }
    }

    private func selectTheme(_ id: AppThemeID) {
        settings.selectTheme(
            id,
            access: PremiumAccessPolicy(isPremium: premium.isPremium)
        )
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

private enum PaywallPage: Int {
    case intro = 0
    case plans
}

private struct OnboardingPaywallView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(PremiumStore.self) private var premium
    @Environment(SettingsStore.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showClose = false
    @State private var restoreMessage: String?

    let page: PaywallPage

    var body: some View {
        VStack(spacing: 0) {
            PaywallTopBar(page: page, showClose: showClose, close: close)
                .padding(.horizontal, 18)
                .padding(.top, 6)

            switch page {
            case .intro:
                PaywallIntroPage(
                    continueAction: continueFromIntro,
                    restore: restore
                )
            case .plans:
                PaywallPlansPage(finish: { move(to: .tutorialFour) })
            }
        }
        .foregroundStyle(theme.ink)
        .task(id: page) {
            showClose = page != .intro
            if page == .intro {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.2)) {
                    showClose = true
                }
            }
        }
        .alert(
            OnboardingCopy.premium,
            isPresented: restoreAlertIsPresented
        ) {
            Button(OnboardingCopy.ok, role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }

    private func continueFromIntro() {
        move(to: .paywallPlans)
    }

    private func close() {
        move(to: .tutorialFour)
    }

    private var restoreAlertIsPresented: Binding<Bool> {
        Binding(
            get: { restoreMessage != nil },
            set: { isPresented in
                if !isPresented { restoreMessage = nil }
            }
        )
    }

    private func restore() {
        Task {
            let restored = await premium.restorePurchases()
            if restored {
                restoreMessage = OnboardingCopy.restored
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                move(to: .tutorialFour)
            } else if case .failed(let message) = premium.purchaseState {
                restoreMessage = message
            } else {
                restoreMessage = OnboardingCopy.nothingToRestore
            }
        }
    }

    private func move(to step: OnboardingStep) {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.28)) {
            onboarding.move(to: step)
        }
    }
}

private struct PaywallTopBar: View {
    @Environment(SettingsStore.self) private var settings

    let page: PaywallPage
    let showClose: Bool
    let close: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 7) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(index == page.rawValue ? theme.accent : theme.inkMuted.opacity(0.24))
                        .frame(width: index == page.rawValue ? 24 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(OnboardingCopy.pageProgress(page.rawValue + 1, of: 2))

            Spacer()

            Button(OnboardingCopy.close, systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .foregroundStyle(theme.inkSoft)
                .minimumTapTarget()
                .themedGlass(theme: theme, in: Circle(), prominence: .compact)
                .opacity(showClose ? 1 : 0)
                .disabled(!showClose)
        }
        .frame(minHeight: 44)
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }
}

private struct PaywallIntroPage: View {
    @Environment(SettingsStore.self) private var settings

    let continueAction: () -> Void
    let restore: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    PaywallArrowHero(theme: theme)
                    Text(OnboardingCopy.playWithoutLimits)
                        .scaledFont(size: 34, weight: .black, design: .rounded, relativeTo: .largeTitle)
                        .multilineTextAlignment(.center)
                        .artworkLegibility(theme: theme)
                    Text(OnboardingCopy.anyPhotoMaze)
                        .font(.headline)
                        .foregroundStyle(theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .artworkLegibility(theme: theme)
                }

                PhotoMazePaywallPreview(theme: theme)

                VStack(alignment: .leading, spacing: 14) {
                    PaywallBenefit(icon: "lightbulb.max.fill", text: OnboardingCopy.unlimitedHints, theme: theme)
                    PaywallBenefit(icon: "photo.on.rectangle.angled", text: OnboardingCopy.turnAnyPhoto, theme: theme)
                    PaywallBenefit(icon: "rectangle.slash", text: OnboardingCopy.noAds, theme: theme)
                    PaywallBenefit(icon: "paintpalette.fill", text: OnboardingCopy.morePremiumThemes, theme: theme)
                }
                .artworkLegibility(theme: theme)
                .padding(18)
                .frame(maxWidth: 520, alignment: .leading)
                .themedGlass(
                    theme: theme,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                    prominence: .liquidGlass
                )

                OnboardingPrimaryButton(
                    title: OnboardingCopy.continueAction,
                    action: continueAction,
                    theme: theme
                )

                PaywallLegalFooter(theme: theme, restore: restore)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }
}

private struct PaywallPlansPage: View {
    private enum PresentedAlert: Identifiable {
        case message(String)

        var id: String {
            switch self {
            case .message(let message): return "message-\(message)"
            }
        }
    }

    @Environment(PremiumStore.self) private var premium
    @Environment(SettingsStore.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedProductID = PremiumProductID.weekly
    @State private var alert: PresentedAlert?

    let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(theme.rewardGold)
                    Text(OnboardingCopy.choosePlan)
                        .scaledFont(size: 34, weight: .black, design: .rounded, relativeTo: .largeTitle)
                        .multilineTextAlignment(.center)
                }

                plansContent

                purchaseFooter
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .alert(item: $alert) { alert in
            switch alert {
            case .message(let message):
                return Alert(
                    title: Text(OnboardingCopy.premium),
                    message: Text(message),
                    dismissButton: .default(Text(OnboardingCopy.ok))
                )
            }
        }
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }

    private var selectedProduct: Product? {
        premium.products.first { $0.id == selectedProductID }
    }

    @ViewBuilder
    private var plansContent: some View {
        if premium.hasAvailablePaywall {
            AdaptiveGlassEffectContainer(spacing: 8) {
                VStack(spacing: 12) {
                    if let weekly = premium.weeklyProduct {
                        PlanOptionButton(
                            title: OnboardingCopy.week,
                            detail: OnboardingCopy.weeklyPrice(weekly.displayPrice),
                            badge: nil,
                            isSelected: selectedProductID == weekly.id,
                            theme: theme,
                            action: { selectProduct(weekly.id) }
                        )
                    }

                    if let annual = premium.annualProduct {
                        PlanOptionButton(
                            title: OnboardingCopy.year,
                            detail: annualDetail(annual),
                            badge: savingsText,
                            isSelected: selectedProductID == annual.id,
                            theme: theme,
                            action: { selectProduct(annual.id) }
                        )
                    }
                }
            }
            .frame(maxWidth: 540)
        } else if premium.loadState == .loading || premium.loadState == .idle {
            paywallStatusPanel {
                ProgressView()
                    .tint(theme.accent)
                Text(OnboardingCopy.choosePlan)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.inkSoft)
            }
        } else {
            paywallStatusPanel {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
                Text(OnboardingCopy.purchaseFailed)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkSoft)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task {
                        await premium.loadProductsIfNeeded(force: true)
                    }
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
                .minimumTapTarget()
            }
        }
    }

    private var purchaseControls: some View {
        OnboardingPrimaryButton(
            title: primaryTitle,
            isLoading: premium.purchaseState == .purchasing,
            isDisabled: selectedProduct == nil,
            action: purchase,
            theme: theme
        )
    }

    private var purchaseFooter: some View {
        VStack(spacing: 4) {
            if premium.hasAvailablePaywall {
                VStack(spacing: 8) {
                    PaywallRenewalDisclosure(theme: theme)
                    purchaseControls
                }
            }

            PaywallLegalFooter(theme: theme, restore: restore)
        }
    }

    private func paywallStatusPanel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(18)
        .frame(maxWidth: 540, minHeight: 130)
        .themedGlass(
            theme: theme,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private var primaryTitle: String {
        guard let selectedProduct else { return OnboardingCopy.continueAction }
        if selectedProduct.id == PremiumProductID.weekly {
            return OnboardingCopy.subscribeWeekly
        }
        return OnboardingCopy.subscribeAnnual(selectedProduct.displayPrice)
    }

    private var savingsText: String? {
        guard let weekly = premium.weeklyProduct,
              let annual = premium.annualProduct
        else { return nil }
        let weeklyYear = NSDecimalNumber(decimal: weekly.price).doubleValue * 52
        let annualYear = NSDecimalNumber(decimal: annual.price).doubleValue
        guard weeklyYear > 0, annualYear < weeklyYear else { return nil }
        return OnboardingCopy.savings(Int(((weeklyYear - annualYear) / weeklyYear * 100).rounded()))
    }

    private func selectProduct(_ productID: String) {
        guard selectedProductID != productID else { return }
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .smooth(duration: 0.26, extraBounce: 0)
        ) {
            selectedProductID = productID
        }
    }

    private func annualDetail(_ product: Product) -> String {
        let perWeek = product.price / Decimal(52)
        let formattedPerWeek = product.priceFormatStyle.format(perWeek)
        return OnboardingCopy.planPriceLine(
            OnboardingCopy.annualPrice(product.displayPrice),
            OnboardingCopy.annualPerWeek(formattedPerWeek)
        )
    }

    private func purchase() {
        guard let selectedProduct else { return }
        Task {
            let succeeded = await premium.purchase(selectedProduct)
            guard succeeded else {
                switch premium.purchaseState {
                case .pending:
                    alert = .message(OnboardingCopy.purchasePending)
                case .failed(let message):
                    alert = .message(message)
                default:
                    break
                }
                return
            }

            finish()
        }
    }

    private func restore() {
        Task {
            let restored = await premium.restorePurchases()
            alert = .message(restored ? OnboardingCopy.restored : restoreFailureMessage)
            if restored {
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                finish()
            }
        }
    }

    private var restoreFailureMessage: String {
        if case .failed(let message) = premium.purchaseState {
            return message
        }
        return OnboardingCopy.nothingToRestore
    }
}

private struct PaywallArrowHero: View {
    let theme: GameTheme

    var body: some View {
        HStack(spacing: -8) {
            ForEach(["arrow.up.right", "arrow.right", "arrow.down.right"], id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 64, height: 64)
                    .background(theme.primaryGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .rotationEffect(.degrees(symbol == "arrow.right" ? 0 : (symbol == "arrow.up.right" ? -8 : 8)))
                    .shadow(color: theme.primaryShadow.opacity(0.28), radius: 10, y: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PhotoMazePaywallPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsMaze = false

    let theme: GameTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.accent2.opacity(0.88), theme.achievementGold.opacity(0.82), theme.accent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(theme.boardBackground.opacity(0.9))
                .scaleEffect(showsMaze ? 0.82 : 1)
                .opacity(showsMaze ? 0 : 1)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index.isMultiple(of: 2) ? "arrow.right" : "arrow.down")
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index.isMultiple(of: 2) ? "arrow.up" : "arrow.left")
                    }
                }
            }
            .font(.system(size: 24, weight: .black))
            .foregroundStyle(theme.boardBackground.opacity(0.92))
            .scaleEffect(showsMaze ? 1 : 0.86)
            .opacity(showsMaze ? 1 : 0)

            Text("PHOTO MAZE")
                .font(.caption.bold())
                .tracking(1.4)
                .foregroundStyle(theme.boardBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(theme.ink.opacity(0.54), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(12)
        }
        .frame(maxWidth: 520)
        .frame(height: 150)
        .clipShape(.rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 1)
        }
        .accessibilityLabel(OnboardingCopy.anyPhotoMaze)
        .task {
            if reduceMotion {
                showsMaze = true
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(showsMaze ? 2.3 : 1.2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.65)) {
                    showsMaze.toggle()
                }
            }
        }
    }
}

private struct PaywallBenefit: View {
    let icon: String
    let text: String
    let theme: GameTheme

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(theme.accent)
                .frame(width: 30)
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(theme.inkSoft)
    }
}

struct PlanOptionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    let theme: GameTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? theme.accent : theme.inkMuted)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffectsRemoved(reduceMotion)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline.bold())
                            .foregroundStyle(theme.ink)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .allowsTightening(true)
                                .foregroundStyle(isSelected ? theme.textOnAccent : theme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isSelected ? theme.accent : theme.accent.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .allowsTightening(true)
                }

                Spacer(minLength: 0)
            }
            .artworkLegibility(theme: theme)
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedGlass(
                theme: theme,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                prominence: .interactiveGlass,
                isSelected: isSelected
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PaywallLegalFooter: View {
    let theme: GameTheme
    var restore: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let restore {
                Button(action: restore) {
                    legalText(OnboardingCopy.restore)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Link(destination: AppLegalLinks.terms) {
                    legalText(OnboardingCopy.terms)
                }

                Text("·")
                    .accessibilityHidden(true)

                Link(destination: AppLegalLinks.privacy) {
                    legalText(OnboardingCopy.privacy)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .font(.caption)
        .foregroundStyle(theme.inkMuted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .artworkLegibility(theme: theme)
    }

    private func legalText(_ text: String) -> some View {
        Text(text)
            .underline()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .foregroundStyle(theme.inkMuted)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct PaywallRenewalDisclosure: View {
    let theme: GameTheme

    var body: some View {
        Text(OnboardingCopy.autoRenewalDisclosure)
            .font(.footnote)
            .foregroundStyle(theme.inkSoft)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 540)
            .padding(.horizontal, 12)
            .artworkLegibility(theme: theme)
    }
}

enum AppLegalLinks {
    static let terms = URL(string: "https://kinapp.dev/arrowmaze/terms/")!
    static let privacy = URL(string: "https://kinapp.dev/arrowmaze/privacy/")!
    static let support = URL(string: "https://kinapp.dev/arrowmaze/support/")!
}

struct OnboardingPrimaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void
    let theme: GameTheme

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                    .contentTransition(.opacity)
                if isLoading {
                    ProgressView().tint(theme.primaryText)
                }
            }
            .scaledFont(size: 18, weight: .bold, design: .rounded, relativeTo: .headline)
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 22)
            .frame(maxWidth: 540)
            .frame(minHeight: 56)
            .background(theme.primaryGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: theme.primaryShadow.opacity(0.27), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.55 : 1)
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
                        ThemeChoiceButton(
                            id: .aurora,
                            description: OnboardingCopy.auroraDescription,
                            selectedID: settings.settings.themeID,
                            action: select
                        )
                        ThemeChoiceButton(
                            id: .neon,
                            description: OnboardingCopy.neonDescription,
                            selectedID: settings.settings.themeID,
                            action: select
                        )
                        ThemeChoiceButton(
                            id: .petal,
                            description: OnboardingCopy.petalDescription,
                            selectedID: settings.settings.themeID,
                            action: select
                        )
                    }
                    .frame(maxWidth: 560)

                    Label(OnboardingCopy.morePremiumThemes, systemImage: "crown.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.rewardGold)
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
    let description: String
    let selectedID: AppThemeID
    let action: (AppThemeID) -> Void

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
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(previewTheme.inkMuted)
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
