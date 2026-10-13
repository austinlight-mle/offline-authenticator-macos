//
// Color+Hex.swift
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

import SwiftUI

extension Color {
    /// Creates a color from a hex string such as `6D4AFF` or `#6D4AFF`. Returns `nil` when invalid.
    init?(hex: String) {
        guard let rgb = Color.rgbComponents(hex: hex) else { return nil }
        self.init(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2, opacity: 1)
    }

    /// Relative luminance (0 = black, 1 = white) of a hex color, used to pick a contrasting tile.
    static func luminance(hex: String) -> Double? {
        guard let rgb = rgbComponents(hex: hex) else { return nil }
        func linear(_ channel: Double) -> Double {
            channel <= 0.039_28 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
    }

    private static func rgbComponents(hex: String) -> (Double, Double, Double)? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return (red, green, blue)
    }
}

/// Curated palette offered when tinting groups and symbol icons.
enum IconPalette {
    static let hexValues: [String] = [
        "6D4AFF", "B578D9", "F9AF94", "FFD580", "1EA885", "12B5D5", "2C89DB", "F7578C",
        "E5484D", "F97316", "EAB308", "22C55E", "0EA5E9", "8B5CF6", "64748B", "1C1B1E"
    ]

    static let `default` = "6D4AFF"
}
