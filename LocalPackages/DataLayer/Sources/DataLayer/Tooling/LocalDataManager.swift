//
// LocalDataManager.swift
// Altosec Authenticator - Created on 03/06/2025.
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
import Models
import SimplyPersist
import SwiftData

public protocol LocalDataManagerProtocol: Sendable, Actor {
    var persistentStorage: any PersistenceServicing { get }

    func refreshLocalStorage() async
}

public actor LocalDataManager: LocalDataManagerProtocol {
    private let settingsService: any SettingsServicing

    public private(set) var persistentStorage: any PersistenceServicing

    @MainActor
    public init(settingsService: any SettingsServicing) {
        self.settingsService = settingsService
        persistentStorage = LocalDataManager
            .createPersistenceService(iCloudSyncEnabled: settingsService.iCloudSync)
    }

    public func refreshLocalStorage() async {
        let iCloudSyncEnabled = await settingsService.iCloudSync
        persistentStorage = LocalDataManager.createPersistenceService(iCloudSyncEnabled: iCloudSyncEnabled)
    }
}

private extension LocalDataManager {
    static func createPersistenceService(iCloudSyncEnabled: Bool) -> PersistenceService {
        let cloudKitDatabase: ModelConfiguration
            .CloudKitDatabase = iCloudSyncEnabled ? .private("iCloud.me.altosec.authenticator") : .none
        do {
            if #available(iOS 18, *) {
                let entryConfig = ModelConfiguration(schema: Schema([EncryptedEntryEntity.self]),
                                                     isStoredInMemoryOnly: false,
                                                     cloudKitDatabase: cloudKitDatabase)
                // Groups and entry customizations are device local metadata, so they live in the
                // non CloudKit store next to logs and user data.
                let localDataConfig = ModelConfiguration("localData",
                                                         schema: Schema([
                                                             LogEntryEntity.self,
                                                             EncryptedUserDataEntity.self,
                                                             EntryGroupEntity.self,
                                                             EntryMetadataEntity.self
                                                         ]),
                                                         isStoredInMemoryOnly: false,
                                                         cloudKitDatabase: .none)
                return try PersistenceService(for: EncryptedEntryEntity.self,
                                              LogEntryEntity.self,
                                              EncryptedUserDataEntity.self,
                                              EntryGroupEntity.self,
                                              EntryMetadataEntity.self,
                                              configurations: entryConfig,
                                              localDataConfig)
            } else {
                // iOS 17 fallback: Single store (no CloudKit)
                let allInOneConfig = ModelConfiguration(schema: Schema([
                    EncryptedEntryEntity.self,
                    LogEntryEntity.self,
                    EncryptedUserDataEntity.self,
                    EntryGroupEntity.self,
                    EntryMetadataEntity.self
                ]),
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none)

                return try PersistenceService(for: EncryptedEntryEntity.self,
                                              LogEntryEntity.self,
                                              EncryptedUserDataEntity.self,
                                              EntryGroupEntity.self,
                                              EntryMetadataEntity.self,
                                              configurations: allInOneConfig)
            }
        } catch {
            fatalError("Should have persistence storage \(error)")
        }
    }
}
