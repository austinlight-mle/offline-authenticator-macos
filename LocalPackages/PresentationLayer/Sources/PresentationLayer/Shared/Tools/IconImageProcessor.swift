//
// IconImageProcessor.swift
// Altosec Authenticator - Created on 12/10/2026.
// Copyright (c) 2026 Proton Technologies AG
//
// This file is part of Altosec Authenticator.
//
// Altosec Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Altosec Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Altosec Authenticator. If not, see https://www.gnu.org/licenses/.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IconImageProcessorError: Error {
    case unreadable
    case encodingFailed
}

/// Downscales a user provided picture to a small square PNG so it can be stored next to the entry.
enum IconImageProcessor {
    static let maxDimension: CGFloat = 128

    static func makeIconData(from url: URL) throws -> Data {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return try makeIconData(from: data)
    }

    static func makeIconData(from data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw IconImageProcessorError.unreadable
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw IconImageProcessorError.unreadable
        }
        let squared = cropToSquare(thumbnail)

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output,
                                                                 UTType.png.identifier as CFString,
                                                                 1,
                                                                 nil) else {
            throw IconImageProcessorError.encodingFailed
        }
        CGImageDestinationAddImage(destination, squared, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw IconImageProcessorError.encodingFailed
        }
        return output as Data
    }

    private static func cropToSquare(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        guard width != height else { return image }
        let side = min(width, height)
        let rect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)
        return image.cropping(to: rect) ?? image
    }
}
