//
//  PhotoImageDownsampler.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import ImageIO

nonisolated enum PhotoImageDownsampler {
    /// ImageBoardBuilder supports at most 128 cells on a grid axis. A 2,048 px
    /// cap preserves useful sampling detail while bounding the decoded bitmap.
    static let maximumPixelSize = 2_048

    /// Decodes an orientation-corrected processing image without first
    /// materializing the full-resolution photo in memory.
    static func downsample(_ data: Data) -> CGImage? {
        guard !data.isEmpty, !Task.isCancelled else { return nil }

        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        guard !Task.isCancelled else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ] as CFDictionary

        let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
        guard !Task.isCancelled else { return nil }
        return thumbnail
    }
}
