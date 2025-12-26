//
//  SettingsView.swift
//  SlideCraft
//
//  Dark Mode
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var openAIKey: String = ""
    @State private var geminiKey: String = ""
    @State private var showOpenAIKey: Bool = false
    @State private var showGeminiKey: Bool = false
    @State private var saveStatus: String?

    private let keychain = KeychainService.shared

    var body: some View {
        ZStack {
            Color.scBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: SCSpacing.lg) {
                        apiKeysSection
                        statusSection
                    }
                    .padding(SCSpacing.lg)
                    .frame(maxWidth: 520)
                }
                .frame(maxWidth: .infinity)

                // Footer
                footerView
            }
        }
        .frame(width: 580, height: 540)
        .onAppear {
            loadKeys()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Réglages")
                    .font(SCTypography.title2)
                    .foregroundColor(.scText)
                Text("Configuration des clés API")
                    .font(SCTypography.caption)
                    .foregroundColor(.scTextTertiary)
            }
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.scPrimary.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.scPrimary)
            }
        }
        .padding(SCSpacing.lg)
        .background(Color.scSurface)
        .overlay(
            Rectangle()
                .fill(Color.scBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - API Keys Section

    private var apiKeysSection: some View {
        SCCard {
            VStack(alignment: .leading, spacing: SCSpacing.lg) {
                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    SCSectionHeader(
                        title: "Clés API",
                        subtitle: "Stockées de manière sécurisée dans le Trousseau macOS"
                    )

                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.scSuccess)
                        Text("Vos clés sont chiffrées et sécurisées")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextSecondary)
                    }
                }

                // OpenAI Key
                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    HStack {
                        Text("Clé API OpenAI")
                            .font(SCTypography.headline)
                            .foregroundColor(.scText)

                        Spacer()

                        if keychain.hasKey(.openAIAPIKey) {
                            SCBadge(text: "Configurée", color: .scSuccess)
                        }
                    }

                    HStack(spacing: SCSpacing.sm) {
                        Group {
                            if showOpenAIKey {
                                TextField("sk-...", text: $openAIKey)
                            } else {
                                SecureField("sk-...", text: $openAIKey)
                            }
                        }
                        .textFieldStyle(SCTextFieldStyle())

                        Button {
                            showOpenAIKey.toggle()
                        } label: {
                            Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                                .foregroundColor(.scTextSecondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 32)
                    }

                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        HStack(spacing: SCSpacing.xs) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Obtenir votre clé API OpenAI")
                        }
                        .font(SCTypography.caption)
                        .foregroundColor(.scPrimary)
                    }
                }

                SCDivider()

                // Gemini Key
                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    HStack {
                        Text("Clé API Google Gemini")
                            .font(SCTypography.headline)
                            .foregroundColor(.scText)

                        Spacer()

                        if keychain.hasKey(.geminiAPIKey) {
                            SCBadge(text: "Configurée", color: .scSuccess)
                        }
                    }

                    HStack(spacing: SCSpacing.sm) {
                        Group {
                            if showGeminiKey {
                                TextField("AIza...", text: $geminiKey)
                            } else {
                                SecureField("AIza...", text: $geminiKey)
                            }
                        }
                        .textFieldStyle(SCTextFieldStyle())

                        Button {
                            showGeminiKey.toggle()
                        } label: {
                            Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                                .foregroundColor(.scTextSecondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 32)
                    }

                    Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                        HStack(spacing: SCSpacing.xs) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Obtenir votre clé API Google AI Studio")
                        }
                        .font(SCTypography.caption)
                        .foregroundColor(.scPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        SCCard {
            VStack(alignment: .leading, spacing: SCSpacing.md) {
                SCSectionHeader(title: "Statut des services")

                HStack(spacing: SCSpacing.lg) {
                    statusIndicator(
                        title: "OpenAI",
                        subtitle: "Texte",
                        icon: "text.bubble.fill",
                        isConfigured: keychain.hasKey(.openAIAPIKey)
                    )

                    statusIndicator(
                        title: "Gemini",
                        subtitle: "Images",
                        icon: "photo.fill",
                        isConfigured: keychain.hasKey(.geminiAPIKey)
                    )
                }

                if let status = saveStatus {
                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: status.contains("succès") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(status.contains("succès") ? .scSuccess : .scWarning)
                        Text(status)
                            .font(SCTypography.callout)
                            .foregroundColor(status.contains("succès") ? .scSuccess : .scWarning)
                    }
                    .padding(SCSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(status.contains("succès") ? Color.scSuccess.opacity(0.1) : Color.scWarning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func statusIndicator(title: String, subtitle: String, icon: String, isConfigured: Bool) -> some View {
        HStack(spacing: SCSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: SCRadius.sm)
                    .fill(isConfigured ? Color.scSuccess.opacity(0.15) : Color.scWarning.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isConfigured ? .scSuccess : .scWarning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                HStack(spacing: SCSpacing.xs) {
                    Circle()
                        .fill(isConfigured ? Color.scSuccess : Color.scWarning)
                        .frame(width: 6, height: 6)
                    Text(isConfigured ? "OK" : "Non défini")
                        .font(SCTypography.caption2)
                        .foregroundColor(.scTextTertiary)
                }
            }
        }
        .padding(SCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: SCRadius.md)
                .stroke(Color.scBorder, lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Annuler") {
                dismiss()
            }
            .buttonStyle(SCGhostButtonStyle())

            Spacer()

            Button {
                saveKeys()
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "checkmark")
                    Text("Enregistrer")
                }
            }
            .buttonStyle(SCPrimaryButtonStyle())
        }
        .padding(SCSpacing.lg)
        .background(Color.scSurface)
        .overlay(
            Rectangle()
                .fill(Color.scBorder)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func loadKeys() {
        openAIKey = keychain.get(key: .openAIAPIKey) ?? ""
        geminiKey = keychain.get(key: .geminiAPIKey) ?? ""
    }

    private func saveKeys() {
        if !openAIKey.isEmpty {
            _ = keychain.save(key: .openAIAPIKey, value: openAIKey)
        } else {
            keychain.delete(key: .openAIAPIKey)
        }

        if !geminiKey.isEmpty {
            _ = keychain.save(key: .geminiAPIKey, value: geminiKey)
        } else {
            keychain.delete(key: .geminiAPIKey)
        }

        withAnimation {
            saveStatus = "Clés enregistrées avec succès"
        }

        // Post notification to update services
        NotificationCenter.default.post(name: .apiKeysUpdated, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                saveStatus = nil
            }
            dismiss()
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let apiKeysUpdated = Notification.Name("apiKeysUpdated")
}

#Preview {
    SettingsView()
}
