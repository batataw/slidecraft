//
//  TikTokPublishView.swift
//  SlideCraft
//

import SwiftUI
import SwiftData

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
            header

            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    previewSection
                    formSection
                    statusSection
                }
                .padding(SCSpacing.xl)
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: .infinity)

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
            Text("Apercu des slides")
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

            if !tiktokService.isAuthenticated {
                HStack(spacing: SCSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.scWarning)

                    Text("Connectez votre compte TikTok dans les Reglages pour publier")
                        .font(SCTypography.callout)
                        .foregroundColor(.scText)

                    Spacer()

                    Button("Reglages") {
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

                Text("Publication reussie ! Votre carrousel est en ligne sur TikTok.")
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
            HStack(spacing: SCSpacing.xs) {
                Image(systemName: "doc.badge.clock")
                    .font(.system(size: 12))
                Text("Brouillon sauvegarde automatiquement")
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
            try? await Task.sleep(nanoseconds: 500_000_000)
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
                    carousel.tiktokPostId = postId
                    carousel.tiktokPublishedAt = Date()
                    carousel.tiktokTitle = nil
                    carousel.tiktokDescription = nil
                    try? modelContext.save()

                    isPublishing = false
                    publishSuccess = true
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishError = error.localizedDescription
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
