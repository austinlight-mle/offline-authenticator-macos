//
// EntryMetadataEntity.swift
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
import SwiftData

/// Persisted ``EntryCustomization`` for a single entry, keyed by the entry id.
///
/// The icon override is stored as JSON so the schema stays a flat set of columns and new
/// icon kinds can be added without a migration.
@Model
public final class EntryMetadataEntity: @unchecked Sendable {
    public private(set) var entryId: String = ""
    public private(set) var groupId: String?
    public private(set) var iconData: Data?
    public private(set) var modifiedTime: TimeInterval = Date().timeIntervalSince1970

    public init(entryId: String, customization: EntryCustomization) {
        self.entryId = entryId
        apply(customization)
    }

    public var customization: EntryCustomization {
        let icon: EntryIcon? = if let iconData {
            try? JSONDecoder().decode(EntryIcon.self, from: iconData)
        } else {
            nil
        }
        return EntryCustomization(groupId: groupId, icon: icon)
    }

    public func apply(_ customization: EntryCustomization) {
        groupId = customization.groupId
        iconData = customization.icon.flatMap { try? JSONEncoder().encode($0) }
        modifiedTime = Date.now.timeIntervalSince1970
    }

    public func clearGroup() {
        groupId = nil
        modifiedTime = Date.now.timeIntervalSince1970
    }
}
