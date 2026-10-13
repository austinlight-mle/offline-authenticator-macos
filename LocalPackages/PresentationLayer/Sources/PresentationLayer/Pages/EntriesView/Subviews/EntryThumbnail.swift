//
// EntryThumbnail.swift
// Altosec Authenticator - Created on 27/06/2025.
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

import DataLayer
import Models
import SwiftUI

/// Icon shown at the leading edge of an entry cell. Resolves the user override, the bundled brand
/// icon, the remote favicon and the first letter fallback in that order.
struct EntryThumbnail: View, @preconcurrency Equatable {
    let entry: EntryUiModel
    var size: CGFloat = 34

    private let catalog = ToolsContainer.shared.brandIconCatalog()

    init(entry: EntryUiModel, size: CGFloat = 34) {
        self.entry = entry
        self.size = size
    }

    var body: some View {
        EntryIconView(icon: resolvedIcon, size: size)
            .equatable()
    }

    private var resolvedIcon: ResolvedEntryIcon {
        ResolvedEntryIcon.resolve(override: entry.iconOverride,
                                  issuerInfo: entry.issuerInfo,
                                  letter: entry.orderedEntry.entry.capitalLetter,
                                  catalog: catalog)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry.iconOverride == rhs.entry.iconOverride &&
            lhs.entry.issuerInfo == rhs.entry.issuerInfo &&
            lhs.entry.orderedEntry.entry.capitalLetter == rhs.entry.orderedEntry.entry.capitalLetter &&
            lhs.size == rhs.size
    }
}
