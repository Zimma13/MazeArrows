//
//  PremiumPaywallView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import StoreKit
import SwiftUI

enum PremiumPaywallContext: Hashable, Identifiable, Sendable {
    case photoMaze
    case hints
    case theme(AppThemeID)
    case settings

    var id: String {
        switch self {
        case .photoMaze:
            "photo-maze"
        case .hints:
            "hints"
        case .theme(let id):
            "theme-\(id.rawValue)"
        case .settings:
            "settings"
        }
    }

    var title: String {
        switch self {
        case .photoMaze:
            OnboardingCopy.unlimitedPhotoMazes
        case .hints:
            OnboardingCopy.unlimitedHints
        case .theme(let id):
            id.displayName
        case .settings:
            OnboardingCopy.playWithoutLimits
        }
    }

    var subtitle: String {
        switch self {
        case .photoMaze:
            OnboardingCopy.turnAnyPhoto
        case .hints:
            OnboardingCopy.playWithoutLimits
        case .theme:
            OnboardingCopy.morePremiumThemes
        case .settings:
            OnboardingCopy.anyPhotoMaze
        }
    }

    var symbolName: String {
        switch self {
        case .photoMaze:
            "photo.on.rectangle.angled"
        case .hints:
            "lightbulb.max.fill"
        case .theme:
            "paintpalette.fill"
        case .settings:
            "crown.fill"
        }
    }
}

struct PremiumPaywallView: View {
    private enum PresentedAlert: Identifiable {
        case message(String)

        var id: String {
            switch self {
            case .message(let message):
                "message-\(message)"
            }
        }
    }

    @Environment(PremiumStore.self) private var premium
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedProductID = PremiumProductID.weekly
    @State private var alert: PresentedAlert?
    @State private var didComplete = false
    @State private var contextTitleHeight: CGFloat = 48

    let context: PremiumPaywallContext
    let onUnlocked: () -> Void

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }

    private var selectedProduct: Product? {
        premium.products.first { $0.id == selectedProductID }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PaywallMazeBackgroundView(theme: theme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    contextHeader
                        .padding(.top, 48)

                    benefitsCard
                    plansContent

                    purchaseFooter
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)

            closeButton
                .padding(.top, 14)
                .padding(.trailing, 16)
        }
        .interactiveDismissDisabled(premium.purchaseState == .purchasing)
        .task {
            if !premium.hasLoadedEntitlements {
                await premium.refreshEntitlements()
            }
            guard !completeIfUnlocked() else { return }
            await premium.loadProductsIfNeeded()
        }
        .onChange(of: premium.isPremium) { _, isPremium in
            if isPremium {
                completeIfUnlocked()
            }
        }
        .onDisappear {
            premium.resetPurchaseMessage()
        }
        .alert(item: $alert) { alert in
            switch alert {
            case .message(let message):
                Alert(
                    title: Text(OnboardingCopy.premium),
                    message: Text(message),
                    dismissButton: .default(Text(OnboardingCopy.ok))
                )
            }
        }
    }

    private var contextHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                contextHero(size: contextHeroSize)

                Text(context.title)
                    .scaledFont(size: 34, weight: .black, design: .rounded, relativeTo: .largeTitle)
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .artworkLegibility(theme: theme)
                    .accessibilityAddTraits(.isHeader)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height.rounded(.up)
                    } action: { height in
                        guard abs(contextTitleHeight - height) > 0.5 else { return }
                        contextTitleHeight = height
                    }
            }

            Text(context.subtitle)
                .font(.headline)
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
                .artworkLegibility(theme: theme)
        }
    }

    private var contextHeroSize: CGFloat {
        min(max(contextTitleHeight + 10, 58), 82)
    }

    private func contextHero(size: CGFloat) -> some View {
        contextHeroArtwork
            .scaleEffect(size / 82)
            .frame(width: size, height: size)
    }

    private var contextHeroArtwork: some View {
        ZStack(alignment: .top) {
            Group {
                if context == .settings {
                    Image(settings.settings.themeID.appIconPreviewAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(.rect(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.28), lineWidth: 1)
                        }
                } else {
                    Image(systemName: context.symbolName)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 82, height: 82)
                        .background(
                            theme.primaryGradient,
                            in: RoundedRectangle(cornerRadius: 25, style: .continuous)
                        )
                }
            }
            .frame(width: 82, height: 82)
            .shadow(color: theme.primaryShadow.opacity(0.30), radius: 12, y: 6)
            .accessibilityHidden(true)

            Text(OnboardingCopy.premium)
                .font(.caption2.bold())
                .textCase(.uppercase)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(theme.primaryGradient, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.32), lineWidth: 1)
                }
                .shadow(color: theme.primaryShadow.opacity(0.28), radius: 6, y: 3)
                .rotationEffect(.degrees(-6))
                .offset(x: 4, y: -10)
                .accessibilityLabel(OnboardingCopy.premium)
        }
        .frame(width: 82, height: 82)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            PremiumBenefitRow(
                icon: "photo.on.rectangle.angled",
                text: OnboardingCopy.unlimitedPhotoMazes,
                theme: theme
            )
            PremiumBenefitRow(
                icon: "lightbulb.max.fill",
                text: OnboardingCopy.unlimitedHints,
                theme: theme
            )
            PremiumBenefitRow(
                icon: "rectangle.slash",
                text: OnboardingCopy.noAds,
                theme: theme
            )
            PremiumBenefitRow(
                icon: "paintpalette.fill",
                text: OnboardingCopy.morePremiumThemes,
                theme: theme
            )
        }
        .artworkLegibility(theme: theme)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedGlass(
            theme: theme,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            prominence: .liquidGlass
        )
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
        } else if premium.loadState == .loading || premium.loadState == .idle {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(theme.accent)
                Text(OnboardingCopy.choosePlan)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 130)
            .themedGlass(
                theme: theme,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
                Text(OnboardingCopy.purchaseFailed)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
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
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 130)
            .themedGlass(
                theme: theme,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
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

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.bold))
                .foregroundStyle(theme.inkSoft)
                .frame(width: 44, height: 44)
                .themedGlass(theme: theme, in: Circle(), prominence: .compact)
        }
        .buttonStyle(.plain)
        .disabled(premium.purchaseState == .purchasing)
        .accessibilityLabel(OnboardingCopy.close)
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
        let percent = Int(((weeklyYear - annualYear) / weeklyYear * 100).rounded())
        return OnboardingCopy.savings(percent)
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
        return OnboardingCopy.planPriceLine(
            OnboardingCopy.annualPrice(product.displayPrice),
            OnboardingCopy.annualPerWeek(product.priceFormatStyle.format(perWeek))
        )
    }

    private func purchase() {
        guard let selectedProduct else { return }
        Task {
            let succeeded = await premium.purchase(selectedProduct)
            if succeeded {
                completeIfUnlocked()
                return
            }

            switch premium.purchaseState {
            case .pending:
                alert = .message(OnboardingCopy.purchasePending)
            case .failed(let message):
                alert = .message(message)
            case .cancelled, .idle, .purchased, .purchasing:
                break
            }
        }
    }

    private func restore() {
        Task {
            let restored = await premium.restorePurchases()
            if restored {
                completeIfUnlocked()
            } else {
                alert = .message(restoreFailureMessage)
            }
        }
    }

    private var restoreFailureMessage: String {
        if case .failed(let message) = premium.purchaseState {
            return message
        }
        return OnboardingCopy.nothingToRestore
    }

    @discardableResult
    private func completeIfUnlocked() -> Bool {
        guard premium.isPremium, !didComplete else { return didComplete }
        didComplete = true
        onUnlocked()
        dismiss()
        return true
    }
}

private struct PremiumBenefitRow: View {
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
