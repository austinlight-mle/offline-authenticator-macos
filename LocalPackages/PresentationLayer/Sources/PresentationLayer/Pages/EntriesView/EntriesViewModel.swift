//
// EntriesViewModel.swift
// Altosec Authenticator - Created on 10/02/2025.
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
//

import Combine
import CommonUtilities
import DataLayer
import FactoryKit
import Foundation
import Macro
import Models

@Observable
final class EntriesViewModel {
    var animatingEntry: EntryAction?

    var reorderingEntries: [EntryUiModel]?

    private(set) var entries: [EntryUiModel] = []

    /// The entries the grid/list should render.
    ///
    /// Prefers the in-progress reorder snapshot (`reorderingEntries`), but only while it still
    /// represents the same set of entries as `entries`. Once the underlying set changes — e.g. a new
    /// entry is created after a drag was cancelled without landing on a drop destination, leaving a
    /// stale snapshot behind — the snapshot is ignored so the change is always reflected on screen.
    var displayedEntries: [EntryUiModel] {
        guard let reorderingEntries,
              reorderingEntries.hasSameMembers(as: entries) else {
            return entries
        }
        return reorderingEntries
    }

    var dataState: DataState<[EntryUiModel]> {
        entryDataService.dataState
    }

    var noEntries: Bool {
        dataState.data?.isEmpty == true
    }

    var focusSearchOnLaunch: Bool {
        settingsService.focusSearchOnLaunch
    }

    var isAuthenticated: Bool {
        userSessionManager.isAuthenticatedWithUserData.value
    }

    var sortOption: SortOption {
        settingsService.sortOption
    }

    /// User defined groups, in display order.
    var groups: [EntryGroup] {
        entryDataService.groups
    }

    /// Currently selected group filter. `nil` shows every entry.
    var selectedGroupId: String? {
        didSet {
            guard selectedGroupId != oldValue else { return }
            if let selectedGroupId {
                kSharedUserDefaults.set(selectedGroupId, forKey: Self.selectedGroupKey)
            } else {
                kSharedUserDefaults.removeObject(forKey: Self.selectedGroupKey)
            }
            updateEntries()
        }
    }

    var selectedGroup: EntryGroup? {
        guard let selectedGroupId else { return nil }
        return groups.first { $0.id == selectedGroupId }
    }

    var showGroupBar: Bool {
        !groups.isEmpty && !noEntries
    }

    /// Number of entries per group (`nil` key = all entries), ignoring the current search.
    var groupCounts: [String?: Int] {
        var counts = [String?: Int]()
        let all = entryDataService.dataState.data ?? []
        counts[String?.none] = all.count
        for entry in all {
            if let groupId = entry.groupId {
                counts[groupId, default: 0] += 1
            }
        }
        return counts
    }

    private static let selectedGroupKey = "SelectedGroupId"

    var query = "" {
        didSet {
            searchTextStream.send(query)
        }
    }

    @ObservationIgnored
    private var badgeTask: Task<Void, Never>?

    @ObservationIgnored
    private var searchResults: [EntryUiModel]?

    @ObservationIgnored
    private let searchTextStream: CurrentValueSubject<String, Never> = .init("")

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.copyTextToClipboard)
    private var copyTextToClipboard

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.userSessionManager)
    private(set) var userSessionManager

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.userDataRefresh)
    private var userDataRefresh

    // periphery:ignore
    @ObservationIgnored
    @Injected(\ServiceContainer.iosToWatchCommunicationManager)
    private var iosToWatchCommunicationManager

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logger

    #if os(iOS)
    @ObservationIgnored
    @LazyInjected(\ToolsContainer.hapticsManager)
    private var hapticsManager
    #endif

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private(set) var settingsService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.requestForReview)
    private var requestForReview

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.inAppMessagingService)
    var inAppService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.authenticateBiometrically)
    private var authenticateBiometrically

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.localDataManager)
    private var localDataManager

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.updatingSettings)
    private var updatingSettings

    @ObservationIgnored
    private var disableICloudTask: Task<Void, Never>?

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var loadLocalTask: Task<Void, Never>?
    @ObservationIgnored
    private var fullSyncTask: Task<Void, Never>?
    @ObservationIgnored
    private var searchTask: Task<Void, Never>?
    @ObservationIgnored
    private var moveItemTask: Task<Void, Never>?
    @ObservationIgnored
    private var lastForegroundReloadDate: Date?
    @ObservationIgnored
    private(set) var isCodeRefreshPaused = false
    private static let foregroundReloadThrottle: TimeInterval = 30

    private(set) var deleteTask: Task<Void, Never>?

    init() {
        selectedGroupId = kSharedUserDefaults.string(forKey: Self.selectedGroupKey)

        searchTextStream
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self else { return }
                executeSearch(query: query)
            }
            .store(in: &cancellables)

        userSessionManager.isAuthenticatedWithUserData
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] status in
                guard let self, status else { return }
                fullSync(refreshUserData: false)
            }
            .store(in: &cancellables)

        userSessionManager.sessionWasInvalidated
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] status in
                guard let self, status else { return }
                alertService.showAlert(.main(.init(title: "Sync between your devices is paused",
                                                   titleBundle: .module,
                                                   // swiftlint:disable:next line_length
                                                   message: .localized("Your session is expired or revoked, please log in to your Proton account again.",
                                                                       .module),
                                                   actions: [.ok])))
            }
            .store(in: &cancellables)
    }

    func moveItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        defer {
            if moveItemTask == nil {
                reorderingEntries = nil
            }
        }

        // Get the actual index values after removing
        guard let offset = source.first else {
            return
        }
        var targetIndex = destination

        // Adjust the destination if moving downward in the list
        if offset < destination {
            targetIndex -= 1
        }
        guard offset != targetIndex else {
            return
        }
        // The list may be filtered (search or group), so translate the displayed positions into
        // positions of the complete data set before persisting the new order.
        let (fullSource, fullTarget) = fullDataPositions(displayedSource: offset, displayedTarget: targetIndex)
        guard fullSource != fullTarget else {
            return
        }
        moveItemTask = Task { [weak self] in
            guard let self else { return }
            defer {
                moveItemTask = nil
                reorderingEntries = nil
            }
            do {
                try await entryDataService.reorderItem(from: fullSource, to: fullTarget)
                await requestForReview()
            } catch {
                handle(error)
            }
        }
    }

    func loadEntries() {
        guard loadLocalTask == nil else {
            return
        }
        loadLocalTask = Task { [weak self] in
            guard let self else { return }
            defer {
                loadLocalTask = nil
            }
            do {
                if Task.isCancelled {
                    return
                }
                try await entryDataService.loadEntries()
                if Task.isCancelled {
                    return
                }
            } catch {
                handle(error)
            }
        }
    }

    func checkWatchConnectivity() {
        iosToWatchCommunicationManager.checkIfActive()
    }

    func cleanSearch() {
        query = ""
    }

    func selectGroup(_ groupId: String?) {
        selectedGroupId = groupId
    }

    func moveToGroup(_ entry: EntryUiModel, groupId: String?) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await entryDataService.setGroup(groupId, for: [entry.id])
            } catch {
                handle(error)
            }
        }
    }
}

extension EntriesViewModel {
    func reloadData() {
        lastForegroundReloadDate = .now
        reorderingEntries = nil
        if isAuthenticated {
            fullSync()
        } else {
            loadEntries()
        }
    }

    func reloadDataOnForeground() {
        if let lastForegroundReloadDate,
           Date.now.timeIntervalSince(lastForegroundReloadDate) < Self.foregroundReloadThrottle,
           !entries.isEmpty {
            if isCodeRefreshPaused {
                toggleCodeRefresh(false)
            }
            return
        }
        reloadData()
    }

    func copyTokenToClipboard(entryAction: EntryAction) {
        guard entryAction != animatingEntry else {
            return
        }
        animatingEntry = entryAction
        // Always copy a code computed right now: the cell may hold a value from an earlier emission.
        let code = (try? entryDataService.currentCode(for: entryAction.entryUiModel.orderedEntry.entry))
            ?? entryAction.entryUiModel.code
        let codeValue = entryAction.isCurrentCodeCopyAction ? code.current : code.next
        assert(!codeValue.isEmpty, "Code should not be empty")
        copyTextToClipboard(codeValue)
        #if os(iOS)
        hapticsManager(.defaultImpact)
        #endif
        badgeTask?.cancel()
        badgeTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            animatingEntry = nil
            badgeTask = nil
        }
    }

    func toggleCodeRefresh(_ shouldPause: Bool) {
        isCodeRefreshPaused = shouldPause
        if shouldPause {
            entryDataService.stopTotpGenerator()
        } else {
            entryDataService.startTotpGenerator()
        }
    }

    func delete(_ entry: EntryUiModel) {
        let issuer = entry.orderedEntry.entry.issuer
        let action = ActionConfig(title: "Delete \"\(issuer)\"",
                                  titleBundle: .module,
                                  role: .destructive,
                                  action: { [weak self] in
                                      guard let self else {
                                          return
                                      }
                                      confirmDelete(entry)
                                  })
        alertService.showAlert(.main(.init(title: "Delete entry",
                                           titleBundle: .module,
                                           // swiftlint:disable:next line_length
                                           message: .localized("You are about to delete \"\(issuer)\", this action is irreversible.",
                                                               .module),
                                           actions: [action])))
    }

    func showICloudDisablePromptIfNeeded() {
        guard settingsService.iCloudSync,
              !settingsService.iCloudDisablePromptDismissed,
              settingsService.onboarded else {
            return
        }

        settingsService.setICloudDisablePromptDismissed(true)

        let disableAction = ActionConfig(title: "Disable iCloud sync",
                                         titleBundle: .module,
                                         action: { [weak self] in
                                             guard let self else { return }
                                             disableICloudSyncFromPrompt()
                                         })

        alertService.showAlert(.main(.init(title: "Switch off iCloud sync",
                                           titleBundle: .module,
                                           // swiftlint:disable:next line_length
                                           message: .localized("Due to reliability issues with Apple's iCloud, we recommend using Proton sync and/or backup system instead.",
                                                               .module),
                                           actions: [disableAction, .ok])))
    }

    func disableICloudSyncFromPrompt() {
        guard disableICloudTask == nil else { return }
        disableICloudTask = Task { [weak self] in
            guard let self else { return }
            defer {
                disableICloudTask = nil
                updatingSettings.send(false)
            }
            updatingSettings.send(true)
            let reason = #localized("Please authenticate", bundle: .module)
            do {
                if try await authenticateBiometrically(policy: AppConstants.laEnablingPolicy,
                                                       reason: reason) {
                    settingsService.toggleICloudSync(false)
                    await localDataManager.refreshLocalStorage()
                }
            } catch {
                handle(error)
            }
        }
    }

    func refreshSearchResults() {
        executeSearch(query: query)
    }

    func refreshEntries() {
        updateEntries()
    }

    func refreshCodesNow() {
        entryDataService.refreshCodesNow()
    }
}

private extension EntriesViewModel {
    func fullSync(refreshUserData: Bool = true) {
        guard fullSyncTask == nil else {
            return
        }
        fullSyncTask = Task { [weak self] in
            guard let self else { return }
            defer {
                fullSyncTask = nil
            }
            do {
                if let loadTask = loadLocalTask {
                    await loadTask.value
                }
                if Task.isCancelled {
                    return
                }
                if refreshUserData {
                    do {
                        try await userDataRefresh()
                    } catch {
                        logger.log(.error,
                                   category: .network,
                                   "User data refresh failed: \(error.localizedDescription)")
                    }
                }
                if Task.isCancelled {
                    return
                }
                try await entryDataService.fullRefresh()
                if Task.isCancelled {
                    return
                }
            } catch {
                handle(error)
            }
        }
    }

    func handle(_ error: any Error, function: String = #function, line: Int = #line) {
        guard !alertService.isShowingAlert else {
            return
        }
        logger.log(.error, category: .ui, error.localizedDescription, function: function, line: line)
        alertService.showError(error, mainDisplay: true, action: nil)
    }

    func executeSearch(query: String) {
        searchTask?.cancel()
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanQuery.isEmpty {
            searchResults = nil
            updateEntries()
            return
        }

        searchTask = Task { [weak self] in
            guard let self, let data = entryDataService.dataState.data else {
                return
            }
            if Task.isCancelled {
                return
            }
            searchResults = await data.filtered(matching: cleanQuery)
            updateEntries()
        }
    }

    func fullDataPositions(displayedSource: Int, displayedTarget: Int) -> (source: Int, target: Int) {
        guard let all = entryDataService.dataState.data,
              all.count != entries.count,
              let movedId = entries[safeIndex: displayedSource]?.id,
              let targetId = entries[safeIndex: displayedTarget]?.id,
              let fullSource = all.firstIndex(where: { $0.id == movedId }),
              let fullTarget = all.firstIndex(where: { $0.id == targetId }) else {
            return (displayedSource, displayedTarget)
        }
        return (fullSource, fullTarget)
    }

    func updateEntries() {
        if let selectedGroupId, !groups.contains(where: { $0.id == selectedGroupId }) {
            // The selected group was deleted: fall back to showing everything.
            self.selectedGroupId = nil
            return
        }

        let base: [EntryUiModel] = if let results = searchResults {
            results
        } else {
            entryDataService.dataState.data ?? []
        }
        let filtered = if let selectedGroupId {
            base.filter { $0.groupId == selectedGroupId }
        } else {
            base
        }
        entries = filtered.sorted(by: settingsService.sortOption)

        if let reorderingEntries, !reorderingEntries.hasSameMembers(as: entries) {
            self.reorderingEntries = nil
        }
    }

    func confirmDelete(_ entry: EntryUiModel) {
        guard deleteTask == nil else { return }
        deleteTask = Task { [weak self] in
            guard let self else { return }
            defer { deleteTask = nil }
            do {
                try await entryDataService.delete(entry)
            } catch {
                handle(error)
            }
        }
    }
}

private extension [EntryUiModel] {
    func sorted(by option: SortOption) -> Self {
        switch option {
        case .manual:
            self

        case .issuerAsc:
            sorted(by: {
                $0.orderedEntry.entry.issuer.lowercased() < $1.orderedEntry.entry.issuer.lowercased()
            })

        case .issuerDesc:
            sorted(by: {
                $0.orderedEntry.entry.issuer.lowercased() > $1.orderedEntry.entry.issuer.lowercased()
            })

        case .creationDateAsc:
            sorted(by: { $0.orderedEntry.creationDate < $1.orderedEntry.creationDate })

        case .creationDateDesc:
            sorted(by: { $0.orderedEntry.creationDate > $1.orderedEntry.creationDate })

        case .modificationDateAsc:
            sorted(by: { $0.orderedEntry.modifiedTime < $1.orderedEntry.modifiedTime })

        case .modificationDateDesc:
            sorted(by: { $0.orderedEntry.modifiedTime > $1.orderedEntry.modifiedTime })
        }
    }
}

extension [EntryUiModel] {
    /// Returns the entries whose name or issuer contains `query`.
    ///
    /// The query is normalised (trimmed + lowercased) before matching, so a raw, cased query can
    /// never silently return zero results — the search regression this guards against.
    @concurrent
    func filtered(matching query: String) async -> [EntryUiModel] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return self }
        return filter {
            $0.orderedEntry.entry.name.lowercased().contains(normalizedQuery) ||
                $0.orderedEntry.entry.issuer.lowercased().contains(normalizedQuery)
        }
    }
}
