//
// LocalSecretStore.swift
// Altosec Authenticator - Created on 13/10/2026.
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

#if os(macOS)
import CryptoKit
import Foundation
import IOKit
import Security

/// Encrypted, file based replacement for the keychain on native macOS.
///
/// Ad hoc signed builds get a different code signature on every build, so each keychain item
/// asks for permission again at every launch. Instead, secrets are kept in an AES-GCM sealed
/// file inside the app's sandbox container. The vault key is wrapped with a key derived from the
/// Mac's hardware UUID so the files are only readable on this machine, and both files are
/// restricted to the current user (`0600`).
///
/// Keys are namespaced as `"<service>/<account>"` to mirror the keychain layout.
public final class LocalSecretStore: @unchecked Sendable {
    public static let shared = LocalSecretStore()

    public enum StoreError: Error {
        case cannotCreateDirectory
        case corruptedVault
    }

    private let lock = NSLock()
    private let directory: URL
    private var vaultKey: SymmetricKey?
    private var items: [String: Data] = [:]
    private var loaded = false

    private var keyFile: URL { directory.appendingPathComponent("vault.key") }
    private var dataFile: URL { directory.appendingPathComponent("secrets.sealed") }

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            self.directory = base.appendingPathComponent("Altosec Authenticator/Vault", isDirectory: true)
        }
    }

    // MARK: - Public API

    public func data(forKey key: String) -> Data? {
        lock.withLock {
            loadIfNeeded()
            return items[key]
        }
    }

    public func set(_ data: Data, forKey key: String) throws {
        try lock.withLock {
            loadIfNeeded()
            items[key] = data
            try persist()
        }
    }

    public func remove(forKey key: String) throws {
        try lock.withLock {
            loadIfNeeded()
            guard items.removeValue(forKey: key) != nil else { return }
            try persist()
        }
    }

    public func removeAll() throws {
        try lock.withLock {
            loadIfNeeded()
            items.removeAll()
            try persist()
        }
    }

    public var allKeys: [String] {
        lock.withLock {
            loadIfNeeded()
            return items.keys.sorted()
        }
    }

    public static func key(service: String, account: String) -> String {
        "\(service)/\(account)"
    }

    // MARK: - Loading / persisting

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        do {
            try ensureDirectory()
            let key = try loadOrCreateVaultKey()
            vaultKey = key
            if let sealed = try? Data(contentsOf: dataFile), !sealed.isEmpty {
                let box = try AES.GCM.SealedBox(combined: sealed)
                let plain = try AES.GCM.open(box, using: key)
                items = try JSONDecoder().decode([String: Data].self, from: plain)
            } else {
                items = LegacyKeychainMigration.collectItems()
                if !items.isEmpty {
                    try persist()
                    LegacyKeychainMigration.deleteItems()
                }
            }
        } catch {
            assertionFailure("LocalSecretStore failed to load: \(error)")
            items = [:]
        }
    }

    private func persist() throws {
        guard let vaultKey else { throw StoreError.corruptedVault }
        try ensureDirectory()
        let plain = try JSONEncoder().encode(items)
        let box = try AES.GCM.seal(plain, using: vaultKey)
        guard let combined = box.combined else { throw StoreError.corruptedVault }
        try write(combined, to: dataFile)
    }

    private func ensureDirectory() throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch {
            throw StoreError.cannotCreateDirectory
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    // MARK: - Vault key

    private static let saltLength = 16
    private static let wrapInfo = Data("me.altosec.authenticator.vault-key".utf8)

    private func loadOrCreateVaultKey() throws -> SymmetricKey {
        if let wrapped = try? Data(contentsOf: keyFile), wrapped.count > Self.saltLength {
            let salt = wrapped.prefix(Self.saltLength)
            let sealed = wrapped.dropFirst(Self.saltLength)
            let box = try AES.GCM.SealedBox(combined: sealed)
            let raw = try AES.GCM.open(box, using: Self.wrappingKey(salt: salt))
            return SymmetricKey(data: raw)
        }

        let key = SymmetricKey(size: .bits256)
        var salt = Data(count: Self.saltLength)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, $0.baseAddress!) }
        let raw = key.withUnsafeBytes { Data($0) }
        let box = try AES.GCM.seal(raw, using: Self.wrappingKey(salt: salt))
        guard let combined = box.combined else { throw StoreError.corruptedVault }
        try write(salt + combined, to: keyFile)
        return key
    }

    /// Derives the key that wraps the vault key from the hardware UUID of this Mac.
    private static func wrappingKey(salt: Data) -> SymmetricKey {
        let secret = Data((hardwareUUID() ?? "altosec-authenticator-fallback").utf8)
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: secret),
                                      salt: salt,
                                      info: wrapInfo,
                                      outputByteCount: 32)
    }

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let property = IORegistryEntryCreateCFProperty(service,
                                                       kIOPlatformUUIDKey as CFString,
                                                       kCFAllocatorDefault,
                                                       0)
        return property?.takeRetainedValue() as? String
    }
}

/// One time import of the items the app used to keep in the login keychain.
private enum LegacyKeychainMigration {
    static let service = AppConstants.service
    static let accountsWithoutService = ["me.altosec.uniqueDeviceIdentifier"]

    static func collectItems() -> [String: Data] {
        var result: [String: Data] = [:]
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData: true
        ]
        var items: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
           let entries = items as? [[CFString: Any]] {
            for entry in entries {
                if let account = entry[kSecAttrAccount] as? String, let data = entry[kSecValueData] as? Data {
                    result[LocalSecretStore.key(service: service, account: account)] = data
                }
            }
        }

        for account in accountsWithoutService {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: account,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true
            ]
            var item: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data {
                result[LocalSecretStore.key(service: service, account: account)] = data
            }
        }
        return result
    }

    static func deleteItems() {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
        for account in accountsWithoutService {
            SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: account] as CFDictionary)
        }
    }
}
#endif
