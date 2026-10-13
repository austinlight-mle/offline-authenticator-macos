//
// EntryUiModel.swift
// Altosec Authenticator - Created on 17/02/2025.
// Copyright (c) 2025 Proton Technologies AG
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
import SwiftUI
import UniformTypeIdentifiers

public struct EntryUiModel: Sendable, Identifiable, Equatable, Hashable, Codable {
    public var orderedEntry: OrderedEntry
    public let code: Code
    public let issuerInfo: AuthIssuerInfo?
    /// Local presentation metadata (group + icon override). `nil` when the entry has none.
    public var customization: EntryCustomization?

    public var id: String {
        orderedEntry.id
    }

    public init(orderedEntry: OrderedEntry,
                code: Code,
                issuerInfo: AuthIssuerInfo?,
                customization: EntryCustomization? = nil) {
        self.orderedEntry = orderedEntry
        self.code = code
        self.issuerInfo = issuerInfo
        self.customization = customization?.isEmpty == true ? nil : customization
    }

    public func copy(newEntry: Entry) -> Self {
        Self(orderedEntry: orderedEntry.updateEntry(newEntry),
             code: code,
             issuerInfo: issuerInfo,
             customization: customization)
    }

    public func updateRemoteInfos(_ remoteId: String) -> Self {
        Self(orderedEntry: orderedEntry.updateRemoteInfos(remoteId),
             code: code,
             issuerInfo: issuerInfo,
             customization: customization)
    }
}

public extension EntryUiModel {
    func updateCode(_ code: Code) -> EntryUiModel {
        EntryUiModel(orderedEntry: orderedEntry,
                     code: code,
                     issuerInfo: issuerInfo,
                     customization: customization)
    }

    func updateOrder(_ order: Int) -> EntryUiModel {
        EntryUiModel(orderedEntry: orderedEntry.updateOrder(order),
                     code: code,
                     issuerInfo: issuerInfo,
                     customization: customization)
    }

    func updateCustomization(_ customization: EntryCustomization?) -> EntryUiModel {
        EntryUiModel(orderedEntry: orderedEntry,
                     code: code,
                     issuerInfo: issuerInfo,
                     customization: customization)
    }

    /// The id of the group the entry belongs to, if any.
    var groupId: String? {
        customization?.groupId
    }

    /// The user chosen icon override, if any.
    var iconOverride: EntryIcon? {
        customization?.icon
    }
}

public extension [EntryUiModel] {
    /// Removes duplicate entries (same `id`), keeping only the one with the newest `modifiedTime`.
    func deduplicatedByNewestModifiedTime() -> [EntryUiModel] {
        var seen = [String: Int]()
        var result = [EntryUiModel]()
        for entry in self {
            if let existingIndex = seen[entry.id] {
                if entry.orderedEntry.modifiedTime > result[existingIndex].orderedEntry.modifiedTime {
                    result[existingIndex] = entry
                }
            } else {
                seen[entry.id] = result.count
                result.append(entry)
            }
        }
        return result
    }
}
