//
// BrandIcon.swift
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

import Foundation

/// A brand icon bundled with the app (usable offline).
///
/// Vector icons are shipped in the presentation asset catalog under `image`; brands without a
/// vector asset are rendered as a `monogram` on a tile filled with the brand color.
public struct BrandIcon: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let title: String
    /// Brand color as hex without `#`.
    public let hex: String
    /// Alternative names used when matching issuers.
    public let aliases: [String]
    /// Name of the asset catalog image (template rendered unless `multicolor`).
    public let image: String?
    /// `true` when the image carries its own colors and must not be tinted.
    public let multicolor: Bool
    /// Short text rendered in place of a vector image.
    public let monogram: String?

    public init(id: String,
                title: String,
                hex: String,
                aliases: [String] = [],
                image: String? = nil,
                multicolor: Bool = false,
                monogram: String? = nil) {
        self.id = id
        self.title = title
        self.hex = hex
        self.aliases = aliases
        self.image = image
        self.multicolor = multicolor
        self.monogram = monogram
    }

    public var hasVectorImage: Bool {
        image != nil
    }

    /// Text shown when no vector image is available.
    public var displayMonogram: String {
        if let monogram, !monogram.isEmpty {
            return monogram
        }
        return String(title.prefix(1)).uppercased()
    }
}

public extension String {
    /// Normalised form used to compare issuer names, domains and brand aliases:
    /// lowercased with everything but ASCII letters and digits removed.
    var brandMatchingKey: String {
        lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII }
            .map { String($0) }
            .joined()
    }
}
