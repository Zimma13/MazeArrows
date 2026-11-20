import CryptoKit
import Foundation
import SpriteKit
import Testing
@testable import MazeArrows

@MainActor
struct Version2CompatibilityTests {
    private var dataDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("MazeArrows/Data")
    }

    private func store() -> ProgressStore {
        ProgressStore(defaults: UserDefaults(suiteName: "MazeArrowsV2Tests-\(UUID().uuidString)")!)
    }

    private func level(index: Int) -> Level {
        Level(id: "story_\(index)", index: index, difficulty: .easy, width: 6, height: 5, lives: 4,
              pieces: [
                ArrowPiece(id: "key", cells: [.init(x: 1, y: 0), .init(x: 0, y: 0)], direction: .left, kind: .lockedKey, colorGroup: 1),
                ArrowPiece(id: "target", cells: [.init(x: 0, y: 2), .init(x: 1, y: 2)], direction: .right)
              ], obstacles: [.init(id: "gate", kind: .keyGate, cell: .init(x: 3, y: 2), parameter: "key", colorGroup: 1)],
              rulesVersion: 2)
    }

    @Test func shippedOriginalCatalogIsByteForByteUnchanged() throws {
        let bytes = try Data(contentsOf: dataDirectory.appendingPathComponent("levels.json"))
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        #expect(hash == "f781f36eb3a64e8e2e84c5fb3e693e83e0f1425cc37a801d63acd7a06fb223c9")
    }

    @Test func continuationAppendsWithoutChangingOriginalLevels() throws {
        let legacyData = try Data(contentsOf: dataDirectory.appendingPathComponent("levels.json"))
        let v2Data = try Data(contentsOf: dataDirectory.appendingPathComponent("levels-v2.json"))
        let legacy = try JSONDecoder().decode([Level].self, from: legacyData)
        let combined = try LevelLoader.decodeCatalog(legacyData: legacyData, continuationData: v2Data)
        #expect(combined.map(\.index) == Array(1...260))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(Array(combined.prefix(240))) == encoder.encode(legacy))
        #expect(throws: (any Error).self) {
            try LevelLoader.decodeCatalog(legacyData: legacyData, continuationData: Data("[]".utf8))
        }
    }

    @Test func originalCampaignAchievementStillUnlocksAt240() {
        let progress = store()
        progress.progress.completedLevels = Set(1...239)
        progress.progress.unlockedLevelIndex = 240
        _ = progress.recordStoryCompletion(levelIndex: 240, mistakesCount: 0, level: level(index: 240))
        #expect(progress.progress.earnedAchievements.contains(.allLevelsComplete))
        #expect(progress.progress.unlockedLevelIndex == 241)
        #expect(Chapter.all.last?.isUnlocked(progress: progress.progress) == true)
        #expect(!progress.progress.completedLevels.contains(241))
    }

    @Test func oldSaveAndRewardsSurviveLoadingAndContinuing() throws {
        let defaults = UserDefaults(suiteName: "MazeArrowsV2SaveTests-\(UUID().uuidString)")!
        var old = PlayerProgress.initial
        old.unlockedLevelIndex = 241
        old.completedLevels = Set(1...240)
        old.stars = Dictionary(uniqueKeysWithValues: (1...240).map { ($0, 2) })
        old.bestTimes = [1: 21, 240: 219]
        old.coins = 431
        old.earnedAchievements = [.allLevelsComplete]
        let saved = try JSONEncoder().encode(old)
        defaults.set(saved, forKey: "MazeArrows.PlayerProgress.v2")
        let progress = ProgressStore(defaults: defaults)
        #expect(progress.progress.completedLevels == old.completedLevels)
        #expect(progress.progress.stars == old.stars)
        #expect(progress.progress.bestTimes == old.bestTimes)
        #expect(progress.progress.coins == 431)
        #expect(progress.progress.unlockedLevelIndex == 241)
        #expect(progress.progress.earnedAchievements.contains(.allLevelsComplete))
        #expect(progress.recordStoryCompletion(levelIndex: 241, mistakesCount: 0, level: level(index: 241)) == 75)
        #expect(progress.recordStoryCompletion(levelIndex: 241, mistakesCount: 0, level: level(index: 241)) == 0)
        for index in 1...240 { #expect(progress.progress.stars[index] == old.stars[index]) }
        #expect(progress.progress.bestTimes == old.bestTimes)
        #expect(progress.progress.unlockedLevelIndex == 242)
    }

    @Test func trainingProtectsEveryBlockedAttemptBut242DoesNot() {
        for index in [241, 242] {
            let fixture = level(index: index)
            let progress = store()
            let model = GameViewModel(level: fixture, mode: .story(index: index), progressStore: progress)
            let scene = GameScene(level: fixture, theme: .aurora, size: CGSize(width: 300, height: 300))
            model.scene = scene
            model.beginSession()
            for _ in 0..<3 {
                model.sceneDidTapPiece("target")
                // A geometry rebuild settles pending feedback, unlike
                // suspension (which intentionally discards its callbacks).
                scene.size = CGSize(width: scene.size.width + 1, height: scene.size.height)
                #expect(!model.inputLocked)
            }
            #expect(model.mistakesCount == (index == 241 ? 0 : 3))
            #expect(model.lives == (index == 241 ? 4 : 1))
            #expect(model.movesMade == 0)
            #expect(scene.board.pieces.count == 2)
            #expect(!scene.board.isKeyGateOpen(fixture.obstacles[0]))
            model.endSession()
        }
    }

    @Test func gateInspectionDoesNotSpendResourcesOrCountAsMove() {
        let fixture = level(index: 242)
        let progress = store()
        let hints = progress.progress.hintsCount
        let undos = progress.progress.undosCount
        let coins = progress.progress.coins
        let model = GameViewModel(level: fixture, mode: .story(index: 242), progressStore: progress)
        let scene = GameScene(level: fixture, theme: .aurora, size: CGSize(width: 300, height: 300))
        model.scene = scene
        model.beginSession()
        model.sceneDidInspectKeyGate("gate")
        #expect(model.gateMessage != nil)
        #expect(model.movesMade == 0 && model.mistakesCount == 0 && model.lives == 4)
        #expect(progress.progress.hintsCount == hints && progress.progress.undosCount == undos && progress.progress.coins == coins)
        #expect(model.hintsUsed == 0)
        model.endSession()
    }

    @Test func resizingGateGuidancePreservesLiveBoardPendingMoveAndUndoHistory() {
        let fixture = level(index: 242)
        let progress = store()
        let model = GameViewModel(level: fixture, mode: .story(index: 242), progressStore: progress)
        let container = SceneContainer()
        func scene(size: CGSize) -> GameScene {
            container.scene(
                for: fixture, theme: .aurora, increasedContrast: false,
                showsArrowOutlines: false,
                arrowOutlineColor: .init(red: 0.12, green: 0.12, blue: 0.16),
                size: size, reduceMotion: true, delegate: model,
                onPreparationStarted: {}, onReady: {}, bind: { model.scene = $0 }
            )
        }
        let original = scene(size: CGSize(width: 300, height: 250))
        // Render nodes without relying on a simulator animation clock. The
        // later resize must finish this pending fly-out on the same scene.
        original.didChangeSize(.zero)
        model.beginSession()
        model.sceneDidTapPiece("key")
        #expect(model.movesMade == 1)
        #expect(original.board.pieces.map(\.id) == ["target"])
        #expect(original.board.isKeyGateOpen(fixture.obstacles[0]))

        let resized = scene(size: CGSize(width: 240, height: 200))
        #expect(resized === original)
        #expect(resized.board.pieces.map(\.id) == ["target"])
        #expect(resized.board.isKeyGateOpen(fixture.obstacles[0]))
        #expect(model.movesMade == 1 && model.mistakesCount == 0)
        #expect(!model.inputLocked)
        model.consumeUndo()
        #expect(Set(resized.board.pieces.map(\.id)) == ["key", "target"])
        #expect(!resized.board.isKeyGateOpen(fixture.obstacles[0]))
        model.endSession()
    }

    @Test func restartDuringKeyFlightDiscardsOldCompletionAndClosesEveryGate() throws {
        let fixture = level(index: 242)
        let progress = store()
        let model = GameViewModel(level: fixture, mode: .story(index: 242), progressStore: progress)
        let scene = GameScene(level: fixture, theme: .aurora, size: CGSize(width: 300, height: 250), reduceMotion: true)
        scene.didChangeSize(.zero)
        model.scene = scene
        model.beginSession()
        let oldKeyNode = try #require(scene.childNode(withName: "//key") as? ArrowPieceNode)
        model.sceneDidTapPiece("key")
        #expect(model.inputLocked)
        #expect(scene.board.isKeyGateOpen(fixture.obstacles[0]))

        model.restart()
        #expect(scene.board.pieces == fixture.pieces)
        #expect(!scene.board.isKeyGateOpen(fixture.obstacles[0]))
        #expect(model.movesMade == 0 && model.mistakesCount == 0 && model.gateMessage == nil)
        #expect(!model.inputLocked && !model.isCompleted)
        let freshKeyNode = try #require(scene.childNode(withName: "//key") as? ArrowPieceNode)
        #expect(freshKeyNode !== oldKeyNode)

        // Start a new operation before attempting to flush the stale node.
        // An old callback must not unlock or remove the new attempt's node.
        model.sceneDidTapPiece("key")
        oldKeyNode.interruptActions(completingPendingOperations: true)
        #expect(model.inputLocked)
        #expect(model.movesMade == 1 && model.gateMessage == nil)
        #expect(scene.childNode(withName: "//key") === freshKeyNode)
        #expect(progress.progress.completedLevels.isEmpty)
        scene.size = CGSize(width: 288, height: 240)
        #expect(!model.inputLocked)
        #expect(scene.board.pieces.map(\.id) == ["target"])
        #expect(scene.board.isKeyGateOpen(fixture.obstacles[0]))
        model.endSession()
    }

    @Test func endingSessionDuringFinalFlightCannotRecordAStaleVictory() throws {
        let fixture = level(index: 242)
        let progress = store()
        let initialCoins = progress.progress.coins
        let model = GameViewModel(level: fixture, mode: .story(index: 242), progressStore: progress)
        let scene = GameScene(level: fixture, theme: .aurora, size: CGSize(width: 300, height: 250), reduceMotion: true)
        scene.didChangeSize(.zero)
        model.scene = scene
        model.beginSession()
        model.sceneDidTapPiece("key")
        scene.size = CGSize(width: 288, height: 240)
        let finalNode = try #require(scene.childNode(withName: "//target") as? ArrowPieceNode)
        model.sceneDidTapPiece("target")
        #expect(scene.board.pieces.isEmpty)
        #expect(model.inputLocked && !model.isCompleted)

        model.endSession()
        finalNode.interruptActions(completingPendingOperations: true)
        #expect(!model.isCompleted)
        #expect(progress.progress.completedLevels.isEmpty)
        #expect(progress.progress.stars.isEmpty)
        #expect(progress.progress.coins == initialCoins)
        #expect(model.scene == nil)
    }

    @Test func master241KeepsItsOwnPenaltyInsteadOfTrainingProtection() {
        for modifier in GameMode.masterModifiers {
            let fixture = level(index: 241)
            let progress = store()
            let model = GameViewModel(level: fixture, mode: .master(index: 241), gameMode: modifier, progressStore: progress)
            let scene = GameScene(level: fixture, theme: .aurora, size: CGSize(width: 300, height: 250), reduceMotion: true)
            scene.didChangeSize(.zero)
            model.scene = scene
            model.beginSession()
            let startingLives = model.lives
            #expect(!model.isGateTraining)
            model.sceneDidTapPiece("target")
            #expect(model.mistakesCount == 1)
            #expect(model.lives == startingLives - 1)
            #expect(model.movesMade == 0)
            scene.size = CGSize(width: 288, height: 240)
            #expect(!model.inputLocked)
            #expect(scene.board.pieces == fixture.pieces)
            #expect(!scene.board.isKeyGateOpen(fixture.obstacles[0]))
            model.endSession()
        }
    }

    @Test func keyInspectionIsFreeWithPreviewDisabledAndInHardMode() {
        for gameMode in [GameMode.classic, .hard] {
            let defaults = UserDefaults(suiteName: "MazeArrowsV2SettingsTests-\(UUID().uuidString)")!
            let settings = SettingsStore(defaults: defaults)
            settings.settings.previewPathEnabled = gameMode == .hard
            settings.settings.soundEnabled = false
            settings.settings.hapticsEnabled = false
            let progress = store()
            let fixture = level(index: 241)
            let mode: GameViewModel.LevelMode = gameMode == .hard ? .master(index: 241) : .story(index: 241)
            let model = GameViewModel(level: fixture, mode: mode, gameMode: gameMode, progressStore: progress, settingsStore: settings)
            let scene = GameScene(level: fixture, theme: .aurora, size: CGSize(width: 300, height: 250))
            scene.didChangeSize(.zero)
            model.scene = scene
            model.beginSession()
            let hints = progress.progress.hintsCount
            let undos = progress.progress.undosCount
            let coins = progress.progress.coins
            let lives = model.lives

            model.sceneDidLongPressPiece("key")

            #expect(model.gateMessage == scene.keyGateKeyAccessibilityValue(forKeyID: "key"))
            #expect(model.gateMessage != nil)
            #expect(scene.childNode(withName: "//preview") == nil)
            #expect(model.hintsUsed == 0 && model.movesMade == 0 && model.mistakesCount == 0)
            #expect(model.lives == lives && model.combo == 0 && !model.inputLocked)
            #expect(progress.progress.hintsCount == hints && progress.progress.undosCount == undos && progress.progress.coins == coins)
            model.sceneDidEndLongPress()
            #expect(scene.board.pieces == fixture.pieces)
            #expect(!scene.board.isKeyGateOpen(fixture.obstacles[0]))
            model.endSession()
        }
    }
}
