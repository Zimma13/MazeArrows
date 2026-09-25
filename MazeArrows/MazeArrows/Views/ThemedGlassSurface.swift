//
//  ThemedGlassSurface.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  A contrast-safe glass surface for content placed over moving artwork,
//  photos, or other visually busy backgrounds.
//

import SwiftUI

enum ThemedGlassProminence: Sendable {
    case panel
    case compact
    case quiet
    /// Native, noninteractive Liquid Glass for informational cards.
    case liquidGlass
    /// Native interactive Liquid Glass on iOS 26, with a light material
    /// fallback on earlier releases.
    case interactiveGlass
    /// Border-only in normal use, with an opaque accessibility fallback when
    /// Reduce Transparency is enabled.
    case transparent
}

struct ThemedGlassSurface<S: InsettableShape>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let theme: GameTheme
    let shape: S
    var prominence: ThemedGlassProminence = .panel
    var isSelected = false
    var emphasizedBorder = false

    var body: some View {
        shape
            .fill(baseStyle)
            .overlay {
                if !reduceTransparency {
                    shape.fill(theme.glassTint.opacity(tintOpacity))
                }
            }
            .overlay {
                shape
                    .fill(theme.accent.opacity(selectionOpacity))
                    .opacity(isSelected ? 1 : 0)
            }
            .overlay {
                shape.strokeBorder(
                    (isSelected || emphasizedBorder) ? theme.accent : theme.glassBorder,
                    lineWidth: borderWidth
                )
            }
            .shadow(
                color: theme.glassShadow,
                radius: shadowRadius,
                y: shadowOffset
            )
    }

    private var baseStyle: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(theme.glassSolid)
        }

        switch prominence {
        case .panel:
            return AnyShapeStyle(.regularMaterial)
        case .compact, .quiet:
            return AnyShapeStyle(.thinMaterial)
        case .liquidGlass, .interactiveGlass:
            return AnyShapeStyle(.ultraThinMaterial)
        case .transparent:
            return AnyShapeStyle(.clear)
        }
    }

    private var tintOpacity: Double {
        if prominence == .transparent {
            return 0
        }

        if colorSchemeContrast == .increased {
            if prominence == .liquidGlass || prominence == .interactiveGlass {
                return prominence == .liquidGlass ? 0.22 : 0.18
            }
            return theme.id == .neon ? 0.90 : 0.94
        }

        switch prominence {
        case .panel:
            return theme.id == .neon ? 0.78 : 0.86
        case .compact:
            return theme.id == .neon ? 0.72 : 0.80
        case .quiet:
            return theme.id == .neon ? 0.68 : 0.76
        case .liquidGlass:
            return 0.12
        case .interactiveGlass:
            return 0.08
        case .transparent:
            return 0
        }
    }

    private var selectionOpacity: Double {
        colorSchemeContrast == .increased ? 0.14 : 0.10
    }

    private var borderWidth: CGFloat {
        if isSelected {
            return colorSchemeContrast == .increased ? 2.5 : 2
        }
        if emphasizedBorder {
            return colorSchemeContrast == .increased ? 2 : 1.5
        }
        if prominence == .quiet {
            return colorSchemeContrast == .increased ? 1 : 0.75
        }
        return colorSchemeContrast == .increased ? 1.5 : 1
    }

    private var shadowRadius: CGFloat {
        switch prominence {
        case .panel: return 12
        case .compact: return 7
        case .liquidGlass: return 8
        case .interactiveGlass: return 4
        case .quiet, .transparent: return 0
        }
    }

    private var shadowOffset: CGFloat {
        switch prominence {
        case .panel: return 5
        case .compact: return 2
        case .liquidGlass: return 3
        case .interactiveGlass: return 1
        case .quiet, .transparent: return 0
        }
    }
}

private struct ThemedGlassModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let theme: GameTheme
    let shape: S
    let prominence: ThemedGlassProminence
    let isSelected: Bool
    let emphasizedBorder: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if (prominence == .liquidGlass || prominence == .interactiveGlass),
           !reduceTransparency,
           #available(iOS 26.0, *) {
            if prominence == .interactiveGlass {
                content
                    .glassEffect(
                        .regular
                            .tint(nativeGlassTint)
                            .interactive(),
                        in: shape
                    )
                    .overlay {
                        glassSelectionOverlay
                    }
            } else {
                content
                    .glassEffect(
                        .regular.tint(nativeGlassTint),
                        in: shape
                    )
                    .overlay {
                        glassSelectionOverlay
                    }
            }
        } else {
            content.background {
                ThemedGlassSurface(
                    theme: theme,
                    shape: shape,
                    prominence: prominence,
                    isSelected: isSelected,
                    emphasizedBorder: emphasizedBorder
                )
            }
        }
    }

    private var nativeGlassTint: Color {
        if prominence == .liquidGlass {
            return theme.glassTint.opacity(colorSchemeContrast == .increased ? 0.22 : 0.14)
        }
        return theme.glassTint.opacity(colorSchemeContrast == .increased ? 0.18 : 0.10)
    }

    private var glassSelectionOverlay: some View {
        shape
            .fill(theme.accent.opacity(colorSchemeContrast == .increased ? 0.14 : 0.10))
            .opacity(isSelected ? 1 : 0)
            .overlay {
                shape.strokeBorder(
                    (isSelected || emphasizedBorder) ? theme.accent : theme.glassBorder,
                    lineWidth: borderWidth
                )
            }
            .allowsHitTesting(false)
    }

    private var borderWidth: CGFloat {
        if isSelected {
            return colorSchemeContrast == .increased ? 2.5 : 2
        }
        if emphasizedBorder {
            return colorSchemeContrast == .increased ? 2 : 1.5
        }
        return colorSchemeContrast == .increased ? 1.5 : 1
    }
}

/// Coordinates sibling Liquid Glass controls on iOS 26 while preserving the
/// exact same layout on earlier releases.
struct AdaptiveGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    private let content: Content

    init(
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    func themedGlass<S: InsettableShape>(
        theme: GameTheme,
        in shape: S,
        prominence: ThemedGlassProminence = .panel,
        isSelected: Bool = false,
        emphasizedBorder: Bool = false
    ) -> some View {
        modifier(
            ThemedGlassModifier(
                theme: theme,
                shape: shape,
                prominence: prominence,
                isSelected: isSelected,
                emphasizedBorder: emphasizedBorder
            )
        )
    }

    /// Keeps theme-colored text and symbols legible over the animated board
    /// without placing an opaque panel behind them.
    func artworkLegibility(theme: GameTheme, isEnabled: Bool = true) -> some View {
        shadow(
            color: isEnabled ? theme.boardBackground.opacity(0.95) : .clear,
            radius: isEnabled ? 2.5 : 0
        )
        .shadow(
            color: isEnabled ? theme.boardBackground.opacity(0.55) : .clear,
            radius: isEnabled ? 6 : 0,
            y: isEnabled ? 1 : 0
        )
    }
}
