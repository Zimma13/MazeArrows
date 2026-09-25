//
//  MinimumTapTarget.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Keeps compact artwork compact while giving controls the 44-point hit area
//  expected by iOS accessibility and ergonomics guidelines.
//

import SwiftUI

extension View {
    nonisolated func minimumTapTarget(
        width: CGFloat = 44,
        height: CGFloat = 44
    ) -> some View {
        frame(minWidth: width, minHeight: height)
            .contentShape(Rectangle())
    }
}
