//
//  ScaledSystemFont.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Preserves the app's visual typography while routing every custom system
//  size through UIFontMetrics via SwiftUI's ScaledMetric.
//

import SwiftUI

nonisolated private struct ScaledSystemFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat

    private let weight: Font.Weight
    private let design: Font.Design

    init(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        relativeTo textStyle: Font.TextStyle?
    ) {
        let referenceStyle = textStyle ?? Self.referenceStyle(for: size)
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: referenceStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }

    private static func referenceStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11: return .caption2
        case ..<13: return .caption
        case ..<16: return .subheadline
        case ..<20: return .body
        case ..<24: return .title3
        case ..<29: return .title2
        default: return .largeTitle
        }
    }
}

extension View {
    nonisolated func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle? = nil
    ) -> some View {
        modifier(
            ScaledSystemFontModifier(
                size: size,
                weight: weight,
                design: design,
                relativeTo: textStyle
            )
        )
    }
}

/// Uses the familiar horizontal row at normal sizes and reflows the same
/// content vertically once the user enters an accessibility text category.
struct DynamicTypeStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let spacing: CGFloat
    private let verticalAlignment: VerticalAlignment
    private let horizontalAlignment: HorizontalAlignment
    private let content: Content

    init(
        spacing: CGFloat = 8,
        verticalAlignment: VerticalAlignment = .center,
        horizontalAlignment: HorizontalAlignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.verticalAlignment = verticalAlignment
        self.horizontalAlignment = horizontalAlignment
        self.content = content()
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))

        layout { content }
    }
}
