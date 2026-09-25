//
//  GameCenterAuthenticationView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI
import UIKit

/// Hosts the system controller supplied by `GKLocalPlayer.authenticateHandler`.
/// The controller itself owns the sign-in flow and its accessibility behavior.
struct GameCenterAuthenticationView: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        viewController
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {}
}
