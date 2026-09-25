//
//  LevelShareViews.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Share sheet (QR + link) and import sheet (paste a code) for shared levels.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - share

struct ShareLevelSheet: View {
    let level: Level
    let theme: GameTheme

    private var shareURL: URL? { LevelShareCodec.shareURL(for: level) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text("Share This Maze")
                .scaledFont(size: 20, weight: .black, design: .rounded)
                .foregroundStyle(theme.ink)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)

            if let shareURL {
                if let qr = Self.qrImage(for: shareURL.absoluteString) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(theme.glassBorder)
                        )
                        .accessibilityLabel("QR code for the maze link")

                    Text("Scan with the camera to open the level, or send the link.")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(theme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    // Very detailed levels exceed QR capacity — link still works.
                    Text("This maze is too detailed for a QR code — send the link instead.")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(theme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                ShareLink(item: shareURL) {
                    Text("Share Link")
                        .textCase(.uppercase)
                        .scaledFont(size: 15, weight: .heavy)
                        .tracking(1.0)
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(theme.primaryGradient))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Button {
                    UIPasteboard.general.string = shareURL.absoluteString
                    if UIAccessibility.isVoiceOverRunning {
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: String(localized: "Maze link copied.")
                        )
                    }
                } label: {
                    Text("Copy Code")
                        .textCase(.uppercase)
                        .scaledFont(size: 14, weight: .bold)
                        .foregroundStyle(theme.inkSoft)
                        .minimumTapTarget()
                }
                .buttonStyle(.plain)
            } else {
                Text("This level is too large to share.")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(theme.inkMuted)
            }
                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.appBackground.ignoresSafeArea())
    }

    static func qrImage(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - import

struct ImportLevelSheet: View {
    let theme: GameTheme
    let onImport: (Level) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var failure: LevelImportError?
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?
    @State private var importRequestID = UUID()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text("Import a Maze")
                .scaledFont(size: 20, weight: .black, design: .rounded)
                .foregroundStyle(theme.ink)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)

            Text("Paste a maze link or code you received.")
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(theme.inkMuted)

            TextField("mazearrows://…", text: $code, axis: .vertical)
                .scaledFont(size: 13, weight: .medium, design: .monospaced)
                .lineLimit(3...5)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .frame(minHeight: 44)
                .accessibilityLabel("Maze link or code")
                .accessibilityHint("Paste the link or code received from a friend.")
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(failure != nil ? theme.danger : theme.glassBorder)
                        )
                )
                .padding(.horizontal, 24)
                .disabled(isImporting)
                .onChange(of: code) { _, newValue in
                    guard !LevelShareCodec.inputSizeIsAllowed(newValue) else { return }
                    cancelImport()
                    code = ""
                    failure = .invalidCode
                }

            Button {
                cancelImport()
                if let pasted = UIPasteboard.general.string,
                   LevelShareCodec.inputSizeIsAllowed(pasted) {
                    code = pasted
                    failure = nil
                } else {
                    code = ""
                    failure = .invalidCode
                }
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
                    .scaledFont(size: 14, weight: .bold)
                    .foregroundStyle(theme.inkSoft)
                    .minimumTapTarget()
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
            .accessibilityLabel("Paste maze link or code")

            if failure == .invalidCode {
                Label("That code doesn't look like a valid maze.", systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(theme.ink)
            } else if failure == .timedOut {
                Label("Import took too long. Please try again.", systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(theme.ink)
            }

            PrimaryButton(text: isImporting ? "Opening…" : "Open", theme: theme, action: startImport)
            .padding(.horizontal, 24)
            .disabled(
                isImporting || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.appBackground.ignoresSafeArea())
        .onDisappear(perform: cancelImport)
    }

    private func startImport() {
        cancelImport()
        let input = code
        let requestID = UUID()
        importRequestID = requestID
        isImporting = true
        failure = nil

        importTask = Task {
            do {
                let level = try await LevelImportService.importLevel(from: input)
                guard !Task.isCancelled, importRequestID == requestID else { return }
                isImporting = false
                importTask = nil
                dismiss()
                onImport(level)
            } catch is CancellationError {
                guard importRequestID == requestID else { return }
                isImporting = false
                importTask = nil
            } catch let error as LevelImportError {
                guard importRequestID == requestID else { return }
                isImporting = false
                importTask = nil
                failure = error
            } catch {
                guard importRequestID == requestID else { return }
                isImporting = false
                importTask = nil
                failure = .invalidCode
            }
        }
    }

    private func cancelImport() {
        importRequestID = UUID()
        importTask?.cancel()
        importTask = nil
        isImporting = false
    }
}
