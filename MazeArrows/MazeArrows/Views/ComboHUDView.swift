//
//  ComboHUDView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

enum ComboHUDAnimationStyle: String, CaseIterable, Sendable {
    case softSwap
    case verticalCarousel
    case flip
    case capsuleMorph

    /// Rotates the presentation at combo milestones 3, 6, 9, 12, then repeats.
    static func style(for combo: Int) -> Self {
        guard combo >= 3 else { return .capsuleMorph }

        let milestoneIndex = (combo / 3) - 1
        let cycle: [Self] = [.softSwap, .verticalCarousel, .flip, .capsuleMorph]
        return cycle[milestoneIndex % cycle.count]
    }

    var milestoneTransition: AnyTransition {
        switch self {
        case .softSwap:
            .scale(scale: 0.82).combined(with: .opacity)
        case .verticalCarousel:
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .flip:
            .modifier(
                active: ComboHUDFlipTransitionModifier(angle: 88),
                identity: ComboHUDFlipTransitionModifier(angle: 0)
            )
            .combined(with: .opacity)
        case .capsuleMorph:
            .scale(scale: 0.42).combined(with: .opacity)
        }
    }

    var milestoneAnimation: Animation {
        switch self {
        case .softSwap:
            .snappy(duration: 0.34, extraBounce: 0.08)
        case .verticalCarousel:
            .smooth(duration: 0.28)
        case .flip:
            .snappy(duration: 0.38, extraBounce: 0.04)
        case .capsuleMorph:
            .spring(duration: 0.44, bounce: 0.18)
        }
    }
}

private struct ComboHUDFlipTransitionModifier: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content.rotation3DEffect(
            .degrees(angle),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.65
        )
    }
}

struct ComboHUDSwitcher<NormalContent: View>: View {
    let isShowingCombo: Bool
    let combo: Int
    let callout: String?
    let style: ComboHUDAnimationStyle
    let theme: GameTheme
    let reduceMotion: Bool
    let alignment: Alignment

    private let normalContent: NormalContent

    init(
        isShowingCombo: Bool,
        combo: Int,
        callout: String?,
        style: ComboHUDAnimationStyle,
        theme: GameTheme,
        reduceMotion: Bool,
        alignment: Alignment,
        @ViewBuilder normalContent: () -> NormalContent
    ) {
        self.isShowingCombo = isShowingCombo
        self.combo = combo
        self.callout = callout
        self.style = style
        self.theme = theme
        self.reduceMotion = reduceMotion
        self.alignment = alignment
        self.normalContent = normalContent()
    }

    var body: some View {
        // The invisible normal HUD is a permanent layout template. Swapping
        // animations therefore never changes the board's available height.
        normalContent
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: alignment) {
                animatedContent
            }
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var animatedContent: some View {
        if reduceMotion {
            crossFade
        } else {
            switch style {
            case .softSwap:
                softSwap
            case .verticalCarousel:
                verticalCarousel
            case .flip:
                flip
            case .capsuleMorph:
                capsuleMorph
            }
        }
    }

    private var normalHUD: some View {
        normalContent
            .accessibilityHidden(isShowingCombo)
    }

    private var comboHUD: some View {
        ComboHUDContent(
            combo: combo,
            callout: callout,
            style: style,
            theme: theme,
            reduceMotion: reduceMotion
        )
        .accessibilityHidden(true)
    }

    private var crossFade: some View {
        ZStack(alignment: alignment) {
            normalHUD.opacity(isShowingCombo ? 0 : 1)
            comboHUD.opacity(isShowingCombo ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.15), value: isShowingCombo)
    }

    private var softSwap: some View {
        ZStack(alignment: alignment) {
            normalHUD
                .opacity(isShowingCombo ? 0 : 1)
                .scaleEffect(isShowingCombo ? 0.92 : 1)
                .offset(y: isShowingCombo ? -4 : 0)
                .blur(radius: isShowingCombo ? 2 : 0)

            comboHUD
                .opacity(isShowingCombo ? 1 : 0)
                .scaleEffect(isShowingCombo ? 1 : 0.82)
                .offset(y: isShowingCombo ? 0 : 5)
        }
        .animation(
            .snappy(duration: 0.34, extraBounce: 0.08),
            value: isShowingCombo
        )
    }

    private var verticalCarousel: some View {
        ZStack(alignment: alignment) {
            if isShowingCombo {
                comboHUD.transition(carouselTransition)
            } else {
                normalHUD.transition(carouselTransition)
            }
        }
        .clipped()
        .animation(.smooth(duration: 0.28), value: isShowingCombo)
    }

    private var carouselTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    private var flip: some View {
        ZStack(alignment: alignment) {
            normalHUD
                .opacity(isShowingCombo ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingCombo ? -88 : 0),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.65
                )

            comboHUD
                .opacity(isShowingCombo ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingCombo ? 0 : 88),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.65
                )
        }
        .animation(
            .snappy(duration: 0.38, extraBounce: 0.04),
            value: isShowingCombo
        )
    }

    private var capsuleMorph: some View {
        ZStack(alignment: alignment) {
            normalHUD
                .opacity(isShowingCombo ? 0 : 1)
                .scaleEffect(
                    x: isShowingCombo ? 0.52 : 1,
                    y: isShowingCombo ? 0.82 : 1
                )
                .blur(radius: isShowingCombo ? 2 : 0)

            comboHUD
                .opacity(isShowingCombo ? 1 : 0)
                .scaleEffect(
                    x: isShowingCombo ? 1 : 0.42,
                    y: isShowingCombo ? 1 : 0.72
                )
        }
        .animation(
            .spring(duration: 0.44, bounce: 0.18),
            value: isShowingCombo
        )
    }
}

private struct ComboHUDContent: View {
    let combo: Int
    let callout: String?
    let style: ComboHUDAnimationStyle
    let theme: GameTheme
    let reduceMotion: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var highlight: Color {
        combo >= 5 ? theme.accent2 : theme.accent
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(callout ?? String(localized: "Combo!"))
                .textCase(.uppercase)
                .scaledFont(size: 10, weight: .black)
                .tracking(1.6)
                .foregroundStyle(theme.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("×")
                Text("\(combo)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(combo)))
                    .animation(
                        reduceMotion ? nil : .snappy(duration: 0.2),
                        value: combo
                    )
            }
            .scaledFont(
                size: dynamicTypeSize.isAccessibilitySize ? 27 : 31,
                weight: .black,
                design: .rounded
            )
            .foregroundStyle(theme.ink)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: combo) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(reduceMotion ? 1 : 1.14, duration: 0.14)
                    CubicKeyframe(1, duration: 0.18)
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 6)
        .background {
            comboBackground
        }
        .shadow(color: highlight.opacity(0.24), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var comboBackground: some View {
        switch style {
        case .softSwap, .verticalCarousel:
            Capsule()
                .fill(theme.surface)
                .overlay(Capsule().stroke(theme.glassBorder))

        case .flip:
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(highlight.opacity(0.38))
                )

        case .capsuleMorph:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.surface,
                            highlight.opacity(0.22),
                            theme.surface
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(Capsule().stroke(highlight.opacity(0.5), lineWidth: 1.5))
        }
    }
}
