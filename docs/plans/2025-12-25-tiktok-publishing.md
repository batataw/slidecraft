# TikTok Publishing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add direct TikTok Photo Carousel publishing from SlideCraft with OAuth authentication, draft saving, and status badges.

**Architecture:** OAuth 2.0 flow using ASWebAuthenticationSession for login, tokens stored in Keychain, dedicated TikTokPublishView for composing posts, and draft persistence on Carousel model for retry on failure.

**Tech Stack:** SwiftUI, AuthenticationServices (ASWebAuthenticationSession), Security (Keychain), TikTok Content Posting API

---

## Task 1: Add TikTok Fields to Carousel Model

**Files:**
- Modify: `SlideCraft/Models/Carousel.swift`

**Step 1: Add TikTok properties to Carousel**

```swift
// Add after line 17 (after referenceImagePath)
// TikTok publishing
var tiktokTitle: String?
var tiktokDescription: String?
var tiktokPostId: String?
var tiktokPublishedAt: Date?
```

**Step 2: Add computed property for publish status**

```swift
// Add after isComplete computed property (after line 43)
var tiktokPublishStatus: TikTokPublishStatus {
    if tiktokPostId != nil {
        return .published
    } else if tiktokTitle != nil || tiktokDescription != nil {
        return .draft
    }
    return .none
}
```

**Step 3: Add TikTokPublishStatus enum (before @Model)**

```swift
enum TikTokPublishStatus {
    case none
    case draft
    case published
}
```

**Step 4: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add SlideCraft/Models/Carousel.swift
git commit -m "feat(model): add TikTok publishing fields to Carousel"
```

---

## Task 2: Add TikTok Keychain Keys

**Files:**
- Modify: `SlideCraft/Services/KeychainService.swift`

**Step 1: Add TikTok keys to KeychainKey enum**

```swift
// Add to KeychainKey enum (after line 11)
case tiktokAccessToken = "com.slidecraft.tiktok-access-token"
case tiktokRefreshToken = "com.slidecraft.tiktok-refresh-token"
case tiktokOpenId = "com.slidecraft.tiktok-open-id"
```

**Step 2: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add SlideCraft/Services/KeychainService.swift
git commit -m "feat(keychain): add TikTok token storage keys"
```

---

## Task 3: Create TikTokService Protocol and Implementation

**Files:**
- Create: `SlideCraft/Services/TikTokService.swift`

**Step 1: Create TikTokService.swift with protocol and implementation**

```swift
//
//  TikTokService.swift
//  SlideCraft
//

import Foundation
import AuthenticationServices

// MARK: - Errors

enum TikTokError: LocalizedError {
    case notAuthenticated
    case authenticationFailed(String)
    case tokenRefreshFailed
    case uploadFailed(String)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Non connecté à TikTok. Connectez-vous dans les Réglages."
        case .authenticationFailed(let message):
            return "Échec de l'authentification: \(message)"
        case .tokenRefreshFailed:
            return "Session expirée. Reconnectez-vous dans les Réglages."
        case .uploadFailed(let message):
            return "Échec de la publication: \(message)"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        case .invalidResponse:
            return "Réponse invalide du serveur TikTok"
        }
    }
}

// MARK: - Protocol

protocol TikTokServiceProtocol: Sendable {
    var isAuthenticated: Bool { get }
    var username: String? { get }
    func authenticate() async throws
    func disconnect()
    func publishCarousel(images: [URL], title: String, description: String) async throws -> String
}

// MARK: - Implementation

final class TikTokService: TikTokServiceProtocol, @unchecked Sendable {

    // TODO: Replace with your TikTok app credentials
    private let clientKey = "YOUR_TIKTOK_CLIENT_KEY"
    private let clientSecret = "YOUR_TIKTOK_CLIENT_SECRET"
    private let redirectURI = "slidecraft://tiktok/callback"

    private let keychain = KeychainService.shared

    var isAuthenticated: Bool {
        keychain.hasKey(.tiktokAccessToken)
    }

    var username: String? {
        // For now, return a placeholder if authenticated
        // In production, fetch from TikTok user info endpoint
        isAuthenticated ? "@utilisateur" : nil
    }

    // MARK: - Authentication

    func authenticate() async throws {
        let state = UUID().uuidString
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: "https://www.tiktok.com/v2/auth/authorize/")!
        components.queryItems = [
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "user.info.basic,video.publish"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw TikTokError.authenticationFailed("URL invalide")
        }

        let callbackURL = try await performOAuth(url: authURL)

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw TikTokError.authenticationFailed("Paramètres de callback invalides")
        }

        try await exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
    }

    func disconnect() {
        keychain.delete(key: .tiktokAccessToken)
        keychain.delete(key: .tiktokRefreshToken)
        keychain.delete(key: .tiktokOpenId)
    }

    // MARK: - Publishing

    func publishCarousel(images: [URL], title: String, description: String) async throws -> String {
        guard isAuthenticated else {
            throw TikTokError.notAuthenticated
        }

        // Ensure we have a valid token
        try await refreshTokenIfNeeded()

        guard let accessToken = keychain.get(key: .tiktokAccessToken),
              let openId = keychain.get(key: .tiktokOpenId) else {
            throw TikTokError.notAuthenticated
        }

        // Step 1: Initialize photo post
        let postId = try await initializePhotoPost(
            accessToken: accessToken,
            openId: openId,
            title: title,
            description: description,
            photoCount: images.count
        )

        // Step 2: Upload each image
        for (index, imageURL) in images.enumerated() {
            try await uploadImage(
                accessToken: accessToken,
                postId: postId,
                imageURL: imageURL,
                index: index
            )
        }

        // Step 3: Publish the post
        try await finalizePost(accessToken: accessToken, postId: postId)

        return postId
    }

    // MARK: - Private Helpers

    @MainActor
    private func performOAuth(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "slidecraft"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: TikTokError.authenticationFailed(error.localizedDescription))
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: TikTokError.authenticationFailed("Pas de callback"))
                }
            }

            session.presentationContextProvider = PresentationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws {
        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/oauth/token/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_key": clientKey,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TikTokError.authenticationFailed("Échec de l'échange de token")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let accessToken = json?["access_token"] as? String,
              let refreshToken = json?["refresh_token"] as? String,
              let openId = json?["open_id"] as? String else {
            throw TikTokError.invalidResponse
        }

        _ = keychain.save(key: .tiktokAccessToken, value: accessToken)
        _ = keychain.save(key: .tiktokRefreshToken, value: refreshToken)
        _ = keychain.save(key: .tiktokOpenId, value: openId)
    }

    private func refreshTokenIfNeeded() async throws {
        guard let refreshToken = keychain.get(key: .tiktokRefreshToken) else {
            throw TikTokError.notAuthenticated
        }

        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/oauth/token/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_key": clientKey,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Token refresh failed, user needs to re-authenticate
            disconnect()
            throw TikTokError.tokenRefreshFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let accessToken = json?["access_token"] as? String {
            _ = keychain.save(key: .tiktokAccessToken, value: accessToken)
        }
        if let newRefreshToken = json?["refresh_token"] as? String {
            _ = keychain.save(key: .tiktokRefreshToken, value: newRefreshToken)
        }
    }

    private func initializePhotoPost(accessToken: String, openId: String, title: String, description: String, photoCount: Int) async throws -> String {
        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/post/publish/content/init/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "post_info": [
                "title": title,
                "description": description,
                "disable_comment": false,
                "privacy_level": "PUBLIC_TO_EVERYONE"
            ],
            "source_info": [
                "source": "FILE_UPLOAD",
                "photo_cover_index": 0,
                "photo_images": (0..<photoCount).map { _ in ["image_type": "JPEG"] }
            ],
            "post_mode": "DIRECT_POST",
            "media_type": "PHOTO"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TikTokError.uploadFailed("Échec de l'initialisation")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataDict = json?["data"] as? [String: Any],
              let publishId = dataDict["publish_id"] as? String else {
            throw TikTokError.invalidResponse
        }

        return publishId
    }

    private func uploadImage(accessToken: String, postId: String, imageURL: URL, index: Int) async throws {
        // Read image data
        let imageData = try Data(contentsOf: imageURL)

        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/post/publish/content/upload/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add publish_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"publish_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(postId)\r\n".data(using: .utf8)!)

        // Add image_index field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image_index\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(index)\r\n".data(using: .utf8)!)

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"slide_\(index).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TikTokError.uploadFailed("Échec de l'upload de l'image \(index + 1)")
        }
    }

    private func finalizePost(accessToken: String, postId: String) async throws {
        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/post/publish/status/fetch/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["publish_id": postId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Poll for completion
        for _ in 0..<30 {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TikTokError.uploadFailed("Échec de la vérification du statut")
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let dataDict = json?["data"] as? [String: Any],
               let status = dataDict["status"] as? String {
                if status == "PUBLISH_COMPLETE" {
                    return
                } else if status == "FAILED" {
                    let reason = dataDict["fail_reason"] as? String ?? "Raison inconnue"
                    throw TikTokError.uploadFailed(reason)
                }
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        throw TikTokError.uploadFailed("Timeout lors de la publication")
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation Context Provider

private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - CommonCrypto Import

import CommonCrypto
```

**Step 2: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add SlideCraft/Services/TikTokService.swift
git commit -m "feat(service): add TikTokService with OAuth and publishing"
```

---

## Task 4: Add URL Scheme for OAuth Callback

**Files:**
- Modify: `SlideCraft/Info.plist` (via Xcode project settings)
- Create: `SlideCraft/SlideCraft.entitlements` (if not exists)

**Step 1: Add URL scheme to Info.plist**

Add to project's Info.plist (or via Target > Info > URL Types):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.slidecraft.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>slidecraft</string>
        </array>
    </dict>
</array>
```

**Step 2: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add SlideCraft/Info.plist
git commit -m "feat(config): add slidecraft URL scheme for OAuth callback"
```

---

## Task 5: Add TikTok Section to SettingsView

**Files:**
- Modify: `SlideCraft/Views/SettingsView.swift`

**Step 1: Add TikTok state variables**

```swift
// Add after line 17 (after saveStatus)
@State private var tiktokService = TikTokService()
@State private var isConnectingTikTok = false
@State private var tiktokError: String?
```

**Step 2: Add tiktokSection to ScrollView content (after statusSection)**

```swift
// Add after statusSection in the ScrollView VStack (around line 34)
tiktokSection
```

**Step 3: Add the tiktokSection computed property**

```swift
// Add after statusSection computed property (after line 234)

// MARK: - TikTok Section

private var tiktokSection: some View {
    SCCard {
        VStack(alignment: .leading, spacing: SCSpacing.lg) {
            SCSectionHeader(
                title: "TikTok",
                subtitle: "Publiez vos carrousels directement sur TikTok"
            )

            if tiktokService.isAuthenticated {
                // Connected state
                HStack {
                    HStack(spacing: SCSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.scSuccess.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.scSuccess)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Compte connecté")
                                .font(SCTypography.headline)
                                .foregroundColor(.scText)
                            Text(tiktokService.username ?? "@utilisateur")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)
                        }
                    }

                    Spacer()

                    Button("Déconnecter") {
                        tiktokService.disconnect()
                    }
                    .buttonStyle(SCGhostButtonStyle())
                }
            } else {
                // Disconnected state
                VStack(alignment: .leading, spacing: SCSpacing.md) {
                    HStack(spacing: SCSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.scTextTertiary.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .foregroundColor(.scTextTertiary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Non connecté")
                                .font(SCTypography.headline)
                                .foregroundColor(.scText)
                            Text("Connectez votre compte TikTok pour publier")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)
                        }
                    }

                    Button {
                        connectTikTok()
                    } label: {
                        HStack(spacing: SCSpacing.sm) {
                            if isConnectingTikTok {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isConnectingTikTok ? "Connexion..." : "Connecter mon compte")
                        }
                    }
                    .buttonStyle(SCPrimaryButtonStyle())
                    .disabled(isConnectingTikTok)

                    if let error = tiktokError {
                        HStack(spacing: SCSpacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.scError)
                            Text(error)
                                .font(SCTypography.caption)
                                .foregroundColor(.scError)
                        }
                    }
                }
            }
        }
    }
}

private func connectTikTok() {
    isConnectingTikTok = true
    tiktokError = nil

    Task {
        do {
            try await tiktokService.authenticate()
            await MainActor.run {
                isConnectingTikTok = false
            }
        } catch {
            await MainActor.run {
                isConnectingTikTok = false
                tiktokError = error.localizedDescription
            }
        }
    }
}
```

**Step 4: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add SlideCraft/Views/SettingsView.swift
git commit -m "feat(settings): add TikTok connection section"
```

---

## Task 6: Create TikTokPublishView

**Files:**
- Create: `SlideCraft/Views/TikTokPublishView.swift`

**Step 1: Create the view file**

```swift
//
//  TikTokPublishView.swift
//  SlideCraft
//

import SwiftUI
import SwiftData
import Combine

struct TikTokPublishView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isPublishing: Bool = false
    @State private var publishError: String?
    @State private var publishSuccess: Bool = false

    private let tiktokService = TikTokService()
    private let maxTitleLength = 150
    private let maxDescriptionLength = 2200

    // Debounce for auto-save
    @State private var saveTask: Task<Void, Never>?

    private var carousel: Carousel? {
        appState.carouselViewModel.currentCarousel
    }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        tiktokService.isAuthenticated &&
        !isPublishing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    // Preview
                    previewSection

                    // Form
                    formSection

                    // Error/Success messages
                    statusSection
                }
                .padding(SCSpacing.xl)
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: .infinity)

            // Footer
            footer
        }
        .frame(minWidth: 700, minHeight: 600)
        .background(Color.scBackground)
        .onAppear {
            loadDraft()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                appState.navigateToCarouselEditor()
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text("Retour")
                }
            }
            .buttonStyle(SCGhostButtonStyle())

            Spacer()

            Text("Publier sur TikTok")
                .font(SCTypography.headline)
                .foregroundColor(.scText)

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 80)
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.vertical, SCSpacing.md)
        .background(Color.scBackgroundSecondary)
        .overlay(alignment: .bottom) {
            SCDivider()
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            Text("Aperçu des slides")
                .font(SCTypography.caption)
                .foregroundColor(.scTextTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SCSpacing.md) {
                    if let carousel = carousel {
                        ForEach(Array(carousel.sortedSlides.enumerated()), id: \.element.id) { index, slide in
                            if let imagePath = slide.imagePath,
                               let image = NSImage(contentsOfFile: imagePath) {
                                VStack(spacing: SCSpacing.xs) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(4/5, contentMode: .fill)
                                        .frame(width: 80, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: SCRadius.sm)
                                                .stroke(Color.scBorder, lineWidth: 1)
                                        )

                                    Text("\(index + 1)")
                                        .font(SCTypography.caption2)
                                        .foregroundColor(.scTextTertiary)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, SCSpacing.sm)
            }
        }
        .padding(SCSpacing.lg)
        .background(Color.scCard)
        .clipShape(RoundedRectangle(cornerRadius: SCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: SCRadius.lg)
                .stroke(Color.scBorder, lineWidth: 1)
        )
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.lg) {
            // Title field
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                HStack {
                    Text("Titre")
                        .font(SCTypography.headline)
                        .foregroundColor(.scText)

                    Spacer()

                    Text("\(title.count)/\(maxTitleLength)")
                        .font(SCTypography.caption)
                        .foregroundColor(title.count > maxTitleLength ? .scError : .scTextTertiary)
                }

                TextField("Titre de votre publication...", text: $title)
                    .textFieldStyle(SCTextFieldStyle())
                    .onChange(of: title) {
                        scheduleSave()
                    }
            }

            // Description field
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                HStack {
                    Text("Description")
                        .font(SCTypography.headline)
                        .foregroundColor(.scText)

                    Spacer()

                    Text("\(description.count)/\(maxDescriptionLength)")
                        .font(SCTypography.caption)
                        .foregroundColor(description.count > maxDescriptionLength ? .scError : .scTextTertiary)
                }

                TextEditor(text: $description)
                    .font(SCTypography.body)
                    .foregroundColor(.scText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(SCSpacing.md)
                    .background(Color.scSurface)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: SCRadius.md)
                            .stroke(Color.scBorder, lineWidth: 1)
                    )
                    .onChange(of: description) {
                        scheduleSave()
                    }
            }

            // TikTok connection status
            if !tiktokService.isAuthenticated {
                HStack(spacing: SCSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.scWarning)

                    Text("Connectez votre compte TikTok dans les Réglages pour publier")
                        .font(SCTypography.callout)
                        .foregroundColor(.scText)

                    Spacer()

                    Button("Réglages") {
                        appState.openSettings()
                    }
                    .buttonStyle(SCSecondaryButtonStyle())
                }
                .padding(SCSpacing.md)
                .background(Color.scWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
            }
        }
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        if let error = publishError {
            HStack(spacing: SCSpacing.md) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.scError)

                Text(error)
                    .font(SCTypography.callout)
                    .foregroundColor(.scError)

                Spacer()

                Button {
                    publishError = nil
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.scTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(SCSpacing.md)
            .background(Color.scError.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
        }

        if publishSuccess {
            HStack(spacing: SCSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.scSuccess)

                Text("Publication réussie ! Votre carrousel est en ligne sur TikTok.")
                    .font(SCTypography.callout)
                    .foregroundColor(.scSuccess)

                Spacer()
            }
            .padding(SCSpacing.md)
            .background(Color.scSuccess.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Draft indicator
            HStack(spacing: SCSpacing.xs) {
                Image(systemName: "doc.badge.clock")
                    .font(.system(size: 12))
                Text("Brouillon sauvegardé automatiquement")
                    .font(SCTypography.caption)
            }
            .foregroundColor(.scTextTertiary)

            Spacer()

            Button {
                publish()
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    if isPublishing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("Publication en cours...")
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("Publier")
                    }
                }
            }
            .buttonStyle(SCPrimaryButtonStyle())
            .disabled(!canPublish)
        }
        .padding(SCSpacing.lg)
        .background(Color.scBackgroundSecondary)
        .overlay(alignment: .top) {
            SCDivider()
        }
    }

    // MARK: - Actions

    private func loadDraft() {
        guard let carousel = carousel else { return }
        title = carousel.tiktokTitle ?? ""
        description = carousel.tiktokDescription ?? ""
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            await MainActor.run {
                saveDraft()
            }
        }
    }

    private func saveDraft() {
        guard let carousel = carousel else { return }
        carousel.tiktokTitle = title.isEmpty ? nil : title
        carousel.tiktokDescription = description.isEmpty ? nil : description
        carousel.updatedAt = Date()
        try? modelContext.save()
    }

    private func publish() {
        guard let carousel = carousel else { return }

        isPublishing = true
        publishError = nil
        publishSuccess = false

        // Collect image URLs
        let imageURLs = carousel.sortedSlides.compactMap { slide -> URL? in
            guard let path = slide.imagePath else { return nil }
            return URL(fileURLWithPath: path)
        }

        Task {
            do {
                let postId = try await tiktokService.publishCarousel(
                    images: imageURLs,
                    title: title,
                    description: description
                )

                await MainActor.run {
                    // Update carousel with success info
                    carousel.tiktokPostId = postId
                    carousel.tiktokPublishedAt = Date()
                    carousel.tiktokTitle = nil  // Clear draft
                    carousel.tiktokDescription = nil
                    try? modelContext.save()

                    isPublishing = false
                    publishSuccess = true
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishError = error.localizedDescription
                    // Draft is already saved, so user can retry
                }
            }
        }
    }
}

#Preview {
    TikTokPublishView()
        .environment(AppState())
        .modelContainer(for: [Carousel.self, Slide.self])
}
```

**Step 2: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add SlideCraft/Views/TikTokPublishView.swift
git commit -m "feat(view): add TikTokPublishView for publishing carousels"
```

---

## Task 7: Add Navigation to TikTokPublishView

**Files:**
- Modify: `SlideCraft/ViewModels/AppState.swift`
- Modify: `SlideCraft/ContentView.swift`

**Step 1: Add tiktokPublish case to AppScreen enum**

```swift
// Add to AppScreen enum (after line 15)
case tiktokPublish
```

**Step 2: Add navigation function to AppState**

```swift
// Add after navigateToCarouselEditor() function (after line 86)
func navigateToTikTokPublish() {
    currentScreen = .tiktokPublish
}
```

**Step 3: Add case to ContentView switch**

```swift
// Add to switch statement in ContentView (after line 23)
case .tiktokPublish:
    TikTokPublishView()
```

**Step 4: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add SlideCraft/ViewModels/AppState.swift SlideCraft/ContentView.swift
git commit -m "feat(navigation): add TikTok publish screen navigation"
```

---

## Task 8: Add TikTok Button to CarouselEditorView

**Files:**
- Modify: `SlideCraft/Views/CarouselEditorView.swift`

**Step 1: Add TikTok service state**

```swift
// Add after exportService declaration (around line 43)
private let tiktokService = TikTokService()
```

**Step 2: Add TikTok button to rightActions (in the export buttons section)**

Find the HStack with export buttons (around line 179) and add the TikTok button:

```swift
// Replace the export buttons HStack (lines 179-215) with:
HStack(spacing: SCSpacing.sm) {
    Button {
        showSocialDescriptionSheet = true
        Task {
            await viewModel.generateSocialContent()
        }
    } label: {
        HStack(spacing: SCSpacing.xs) {
            Image(systemName: "text.bubble")
            Text("Description")
        }
    }
    .buttonStyle(SCGhostButtonStyle())
    .disabled(viewModel.isGeneratingSocialContent)

    Button {
        appState.navigateToTikTokPublish()
    } label: {
        HStack(spacing: SCSpacing.xs) {
            Image(systemName: "play.rectangle.fill")
            Text("TikTok")
        }
    }
    .buttonStyle(SCSecondaryButtonStyle())
    .disabled(!tiktokService.isAuthenticated)
    .help(tiktokService.isAuthenticated ? "Publier sur TikTok" : "Connectez TikTok dans les Réglages")

    Button {
        exportAsZIP()
    } label: {
        HStack(spacing: SCSpacing.xs) {
            Image(systemName: "photo.on.rectangle")
            Text("ZIP")
        }
    }
    .buttonStyle(SCSecondaryButtonStyle())
    .disabled(isExporting)

    Button {
        exportAsPDF()
    } label: {
        HStack(spacing: SCSpacing.xs) {
            Image(systemName: "doc.richtext")
            Text("PDF")
        }
    }
    .buttonStyle(SCPrimaryButtonStyle())
    .disabled(isExporting)
}
```

**Step 3: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 4: Commit**

```bash
git add SlideCraft/Views/CarouselEditorView.swift
git commit -m "feat(editor): add TikTok publish button"
```

---

## Task 9: Add Status Badges to HomeView

**Files:**
- Modify: `SlideCraft/Views/HomeView.swift`

**Step 1: Update ProjectCard statusText computed property**

Replace the statusText and statusColor computed properties (lines 250-268):

```swift
private var statusText: String {
    switch carousel.tiktokPublishStatus {
    case .published:
        return "Publié"
    case .draft:
        return "Brouillon"
    case .none:
        if carousel.isComplete {
            return "Complet"
        } else if carousel.allTextsValidated {
            return "Images en cours"
        } else {
            return "Validation"
        }
    }
}

private var statusColor: Color {
    switch carousel.tiktokPublishStatus {
    case .published:
        return .scSuccess
    case .draft:
        return .orange
    case .none:
        if carousel.isComplete {
            return .scSuccess
        } else if carousel.allTextsValidated {
            return .scSecondary
        } else {
            return .scWarning
        }
    }
}
```

**Step 2: Build to verify**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add SlideCraft/Views/HomeView.swift
git commit -m "feat(home): add TikTok publish status badges"
```

---

## Task 10: Final Build and Test

**Step 1: Clean build**

```bash
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug clean build 2>&1 | tail -30
```

**Step 2: Manual testing checklist**

1. Open Settings, verify TikTok section appears
2. Create a carousel, complete all slides
3. Verify TikTok button appears in CarouselEditorView
4. Open TikTokPublishView, verify draft saves
5. Close and reopen, verify draft loads
6. Check HomeView badges show correct status

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete TikTok publishing feature

- Add TikTok OAuth authentication
- Add TikTokPublishView for composing posts
- Auto-save drafts for retry on failure
- Add status badges on HomeView
- Add TikTok section in Settings"
```

---

## Prerequisites (User Action Required)

Before testing the full OAuth flow:

1. **Create TikTok Developer Account:**
   - Go to https://developers.tiktok.com/
   - Register as a developer

2. **Create TikTok App:**
   - Create new app in TikTok Developer Portal
   - Add "Login Kit" and "Content Posting API" products
   - Set redirect URI to: `slidecraft://tiktok/callback`
   - Note your Client Key and Client Secret

3. **Update TikTokService.swift:**
   - Replace `YOUR_TIKTOK_CLIENT_KEY` with your actual client key
   - Replace `YOUR_TIKTOK_CLIENT_SECRET` with your actual client secret

4. **Submit for Review:**
   - TikTok requires app review before production use
   - For development, use sandbox mode
