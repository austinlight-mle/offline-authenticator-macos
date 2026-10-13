//
// EntryIconPickerSheet.swift
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

import FactoryKit
import Models
import SwiftUI

/// Icon picker presented from an entry's context menu: saves the choice straight away.
struct EntryIconPickerSheet: View {
    let entry: EntryUiModel

    private let entryDataService = ServiceContainer.shared.entryDataService()
    private let alertService = ServiceContainer.shared.alertService()

    var body: some View {
        IconPickerView(current: entry.iconOverride,
                       issuerInfo: entry.issuerInfo,
                       letter: entry.orderedEntry.entry.capitalLetter) { icon in
            var customization = entry.customization ?? .none
            customization.icon = icon
            Task {
                do {
                    try await entryDataService.setCustomization(customization, for: entry.id)
                } catch {
                    alertService.showError(error)
                }
            }
        }
    }
}
