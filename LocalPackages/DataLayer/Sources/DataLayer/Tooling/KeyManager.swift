//
// KeyManager.swift
// Altosec Authenticator - Created on 30/04/2025.
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

import CommonUtilities
import CryptoKit
import Foundation
import Models
@preconcurrency import ProtonCoreKeymaker
import Security

public protocol KeysProvider: Sendable {
    func getSymmetricKey() throws -> SymmetricKey

    func get(keyId: String) throws -> Data
    func set(_ keyData: Data, for keyId: String) throws
    func clear(keyId: String, isSynced: Bool) throws
}

public extension KeysProvider {
    func clear(keyId: String, isSynced: Bool = true) throws {
        try clear(keyId: keyId, isSynced: isSynced)
    }
}

public protocol MainKeyProvider: Sendable, AnyObject {
    var mainKey: MainKey? { get }
}

#if os(macOS)
/// Native macOS builds keep the main key in the app's encrypted local vault instead of relying on
/// Proton Core's `Keymaker`, whose keychain items would prompt for access on every launch.
/// The key is stored under the same account name `Keymaker` used, so vaults migrated from the
/// keychain keep unlocking the existing symmetric key.
final class LocalMainKeyProvider: MainKeyProvider, @unchecked Sendable {
    private static let account = "NoneProtection"
    private static let length = 32
    private let lock = NSLock()
    private var cached: MainKey?

    private var storeKey: String { LocalSecretStore.key(service: AppConstants.service, account: Self.account) }

    var mainKey: MainKey? {
        lock.withLock {
            if let cached {
                return cached
            }
            if let data = LocalSecretStore.shared.data(forKey: storeKey), data.count == Self.length {
                cached = [UInt8](data)
                return cached
            }
            guard let random = try? Data.random(byteCount: Self.length) else { return nil }
            do {
                try LocalSecretStore.shared.set(random, forKey: storeKey)
            } catch {
                return nil
            }
            cached = [UInt8](random)
            return cached
        }
    }
}
#else
extension Keymaker: @unchecked @retroactive Sendable, MainKeyProvider {
    override public convenience init() {
        let keychain = CoreKeychain()
        let locker = Autolocker(lockTimeProvider: keychain)
        self.init(autolocker: locker, keychain: keychain)
    }
}

final class CoreKeychain: Keychain, @unchecked Sendable {
    init() {
        super.init(service: "me.altosec.authenticator", accessGroup: AppConstants.keychainGroup)
    }
}

extension CoreKeychain: SettingsProvider {
    private static let LockTimeKey = "AuthAccount.LockTimeKey"

    var lockTime: AutolockTimeout {
        get {
            guard let string = try? stringOrError(forKey: Self.LockTimeKey), let intValue = Int(string) else {
                return .never
            }
            return AutolockTimeout(rawValue: intValue)
        }
        set {
            do {
                try setOrError(String(newValue.rawValue), forKey: Self.LockTimeKey)
            } catch {
                print("Failed to set lockTime with error: \(error)")
            }
        }
    }
}
#endif

public final class KeysManager: KeysProvider {
    private let keychain: any KeychainServicing
    private let keyMaker: any MainKeyProvider
    private let keychainKey = "SymmetricKey"

    public init(keychain: any KeychainServicing,
                keyMaker: any MainKeyProvider = KeysManager.defaultMainKeyProvider()) {
        self.keychain = keychain
        self.keyMaker = keyMaker
    }

    public static func defaultMainKeyProvider() -> any MainKeyProvider {
        #if os(macOS)
        LocalMainKeyProvider()
        #else
        Keymaker()
        #endif
    }

    public func getSymmetricKey() throws -> SymmetricKey {
        guard let mainKey = keyMaker.mainKey else {
            throw AuthError.generic(.mainKeyNotFound)
        }

        // At this point either migration is done or no key is generated (first installation)
        // so we proceed as normal (get if exist and random if not)
        if let lockedSymmetricKeyData: Data = try? keychain.get(keyId: keychainKey, isSynced: true) {
            try migrationSymmetricKeyToUnsync(lockedSymmetricKeyData)
            return try unlockSymmetricKey(mainKey: mainKey, lockedSymmetricKeyData)
        }
        if let lockedSymmetricKeyData: Data = try? keychain.get(keyId: keychainKey, isSynced: false) {
            return try unlockSymmetricKey(mainKey: mainKey, lockedSymmetricKeyData)
        }
        return try buildSymmetricKey(mainKey: mainKey)
    }

    public func get(keyId: String) throws -> Data {
        try keychain.get(keyId: keyId, isSynced: true)
    }

    public func set(_ keyData: Data, for keyId: String) throws {
        try keychain.set(keyData, for: keyId, shouldSync: true)
    }

    public func clear(keyId: String, isSynced: Bool) throws {
        try keychain.delete(keyId: keyId, isSynced: isSynced)
    }
}

private extension KeysManager {
    func migrationSymmetricKeyToUnsync(_ lockedSymmetricKeyData: Data) throws {
        try keychain.delete(keyId: keychainKey, isSynced: true)
        try keychain.set(lockedSymmetricKeyData, for: keychainKey, shouldSync: false)
    }

    func buildSymmetricKey(mainKey: MainKey) throws -> SymmetricKey {
        let randomData = try Data.random()
        let lockedData = try Locked<Data>(clearValue: randomData, with: mainKey)
        try keychain.set(lockedData.encryptedValue, for: keychainKey, shouldSync: false)
        return .init(data: randomData)
    }

    func unlockSymmetricKey(mainKey: MainKey, _ lockedSymmetricKeyData: Data) throws -> SymmetricKey {
        let lockedData = Locked<Data>(encryptedValue: lockedSymmetricKeyData)
        var unlockedData: Data
        do {
            unlockedData = try lockedData.unlock(with: mainKey)
        } catch {
            return try buildSymmetricKey(mainKey: mainKey)
        }
        return .init(data: unlockedData)
    }
}
