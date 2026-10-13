//
// EntryCustomization.swift
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

/// The icon displayed for an entry when the user overrides the automatic issuer lookup.
public enum EntryIcon: Sendable, Hashable, Codable {
    /// One of the bundled brand icons, identified by its catalog id (e.g. `google`).
    case brand(String)
    /// An SF Symbol, optionally tinted with a hex color (without `#`).
    case symbol(name: String, colorHex: String?)
    /// A user provided bitmap (PNG data, already downscaled).
    case image(Data)
}

/// Local, per entry presentation metadata (group membership and icon override).
///
/// Like ``EntryGroup`` this is stored outside of the encrypted entry payload, so the
/// Proton sync protocol, backups and import/export formats are unchanged.
public struct EntryCustomization: Sendable, Hashable, Codable {
    public var groupId: String?
    /// `nil` means "automatic": use the bundled brand icon / issuer favicon / first letter.
    public var icon: EntryIcon?

    public init(groupId: String? = nil, icon: EntryIcon? = nil) {
        self.groupId = groupId
        self.icon = icon
    }

    public static let none = EntryCustomization()

    public var isEmpty: Bool {
        groupId == nil && icon == nil
    }
}
