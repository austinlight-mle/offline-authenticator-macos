//
// KeychainService.swift
// Altosec Authenticator - Created on 24/03/2025.
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

// periphery:ignore:all

import CommonUtilities
import Foundation
#if !os(macOS)
@preconcurrency import KeychainAccess
#endif

public protocol KeychainServicing: Sendable {
    func get<T: Decodable & Sendable>(keyId: String, isSynced: Bool) throws -> T
    func set(_ item: some Encodable & Sendable, for keyId: String, shouldSync: Bool) throws
    func delete(keyId: String, isSynced: Bool) throws

    @_spi(QA)
    func deleteAll(synchronized: Bool) throws
    @_spi(QA)
    func getAllContent() -> [[String: Any]]
}

public final class KeychainService: KeychainServicing {
    private let logger: LoggerProtocol
    private let backend: any KeychainBackend

    public init(service: String, accessGroup: String, logger: LoggerProtocol) {
        self.logger = logger
        backend = Self.makeBackend(service: service, accessGroup: accessGroup)
    }

    public func get<T: Decodable & Sendable>(keyId: String, isSynced: Bool) throws -> T {
        guard let data = try backend.data(forKey: keyId, synchronizable: isSynced) else {
            throw KeychainError.itemNotFound
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    public func set(_ item: some Encodable & Sendable, for keyId: String, shouldSync: Bool) throws {
        let data = try JSONEncoder().encode(item)
        try backend.set(data, forKey: keyId, synchronizable: shouldSync)
    }

    public func delete(keyId: String, isSynced: Bool = false) throws {
        try backend.remove(forKey: keyId, synchronizable: isSynced)
    }

    public func deleteAll(synchronized: Bool) throws {
        try backend.removeAll(synchronizable: synchronized)
    }

    /// Native macOS builds are signed to run locally: the keychain would ask for permission at
    /// every launch after each rebuild, so secrets go to the app's encrypted local vault instead.
    /// iOS (including "Designed for iPad" on Apple silicon) keeps the original keychain behaviour.
    private static func makeBackend(service: String, accessGroup: String) -> any KeychainBackend {
        #if os(macOS)
        LocalVaultBackend(service: service)
        #else
        SystemKeychainBackend(keychain: Keychain(service: service, accessGroup: accessGroup))
        #endif
    }

    public func getAllContent() -> [[String: Any]] {
        backend.allItems()
    }
}

private protocol KeychainBackend: Sendable {
    func data(forKey key: String, synchronizable: Bool) throws -> Data?
    func set(_ data: Data, forKey key: String, synchronizable: Bool) throws
    func remove(forKey key: String, synchronizable: Bool) throws
    func removeAll(synchronizable: Bool) throws
    func allItems() -> [[String: Any]]
}

#if os(macOS)
/// Stores every item in `LocalSecretStore`; the synchronizable flag has no meaning here.
private struct LocalVaultBackend: KeychainBackend {
    let service: String

    private func storeKey(_ key: String) -> String {
        LocalSecretStore.key(service: service, account: key)
    }

    func data(forKey key: String, synchronizable: Bool) throws -> Data? {
        LocalSecretStore.shared.data(forKey: storeKey(key))
    }

    func set(_ data: Data, forKey key: String, synchronizable: Bool) throws {
        try LocalSecretStore.shared.set(data, forKey: storeKey(key))
    }

    func remove(forKey key: String, synchronizable: Bool) throws {
        try LocalSecretStore.shared.remove(forKey: storeKey(key))
    }

    func removeAll(synchronizable: Bool) throws {
        let prefix = "\(service)/"
        for key in LocalSecretStore.shared.allKeys where key.hasPrefix(prefix) {
            try LocalSecretStore.shared.remove(forKey: key)
        }
    }

    func allItems() -> [[String: Any]] {
        LocalSecretStore.shared.allKeys.map { key in
            ["key": key, "value": "\(LocalSecretStore.shared.data(forKey: key)?.count ?? 0) bytes"]
        }
    }
}
#else
private struct SystemKeychainBackend: KeychainBackend {
    let keychain: Keychain

    func data(forKey key: String, synchronizable: Bool) throws -> Data? {
        try keychain.synchronizable(synchronizable).getData(key)
    }

    func set(_ data: Data, forKey key: String, synchronizable: Bool) throws {
        try keychain.synchronizable(synchronizable).set(data,
                                                        key: key,
                                                        ignoringAttributeSynchronizable: !synchronizable)
    }

    func remove(forKey key: String, synchronizable: Bool) throws {
        try keychain.synchronizable(synchronizable).remove(key)
    }

    func removeAll(synchronizable: Bool) throws {
        try keychain.synchronizable(synchronizable).removeAll()
    }

    func allItems() -> [[String: Any]] {
        keychain.allItems()
    }
}
#endif

public enum KeychainError: Error, Equatable, CustomDebugStringConvertible {
    case invalidData
    case itemNotFound
    case duplicateItem
    case incorrectAttributeForClass
    case unexpected(OSStatus)

    public var debugDescription: String {
        switch self {
        case .invalidData:
            "Invalid data"

        case .itemNotFound:
            "Item not found"

        case .duplicateItem:
            "Duplicate Item"

        case .incorrectAttributeForClass:
            "Incorrect Attribute for Class"

        case let .unexpected(oSStatus):
            "Unexpected error - \(oSStatus)"
        }
    }
}
