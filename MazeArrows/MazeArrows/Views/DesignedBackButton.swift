//
//  DesignedBackButton.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Keeps pushed screens on the native back control. This avoids stacking a
//  custom circle inside the system Liquid Glass toolbar on iOS 26.
//

import SwiftUI

struct DesignedBackButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(false)
    }
}

extension View {
    /// Native back button with the correct platform chrome and swipe gesture.
    func designedBackButton(theme _: GameTheme) -> some View {
        modifier(DesignedBackButton())
    }

    /// Standard-iOS-style scrims: content scrolling under the status bar /
    /// navigation title fades into the app background at the top, with a
    /// subtler fade at the bottom edge.
    func edgeFades(theme: GameTheme, top: CGFloat = 160, bottom: CGFloat = 44) -> some View {
        modifier(EdgeFades(theme: theme, topHeight: top, bottomHeight: bottom))
    }
}

struct EdgeFades: ViewModifier {
    let theme: GameTheme
    let topHeight: CGFloat
    let bottomHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        // Fully opaque through the status bar and nav title,
                        // then a soft falloff — like a system bar background.
                        .init(color: theme.appBackgroundTop, location: 0),
                        .init(color: theme.appBackgroundTop, location: 0.58),
                        .init(color: theme.appBackgroundTop.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topHeight)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .overlay {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    LinearGradient(
                        colors: [theme.appBackgroundTop.opacity(0), theme.appBackgroundTop],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: bottomHeight)
                }
                // Let the layout container, rather than only the fixed-height
                // gradient, extend beneath the home indicator. This keeps the
                // fade anchored to the physical screen edge instead of the
                // bottom safe-area boundary.
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
    }
}
