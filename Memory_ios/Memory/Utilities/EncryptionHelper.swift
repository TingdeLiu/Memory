import Foundation
import CryptoKit
import CommonCrypto

// MARK: - Encryption Level

enum EncryptionLevel: String, CaseIterable {
    case cloudOnly  // Only encrypt when uploading to cloud (recommended)
    case full       // Encrypt sensitive fields locally + cloud

    var label: String {
        switch self {
        case .cloudOnly: return String(localized: "encryption.cloudOnly.label")
        case .full: return String(localized: "encryption.full.label")
        }
    }

    var description: String {
        switch self {
        case .cloudOnly:
            return String(localized: "encryption.cloudOnly.description")
        case .full:
            return String(localized: "encryption.full.description")
        }
    }

    var icon: String {
        switch self {
        case .cloudOnly: return "icloud.and.arrow.up"
        case .full: return "lock.shield.fill"
        }
    }

    static var current: EncryptionLevel {
        let raw = UserDefaults.standard.string(forKey: "encryptionLevel") ?? "cloudOnly"
        return EncryptionLevel(rawValue: raw) ?? .cloudOnly
    }
}

// MARK: - Encryption Helper

/// Provides AES-GCM encryption and decryption for sensitive memory data.
enum EncryptionHelper {

    private static let keychainService = "com.tyndall.memory.encryption"
    private static let masterKeyAccount = "master-encryption-key"
    private static let recoveryKeyAccount = "recovery-encrypted-master-key"

    // MARK: - Cached Master Key (Performance Optimization)

    /// In-memory cache for the master key to avoid repeated Keychain reads.
    /// Thread-safe via actor isolation or serial access pattern.
    private static var cachedMasterKey: SymmetricKey?
    private static let cacheLock = NSLock()

    // MARK: - Key Management

    /// Generate a new symmetric encryption key.
    static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    /// Get or create the master encryption key, stored in Keychain.
    /// Uses in-memory cache to avoid repeated Keychain calls (performance optimization).
    static func masterKey() throws -> SymmetricKey {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        // Return cached key if available
        if let cached = cachedMasterKey {
            return cached
        }

        // Load from Keychain or create new
        if let existing = try retrieveKeyFromKeychain(forAccount: masterKeyAccount) {
            cachedMasterKey = existing
            return existing
        }
        let newKey = generateKey()
        try storeKeyInKeychain(newKey, forAccount: masterKeyAccount)
        cachedMasterKey = newKey
        return newKey
    }

    /// Clear the cached master key (call when key changes or app locks).
    static func clearCachedMasterKey() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedMasterKey = nil
    }

    /// Derive a per-record key from the master key and a unique salt.
    static func deriveKey(from masterKey: SymmetricKey, salt: Data) -> SymmetricKey {
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: salt,
            info: Data("memory.record.key".utf8),
            outputByteCount: 32
        )
        return derived
    }

    // MARK: - Encrypt / Decrypt Data

    /// Encrypt data using AES-GCM.
    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        return combined
    }

    /// Decrypt data using AES-GCM.
    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Encrypt / Decrypt Strings

    /// Encrypt a string and return Base64-encoded ciphertext.
    static func encryptString(_ string: String, using key: SymmetricKey) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.encodingFailed
        }
        let encrypted = try encrypt(data, using: key)
        return encrypted.base64EncodedString()
    }

    /// Decrypt a Base64-encoded ciphertext back to a string.
    static func decryptString(_ base64String: String, using key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: base64String) else {
            throw EncryptionError.decodingFailed
        }
        let decrypted = try decrypt(data, using: key)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        return string
    }

    // MARK: - File Encryption

    /// Encrypt a file in place.
    static func encryptFile(at url: URL, using key: SymmetricKey) throws {
        let data = try Data(contentsOf: url)
        let encrypted = try encrypt(data, using: key)
        try encrypted.write(to: url)
    }

    /// Decrypt a file in place.
    static func decryptFile(at url: URL, using key: SymmetricKey) throws {
        let data = try Data(contentsOf: url)
        let decrypted = try decrypt(data, using: key)
        try decrypted.write(to: url)
    }

    /// Encrypt file data and return it (non-destructive).
    static func encryptFileData(at url: URL, using key: SymmetricKey) throws -> Data {
        let data = try Data(contentsOf: url)
        return try encrypt(data, using: key)
    }

    /// Decrypt a file to a temporary location for playback.
    static func decryptFileToTemp(at url: URL, using key: SymmetricKey) throws -> URL {
        let data = try Data(contentsOf: url)
        let decrypted = try decrypt(data, using: key)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        try decrypted.write(to: tempURL)
        return tempURL
    }

    // MARK: - Hashing

    /// Compute a SHA-256 hash of the given data.
    static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute a SHA-256 hash of a string.
    static func sha256(_ string: String) -> String {
        sha256(Data(string.utf8))
    }

    // MARK: - Secure Wipe

    /// Overwrite file contents with random data before deleting.
    static func secureDelete(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        if fileSize > 0 {
            var randomData = Data(count: fileSize)
            _ = randomData.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, fileSize, $0.baseAddress!) }
            try randomData.write(to: url)
        }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Key Backup & Recovery (Full Encryption Mode)

    /// Create a recovery-encrypted backup of the master key using a user-provided password.
    /// Uses PBKDF2 to derive an encryption key from the password, then encrypts the master key.
    static func backupMasterKey(withPassword password: String) throws -> Data {
        let master = try masterKey()
        let masterData = master.withUnsafeBytes { Data($0) }

        // Generate random salt for PBKDF2
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }

        // Derive key from password via PBKDF2 (using HKDF as approximation with CryptoKit)
        let passwordKey = deriveKeyFromPassword(password, salt: salt)

        // Encrypt master key with password-derived key
        let encrypted = try encrypt(masterData, using: passwordKey)

        // Combine: salt (32 bytes) + encrypted master key
        var backup = Data()
        backup.append(salt)
        backup.append(encrypted)
        return backup
    }

    /// Restore the master key from a backup using the recovery password.
    static func restoreMasterKey(from backup: Data, withPassword password: String) throws {
        guard backup.count > 32 else {
            throw EncryptionError.decodingFailed
        }

        let salt = backup.prefix(32)
        let encryptedMaster = backup.dropFirst(32)

        let passwordKey = deriveKeyFromPassword(password, salt: salt)
        let masterData = try decrypt(Data(encryptedMaster), using: passwordKey)

        let restoredKey = SymmetricKey(data: masterData)
        try storeKeyInKeychain(restoredKey, forAccount: masterKeyAccount)

        // Update cache with restored key
        cacheLock.lock()
        cachedMasterKey = restoredKey
        cacheLock.unlock()
    }

    /// Derive a symmetric key from a password and salt using PBKDF2-HMAC-SHA256.
    /// Uses 310,000 iterations per OWASP 2023 recommendation for brute-force resistance.
    private static func deriveKeyFromPassword(_ password: String, salt: Data) -> SymmetricKey {
        var derivedKeyData = Data(count: 32)
        let iterations: UInt32 = 310_000

        let status = derivedKeyData.withUnsafeMutableBytes { derivedKeyPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password,
                    password.utf8.count,
                    saltPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    derivedKeyPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    32
                )
            }
        }

        if status != kCCSuccess {
            // Fallback to HKDF if PBKDF2 unavailable (should not happen on iOS)
            let inputKey = SymmetricKey(data: Data(password.utf8))
            return HKDF<SHA256>.deriveKey(
                inputKeyMaterial: inputKey,
                salt: salt,
                info: Data("memory.recovery.key".utf8),
                outputByteCount: 32
            )
        }

        return SymmetricKey(data: derivedKeyData)
    }

    // MARK: - Keychain

    /// Store a key in the Keychain.
    static func storeKeyInKeychain(_ key: SymmetricKey, forAccount account: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
    }

    /// Retrieve a key from the Keychain.
    static func retrieveKeyFromKeychain(forAccount account: String) throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let keyData = result as? Data else {
            throw EncryptionError.keychainError(status)
        }

        return SymmetricKey(data: keyData)
    }

    /// Delete a key from the Keychain.
    static func deleteKeyFromKeychain(forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Delete the master encryption key (used during full data wipe).
    static func deleteMasterKey() {
        clearCachedMasterKey()
        deleteKeyFromKeychain(forAccount: masterKeyAccount)
    }

    /// Store recovery backup data in Keychain.
    static func storeRecoveryBackup(_ data: Data) throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: recoveryKeyAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: recoveryKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
    }

    /// Retrieve recovery backup data from Keychain.
    static func retrieveRecoveryBackup() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: recoveryKeyAccount,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    // MARK: - Errors

    enum EncryptionError: LocalizedError {
        case encryptionFailed
        case encodingFailed
        case decodingFailed
        case keychainError(OSStatus)
        case recoveryFailed

        var errorDescription: String? {
            switch self {
            case .encryptionFailed:
                return "Failed to encrypt data."
            case .encodingFailed:
                return "Failed to encode data for encryption."
            case .decodingFailed:
                return "Failed to decode decrypted data."
            case .keychainError(let status):
                return "Keychain error (code \(status))."
            case .recoveryFailed:
                return "Failed to recover master key. Please check your recovery password."
            }
        }
    }
}

// MARK: - Encrypted Field Helper

/// Provides per-record field-level encryption for SwiftData models in full encryption mode.
enum EncryptedFieldHelper {

    /// Encrypt a string value for a specific record. Returns Base64-encoded ciphertext.
    static func encryptString(_ value: String, recordId: UUID) -> String? {
        do {
            let master = try EncryptionHelper.masterKey()
            let key = EncryptionHelper.deriveKey(from: master, salt: Data(recordId.uuidString.utf8))
            return try EncryptionHelper.encryptString(value, using: key)
        } catch {
            print("[EncryptedFieldHelper] encryptString failed for record \(recordId): \(error.localizedDescription)")
            return nil
        }
    }

    /// Decrypt a Base64-encoded ciphertext for a specific record.
    static func decryptString(_ encrypted: String, recordId: UUID) -> String? {
        do {
            let master = try EncryptionHelper.masterKey()
            let key = EncryptionHelper.deriveKey(from: master, salt: Data(recordId.uuidString.utf8))
            return try EncryptionHelper.decryptString(encrypted, using: key)
        } catch {
            print("[EncryptedFieldHelper] decryptString failed for record \(recordId): \(error.localizedDescription)")
            return nil
        }
    }

    /// Encrypt binary data for a specific record.
    static func encryptData(_ value: Data, recordId: UUID) -> Data? {
        do {
            let master = try EncryptionHelper.masterKey()
            let key = EncryptionHelper.deriveKey(from: master, salt: Data(recordId.uuidString.utf8))
            return try EncryptionHelper.encrypt(value, using: key)
        } catch {
            print("[EncryptedFieldHelper] encryptData failed for record \(recordId): \(error.localizedDescription)")
            return nil
        }
    }

    /// Decrypt binary data for a specific record.
    static func decryptData(_ encrypted: Data, recordId: UUID) -> Data? {
        do {
            let master = try EncryptionHelper.masterKey()
            let key = EncryptionHelper.deriveKey(from: master, salt: Data(recordId.uuidString.utf8))
            return try EncryptionHelper.decrypt(encrypted, using: key)
        } catch {
            print("[EncryptedFieldHelper] decryptData failed for record \(recordId): \(error.localizedDescription)")
            return nil
        }
    }

    /// Encrypt a string array (tags) for a specific record. Encodes as JSON then encrypts.
    static func encryptStringArray(_ value: [String], recordId: UUID) -> String? {
        guard let jsonData = try? JSONEncoder().encode(value),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        return encryptString(jsonString, recordId: recordId)
    }

    /// Decrypt an encrypted string array (tags) for a specific record.
    static func decryptStringArray(_ encrypted: String, recordId: UUID) -> [String]? {
        guard let jsonString = decryptString(encrypted, recordId: recordId),
              let jsonData = jsonString.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: jsonData) else { return nil }
        return array
    }
}
