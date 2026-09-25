//
//  SubjectExtractor.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Vision-based subject cutout for Photo Maze: extracts the foreground
//  object(s) (person, pet, mug — whatever Vision finds) with transparent
//  background, so the mask builder can take "opaque = subject" directly
//  instead of guessing by luminance. When the photo contains several
//  objects, each instance is also extracted separately so the player can
//  pick which one becomes the maze.
//

import Foundation
import CoreImage
import Vision

nonisolated enum SubjectCutoutMode: Sendable {
    case automatic
    case centeredPerson
}

nonisolated struct SubjectCutouts: Sendable {
    /// All found objects merged into one cutout.
    let combined: CGImage
    /// Individual objects, in Vision's instance order. Empty when the photo
    /// has a single instance (then it equals `combined`).
    let instances: [CGImage]
    /// Distinguishes a precise system cutout from the explicit portrait
    /// fallback used when segmentation models are unavailable.
    let mode: SubjectCutoutMode

    init(
        combined: CGImage,
        instances: [CGImage],
        mode: SubjectCutoutMode = .automatic
    ) {
        self.combined = combined
        self.instances = instances
        self.mode = mode
    }
}

nonisolated enum SubjectExtractor {

    /// The board sampler never needs more than 128 cells on an axis. Keeping
    /// cutouts at 1,024 px still provides at least 8 source pixels per cell,
    /// while using at most one quarter of a 2,048 px cutout's bitmap memory.
    static let maximumCutoutPixelSize = 1_024

    /// A busy group photo can contain many foreground instances. "All"
    /// continues to include every detected subject, but retaining more than
    /// eight separate full previews has little UI value and unbounded memory.
    static let maximumRetainedInstances = 8

    private static let pipeline = SubjectExtractionPipeline()

    /// Returns the subject(s) with a transparent background, cropped to
    /// their bounds, or nil when Vision finds no clear foreground instance.
    /// Calls are serialized so cancelled and replacement requests cannot keep
    /// multiple Vision models and their pixel buffers alive at the same time.
    static func extractSubjects(from image: CGImage) async -> SubjectCutouts? {
        await pipeline.extractSubjects(from: image)
    }
}

/// Vision's foreground request is synchronous. Actor isolation keeps at most
/// one request inside `perform` while the cancellation handler can still abort
/// that request directly from the task's cancellation executor.
private actor SubjectExtractionPipeline {
    func extractSubjects(from image: CGImage) async -> SubjectCutouts? {
        guard !Task.isCancelled else { return nil }
        let job = SubjectExtractionJob(image: image)
        return await withTaskCancellationHandler {
            job.run()
        } onCancel: {
            job.cancel()
        }
    }
}

/// `VNRequest.cancel()` is explicitly designed to abort an in-flight request.
/// The wrapper owns immutable references; `run()` is actor-serialized and the
/// only concurrent operation is the documented cancellation call.
nonisolated private final class SubjectExtractionJob: @unchecked Sendable {
    private let foregroundRequest = VNGenerateForegroundInstanceMaskRequest()
    private let personInstanceRequest = VNGeneratePersonInstanceMaskRequest()
    private let personRequest = VNGeneratePersonSegmentationRequest()
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let humanRectangleRequest = VNDetectHumanRectanglesRequest()
    private let handler: VNImageRequestHandler
    private let sourceImage: CGImage

    init(image: CGImage) {
        sourceImage = image
        handler = VNImageRequestHandler(cgImage: image, options: [:])
        personRequest.qualityLevel = .accurate
        humanRectangleRequest.upperBodyOnly = false
    }

    func cancel() {
        foregroundRequest.cancel()
        personInstanceRequest.cancel()
        personRequest.cancel()
        poseRequest.cancel()
        humanRectangleRequest.cancel()
    }

    func run() -> SubjectCutouts? {
        guard !Task.isCancelled else { return nil }

        let context = CIContext(options: [.cacheIntermediates: false])
        defer { context.clearCaches() }

        if let cutouts = foregroundCutouts(using: context) {
            return cutouts
        }
        guard !Task.isCancelled else { return nil }
        if let cutout = coreImagePersonCutout(using: context) {
            return cutout
        }
        guard !Task.isCancelled else { return nil }
        if let cutouts = personInstanceCutouts(using: context) {
            return cutouts
        }
        guard !Task.isCancelled else { return nil }
        if let cutout = personCutout(using: context) {
            return cutout
        }
        guard !Task.isCancelled else { return nil }
        if let cutout = poseCutout(using: context) {
            return cutout
        }
        guard !Task.isCancelled else { return nil }
        if let cutout = humanRectangleCutout(using: context) {
            return cutout
        }
        guard !Task.isCancelled else { return nil }
        return centeredPersonCutout(using: context)
    }

    /// General foreground-instance segmentation is best when it succeeds:
    /// it supports arbitrary objects and lets the player choose an instance.
    private func foregroundCutouts(using context: CIContext) -> SubjectCutouts? {
        do {
            try handler.perform([foregroundRequest])
        } catch {
            #if DEBUG
            print("[SubjectExtractor] Foreground instances failed; trying person segmentation: \(error)")
            #endif
            return nil
        }
        guard !Task.isCancelled else { return nil }
        guard let result = foregroundRequest.results?.first,
              !result.allInstances.isEmpty else {
            #if DEBUG
            print("[SubjectExtractor] No foreground instances; trying person segmentation")
            #endif
            return nil
        }

        return cutouts(from: result, using: context)
    }

    /// Core Image exposes person segmentation independently from Vision's
    /// request API. Some runtimes can execute this filter even when the newer
    /// foreground-instance request cannot create its inference context.
    private func coreImagePersonCutout(using context: CIContext) -> SubjectCutouts? {
        let source = CIImage(cgImage: sourceImage)
        guard let filter = CIFilter(name: "CIPersonSegmentation") else { return nil }
        filter.setValue(source, forKey: kCIInputImageKey)
        // 0 = accurate, 1 = balanced, 2 = fast.
        filter.setValue(0, forKey: "inputQualityLevel")
        guard let rawMask = filter.outputImage,
              rawMask.extent.width > 0,
              rawMask.extent.height > 0 else { return nil }

        let mask = rawMask.transformed(by: CGAffineTransform(
            scaleX: source.extent.width / rawMask.extent.width,
            y: source.extent.height / rawMask.extent.height
        )).cropped(to: source.extent)
        guard maskContainsSubject(mask, in: source.extent, using: context) else { return nil }

        let clear = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        ).cropped(to: source.extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else { return nil }
        blend.setValue(source, forKey: kCIInputImageKey)
        blend.setValue(clear, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let output = blend.outputImage?.cropped(to: source.extent),
              let combined = renderCutout(output, using: context) else { return nil }
        return SubjectCutouts(combined: combined, instances: [])
    }

    /// Rendering a 1×1 area average forces lazy Core Image evaluation and
    /// cheaply rejects missing-model output (all black) and all-frame masks.
    private func maskContainsSubject(
        _ mask: CIImage,
        in extent: CGRect,
        using context: CIContext
    ) -> Bool {
        let average = mask.applyingFilter(
            "CIAreaAverage",
            parameters: [kCIInputExtentKey: CIVector(cgRect: extent)]
        )
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            average,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return pixel[0] >= 2 && pixel[0] <= 245
    }

    /// Person-instance masks use a model specialized for people and can
    /// succeed when the general foreground model cannot choose a subject.
    private func personInstanceCutouts(using context: CIContext) -> SubjectCutouts? {
        do {
            try handler.perform([personInstanceRequest])
        } catch {
            #if DEBUG
            print("[SubjectExtractor] Person instances failed; trying semantic segmentation: \(error)")
            #endif
            return nil
        }
        guard !Task.isCancelled else { return nil }
        guard let result = personInstanceRequest.results?.first,
              !result.allInstances.isEmpty else {
            return nil
        }

        return cutouts(from: result, using: context)
    }

    private func cutouts(
        from result: VNInstanceMaskObservation,
        using context: CIContext
    ) -> SubjectCutouts? {

        func cutout(_ instances: IndexSet) -> CGImage? {
            autoreleasepool {
                guard !Task.isCancelled else { return nil }
                guard let buffer = try? result.generateMaskedImage(
                    ofInstances: instances,
                    from: handler,
                    croppedToInstancesExtent: true
                ) else { return nil }

                let image = CIImage(cvPixelBuffer: buffer)
                return renderCutout(image, using: context)
            }
        }

        guard let combined = cutout(result.allInstances) else { return nil }

        var instances: [CGImage] = []
        if result.allInstances.count > 1 {
            instances.reserveCapacity(min(
                result.allInstances.count,
                SubjectExtractor.maximumRetainedInstances
            ))
            for index in result.allInstances.prefix(SubjectExtractor.maximumRetainedInstances) {
                guard !Task.isCancelled else { return nil }
                if let single = cutout(IndexSet(integer: index)) {
                    instances.append(single)
                }
            }
        }
        guard !Task.isCancelled else { return nil }
        return SubjectCutouts(combined: combined, instances: instances)
    }

    /// Specialized fallback for photographs of people. It fixes cases where
    /// the general instance request returns nothing and the luminance fallback
    /// would erase light clothing against a light background.
    private func personCutout(using context: CIContext) -> SubjectCutouts? {
        do {
            try handler.perform([personRequest])
        } catch {
            #if DEBUG
            print("[SubjectExtractor] Person segmentation failed: \(error)")
            #endif
            return nil
        }
        guard !Task.isCancelled,
              let buffer = personRequest.results?.first?.pixelBuffer else { return nil }

        return autoreleasepool {
            let source = CIImage(cgImage: sourceImage)
            let rawMask = CIImage(cvPixelBuffer: buffer)
            guard rawMask.extent.width > 0, rawMask.extent.height > 0 else { return nil }

            let mask = rawMask.transformed(by: CGAffineTransform(
                scaleX: source.extent.width / rawMask.extent.width,
                y: source.extent.height / rawMask.extent.height
            ))
            let clear = CIImage(
                color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            ).cropped(to: source.extent)

            guard let blend = CIFilter(name: "CIBlendWithMask") else { return nil }
            blend.setValue(source, forKey: kCIInputImageKey)
            blend.setValue(clear, forKey: kCIInputBackgroundImageKey)
            blend.setValue(mask, forKey: kCIInputMaskImageKey)
            guard let output = blend.outputImage?.cropped(to: source.extent),
                  let combined = renderCutout(output, using: context) else { return nil }
            return SubjectCutouts(combined: combined, instances: [])
        }
    }

    /// Last-resort fallback for runtimes where semantic person segmentation
    /// is unavailable (notably some Simulator images). A body-pose request is
    /// much more widely supported. Thick, rounded bones plus a torso and head
    /// create a complete approximate silhouette instead of erasing light
    /// clothing with a luminance threshold.
    private func poseCutout(using context: CIContext) -> SubjectCutouts? {
        do {
            try handler.perform([poseRequest])
        } catch {
            #if DEBUG
            print("[SubjectExtractor] Body pose fallback failed: \(error)")
            #endif
            return nil
        }
        guard !Task.isCancelled,
              let observation = poseRequest.results?.max(by: { $0.confidence < $1.confidence })
        else { return nil }

        typealias Joint = VNHumanBodyPoseObservation.JointName
        func point(_ joint: Joint) -> CGPoint? {
            guard let recognized = try? observation.recognizedPoint(joint),
                  recognized.confidence >= 0.2 else { return nil }
            return CGPoint(
                x: recognized.location.x * CGFloat(sourceImage.width),
                y: recognized.location.y * CGFloat(sourceImage.height)
            )
        }

        let joints: [Joint] = [
            .nose, .leftEar, .rightEar, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow, .leftWrist, .rightWrist,
            .root, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
        ]
        let recognized = Dictionary(uniqueKeysWithValues: joints.compactMap { joint in
            point(joint).map { (joint, $0) }
        })
        guard recognized.count >= 6 else { return nil }

        let ys = recognized.values.map(\.y)
        let bodyHeight = max(1, (ys.max() ?? 0) - (ys.min() ?? 0))
        let shoulderWidth: CGFloat = {
            if let left = recognized[.leftShoulder], let right = recognized[.rightShoulder] {
                return hypot(left.x - right.x, left.y - right.y)
            }
            return bodyHeight * 0.22
        }()
        guard bodyHeight >= CGFloat(sourceImage.height) * 0.12,
              shoulderWidth > 1 else { return nil }

        let width = sourceImage.width
        let height = sourceImage.height
        guard let maskContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        maskContext.setAllowsAntialiasing(true)
        maskContext.setShouldAntialias(true)
        maskContext.setStrokeColor(gray: 1, alpha: 1)
        maskContext.setFillColor(gray: 1, alpha: 1)
        maskContext.setLineCap(.round)
        maskContext.setLineJoin(.round)

        func stroke(_ a: Joint, _ b: Joint, width: CGFloat) {
            guard let start = recognized[a], let end = recognized[b] else { return }
            maskContext.setLineWidth(width)
            maskContext.beginPath()
            maskContext.move(to: start)
            maskContext.addLine(to: end)
            maskContext.strokePath()
        }

        let torsoWidth = max(shoulderWidth * 0.82, bodyHeight * 0.13)
        let armWidth = max(shoulderWidth * 0.34, bodyHeight * 0.045)
        let legWidth = max(shoulderWidth * 0.43, bodyHeight * 0.055)

        // Torso: a broad central capsule plus shoulder/hip bridges avoids the
        // hollow middle produced by drawing only the skeleton's outer edges.
        stroke(.neck, .root, width: torsoWidth)
        stroke(.leftShoulder, .rightShoulder, width: torsoWidth * 0.55)
        stroke(.leftHip, .rightHip, width: torsoWidth * 0.58)
        stroke(.leftShoulder, .leftHip, width: torsoWidth * 0.55)
        stroke(.rightShoulder, .rightHip, width: torsoWidth * 0.55)

        stroke(.leftShoulder, .leftElbow, width: armWidth)
        stroke(.leftElbow, .leftWrist, width: armWidth * 0.9)
        stroke(.rightShoulder, .rightElbow, width: armWidth)
        stroke(.rightElbow, .rightWrist, width: armWidth * 0.9)

        stroke(.leftHip, .leftKnee, width: legWidth)
        stroke(.leftKnee, .leftAnkle, width: legWidth * 0.82)
        stroke(.rightHip, .rightKnee, width: legWidth)
        stroke(.rightKnee, .rightAnkle, width: legWidth * 0.82)

        if let nose = recognized[.nose] ?? recognized[.neck] {
            var radius = max(shoulderWidth * 0.24, bodyHeight * 0.06)
            if let leftEar = recognized[.leftEar], let rightEar = recognized[.rightEar] {
                radius = max(radius, hypot(leftEar.x - rightEar.x, leftEar.y - rightEar.y) * 0.62)
            }
            maskContext.fillEllipse(in: CGRect(
                x: nose.x - radius,
                y: nose.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }

        guard let maskImage = maskContext.makeImage() else { return nil }
        let source = CIImage(cgImage: sourceImage)
        let mask = CIImage(cgImage: maskImage)
        let clear = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        ).cropped(to: source.extent)

        guard let blend = CIFilter(name: "CIBlendWithMask") else { return nil }
        blend.setValue(source, forKey: kCIInputImageKey)
        blend.setValue(clear, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let output = blend.outputImage?.cropped(to: source.extent),
              let combined = renderCutout(output, using: context) else { return nil }
        return SubjectCutouts(combined: combined, instances: [])
    }

    /// Final deterministic fallback. Older Simulator runtimes may omit every
    /// semantic/pose model but still support the classic human rectangle
    /// detector. The detected bounds seed a conservative full-body shape so
    /// a pale uniform is never reduced to disconnected luminance fragments.
    private func humanRectangleCutout(using context: CIContext) -> SubjectCutouts? {
        do {
            try handler.perform([humanRectangleRequest])
        } catch {
            #if DEBUG
            print("[SubjectExtractor] Human rectangle fallback failed: \(error)")
            #endif
            return nil
        }
        guard !Task.isCancelled,
              let observation = humanRectangleRequest.results?.max(by: {
                  $0.boundingBox.width * $0.boundingBox.height <
                      $1.boundingBox.width * $1.boundingBox.height
              }),
              observation.confidence >= 0.45 else { return nil }

        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: sourceImage.width,
            height: sourceImage.height
        )
        var body = CGRect(
            x: observation.boundingBox.minX * imageBounds.width,
            y: observation.boundingBox.minY * imageBounds.height,
            width: observation.boundingBox.width * imageBounds.width,
            height: observation.boundingBox.height * imageBounds.height
        )
        body = body.insetBy(dx: -body.width * 0.04, dy: -body.height * 0.025)
            .intersection(imageBounds)
        guard body.width >= imageBounds.width * 0.08,
              body.height >= imageBounds.height * 0.18 else { return nil }

        guard let maskContext = CGContext(
            data: nil,
            width: sourceImage.width,
            height: sourceImage.height,
            bitsPerComponent: 8,
            bytesPerRow: sourceImage.width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        maskContext.setAllowsAntialiasing(true)
        maskContext.setShouldAntialias(true)
        maskContext.setFillColor(gray: 1, alpha: 1)
        maskContext.setStrokeColor(gray: 1, alpha: 1)
        maskContext.setLineCap(.round)
        maskContext.setLineJoin(.round)

        func location(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: body.minX + body.width * x, y: body.minY + body.height * y)
        }
        func stroke(_ start: CGPoint, _ end: CGPoint, width: CGFloat) {
            maskContext.setLineWidth(width)
            maskContext.beginPath()
            maskContext.move(to: start)
            maskContext.addLine(to: end)
            maskContext.strokePath()
        }

        // Head and torso.
        maskContext.fillEllipse(in: CGRect(
            x: body.minX + body.width * 0.37,
            y: body.minY + body.height * 0.79,
            width: body.width * 0.26,
            height: body.height * 0.16
        ))
        stroke(location(0.5, 0.73), location(0.5, 0.45), width: body.width * 0.48)
        stroke(location(0.30, 0.70), location(0.70, 0.70), width: body.width * 0.20)

        // Rounded arms. Their slightly open stance retains equipment close to
        // the hands without turning the whole detected rectangle opaque.
        let armWidth = max(3, body.width * 0.13)
        stroke(location(0.31, 0.69), location(0.18, 0.56), width: armWidth)
        stroke(location(0.18, 0.56), location(0.08, 0.50), width: armWidth * 0.86)
        stroke(location(0.69, 0.69), location(0.82, 0.56), width: armWidth)
        stroke(location(0.82, 0.56), location(0.92, 0.50), width: armWidth * 0.86)

        // Two separated legs keep the result readable as a person instead of
        // a solid rectangle, while the broad upper strokes preserve trousers.
        let legWidth = max(4, body.width * 0.17)
        stroke(location(0.41, 0.44), location(0.33, 0.23), width: legWidth)
        stroke(location(0.33, 0.23), location(0.22, 0.05), width: legWidth * 0.82)
        stroke(location(0.59, 0.44), location(0.67, 0.23), width: legWidth)
        stroke(location(0.67, 0.23), location(0.78, 0.05), width: legWidth * 0.82)

        guard let maskImage = maskContext.makeImage() else { return nil }
        let source = CIImage(cgImage: sourceImage)
        let mask = CIImage(cgImage: maskImage)
        let clear = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        ).cropped(to: source.extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else { return nil }
        blend.setValue(source, forKey: kCIInputImageKey)
        blend.setValue(clear, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let output = blend.outputImage?.cropped(to: body),
              let combined = renderCutout(output, using: context) else { return nil }
        return SubjectCutouts(combined: combined, instances: [])
    }

    /// Explicitly approximate fallback for centered portrait photos. This is
    /// only reached after every system subject/person detector has failed.
    /// It produces a complete, switchable person-shaped mask instead of the
    /// disconnected patches generated by luminance on pale clothing.
    private func centeredPersonCutout(using context: CIContext) -> SubjectCutouts? {
        let sourceWidth = CGFloat(sourceImage.width)
        let sourceHeight = CGFloat(sourceImage.height)
        let aspect = sourceWidth / max(1, sourceHeight)
        guard (0.45...0.9).contains(aspect) else { return nil }

        guard let maskContext = CGContext(
            data: nil,
            width: sourceImage.width,
            height: sourceImage.height,
            bitsPerComponent: 8,
            bytesPerRow: sourceImage.width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        maskContext.setAllowsAntialiasing(true)
        maskContext.setShouldAntialias(true)
        maskContext.setFillColor(gray: 1, alpha: 1)
        maskContext.setStrokeColor(gray: 1, alpha: 1)
        maskContext.setLineCap(.round)
        maskContext.setLineJoin(.round)

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: sourceWidth * x, y: sourceHeight * y)
        }
        func stroke(_ points: [CGPoint], width: CGFloat) {
            guard let first = points.first else { return }
            maskContext.setLineWidth(width)
            maskContext.beginPath()
            maskContext.move(to: first)
            for point in points.dropFirst() { maskContext.addLine(to: point) }
            maskContext.strokePath()
        }

        // Coordinates use Core Graphics' bottom-left origin. The broad torso
        // and separated legs intentionally favor completeness over a false
        // claim of pixel-accurate automatic segmentation.
        maskContext.fillEllipse(in: CGRect(
            x: sourceWidth * 0.37,
            y: sourceHeight * 0.67,
            width: sourceWidth * 0.26,
            height: sourceHeight * 0.17
        ))
        stroke([point(0.5, 0.66), point(0.5, 0.41)], width: sourceWidth * 0.42)
        stroke([point(0.30, 0.62), point(0.70, 0.62)], width: sourceWidth * 0.18)

        let armWidth = max(3, sourceWidth * 0.13)
        stroke(
            [point(0.31, 0.61), point(0.18, 0.53), point(0.07, 0.50)],
            width: armWidth
        )
        stroke(
            [point(0.69, 0.61), point(0.78, 0.53), point(0.88, 0.50)],
            width: armWidth
        )

        let legWidth = max(4, sourceWidth * 0.17)
        stroke(
            [point(0.41, 0.42), point(0.34, 0.25), point(0.20, 0.06)],
            width: legWidth
        )
        stroke(
            [point(0.59, 0.42), point(0.66, 0.25), point(0.80, 0.06)],
            width: legWidth
        )

        guard let maskImage = maskContext.makeImage() else { return nil }
        let source = CIImage(cgImage: sourceImage)
        let mask = CIImage(cgImage: maskImage)
        let clear = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        ).cropped(to: source.extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else { return nil }
        blend.setValue(source, forKey: kCIInputImageKey)
        blend.setValue(clear, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let output = blend.outputImage?.cropped(to: source.extent),
              let combined = renderCutout(output, using: context) else { return nil }
        return SubjectCutouts(
            combined: combined,
            instances: [],
            mode: .centeredPerson
        )
    }

    private func renderCutout(_ image: CIImage, using context: CIContext) -> CGImage? {
        let longestSide = max(image.extent.width, image.extent.height)
        guard longestSide > 0 else { return nil }

        let scale = min(
            1,
            CGFloat(SubjectExtractor.maximumCutoutPixelSize) / longestSide
        )
        let rendered = scale < 1
            ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : image
        let bounds = rendered.extent.integral
        guard !bounds.isEmpty else { return nil }
        return context.createCGImage(rendered, from: bounds)
    }
}
