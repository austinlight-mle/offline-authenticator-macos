//
// EntryGroupEntity.swift
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

/// Persisted representation of an ``EntryGroup``. Stored in the local (non iCloud) store.
@Model
public final class EntryGroupEntity: @unchecked Sendable {
    public private(set) var id: String = UUID().uuidString
    public private(set) var name: String = ""
    public private(set) var symbolName: String = EntryGroup.defaultSymbolName
    public private(set) var colorHex: String?
    public private(set) var order: Int = 0
    public private(set) var creationDate: TimeInterval = Date().timeIntervalSince1970

    public init(group: EntryGroup) {
        id = group.id
        name = group.name
        symbolName = group.symbolName
        colorHex = group.colorHex
        order = group.order
        creationDate = group.creationDate
    }

    public var group: EntryGroup {
        EntryGroup(id: id,
                   name: name,
                   symbolName: symbolName,
                   colorHex: colorHex,
                   order: order,
                   creationDate: creationDate)
    }

    public func update(with group: EntryGroup) {
        name = group.name
        symbolName = group.symbolName
        colorHex = group.colorHex
        order = group.order
    }
}
