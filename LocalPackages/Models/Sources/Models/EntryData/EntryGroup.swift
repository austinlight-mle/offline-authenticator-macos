//
// EntryGroup.swift
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

/// A user defined group used to organise entries (e.g. "Work", "Personal").
///
/// Groups are a purely local concept: they are stored next to the encrypted entries on the device
/// and are never part of the encrypted entry payload, so they do not interfere with Proton sync,
/// backups or import/export.
public struct EntryGroup: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public var name: String
    /// SF Symbol used to represent the group in the UI.
    public var symbolName: String
    /// Optional hex color (without `#`) used to tint the group symbol.
    public var colorHex: String?
    public var order: Int
    public let creationDate: TimeInterval

    public static let defaultSymbolName = "folder"

    public init(id: String = UUID().uuidString,
                name: String,
                symbolName: String = EntryGroup.defaultSymbolName,
                colorHex: String? = nil,
                order: Int,
                creationDate: TimeInterval = Date.now.timeIntervalSince1970) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.order = order
        self.creationDate = creationDate
    }
}

public extension [EntryGroup] {
    /// Groups sorted by their manual order, then by name for stability.
    var sortedByOrder: [EntryGroup] {
        sorted {
            if $0.order != $1.order {
                return $0.order < $1.order
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
