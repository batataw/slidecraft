//
//  HomeView.swift
//  SlideCraft
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Carousel.updatedAt, order: .reverse) private var carousels: [Carousel]

    @State private var carouselToDelete: Carousel?
    @State private var showDeleteConfirmation = false

    var body: some View {
        @Bindable var state = appState

        ZStack {
            Color.scBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // API Key Warning
                if !appState.isConfigured {
                    apiKeyWarningBanner
                }

                // Main Content
                ScrollView {
                    projectsSection
                        .padding(SCSpacing.lg)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .sheet(isPresented: $state.showSettings) {
            SettingsView()
        }
        .alert("Supprimer le projet ?", isPresented: $showDeleteConfirmation, presenting: carouselToDelete) { carousel in
            Button("Annuler", role: .cancel) {
                carouselToDelete = nil
            }
            Button("Supprimer", role: .destructive) {
                deleteCarousel(carousel)
            }
        } message: { carousel in
            Text("Le projet \"\(carousel.subject)\" et toutes ses images seront définitivement supprimés.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            // Logo & Title
            HStack(spacing: SCSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: SCRadius.md)
                        .fill(
                            LinearGradient(
                                colors: [.scPrimary, .scPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                        .resizable()
                        .frame(width: 44, height: 44)
                }
                .scGlowPrimary()

                VStack(alignment: .leading, spacing: 2) {
                    Text("SlideCraft")
                        .font(SCTypography.title2)
                        .foregroundColor(.scText)
                    Text("Cr\u{00e9}ez vos histoires en cartoon")
                        .font(SCTypography.caption)
                        .foregroundColor(.scTextTertiary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: SCSpacing.sm) {
                SCIconButton(icon: "person.2.fill") {
                    appState.navigateToCharacters()
                }
                SCIconButton(icon: "photo.artframe") {
                    appState.navigateToBackgrounds()
                }
                SCIconButton(icon: "gearshape") {
                    appState.openSettings()
                }
            }
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.vertical, SCSpacing.md)
        .background(Color.scSurface)
        .overlay(
            Rectangle()
                .fill(Color.scBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - API Key Warning

    private var apiKeyWarningBanner: some View {
        HStack(spacing: SCSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.scWarning)

            Text("Configurez vos cl\u{00e9}s API pour commencer")
                .font(SCTypography.callout)
                .foregroundColor(.scText)

            Spacer()

            Button("Configurer") {
                appState.openSettings()
            }
            .buttonStyle(SCSecondaryButtonStyle())
        }
        .padding(SCSpacing.md)
        .background(Color.scWarning.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(Color.scWarning.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Projects Section

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            // Header with button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mes Projets")
                        .font(SCTypography.headline)
                        .foregroundColor(.scText)
                    Text(carousels.isEmpty ? "Aucun projet" : "\(carousels.count) carrousel(s)")
                        .font(SCTypography.caption)
                        .foregroundColor(.scTextTertiary)
                }

                Spacer()

                Button {
                    appState.navigateToProjectSetup()
                } label: {
                    HStack(spacing: SCSpacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Nouveau")
                            .font(SCTypography.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, SCSpacing.md)
                    .padding(.vertical, SCSpacing.sm)
                    .background(Color.scPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                }
                .buttonStyle(.plain)
                .disabled(!appState.isConfigured)
                .opacity(appState.isConfigured ? 1 : 0.5)
            }

            if carousels.isEmpty {
                SCEmptyState(
                    icon: "photo.stack",
                    title: "Aucun carrousel",
                    message: "Créez votre premier carrousel pour commencer"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: SCSpacing.md) {
                    ForEach(carousels) { carousel in
                        ProjectCard(carousel: carousel) {
                            carouselToDelete = carousel
                            showDeleteConfirmation = true
                        }
                        .onTapGesture {
                            openCarousel(carousel)
                        }
                        .contextMenu {
                            Button {
                                openCarousel(carousel)
                            } label: {
                                Label("Ouvrir", systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                carouselToDelete = carousel
                                showDeleteConfirmation = true
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func openCarousel(_ carousel: Carousel) {
        appState.carouselViewModel.loadCarousel(carousel)
        appState.navigateToCarouselEditor()
    }

    private func deleteCarousel(_ carousel: Carousel) {
        // Supprimer l'image de référence
        if let refPath = carousel.referenceImagePath {
            try? FileManager.default.removeItem(atPath: refPath)
        }

        // Supprimer les images des slides
        for slide in carousel.slides {
            if let imagePath = slide.imagePath {
                try? FileManager.default.removeItem(atPath: imagePath)
            }
        }

        // Supprimer le carousel de la base
        modelContext.delete(carousel)
        carouselToDelete = nil
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let carousel: Carousel
    let onDelete: () -> Void

    @State private var isHovered = false

    private var statusText: String {
        if carousel.isComplete {
            return "Complet"
        } else if carousel.allTextsValidated {
            return "Images en cours"
        } else {
            return "Validation"
        }
    }

    private var statusColor: Color {
        if carousel.isComplete {
            return .scSuccess
        } else if carousel.allTextsValidated {
            return .scSecondary
        } else {
            return .scWarning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Preview - taille fixe
            ZStack {
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .fill(Color.scSurface)

                if let firstSlide = carousel.sortedSlides.first,
                   let imagePath = firstSlide.imagePath,
                   let image = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: SCSpacing.sm) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 28))
                            .foregroundColor(.scTextMuted)
                        Text("Aperçu")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextMuted)
                    }
                }

                // Hover overlay
                if isHovered {
                    RoundedRectangle(cornerRadius: SCRadius.md)
                        .fill(Color.scPrimary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: SCRadius.md)
                                .stroke(Color.scPrimary, lineWidth: 2)
                        )
                }

            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
            .overlay(alignment: .topTrailing) {
                // Delete button on hover
                if isHovered {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.scError)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(SCSpacing.sm)
                }
            }

            // Info - taille fixe
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                Text(carousel.subject)
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)

                HStack(spacing: SCSpacing.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 11))
                        Text("\(carousel.slides.count)")
                    }
                    .font(SCTypography.caption)
                    .foregroundColor(.scTextTertiary)

                    SCBadge(
                        text: statusText,
                        color: statusColor,
                        style: .outline
                    )
                }
            }
            .padding(SCSpacing.md)
        }
        .frame(height: 260)
        .background(Color.scCard)
        .clipShape(RoundedRectangle(cornerRadius: SCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: SCRadius.lg)
                .stroke(Color.scBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .modelContainer(for: [Carousel.self, Slide.self])
}
