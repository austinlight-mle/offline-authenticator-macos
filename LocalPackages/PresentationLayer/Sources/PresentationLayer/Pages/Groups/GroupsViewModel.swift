//
// GroupsViewModel.swift
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

import DataLayer
import FactoryKit
import Foundation
import Macro
import Models

@Observable
final class GroupsViewModel {
    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    private(set) var isSaving = false

    var groups: [EntryGroup] {
        entryDataService.groups
    }

    /// Number of entries per group id (`nil` key = entries without group).
    var counts: [String?: Int] {
        var result = [String?: Int]()
        for entry in entryDataService.dataState.data ?? [] {
            result[entry.groupId, default: 0] += 1
        }
        return result
    }

    func count(for group: EntryGroup) -> Int {
        counts[group.id] ?? 0
    }

    func makeNewGroup() -> EntryGroup {
        EntryGroup(name: "",
                   symbolName: EntryGroup.defaultSymbolName,
                   colorHex: IconPalette.default,
                   order: (groups.map(\.order).max() ?? -1) + 1)
    }

    func save(_ group: EntryGroup) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await entryDataService.saveGroup(group)
            return true
        } catch {
            handle(error)
            return false
        }
    }

    func requestDelete(_ group: EntryGroup) {
        let count = count(for: group)
        let message: String = if count == 0 {
            #localized("The group \"%@\" will be removed.", bundle: .module, group.name)
        } else {
            #localized("The group \"%@\" will be removed. Its %lld entries are kept and simply become ungrouped.",
                       bundle: .module,
                       group.name,
                       count)
        }
        let action = ActionConfig(title: "Delete group",
                                  titleBundle: .module,
                                  role: .destructive,
                                  action: { [weak self] in
                                      guard let self else { return }
                                      Task { [weak self] in
                                          guard let self else { return }
                                          await delete(group)
                                      }
                                  })
        alertService.showAlert(.sheet(.init(title: "Delete group",
                                            titleBundle: .module,
                                            message: .verbatim(message),
                                            actions: [action, .cancel])))
    }

    func delete(_ group: EntryGroup) async {
        do {
            try await entryDataService.deleteGroup(group.id)
        } catch {
            handle(error)
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = groups
        reordered.move(fromOffsets: source, toOffset: destination)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await entryDataService.reorderGroups(reordered)
            } catch {
                handle(error)
            }
        }
    }

    private func handle(_ error: any Error) {
        alertService.showError(error, mainDisplay: false, action: nil)
    }
}
