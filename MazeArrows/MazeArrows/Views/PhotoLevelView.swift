//
//  PhotoLevelView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  "Create from Photo": the user picks an image, we extract a silhouette
//  mask on the grid (with adjustable detail / inversion; color zones are
//  detected automatically), fill it with snake arrows and hand the result
//  to the regular game screen.
//

import SwiftUI
import PhotosUI
import UIKit

struct PhotoLevelView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @Environment(PremiumStore.self) private var premium
    @Environment(AdService.self) private var ads
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceImage: CGImage?
    /// Vision cutouts of the foreground subject(s) (transparent background),
    /// when Vision found any in the photo.
    @State private var subjectCutouts: SubjectCutouts?
    /// Which instance the maze is built from; nil = all objects combined.
    @State private var selectedInstance: Int?
    @State private var useSubjectCutout = true
    @State private var detail: Double = 24
    @State private var invert = false
    @State private var mask: ImageBoardResult?
    @State private var isGenerating = false
    @State private var generationFailed = false
    @State private var playLevel: Level?
    /// The last generated level — reused so Play and the V2 sharing flow hand
    /// out the same board. Reset whenever the mask parameters change.
    @State private var builtLevel: Level?
    @State private var buildStartedAt: Date?
    @State private var completedBuildDuration: TimeInterval?
    @State private var generationProgress: Double = 0
    @State private var pendingOutputAction: PhotoMazeOutputAction?
    @State private var shareLevel: Level?
    @State private var showImportSheet = false
    @State private var showPhotoMazeLimit = false
    @State private var isPresentingRewardedPhotoMazeAd = false

    @State private var imageLoadTask: Task<Void, Never>?
    @State private var subjectTask: Task<Void, Never>?
    @State private var maskTask: Task<Void, Never>?
    @State private var levelTask: Task<Void, Never>?
    @State private var imageRequestID = UUID()
    @State private var subjectRequestID = UUID()
    @State private var maskRequestID = UUID()
    @State private var levelRequestID = UUID()
    @State private var didFinishSubjectExtraction = false
    @State private var isLoadingPhoto = false
    @State private var isRebuildingMask = false
    @State private var premiumPaywallContext: PremiumPaywallContext?

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }
    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()
            if !premium.hasLoadedEntitlements {
                ProgressView("Checking Premium…")
                    .tint(theme.accent)
                    .foregroundStyle(theme.ink)
                    .task {
                        await premium.refreshEntitlements()
                    }
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        previewCard
                        if sourceImage != nil {
                            controls
                        }
                        actionButtons
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle(Text("Photo Maze"))
        .navigationBarTitleDisplayMode(.inline)
        .designedBackButton(theme: theme)
        .edgeFades(theme: theme)
        .navigationDestination(item: $playLevel) { level in
            GameView(model: GameViewModel(
                level: level,
                mode: .generated(difficulty: .medium, seed: 0),
                gameMode: .relax
            ))
        }
        .sheet(item: $shareLevel) { level in
            ShareLevelSheet(level: level, theme: theme)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showImportSheet) {
            ImportLevelSheet(theme: theme) { level in
                playLevel = level
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPhotoMazeLimit) {
            PhotoMazeLimitSheet(
                theme: theme,
                isAdReady: ads.isRewardedAdReady(for: .photoMaze),
                isPresentingAd: isPresentingRewardedPhotoMazeAd,
                watchAd: watchPhotoMazeAd,
                openPremium: openPhotoMazePaywall,
                notNow: dismissPhotoMazeLimit
            )
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $premiumPaywallContext) { context in
            PremiumPaywallView(context: context) {
                resumePendingOutputAfterPremiumUnlock()
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            startImageLoad(from: newItem)
        }
        .onChange(of: detail) { rebuildMask() }
        .onChange(of: invert) { rebuildMask() }
        .onChange(of: useSubjectCutout) { rebuildMask() }
        .onChange(of: selectedInstance) { rebuildMask() }
        .onChange(of: playLevel) { _, level in
            if level != nil {
                releasePhotoBuffersForGameplay()
            }
        }
        .onAppear {
            if premium.hasLoadedEntitlements {
                resumePendingWorkIfNeeded()
            }
        }
        .onChange(of: premium.hasLoadedEntitlements) {
            if premium.hasLoadedEntitlements {
                resumePendingWorkIfNeeded()
            }
        }
        .task {
            if !premium.hasLoadedEntitlements {
                await premium.refreshEntitlements()
            }
            if !premium.isPremium {
                ads.preloadRewardedAd(for: .photoMaze)
            }
        }
        .onDisappear(perform: cancelPendingWork)
    }

    // MARK: - sections

    private var header: some View {
        VStack(spacing: 7) {
            Text("Pick a photo with a clear silhouette — we turn it into a maze of arrows.")
                .scaledFont(size: 14, weight: .medium)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)

            if premium.isPremium {
                Label("Premium · Unlimited Photo Mazes", systemImage: "crown.fill")
                    .foregroundStyle(theme.rewardGold)
            } else if progress.progress.photoMazeRewardedCredits > 0 {
                Label("1 extra Photo Maze ready", systemImage: "play.rectangle.fill")
                    .foregroundStyle(theme.accent)
            } else {
                let remaining = progress.photoMazeFreeGenerationsRemaining()
                HStack(spacing: 5) {
                    Text("Free Photo Maze creations remaining")
                    Text(remaining, format: .number)
                        .monospacedDigit()
                }
                    .foregroundStyle(theme.accent)
            }
        }
        .scaledFont(size: 12, weight: .bold)
        .multilineTextAlignment(.center)
    }

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.boardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.glassBorder)
                )

            if isLoadingPhoto {
                ProgressView()
                    .tint(theme.accent)
            } else if let mask {
                MaskPreview(mask: mask)
                    .padding(18)
            } else if sourceImage != nil {
                Text("No silhouette found — try Invert or another photo")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(24)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .scaledFont(size: 44, weight: .medium)
                    Text("Choose a photo")
                        .scaledFont(size: 15, weight: .bold)
                }
                .foregroundStyle(theme.inkMuted)
            }

            if isGenerating {
                PhotoMazeBuildProgressView(
                    progress: generationProgress,
                    theme: theme
                )
                .padding(24)
            }
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 240 : 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(previewAccessibilityLabel))
        .accessibilityAddTraits(
            isLoadingPhoto || isRebuildingMask || isGenerating
                ? .updatesFrequently
                : []
        )
    }

    private var previewAccessibilityLabel: String {
        if isLoadingPhoto { return String(localized: "Loading photo") }
        if isRebuildingMask { return String(localized: "Updating maze preview") }
        if let mask {
            let moves = builtLevel?.pieces.count ?? estimatedMoves(for: mask)
            if isGenerating {
                let percentage = generationProgress.formatted(
                    .percent.precision(.fractionLength(0))
                )
                return String(
                    localized: "Building Photo Maze. \(percentage) complete."
                )
            }
            if let completedBuildDuration {
                return String(localized: "Maze preview. \(moves) moves. Built in \(formattedDuration(completedBuildDuration)).")
            }
            return String(localized: "Maze preview. About \(moves) moves.")
        }
        if sourceImage != nil {
            return String(localized: "No silhouette found. Try Invert or another photo.")
        }
        return String(localized: "No photo selected")
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if let mask {
                let moves = builtLevel?.pieces.count ?? estimatedMoves(for: mask)
                DynamicTypeStack(spacing: 8) {
                    Text(verbatim: builtLevel == nil
                         ? String(localized: "~\(moves) moves")
                         : String(localized: "\(moves) moves"))
                    Spacer()
                    buildStatus
                }
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(theme.inkMuted)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Maze estimate")
            }

            DynamicTypeStack(spacing: 8) {
                Text("Detail")
                    .scaledFont(size: 13, weight: .bold)
                    .foregroundStyle(theme.inkSoft)
                Slider(value: $detail, in: 14...120, step: 2)
                    .tint(theme.accent)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Detail")
                    .accessibilityValue(Text("\(Int(detail))"))
            }

            if !(subjectCutouts != nil && useSubjectCutout) {
                Toggle(isOn: $invert) {
                    Text("Invert")
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundStyle(theme.inkSoft)
                }
                .tint(theme.accent)
                .frame(minHeight: 44)
            }

            if subjectCutouts != nil {
                Toggle(isOn: $useSubjectCutout) {
                    Text(subjectCutouts?.mode == .centeredPerson
                         ? "Center person"
                         : "Auto-cut subject")
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundStyle(theme.inkSoft)
                }
                .tint(theme.accent)
                .frame(minHeight: 44)
            }

            if subjectCutouts?.mode == .centeredPerson, useSubjectCutout {
                Text("Automatic cutout is unavailable here, so a centered person outline is used.")
                    .scaledFont(size: 11, weight: .medium)
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let cutouts = subjectCutouts, useSubjectCutout, cutouts.instances.count > 1 {
                instancePicker(cutouts: cutouts)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.glassBorder)
                )
        )
    }

    /// The snake fill averages ~7.5 cells per arrow, so the mask size predicts
    /// the move count well before the level is actually generated.
    private func estimatedMoves(for mask: ImageBoardResult) -> Int {
        let moves = Double(mask.allCells.count) / 7.5
        // Round to 5 — this is an estimate, not a promise.
        return max(5, Int((moves / 5).rounded()) * 5)
    }

    /// Shows measured work instead of a synthetic estimate. Generation time
    /// depends heavily on the silhouette topology, not just its cell count.
    @ViewBuilder
    private var buildStatus: some View {
        if isGenerating, let buildStartedAt {
            TimelineView(.periodic(from: buildStartedAt, by: 1)) { context in
                Text("Building… \(formattedDuration(context.date.timeIntervalSince(buildStartedAt)))")
            }
        } else if let completedBuildDuration, builtLevel != nil {
            Text("Ready · \(formattedDuration(completedBuildDuration))")
        } else if generationFailed {
            Text("Build failed")
        } else {
            Text("Preparing…")
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        return Duration.seconds(totalSeconds).formatted(
            .units(
                allowed: [.minutes, .seconds],
                width: .abbreviated,
                maximumUnitCount: 2,
                zeroValueUnits: .show(length: 1)
            )
        )
    }

    private var actionButtons: some View {
        let photoButtonTheme = theme
        let localizedPhotoButtonTitle = photoButtonTitle

        return VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text(verbatim: localizedPhotoButtonTitle)
                    .textCase(.uppercase)
                    .scaledFont(size: 15, weight: .heavy)
                    .tracking(1.0)
                    .foregroundStyle(photoButtonTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(photoButtonTheme.surface)
                            .overlay(Capsule().stroke(photoButtonTheme.glassBorder, lineWidth: 1.5))
                    )
            }
            .buttonStyle(.plain)

            if mask != nil {
                PrimaryButton(text: isGenerating ? "Building…" : "Play", theme: theme) {
                    requestLevel(for: .play)
                }
                .disabled(isGenerating || isRebuildingMask)
                .opacity(isGenerating || isRebuildingMask ? 0.6 : 1.0)

                if FeatureFlags.photoMazeSharingAvailable {
                    GhostButton(text: "Share", theme: theme) {
                        requestLevel(for: .share)
                    }
                    .disabled(isGenerating || isRebuildingMask)
                }
            }

            if FeatureFlags.photoMazeSharingAvailable {
                Button {
                    showImportSheet = true
                } label: {
                    Text("Import a maze from a friend")
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundStyle(theme.inkSoft)
                        .underline()
                        .minimumTapTarget()
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            if generationFailed {
                Label {
                    Text("Couldn't build a level from this shape — try more detail or another photo.")
                        .foregroundStyle(theme.ink)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.danger)
                }
                .scaledFont(size: 13, weight: .medium)
                .multilineTextAlignment(.center)
            }
        }
    }

    private var photoButtonTitle: String {
        sourceImage == nil
            ? String(localized: "Choose a photo")
            : String(localized: "Choose another photo")
    }

    /// Horizontal row of object thumbnails when Vision found several.
    private func instancePicker(cutouts: SubjectCutouts) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                instanceButton(label: String(localized: "All"), image: cutouts.combined, tag: nil)
                ForEach(cutouts.instances.indices, id: \.self) { index in
                    instanceButton(label: "\(index + 1)", image: cutouts.instances[index], tag: index)
                }
            }
        }
    }

    private func instanceButton(label: String, image: CGImage, tag: Int?) -> some View {
        let isSelected = selectedInstance == tag
        return Button {
            selectedInstance = tag
        } label: {
            VStack(spacing: 4) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.boardBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? theme.accent : theme.glassBorder,
                                    lineWidth: isSelected ? 2.5 : 1)
                    )
                HStack(spacing: 3) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .scaledFont(size: 11, weight: .black)
                    }
                    Text(label)
                        .scaledFont(size: 11, weight: .bold)
                }
                .foregroundStyle(isSelected ? theme.ink : theme.inkMuted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: subjectAccessibilityLabel(tag)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func subjectAccessibilityLabel(_ tag: Int?) -> String {
        guard let tag else { return String(localized: "All subjects") }
        return String(localized: "Subject \(tag + 1)")
    }

    // MARK: - pipeline

    private func startImageLoad(from item: PhotosPickerItem) {
        cancelPendingWork()

        sourceImage = nil
        subjectCutouts = nil
        mask = nil
        builtLevel = nil
        buildStartedAt = nil
        completedBuildDuration = nil
        generationProgress = 0
        pendingOutputAction = nil
        selectedInstance = nil
        useSubjectCutout = true
        didFinishSubjectExtraction = false
        generationFailed = false
        isLoadingPhoto = true

        let requestID = UUID()
        imageRequestID = requestID
        imageLoadTask = Task {
            await loadImage(from: item, requestID: requestID)
        }
    }

    private func loadImage(from item: PhotosPickerItem, requestID: UUID) async {
        defer {
            if imageRequestID == requestID {
                imageLoadTask = nil
                isLoadingPhoto = false
            }
        }

        guard let image = await Self.loadProcessingImage(from: item),
              !Task.isCancelled,
              imageRequestID == requestID else {
            if !Task.isCancelled, imageRequestID == requestID {
                announceForVoiceOver(String(localized: "The photo could not be loaded."))
            }
            return
        }

        sourceImage = image
        rebuildMask()
        startSubjectExtraction(from: image, imageRequestID: requestID)
    }

    /// Keeps the compressed picker data scoped to this helper so it can be
    /// released before Vision starts allocating its masks and cutouts.
    private static func loadProcessingImage(from item: PhotosPickerItem) async -> CGImage? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        guard !Task.isCancelled else { return nil }

        let worker = Task.detached(priority: .userInitiated) {
            PhotoImageDownsampler.downsample(data)
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private func startSubjectExtraction(from image: CGImage, imageRequestID: UUID) {
        subjectTask?.cancel()
        let requestID = UUID()
        subjectRequestID = requestID

        subjectTask = Task {
            let cutouts = await SubjectExtractor.extractSubjects(from: image)

            guard !Task.isCancelled,
                  subjectRequestID == requestID,
                  self.imageRequestID == imageRequestID,
                  sourceImage === image else { return }

            subjectTask = nil
            didFinishSubjectExtraction = true
            subjectCutouts = cutouts
            if let cutouts, cutouts.instances.count > 1 {
                announceForVoiceOver(
                    String(localized: "Found \(cutouts.instances.count) subjects. Choose one or use all subjects.")
                )
            }
            if cutouts != nil && useSubjectCutout {
                rebuildMask()
            }
        }
    }

    /// The cutout the mask should be built from, honoring instance selection.
    private var activeCutout: CGImage? {
        guard useSubjectCutout, let cutouts = subjectCutouts else { return nil }
        if let selectedInstance, cutouts.instances.indices.contains(selectedInstance) {
            return cutouts.instances[selectedInstance]
        }
        return cutouts.combined
    }

    private func rebuildMask() {
        guard let sourceImage else { return }

        maskTask?.cancel()
        levelTask?.cancel()
        levelTask = nil
        levelRequestID = UUID()
        isGenerating = false
        builtLevel = nil
        buildStartedAt = nil
        completedBuildDuration = nil
        generationProgress = 0
        pendingOutputAction = nil
        generationFailed = false

        let cutout = activeCutout
        let input = cutout ?? sourceImage
        let usingAlpha = cutout != nil
        let height = Int(detail)
        let inverted = invert

        let requestID = UUID()
        maskRequestID = requestID
        isRebuildingMask = true
        maskTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }

            let worker = Task.detached(priority: .userInitiated) {
                ImageBoardBuilder.build(
                    from: input,
                    targetHeight: height,
                    invert: inverted,
                    useAlphaMask: usingAlpha
                )
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard !Task.isCancelled, maskRequestID == requestID else { return }
            maskTask = nil
            isRebuildingMask = false
            mask = result
            if let result {
                announceForVoiceOver(
                    String(localized: "Maze preview updated. About \(estimatedMoves(for: result)) moves.")
                )
            } else {
                announceForVoiceOver(String(localized: "No silhouette found. Try Invert or another photo."))
            }
        }
    }

    /// Play and the V2 sharing flow reuse a cached board. Only a new successful
    /// build spends one free generation or an earned rewarded-ad credit.
    private func requestLevel(for action: PhotoMazeOutputAction) {
        if let builtLevel {
            perform(action, with: builtLevel)
            return
        }
        guard let mask, !isRebuildingMask, !isGenerating else { return }

        pendingOutputAction = action
        guard let access = progress.photoMazeGenerationAccess(
            isPremium: premium.isPremium
        ) else {
            showPhotoMazeLimit = true
            Analytics.log(.offerShown(
                context: "photo_maze",
                slots: ["rewarded", "premium"]
            ))
            ads.preloadRewardedAd(for: .photoMaze)
            return
        }

        startLevelBuild(from: mask, using: access, action: action)
    }

    private func startLevelBuild(
        from mask: ImageBoardResult,
        using access: PhotoMazeGenerationAccess,
        action: PhotoMazeOutputAction
    ) {
        levelTask?.cancel()
        let requestID = UUID()
        levelRequestID = requestID
        isGenerating = true
        generationFailed = false
        generationProgress = 0
        buildStartedAt = Date()
        completedBuildDuration = nil
        let startedAt = buildStartedAt ?? Date()

        levelTask = Task {
            for await update in PhotoMazeLevelBuilder.updates(for: mask) {
                guard !Task.isCancelled, levelRequestID == requestID else { return }

                switch update {
                case .progress(let value):
                    generationProgress = max(generationProgress, min(1, value))
                case .finished(let level):
                    finishLevelBuild(
                        level,
                        using: access,
                        action: action,
                        startedAt: startedAt,
                        requestID: requestID
                    )
                    return
                }
            }
        }
    }

    private func finishLevelBuild(
        _ level: Level?,
        using access: PhotoMazeGenerationAccess,
        action: PhotoMazeOutputAction,
        startedAt: Date,
        requestID: UUID
    ) {
        guard levelRequestID == requestID else { return }
        levelTask = nil
        isGenerating = false
        buildStartedAt = nil
        completedBuildDuration = Date().timeIntervalSince(startedAt)

        guard let level else {
            generationFailed = true
            announceForVoiceOver(String(localized: "The maze could not be built from this shape."))
            return
        }

        guard progress.commitSuccessfulPhotoMazeGeneration(using: access) else {
            generationFailed = true
            showPhotoMazeLimit = true
            return
        }

        generationProgress = 1
        builtLevel = level
        pendingOutputAction = nil
        perform(action, with: level)
    }

    private func perform(_ action: PhotoMazeOutputAction, with level: Level) {
        switch action {
        case .play:
            playLevel = level
        case .share:
            shareLevel = level
        }
    }

    private func watchPhotoMazeAd() {
        guard !isPresentingRewardedPhotoMazeAd,
              ads.isRewardedAdReady(for: .photoMaze)
        else { return }

        isPresentingRewardedPhotoMazeAd = true
        Task { @MainActor in
            let earned = await ads.presentRewardedAd(for: .photoMaze) {
                progress.grantPhotoMazeRewardedCredit()
                Analytics.log(.offerConverted(context: "photo_maze", slot: "rewarded"))
            }
            isPresentingRewardedPhotoMazeAd = false

            guard earned, let pendingOutputAction else { return }
            showPhotoMazeLimit = false
            await Task.yield()
            requestLevel(for: pendingOutputAction)
        }
    }

    private func openPhotoMazePaywall() {
        showPhotoMazeLimit = false
        Task { @MainActor in
            await Task.yield()
            premiumPaywallContext = .photoMaze
        }
    }

    private func resumePendingOutputAfterPremiumUnlock() {
        guard premium.isPremium, let pendingOutputAction else { return }
        Analytics.log(.offerConverted(context: "photo_maze", slot: "premium"))
        Task { @MainActor in
            await Task.yield()
            requestLevel(for: pendingOutputAction)
        }
    }

    private func dismissPhotoMazeLimit() {
        pendingOutputAction = nil
        showPhotoMazeLimit = false
    }

    private func announceForVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func resumePendingWorkIfNeeded() {
        if sourceImage == nil, let pickerItem {
            startImageLoad(from: pickerItem)
            return
        }

        guard let sourceImage else { return }
        if mask == nil {
            rebuildMask()
        }
        if !didFinishSubjectExtraction {
            startSubjectExtraction(from: sourceImage, imageRequestID: imageRequestID)
        }
    }

    private func cancelPendingWork() {
        imageRequestID = UUID()
        subjectRequestID = UUID()
        maskRequestID = UUID()
        levelRequestID = UUID()

        imageLoadTask?.cancel()
        subjectTask?.cancel()
        maskTask?.cancel()
        levelTask?.cancel()
        imageLoadTask = nil
        subjectTask = nil
        maskTask = nil
        levelTask = nil

        isLoadingPhoto = false
        isRebuildingMask = false
        isGenerating = false
        generationProgress = 0
        if builtLevel == nil {
            buildStartedAt = nil
            completedBuildDuration = nil
        }
    }

    /// The photo editor remains on the navigation stack while the game is
    /// visible. Drop its decoded image and Vision cutouts before pushing the
    /// game so those bitmaps do not inflate the gameplay memory footprint.
    /// `pickerItem` stays available and `onAppear` reloads the editor if the
    /// player returns.
    private func releasePhotoBuffersForGameplay() {
        cancelPendingWork()
        sourceImage = nil
        subjectCutouts = nil
        mask = nil
        selectedInstance = nil
        didFinishSubjectExtraction = false
    }

}

// MARK: - mask preview

/// Draws the extracted mask using the exact RGB palette embedded in the game.
private struct MaskPreview: View {
    let mask: ImageBoardResult

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width / CGFloat(mask.width), size.height / CGFloat(mask.height))
            let offsetX = (size.width - cell * CGFloat(mask.width)) / 2
            let offsetY = (size.height - cell * CGFloat(mask.height)) / 2
            for (zoneIndex, zone) in mask.zones.enumerated() {
                let sourceColor = mask.zoneColors.indices.contains(zoneIndex)
                    ? mask.zoneColors[zoneIndex]
                    : (r: 0.0, g: 0.0, b: 0.0)
                let color = Color(
                    red: sourceColor.r,
                    green: sourceColor.g,
                    blue: sourceColor.b
                )
                for point in zone {
                    let rect = CGRect(
                        x: offsetX + CGFloat(point.x) * cell + cell * 0.08,
                        y: offsetY + CGFloat(point.y) * cell + cell * 0.08,
                        width: cell * 0.84,
                        height: cell * 0.84
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: cell * 0.22),
                        with: .color(color)
                    )
                }
            }
        }
    }
}
