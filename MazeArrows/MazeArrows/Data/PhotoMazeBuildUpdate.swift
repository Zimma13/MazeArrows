//
//  PhotoMazeBuildUpdate.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

enum PhotoMazeBuildUpdate: Sendable {
    case progress(Double)
    case finished(Level?)
}
