import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI
import SwiftData

/// Manages Google Drive sync via REST API v3 with OAuth 2.0 (ASWebAuthenticationSession).
@Observable
final class GoogleDriveSyncService: NSObject {
    static let shared = GoogleDriveSyncService()

    // MARK: - Configuration

    private static let clientId = "" // Set from Google Cloud Console
    private static let redirectURI = "com.tyndall.memory:/oauth2callback"
    private static let scope = "https://www.googleapis.com/auth/drive.file"
    private static let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenURL = "https://oauth2.googleapis.com/token"
    private static let driveAPIBase = "https://www.googleapis.com/drive/v3"
    private static let driveUploadBase = "https://www.googleapis.com/upload/drive/v3"

    private static let keychainService = "com.tyndall.memory.gdrive"
    private static let accessTokenAccount = "access-token"
    private static let refreshTokenAccount = "refresh-token"

    // MARK: - State

    var isSignedIn = false
    var isSyncing = false
    var syncError: String?
    var lastSyncDate: Date?
    var userEmail: String?
    var syncProgress: Double = 0

    @ObservationIgnored
    @AppStorage("googleDriveEnabled") private var googleDriveEnabled = false

    @ObservationIgnored
    @AppStorage("googleDriveLastSync") private var googleDriveLastSyncRaw: Double = 0

    private var accessToken: String?
    private var refreshToken: String?

    // MARK: - Init

    private override init() {
        super.init()
        loadTokens()
        if googleDriveLastSyncRaw > 0 {
            lastSyncDate = Date(timeIntervalSince1970: googleDriveLastSyncRaw)
        }
    }

    // MARK: - OAuth 2.0 with PKCE

    /// Start the OAuth login flow using ASWebAuthenticationSession.
    @MainActor
    func signIn() async throws {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Generate random state parameter for CSRF protection
        let state = generateRandomState()

        guard var components = URLComponents(string: Self.authURL) else {
            throw GoogleDriveError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "state", value: state),
        ]

        guard let authURL = components.url else {
            throw GoogleDriveError.invalidURL
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.tyndall.memory"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: GoogleDriveError.authenticationFailed)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }

        // Extract authorization code and validate state
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw GoogleDriveError.authenticationFailed
        }

        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
    }

    /// Exchange authorization code for access/refresh tokens.
    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws {
        guard let tokenURL = URL(string: Self.tokenURL) else {
            throw GoogleDriveError.invalidURL
        }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": Self.clientId,
            "redirect_uri": Self.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier,
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResponse.access_token
        refreshToken = tokenResponse.refresh_token ?? refreshToken
        isSignedIn = true

        saveTokens()
    }

    /// Refresh the access token using the refresh token.
    func refreshAccessToken() async throws {
        guard let refreshToken else {
            throw GoogleDriveError.notSignedIn
        }

        guard let tokenURL = URL(string: Self.tokenURL) else {
            throw GoogleDriveError.invalidURL
        }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "refresh_token": refreshToken,
            "client_id": Self.clientId,
            "grant_type": "refresh_token",
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResponse.access_token
        saveTokens()
    }

    /// Sign out and clear tokens.
    func signOut() {
        accessToken = nil
        refreshToken = nil
        isSignedIn = false
        userEmail = nil
        deleteTokens()
        googleDriveEnabled = false
    }

    // MARK: - Sync Operations

    /// Perform a full sync with Google Drive.
    func sync(modelContainer: ModelContainer) async {
        guard isSignedIn, let _ = accessToken else {
            syncError = "Not signed in to Google Drive."
            return
        }

        isSyncing = true
        syncError = nil
        syncProgress = 0

        do {
            let context = ModelContext(modelContainer)

            // Ensure app folder exists
            let folderId = try await getOrCreateAppFolder()
            syncProgress = 0.1

            // Upload manifest
            let memories = (try? context.fetch(FetchDescriptor<MemoryEntry>())) ?? []
            let contacts = (try? context.fetch(FetchDescriptor<Contact>())) ?? []
            let messages = (try? context.fetch(FetchDescriptor<Message>())) ?? []

            let manifest = SyncDataSerializer.createManifest(
                memories: memories,
                contacts: contacts,
                messages: messages
            )

            let manifestData = try SyncDataSerializer.serializeAndEncrypt(manifest)
            try await uploadFile(name: "manifest.json.enc", data: manifestData, parentId: folderId)
            syncProgress = 0.2

            // Upload memories
            let memoriesFolderId = try await getOrCreateFolder(name: "memories", parentId: folderId)
            for (index, memory) in memories.enumerated() {
                let serialized = SyncDataSerializer.serialize(memory: memory)
                let encryptedData = try SyncDataSerializer.serializeAndEncrypt(serialized)
                try await uploadFile(
                    name: "\(memory.id.uuidString).json.enc",
                    data: encryptedData,
                    parentId: memoriesFolderId
                )

                // Upload photo data as separate media file
                if let photoData = memory.photoData {
                    let encryptedPhoto = try SyncDataSerializer.serializeAndEncrypt(photoData)
                    try await uploadFile(
                        name: "\(memory.id.uuidString).photo.enc",
                        data: encryptedPhoto,
                        parentId: memoriesFolderId
                    )
                }

                // Upload audio file
                if let audioPath = memory.audioFilePath {
                    let audioURL = AudioRecordingService.recordingURL(for: audioPath)
                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        let key = try EncryptionHelper.masterKey()
                        let encryptedAudio = try EncryptionHelper.encryptFileData(at: audioURL, using: key)
                        try await uploadFile(
                            name: "\(memory.id.uuidString).media.enc",
                            data: encryptedAudio,
                            parentId: memoriesFolderId
                        )
                    }
                }

                // Upload video file
                if let videoPath = memory.videoFilePath {
                    let videoURL = AudioRecordingService.recordingURL(for: videoPath)
                    if FileManager.default.fileExists(atPath: videoURL.path) {
                        let key = try EncryptionHelper.masterKey()
                        let encryptedVideo = try EncryptionHelper.encryptFileData(at: videoURL, using: key)
                        try await uploadFile(
                            name: "\(memory.id.uuidString).video.enc",
                            data: encryptedVideo,
                            parentId: memoriesFolderId
                        )
                    }
                }

                syncProgress = 0.2 + 0.5 * Double(index + 1) / Double(max(1, memories.count))
            }

            // Upload contacts
            let contactsFolderId = try await getOrCreateFolder(name: "contacts", parentId: folderId)
            for contact in contacts {
                let serialized = SyncDataSerializer.serialize(contact: contact)
                let encryptedData = try SyncDataSerializer.serializeAndEncrypt(serialized)
                try await uploadFile(
                    name: "\(contact.id.uuidString).json.enc",
                    data: encryptedData,
                    parentId: contactsFolderId
                )
            }
            syncProgress = 0.8

            // Upload messages
            let messagesFolderId = try await getOrCreateFolder(name: "messages", parentId: folderId)
            for message in messages {
                let serialized = SyncDataSerializer.serialize(message: message)
                let encryptedData = try SyncDataSerializer.serializeAndEncrypt(serialized)
                try await uploadFile(
                    name: "\(message.id.uuidString).json.enc",
                    data: encryptedData,
                    parentId: messagesFolderId
                )
            }
            syncProgress = 0.95

            // Upload key backup if in full mode
            if EncryptionLevel.current == .full, let backup = EncryptionHelper.retrieveRecoveryBackup() {
                try await uploadFile(name: "key_backup.enc", data: backup, parentId: folderId)
            }

            syncProgress = 1.0
            lastSyncDate = Date()
            googleDriveLastSyncRaw = Date().timeIntervalSince1970

        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    // MARK: - Google Drive API

    /// Get or create the "Memory App" folder in Google Drive.
    private func getOrCreateAppFolder() async throws -> String {
        try await getOrCreateFolder(name: "Memory App", parentId: nil)
    }

    /// Find or create a folder in Google Drive.
    private func getOrCreateFolder(name: String, parentId: String?) async throws -> String {
        // Search for existing folder
        var query = "name='\(name)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        if let parentId {
            query += " and '\(parentId)' in parents"
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchURL = URL(string: "\(Self.driveAPIBase)/files?q=\(encodedQuery)&fields=files(id)") else {
            throw GoogleDriveError.invalidURL
        }
        let (data, _) = try await authenticatedRequest(url: searchURL)

        struct FileList: Decodable { let files: [DriveFile] }
        struct DriveFile: Decodable { let id: String }

        let result = try JSONDecoder().decode(FileList.self, from: data)
        if let existing = result.files.first {
            return existing.id
        }

        // Create folder
        var metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
        ]
        if let parentId {
            metadata["parents"] = [parentId]
        }

        guard let createURL = URL(string: "\(Self.driveAPIBase)/files") else {
            throw GoogleDriveError.invalidURL
        }
        var request = URLRequest(url: createURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)

        let (createData, _) = try await URLSession.shared.data(for: request)
        let created = try JSONDecoder().decode(DriveFile.self, from: createData)
        return created.id
    }

    /// Upload a file to Google Drive (create or update).
    private func uploadFile(name: String, data: Data, parentId: String) async throws {
        // Check if file already exists
        let query = "name='\(name)' and '\(parentId)' in parents and trashed=false"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchURL = URL(string: "\(Self.driveAPIBase)/files?q=\(encodedQuery)&fields=files(id)") else {
            throw GoogleDriveError.invalidURL
        }
        let (searchData, _) = try await authenticatedRequest(url: searchURL)

        struct FileList: Decodable { let files: [DriveFile] }
        struct DriveFile: Decodable { let id: String }

        let result = try JSONDecoder().decode(FileList.self, from: searchData)

        if let existing = result.files.first {
            // Update existing file
            guard let updateURL = URL(string: "\(Self.driveUploadBase)/files/\(existing.id)?uploadType=media") else {
                throw GoogleDriveError.invalidURL
            }
            var request = URLRequest(url: updateURL)
            request.httpMethod = "PATCH"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            request.httpBody = data
            let _ = try await URLSession.shared.data(for: request)
        } else {
            // Create new file with multipart upload
            let boundary = UUID().uuidString
            var body = Data()

            let metadata: [String: Any] = [
                "name": name,
                "parents": [parentId],
            ]
            let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)

            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
            body.append(metadataJSON)
            body.append(Data("\r\n".utf8))
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
            body.append(data)
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))

            guard let uploadURL = URL(string: "\(Self.driveUploadBase)/files?uploadType=multipart") else {
                throw GoogleDriveError.invalidURL
            }
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            request.httpBody = body
            let _ = try await URLSession.shared.data(for: request)
        }
    }

    /// Make an authenticated GET request, refreshing token if needed.
    private func authenticatedRequest(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            try await refreshAccessToken()
            request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            return try await URLSession.shared.data(for: request)
        }

        return (data, response)
    }

    // MARK: - PKCE & Security Helpers

    private func generateRandomState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = CryptoKit.SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Token Persistence

    private func saveTokens() {
        if let token = accessToken, let data = token.data(using: .utf8) {
            saveToKeychain(data: data, account: Self.accessTokenAccount)
        }
        if let token = refreshToken, let data = token.data(using: .utf8) {
            saveToKeychain(data: data, account: Self.refreshTokenAccount)
        }
    }

    private func loadTokens() {
        if let data = loadFromKeychain(account: Self.accessTokenAccount) {
            accessToken = String(data: data, encoding: .utf8)
        }
        if let data = loadFromKeychain(account: Self.refreshTokenAccount) {
            refreshToken = String(data: data, encoding: .utf8)
        }
        isSignedIn = accessToken != nil && refreshToken != nil
    }

    private func deleteTokens() {
        deleteFromKeychain(account: Self.accessTokenAccount)
        deleteFromKeychain(account: Self.refreshTokenAccount)
    }

    private func saveToKeychain(data: Data, account: String) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Types

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let token_type: String
        let expires_in: Int
    }

    enum GoogleDriveError: LocalizedError {
        case invalidURL
        case authenticationFailed
        case tokenExchangeFailed
        case tokenRefreshFailed
        case notSignedIn
        case uploadFailed
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL."
            case .authenticationFailed: return "Google authentication failed."
            case .tokenExchangeFailed: return "Failed to exchange authorization code for tokens."
            case .tokenRefreshFailed: return "Failed to refresh access token."
            case .notSignedIn: return "Not signed in to Google Drive."
            case .uploadFailed: return "Failed to upload file to Google Drive."
            case .downloadFailed: return "Failed to download file from Google Drive."
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleDriveSyncService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
