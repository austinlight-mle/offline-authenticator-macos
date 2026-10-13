//
// EntryCustomizationRepository.swift
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
import Models
import SimplyPersist
import SwiftData

/// Everything needed to decorate the entry list: the user's groups and the per entry
/// customizations keyed by entry id.
public struct EntryCustomizationSnapshot: Sendable, Equatable {
    public var groups: [EntryGroup]
    public var customizations: [String: EntryCustomization]

    public init(groups: [EntryGroup] = [], customizations: [String: EntryCustomization] = [:]) {
        self.groups = groups
        self.customizations = customizations
    }

    public static let empty = EntryCustomizationSnapshot()
}

/// Local persistence of groups and entry customizations (never synced, never exported).
public protocol EntryCustomizationRepositoryProtocol: Sendable {
    func fetchAll() async throws -> EntryCustomizationSnapshot

    /// Inserts or updates a group.
    func saveGroup(_ group: EntryGroup) async throws
    /// Inserts or updates several groups at once (used for reordering).
    func saveGroups(_ groups: [EntryGroup]) async throws
    /// Deletes a group and detaches every entry that belonged to it.
    func deleteGroup(id: String) async throws

    /// Stores the customization of an entry. An empty customization removes the record.
    func setCustomization(_ customization: EntryCustomization, for entryId: String) async throws
    func removeCustomizations(for entryIds: [String]) async throws
    func removeAllCustomizations() async throws
}

public actor EntryCustomizationRepository: EntryCustomizationRepositoryProtocol {
    private let localDataManager: any LocalDataManagerProtocol
    private let logger: any LoggerProtocol

    public init(localDataManager: any LocalDataManagerProtocol, logger: any LoggerProtocol) {
        self.localDataManager = localDataManager
        self.logger = logger
    }

    public func fetchAll() async throws -> EntryCustomizationSnapshot {
        let storage = await localDataManager.persistentStorage
        defer { withExtendedLifetime(storage) {} }
        do {
            let groupEntities: [EntryGroupEntity] = try await storage.fetchAll()
            let metadataEntities: [EntryMetadataEntity] = try await storage.fetchAll()

            var seenGroupIds = Set<String>()
            let groups = groupEntities
                .map(\.group)
                .filter { seenGroupIds.insert($0.id).inserted }
                .sortedByOrder

            var customizations = [String: EntryCustomization]()
            for entity in metadataEntities.sorted(by: { $0.modifiedTime < $1.modifiedTime }) {
                let customization = entity.customization
                guard !customization.isEmpty else { continue }
                customizations[entity.entryId] = customization
            }
            log(.debug, "Loaded \(groups.count) groups and \(customizations.count) entry customizations")
            return EntryCustomizationSnapshot(groups: groups, customizations: customizations)
        } catch {
            log(.error, "Failed to load groups and customizations: \(error.localizedDescription)")
            throw error
        }
    }

    public func saveGroup(_ group: EntryGroup) async throws {
        try await saveGroups([group])
    }

    public func saveGroups(_ groups: [EntryGroup]) async throws {
        guard !groups.isEmpty else { return }
        let storage = await localDataManager.persistentStorage
        defer { withExtendedLifetime(storage) {} }
        do {
            let ids = groups.map(\.id)
            let existing: [EntryGroupEntity] = try await storage
                .fetch(predicate: #Predicate<EntryGroupEntity> { ids.contains($0.id) })
            let existingIds = Set(existing.map(\.id))

            if !existing.isEmpty {
                try await storage.performTransaction {
                    for entity in existing {
                        guard let group = groups.first(where: { $0.id == entity.id }) else { continue }
                        entity.update(with: group)
                    }
                }
            }

            let newEntities = groups
                .filter { !existingIds.contains($0.id) }
                .map { EntryGroupEntity(group: $0) }
            if !newEntities.isEmpty {
                try await storage.batchSave(content: newEntities)
            }
            log(.info, "Saved \(groups.count) groups (\(newEntities.count) new)")
        } catch {
            log(.error, "Failed to save groups: \(error.localizedDescription)")
            throw error
        }
    }

    public func deleteGroup(id: String) async throws {
        let storage = await localDataManager.persistentStorage
        defer { withExtendedLifetime(storage) {} }
        do {
            let orphans: [EntryMetadataEntity] = try await storage
                .fetch(predicate: #Predicate<EntryMetadataEntity> { $0.groupId == id })
            if !orphans.isEmpty {
                try await storage.performTransaction {
                    for entity in orphans {
                        entity.clearGroup()
                    }
                }
            }
            try await storage.delete(EntryGroupEntity.self,
                                     predicate: #Predicate<EntryGroupEntity> { $0.id == id })
            try await pruneEmptyMetadata(storage: storage)
            log(.info, "Deleted group \(id), detached \(orphans.count) entries")
        } catch {
            log(.error, "Failed to delete group \(id): \(error.localizedDescription)")
            throw error
        }
    }

    public func setCustomization(_ customization: EntryCustomization, for entryId: String) async throws {
        let storage = await localDataManager.persistentStorage
        defer { withExtendedLifetime(storage) {} }
        do {
            let existing: [EntryMetadataEntity] = try await storage
                .fetch(predicate: #Predicate<EntryMetadataEntity> { $0.entryId == entryId })

            if customization.isEmpty {
                if !existing.isEmpty {
                    try await storage.delete(datas: existing)
                }
                return
            }

            if let first = existing.first {
                let duplicates = Array(existing.dropFirst())
                try await storage.performTransaction {
                    first.apply(customization)
                }
                if !duplicates.isEmpty {
                    try await storage.delete(datas: duplicates)
                }
            } else {
                try await storage.save(data: EntryMetadataEntity(entryId: entryId, customization: customization))
            }
            log(.debug, "Saved customization for entry \(entryId)")
        } catch {
            log(.error, "Failed to save customization for entry \(entryId): \(error.localizedDescription)")
            throw error
        }
    }

    public func removeCustomizations(for entryIds: [String]) async throws {
        guard !entryIds.isEmpty else { return }
        let storage = await localDataManager.persistentStorage
        defer { withExtendedLifetime(storage) {} }
        try await storage.delete(EntryMetadataEntity.self,
                                 predicate: #Predicate<EntryMetadataEntity> { entryIds.contains($0.entryId) })
    }

    public func removeAllCustomizations() async throws {
        let storage = await localDataManager.persistentStorage
        defer { withExtendedLifetime(storage) {} }
        try await storage.deleteAll(dataTypes: [EntryMetadataEntity.self, EntryGroupEntity.self])
    }

    private func pruneEmptyMetadata(storage: any PersistenceServicing) async throws {
        let all: [EntryMetadataEntity] = try await storage.fetchAll()
        let empty = all.filter { $0.customization.isEmpty }
        if !empty.isEmpty {
            try await storage.delete(datas: empty)
        }
    }

    private func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}

/// Non persistent implementation used by tests and previews.
public actor InMemoryEntryCustomizationRepository: EntryCustomizationRepositoryProtocol {
    private var groups: [String: EntryGroup] = [:]
    private var customizations: [String: EntryCustomization] = [:]

    public init(groups: [EntryGroup] = [], customizations: [String: EntryCustomization] = [:]) {
        self.groups = Dictionary(groups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.customizations = customizations
    }

    public func fetchAll() async throws -> EntryCustomizationSnapshot {
        EntryCustomizationSnapshot(groups: Array(groups.values).sortedByOrder,
                                   customizations: customizations.filter { !$0.value.isEmpty })
    }

    public func saveGroup(_ group: EntryGroup) async throws {
        groups[group.id] = group
    }

    public func saveGroups(_ groups: [EntryGroup]) async throws {
        for group in groups {
            self.groups[group.id] = group
        }
    }

    public func deleteGroup(id: String) async throws {
        groups[id] = nil
        for (entryId, customization) in customizations where customization.groupId == id {
            var updated = customization
            updated.groupId = nil
            customizations[entryId] = updated.isEmpty ? nil : updated
        }
    }

    public func setCustomization(_ customization: EntryCustomization, for entryId: String) async throws {
        customizations[entryId] = customization.isEmpty ? nil : customization
    }

    public func removeCustomizations(for entryIds: [String]) async throws {
        for id in entryIds {
            customizations[id] = nil
        }
    }

    public func removeAllCustomizations() async throws {
        customizations = [:]
        groups = [:]
    }
}
